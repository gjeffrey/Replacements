import Foundation
import KeyboardBridge
import ReplacementCore

private func validateMacWrites(_ changes: [Change]) throws {
    for change in changes {
        if let old = change.old, old.shortcut.isEmpty {
            throw ReplacementError.invalid("Words without shortcuts can be viewed and exported here. Edit or delete them on your iPhone or iPad.")
        }
        if let new = change.new, new.shortcut.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ReplacementError.invalid("A shortcut is required on macOS. To add a word without a shortcut, use Text Replacement on your iPhone or iPad.")
        }
    }
}
public actor NativeBackend: ReplacementBackend {
    private let bridge = RPKeyboardBridge()
    private let database: URL
    private var readSource: String?
    public init(database: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/KeyboardServices/TextReplacements.db")) { self.database = database }
    public func read() async throws -> ReadResult {
        if readSource == nil {
            let native: [[String: Any]]? = try? await withCheckedThrowingContinuation { continuation in
                bridge.query { rows, error in
                    if let error { continuation.resume(throwing: error) }
                    else { continuation.resume(returning: rows ?? []) }
                }
            }
            let disk = try? readDisk()
            if let native {
                let rows = try decode(native)
                if let disk, !Validation.sameContents(rows, disk) { readSource = "Native database · read only" }
                else if disk != nil { readSource = "KeyboardServices" }
                else if !rows.isEmpty { readSource = "KeyboardServices" }
            }
            if readSource == nil { readSource = "Native database · read only" }
        }
        if readSource == "KeyboardServices" {
            let native: [[String: Any]] = try await withCheckedThrowingContinuation { continuation in
                bridge.query { rows, error in
                    if let error { continuation.resume(throwing: error) }
                    else { continuation.resume(returning: rows ?? []) }
                }
            }
            let rows = try decode(native)
            // Never accept a native empty/incomplete result over populated on-disk data.
            if let disk = try? readDisk(), !Validation.sameContents(rows, disk) {
                readSource = "Native database · read only"
                return ReadResult(entries: disk, source: readSource!, writable: bridge.available)
            }
            return ReadResult(entries: rows, source: readSource!, writable: bridge.available)
        }
        return ReadResult(entries: try readDisk(), source: readSource!, writable: bridge.available)
    }
    private func readDisk() throws -> [Replacement] { try decode(bridge.readDatabase(atPath: database.path)) }
    private func decode(_ rows: [[String: Any]]) throws -> [Replacement] {
        let result = try rows.map { row -> Replacement in
            guard let id = row["id"] as? String, let shortcut = row["shortcut"] as? String, let phrase = row["phrase"] as? String else { throw ReplacementError.invalid("Unexpected native entry format.") }
            return Replacement(id: id, shortcut: shortcut, phrase: phrase)
        }
        guard Set(result.map(\.id)).count == result.count else { throw ReplacementError.invalid("Native identifiers are not unique; writes are disabled.") }
        return result
    }
    public func validate(_ changes: [Change]) async throws {
        try validateMacWrites(changes)
    }
    public func apply(_ change: Change) async throws {
        try await validate([change])
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let completion: @Sendable (Error?) -> Void = { error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume() }
            }
            switch change {
            case .add(let p): bridge.addShortcut(p.shortcut, phrase: p.phrase, completion: completion)
            case .remove(let p): bridge.removeShortcut(p.shortcut, phrase: p.phrase, completion: completion)
            case .edit(let old, let new): bridge.modifyShortcut(old.shortcut, phrase: old.phrase, toShortcut: new.shortcut, phrase: new.phrase, completion: completion)
            }
        }
    }
}
/// Demo storage is isolated in memory. It never reads or writes native replacements.
public actor DemoBackend: ReplacementBackend {
    private var entries: [Replacement] = [
        Replacement(id: "demo-1", shortcut: ";email", phrase: "hello@example.com"),
        Replacement(id: "demo-2", shortcut: "omw", phrase: "On my way!"),
        Replacement(id: "demo-3", shortcut: ";thanks", phrase: "Thanks for taking a look. I’ll get back to you shortly."),
        Replacement(id: "demo-4", shortcut: ";address", phrase: "123 Example Street\nSan Francisco, CA 94103"),
        Replacement(id: "demo-5", shortcut: ";meeting", phrase: "Does Thursday at 10 work for you?"),
        Replacement(id: "demo-6", shortcut: "brb", phrase: "Be right back."),
        Replacement(id: "demo-7", shortcut: ";email", phrase: "work@example.com")
    ]
    public init() {}
    public func read() async throws -> ReadResult { ReadResult(entries: entries, source: "Demo · isolated from macOS", writable: true) }
    public func validate(_ changes: [Change]) async throws { try validateMacWrites(changes) }
    public func apply(_ change: Change) async throws { try validateMacWrites([change]); entries = try change.applying(to: entries) }
}
