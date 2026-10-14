import SwiftUI
import AppKit
import Observation
import UniformTypeIdentifiers
import ReplacementCore
import ReplacementNative

struct InlineDraft { var original: Pair; var value: Pair }
struct ReviewRow: Identifiable { let id = UUID(); let change: Change }
struct ChangeReview: Identifiable {
    let id = UUID()
    var title: String
    var detail: String
    var changes: [Change]
    var baseline: [Replacement]
    let rows: [ReviewRow]
    init(title: String, detail: String, changes: [Change], baseline: [Replacement]) {
        self.title = title; self.detail = detail; self.changes = changes; self.baseline = baseline
        rows = changes.map { ReviewRow(change: $0) }
    }
}
enum Section: String, CaseIterable, Identifiable { case all, dictionary, issues, templates, details, history, sync; var id: String { rawValue } }
struct SyncCheck: Codable {
    var shortcut: String
    var phase: String
    var observations: [String]
    var originalPhrase: String { "Replacements sync check — first version" }
    var editedPhrase: String { "Replacements sync check — edited version" }
}
@MainActor @Observable final class AppModel {
    var entries: [Replacement] = []
    var drafts: [String: InlineDraft] = [:]
    var issueIDs = Set<String>()
    var query = ""
    var section: Section? = .all
    var selection = Set<String>()
    var busy = false
    var loaded = false
    var writable = false
    var needsRefresh = false
    var source = "Connecting to macOS…"
    var status = ""
    var error: String?
    var review: ChangeReview?
    var showAdd = false
    var showBulk = false
    var snapshots: [Snapshot] = []
    var syncCheck: SyncCheck?
    var selectedTemplate: ShortcutTemplate?
    var personalDetails = PersonalDetails()
    var personalDetailsDraft: PersonalDetails?
    var personalDetailsProblem: String?
    private var personalDetailsWritable = true
    private let personalDetailsStore: PersonalDetailsStore
    let demo: Bool
    let history: HistoryStore
    private let backend: any ReplacementBackend
    private let engine: MutationEngine
    private let support: URL
    init(demo: Bool = CommandLine.arguments.contains("--demo"), supportDirectory: URL? = nil) {
        self.demo = demo
        let base = supportDirectory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        support = base.appendingPathComponent(demo ? "Replacements-Demo" : "Replacements", isDirectory: true)
        personalDetailsStore = PersonalDetailsStore(url: support.appendingPathComponent("personal-details.json"))
        history = HistoryStore(directory: support.appendingPathComponent("History", isDirectory: true))
        backend = demo ? DemoBackend() : NativeBackend()
        engine = MutationEngine(backend: backend, history: history)
        do { personalDetails = try personalDetailsStore.load() }
        catch { personalDetailsProblem = "Your saved details couldn’t be loaded. They have been preserved. Use Forget All in Your Details to reset them."; personalDetailsWritable = false }
        if let data = try? Data(contentsOf: support.appendingPathComponent("sync-check.json")) { syncCheck = try? JSONDecoder().decode(SyncCheck.self, from: data) }
    }
    func navigate(_ destination: Section) {
        query = ""; selection.removeAll(); section = destination
    }
    var shortcutCount: Int { entries.filter { !$0.shortcut.isEmpty }.count }
    var dictionaryCount: Int { entries.filter { $0.shortcut.isEmpty }.count }
    var visible: [Replacement] {
        entries.filter { row in
            ((section ?? .all) != .all || !row.shortcut.isEmpty) && (section != .dictionary || row.shortcut.isEmpty) &&
            (section != .issues || issueIDs.contains(row.id)) && (query.isEmpty || row.shortcut.localizedStandardContains(query) || row.phrase.localizedStandardContains(query))
        }.sorted { $0.shortcut.localizedStandardCompare($1.shortcut) == .orderedAscending || ($0.shortcut == $1.shortcut && $0.phrase < $1.phrase) }
    }
    var selectedRows: [Replacement] { entries.filter { selection.contains($0.id) } }
    var canWrite: Bool { loaded && writable && !busy && !needsRefresh }
    var updateMustWait: Bool {
        busy || !drafts.isEmpty || (personalDetailsDraft != nil && personalDetailsDraft != personalDetails) ||
        showAdd || showBulk || review != nil || selectedTemplate != nil
    }
    func refresh() async {
        guard !busy else { return }
        busy = true; defer { busy = false }
        do {
            let read = try await backend.read()
            entries = read.entries; issueIDs = Validation.issueIDs(entries); source = read.source; writable = read.writable; loaded = true; needsRefresh = false
            selection.formIntersection(Set(entries.map(\.id)))
            snapshots = try history.list()
            status = "\(entries.count) replacements on this Mac"
        } catch { writable = false; self.error = error.localizedDescription; source = "Native access unavailable" }
    }
    func mutate(_ changes: [Change], baseline: [Replacement]? = nil, reason: String) async -> Bool {
        guard canWrite else { return false }
        busy = true; defer { busy = false }
        do {
            let result = try await engine.perform(changes, baseline: baseline ?? entries, reason: reason)
            entries = result.read.entries; issueIDs = Validation.issueIDs(entries); source = result.read.source
            snapshots = try history.list(); selection.formIntersection(Set(entries.map(\.id)))
            status = demo ? "Saved in the isolated demo library." : "Saved and verified on this Mac. Apple handles device sync."
            return true
        } catch {
            self.error = error.localizedDescription
            switch error as? ReplacementError {
            case .invalid, .ambiguous, .busy: needsRefresh = false; status = "No changes saved."
            default: needsRefresh = true; status = "Stopped. Refresh to inspect the native result."
            }
            snapshots = (try? history.list()) ?? snapshots
            return false
        }
    }
    func add(shortcut: String, phrase: String) async -> Bool {
        await mutate([.add(Pair(shortcut: shortcut, phrase: phrase))], reason: "Add replacement")
    }
    func edit(original: Pair, shortcut: String, phrase: String) async -> Bool {
        let pair = Pair(shortcut: shortcut, phrase: phrase)
        guard original != pair else { return true }
        return await mutate([.edit(original, pair)], reason: "Edit replacement")
    }
    func setPersonalDetailDraft(_ value: String, field: DetailField) {
        var draft = personalDetailsDraft ?? personalDetails
        draft[field] = value; personalDetailsDraft = draft
    }
    @discardableResult func savePersonalDetails(_ details: PersonalDetails, fields: [DetailField] = DetailField.allCases) -> Bool {
        guard personalDetailsWritable else { error = personalDetailsProblem; return false }
        do {
            let merged = try personalDetails.merging(details, fields: fields)
            try personalDetailsStore.save(merged)
            personalDetails = merged
            if Set(fields) == Set(DetailField.allCases) { personalDetailsDraft = nil }
            else if var draft = personalDetailsDraft {
                for field in fields { draft[field] = merged[field] }
                personalDetailsDraft = draft == merged ? nil : draft
            }
            status = "Your details are saved on this Mac."
            return true
        } catch { self.error = error.localizedDescription; return false }
    }
    func forgetPersonalDetails() {
        do {
            try personalDetailsStore.forget(); personalDetails = PersonalDetails(); personalDetailsDraft = nil
            personalDetailsProblem = nil; personalDetailsWritable = true
            status = "Saved personal details forgotten."
        } catch { self.error = error.localizedDescription }
    }
    func useTemplate(_ template: ShortcutTemplate, details: PersonalDetails, shortcut: String, remember: Bool) async -> Bool {
        do {
            let phrase = try template.render(with: details)
            let pair = Pair(shortcut: shortcut, phrase: phrase)
            try Validation.check(pair)
            guard Validation.canInsert(pair, into: entries) else { throw ReplacementError.invalid("Choose a different shortcut; this one is already in your library.") }
            if remember && !template.fields.isEmpty && !savePersonalDetails(details, fields: template.fields) { return false }
            guard await mutate([.add(pair)], reason: "Add template: " + template.title) else { return false }
            navigate(.all)
            selection = Set(entries.filter { $0.pair == pair }.map(\.id))
            return true
        } catch { self.error = error.localizedDescription; return false }
    }
    func setDraft(_ value: String, row: Replacement, field: EditField) {
        var draft = drafts[row.id] ?? InlineDraft(original: row.pair, value: row.pair)
        if field == .shortcut { draft.value.shortcut = value } else { draft.value.phrase = value }
        if draft.value == draft.original { drafts[row.id] = nil } else { drafts[row.id] = draft }
    }
    func saveDraft(_ row: Replacement) async {
        guard let draft = drafts[row.id] else { return }
        if await edit(original: draft.original, shortcut: draft.value.shortcut, phrase: draft.value.phrase) {
            drafts[row.id] = nil
        }
    }
    func reviewDelete() {
        guard canWrite, !selectedRows.isEmpty else { return }
        review = ChangeReview(title: "Delete \(selectedRows.count) replacements?", detail: "Apple may sync these deletions to your other devices. A local backup will be created first.", changes: selectedRows.map { .remove($0.pair) }, baseline: entries)
    }
    func importFile() {
        guard canWrite else { return }
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.json, .commaSeparatedText, .propertyList]; panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            guard let format = TransferFormat(rawValue: url.pathExtension.lowercased()) else { throw ReplacementError.invalid("Choose JSON, CSV, or an Apple plist.") }
            let pairs = try Transfer.decode(Data(contentsOf: url), format: format)
            let result = try ImportReview(pairs: pairs, existing: entries)
            review = ChangeReview(title: "Review import", detail: "\(result.additions.count) new · \(result.duplicates) identical entries skipped · \(result.conflicts.count) conflicts skipped. Existing phrases will be preserved.\(result.conflicts.isEmpty ? "" : " Conflicting shortcuts: " + result.conflicts.map(\.shortcut).prefix(12).joined(separator: ", "))", changes: result.additions.map(Change.add), baseline: entries)
        } catch { self.error = error.localizedDescription }
    }
    func exportFile(_ format: TransferFormat, selected: Bool = false, snapshot: Snapshot? = nil) {
        let rows = snapshot?.entries ?? (selected ? selectedRows : entries)
        let panel = NSSavePanel(); panel.nameFieldStringValue = "Replacements.\(format.rawValue)"
        panel.allowedContentTypes = [format == .json ? .json : format == .csv ? .commaSeparatedText : .propertyList]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try Transfer.encode(rows, format: format).write(to: url, options: .atomic); status = "Exported \(rows.count) replacements." }
        catch { self.error = error.localizedDescription }
    }
    func backupNow() {
        guard loaded, !busy else { return }
        do { try history.save(Snapshot(reason: "Manual backup", entries: entries)); snapshots = try history.list(); status = "Local backup saved." }
        catch { self.error = error.localizedDescription }
    }
    func restore(_ snapshot: Snapshot) {
        guard canWrite else { return }
        do {
            let changes = try Planner.restore(snapshot.entries, over: entries)
            review = ChangeReview(title: "Restore this backup?", detail: "This applies \(changes.count) operations to match \(snapshot.entries.count) saved replacements. Replacements added since this backup may be deleted, including on your other Apple devices. Your current list will be backed up first.", changes: changes, baseline: entries)
        } catch { self.error = error.localizedDescription }
    }
    func executeReview(_ pending: ChangeReview) async {
        review = nil
        _ = await mutate(pending.changes, baseline: pending.baseline, reason: pending.title)
    }
    func openSystemSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension")!)
    }
    func revealHistory() {
        do { try FileManager.default.createDirectory(at: history.directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700]); NSWorkspace.shared.open(history.directory) }
        catch { self.error = error.localizedDescription }
    }
    private func saveSync(_ check: SyncCheck) throws {
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let url = support.appendingPathComponent("sync-check.json")
        try JSONEncoder().encode(check).write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        syncCheck = check
    }
    func startSyncCheck() async {
        guard canWrite, !demo else { return }
        var check = SyncCheck(shortcut: ";rp-" + UUID().uuidString.prefix(8).lowercased(), phase: "created", observations: [])
        // Save the harmless marker before the write, so it can be recovered after a crash.
        check.observations.append("\(Date().ISO8601Format()): marker prepared on Mac")
        do { try saveSync(check) } catch { self.error = error.localizedDescription; return }
        if await add(shortcut: check.shortcut, phrase: check.originalPhrase) {
            check.observations.append("\(Date().ISO8601Format()): native creation verified on Mac")
            do { try saveSync(check) } catch { self.error = error.localizedDescription }
        }
    }
    func confirmRemoteAndAdvance() async {
        guard canWrite, var check = syncCheck else { return }
        let next: String
        let change: Change?
        switch check.phase {
        case "created":
            next = "edited"
            change = .edit(Pair(shortcut: check.shortcut, phrase: check.originalPhrase), Pair(shortcut: check.shortcut, phrase: check.editedPhrase))
        case "edited": next = "deleted"; change = .remove(Pair(shortcut: check.shortcut, phrase: check.editedPhrase))
        case "deleted": next = "complete"; change = nil
        default: return
        }
        check.observations.append("\(Date().ISO8601Format()): user observed \(check.phase) on iPhone/iPad")
        // Persist the observation before mutating; phase changes only after verified native success.
        do { try saveSync(check) } catch { self.error = error.localizedDescription; return }
        if let change, !(await mutate([change], reason: "Device sync verification")) { return }
        check.phase = next
        do { try saveSync(check) } catch { self.error = error.localizedDescription }
    }
    func cleanupSyncCheck() async {
        guard canWrite, var check = syncCheck else { return }
        let rows = entries.filter { $0.shortcut == check.shortcut && [$0.phrase].contains(where: { $0 == check.originalPhrase || $0 == check.editedPhrase }) }
        if !rows.isEmpty, !(await mutate(rows.map { .remove($0.pair) }, reason: "Clean up sync marker")) { return }
        check.phase = "cancelled"; check.observations.append("\(Date().ISO8601Format()): marker cleanup verified on Mac; remote cleanup unconfirmed")
        do { try saveSync(check) } catch { self.error = error.localizedDescription }
    }
}
