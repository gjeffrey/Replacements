import SwiftUI
import AppKit
import ReplacementCore

struct AddView: View {
    @Bindable var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var shortcut = ""
    @State private var phrase = ""
    @FocusState private var focus: Bool
    private let dictionaryWord: Bool
    // Seed the form's purpose once when it opens; navigation behind a sheet cannot change it.
    init(model: AppModel) { self.model = model; dictionaryWord = model.section == .dictionary }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(dictionaryWord ? "New dictionary word" : "New replacement").font(.title2.bold())
            Form {
                if dictionaryWord {
                    TextField("Word", text: $phrase).focused($focus).autocorrectionDisabled()
                } else {
                    TextField("Shortcut", text: $shortcut).focused($focus)
                    TextField("Phrase", text: $phrase, axis: .vertical).lineLimit(3...7)
                }
            }
            Text(dictionaryWord ? "Apple will leave this word as you type it. No shortcut is needed." : "Leave the shortcut empty to add a dictionary word.").font(.callout).foregroundStyle(.secondary)
            if let problem { Text(problem).font(.caption).foregroundStyle(.orange) }
            HStack { Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction); Spacer(); if model.busy { ProgressView().controlSize(.small) }; Button(dictionaryWord ? "Add Word" : "Add Replacement") { Task { if await model.add(shortcut: shortcut, phrase: phrase) { if shortcut.isEmpty { model.navigate(.dictionary) }; dismiss() } } }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction).disabled(!model.canWrite || phrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || problem != nil) }
        }.padding(26).frame(width: 500).onAppear { focus = true }
    }
    private var problem: String? {
        guard !phrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        if dictionaryWord && phrase.contains(where: \.isNewline) { return "Use one line for your dictionary word." }
        let pair = Pair(shortcut: shortcut, phrase: phrase)
        do { try Validation.check(pair) } catch { return error.localizedDescription }
        return Validation.canInsert(pair, into: model.entries) ? nil : "This shortcut already exists or conflicts with another replacement."
    }
}
struct ChangeReviewView: View {
    @Bindable var model: AppModel
    let review: ChangeReview
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(review.title).font(.title2.bold())
            Text(review.detail).foregroundStyle(.secondary)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(review.rows) { row in
                        let change = row.change
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: change.old == nil ? "plus.circle" : change.new == nil ? "minus.circle" : "pencil.circle").foregroundStyle(change.new == nil ? .orange : .accentColor)
                            VStack(alignment: .leading, spacing: 4) {
                                Text((change.new ?? change.old)?.shortcut.isEmpty == true ? "Dictionary word" : (change.new ?? change.old)?.shortcut ?? "").font(.system(.body, design: .monospaced).weight(.semibold))
                                if let old = change.old { Text(old.phrase).foregroundStyle(.secondary).lineLimit(3) }
                                if let new = change.new { Text(new.phrase).lineLimit(3) }
                            }
                        }
                        Divider()
                    }
                }.padding(12)
            }.frame(maxHeight: 320).background(.quaternary.opacity(0.3)).clipShape(RoundedRectangle(cornerRadius: 10))
            Text("A backup is required before any write. Bulk operations are verified one at a time; a failure can leave a partial result, available for recovery from History.").font(.caption).foregroundStyle(.secondary)
            HStack { Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction); Spacer(); Button("Apply \(review.changes.count) Changes") { Task { await model.executeReview(review) } }.keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent).disabled(!model.canWrite || review.changes.isEmpty) }
        }.padding(26).frame(width: 610)
    }
}
struct BulkView: View {
    @Bindable var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var find = ""
    @State private var replacement = ""
    @State private var selectedOnly = false
    @State private var problem: String?
    private var rows: [Replacement] { selectedOnly ? model.selectedRows : model.entries }
    private var matches: Int { find.isEmpty ? 0 : rows.filter { $0.phrase.contains(find) }.count }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Find & replace in phrases").font(.title2.bold())
            Text("A literal, case-sensitive match. You’ll review every change before saving.").foregroundStyle(.secondary)
            TextField("Find", text: $find).textFieldStyle(.roundedBorder)
            TextField("Replace with", text: $replacement).textFieldStyle(.roundedBorder)
            Toggle("Only selected replacements", isOn: $selectedOnly).disabled(model.selection.isEmpty)
            Text("\(matches) phrases will change").font(.callout)
            if let problem { Text(problem).foregroundStyle(.orange).font(.caption) }
            HStack { Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction); Spacer(); Button("Review Changes") {
                do {
                    let changes = try Planner.replacing(find, with: replacement, in: rows)
                    let pending = ChangeReview(title: "Review find & replace", detail: "Update \(changes.count) phrases. Shortcuts will be preserved.", changes: changes, baseline: model.entries)
                    dismiss()
                    // Present after the current sheet's dismissal completes.
                    Task { try? await Task.sleep(nanoseconds: 350_000_000); model.review = pending }
                } catch { problem = error.localizedDescription }
            }.buttonStyle(.borderedProminent).disabled(matches == 0 || !model.canWrite || find == replacement) }
        }.padding(26).frame(width: 500)
    }
}
struct HistoryView: View {
    @Bindable var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 7) { Text("A way back.").font(.system(size: 27, weight: .semibold)); Text("A local snapshot before every change. Restore only after reviewing the differences.").foregroundStyle(.secondary) }
                Spacer(); Button("Back Up Now") { model.backupNow() }.disabled(!model.loaded || model.busy)
            }
            if model.snapshots.isEmpty {
                ContentUnavailableView("No backups yet", systemImage: "clock.arrow.circlepath", description: Text("Your first edit will create one automatically."))
            } else {
                List(model.snapshots) { snapshot in
                    HStack(spacing: 16) {
                        Image(systemName: "clock.arrow.circlepath").font(.title2).foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(snapshot.reason).font(.headline)
                            Text("\(snapshot.date.formatted(date: .abbreviated, time: .standard)) · \(snapshot.entries.count) replacements").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Export…") { model.exportFile(.json, snapshot: snapshot) }
                        Button("Review Restore…") { model.restore(snapshot) }.disabled(!model.canWrite)
                    }.padding(.vertical, 8)
                }.listStyle(.inset)
            }
            Spacer(minLength: 0)
            HStack { Text("The 50 most recent snapshots are kept. Export important backups.").font(.caption).foregroundStyle(.secondary); Spacer(); Button("Show in Finder") { model.revealHistory() } }
        }.padding(24)
    }
}
struct SyncView: View {
    @Bindable var model: AppModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Let’s check the other end.").font(.system(size: 27, weight: .semibold))
                Text("A successful Mac save confirms the local library. To verify Apple’s iCloud sync, check a harmless marker on an iPhone or iPad signed into the same Apple Account, with iCloud Drive enabled.").foregroundStyle(.secondary)
                Label("Device verification is manual. This app cannot read your iPhone’s replacement list.", systemImage: "iphone").font(.callout)
                Divider()
                if let check = model.syncCheck {
                    Text(check.phase == "complete" ? "Creation, editing, and deletion observed on your device." : check.phase == "cancelled" ? "Check cancelled. Mac marker cleaned up." : "Current step: \(check.phase.capitalized)").font(.headline)
                    HStack { Text(check.shortcut).font(.system(.title3, design: .monospaced)); Button("Copy Shortcut") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(check.shortcut, forType: .string) } }
                    if check.phase == "created" || check.phase == "edited" {
                        Text("On your device, open Settings → General → Keyboard → Text Replacement. Find the shortcut above and confirm this exact phrase:")
                        Text(check.phase == "created" ? check.originalPhrase : check.editedPhrase).textSelection(.enabled).padding(16).frame(maxWidth: .infinity, alignment: .leading).background(.quaternary).clipShape(RoundedRectangle(cornerRadius: 10))
                        Text("Also type the shortcut followed by a space in Notes. Only advance after you observe the current phrase on the device.").font(.callout).foregroundStyle(.secondary)
                    } else if check.phase == "deleted" {
                        Text("Confirm that the shortcut has disappeared from your device’s Text Replacement list. Try typing it in Notes again.")
                    }
                    if ["created", "edited", "deleted"].contains(check.phase) {
                        HStack {
                            Button(check.phase == "created" ? "I See It on My Device — Test Edit" : check.phase == "edited" ? "I See the Edit — Test Delete" : "It’s Gone — Finish Check") { Task { await model.confirmRemoteAndAdvance() } }.buttonStyle(.borderedProminent).disabled(!model.canWrite)
                            Button("Cancel & Clean Up") { Task { await model.cleanupSyncCheck() } }.disabled(!model.canWrite)
                        }
                        Text("Sync can take time. Refresh the Mac if a step failed. The marker’s recovery details are saved locally before it is created.").font(.caption).foregroundStyle(.secondary)
                    } else {
                        Button("Run Another Check") { Task { await model.startSyncCheck() } }.disabled(!model.canWrite || model.demo)
                    }
                    Divider()
                    ForEach(check.observations, id: \.self) { Text($0).font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary).textSelection(.enabled) }
                } else {
                    Text("This check adds one unique test shortcut, then edits and deletes it as you confirm each step on your device. Your existing replacements are preserved.")
                    Button("Create a Sync Test Marker") { Task { await model.startSyncCheck() } }.buttonStyle(.borderedProminent).disabled(!model.canWrite || model.demo)
                }
                if model.demo { Text("Device sync checks are available in native mode.").font(.caption).foregroundStyle(.secondary) }
                Button("Open Apple Keyboard Settings") { model.openSystemSettings() }
            }.padding(28).frame(maxWidth: 760, alignment: .leading).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
