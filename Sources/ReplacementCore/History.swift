import Foundation

public struct Snapshot: Identifiable, Codable, Sendable {
    public var id: UUID
    public var date: Date
    public var reason: String
    public var entries: [Replacement]
    public init(reason: String, entries: [Replacement]) { id = UUID(); date = Date(); self.reason = reason; self.entries = entries }
}
public struct HistoryStore: Sendable {
    public let directory: URL
    public init(directory: URL) { self.directory = directory }
    public func save(_ snapshot: Snapshot) throws {
        let manager = FileManager.default
        try manager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try manager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]; encoder.dateEncodingStrategy = .iso8601
        let url = directory.appendingPathComponent(snapshot.id.uuidString + ".json")
        try encoder.encode(snapshot).write(to: url, options: .atomic)
        try manager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        // Retain 50 readable snapshots. Corrupt files remain available for manual recovery.
        for old in try list().dropFirst(50) { try manager.removeItem(at: directory.appendingPathComponent(old.id.uuidString + ".json")) }
    }
    public func list() throws -> [Snapshot] {
        guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let urls = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil).filter { $0.pathExtension == "json" }
        return urls.compactMap { url in
            guard let data = try? Data(contentsOf: url), let snapshot = try? decoder.decode(Snapshot.self, from: data) else { return nil }
            return snapshot
        }.sorted { $0.date == $1.date ? $0.id.uuidString > $1.id.uuidString : $0.date > $1.date }
    }
}
public struct ReadResult: Sendable {
    public var entries: [Replacement]
    public var source: String
    public var writable: Bool
    public init(entries: [Replacement], source: String, writable: Bool) { self.entries = entries; self.source = source; self.writable = writable }
}
public protocol ReplacementBackend: Sendable {
    func read() async throws -> ReadResult
    func apply(_ change: Change) async throws
}
public struct MutationResult: Sendable {
    public var read: ReadResult
    public var snapshot: Snapshot
}
public actor MutationEngine {
    private let backend: any ReplacementBackend
    private let history: HistoryStore
    private var busy = false
    public init(backend: any ReplacementBackend, history: HistoryStore) { self.backend = backend; self.history = history }
    public func perform(_ changes: [Change], baseline: [Replacement], reason: String) async throws -> MutationResult {
        guard !busy else { throw ReplacementError.busy }
        busy = true; defer { busy = false }
        guard !changes.isEmpty else { throw ReplacementError.invalid("There are no changes to apply.") }
        let current = try await backend.read()
        guard current.writable else { throw ReplacementError.invalid("Native writes are unavailable on this Mac.") }
        guard Validation.sameContents(current.entries, baseline) else { throw ReplacementError.stale }
        var planned = current.entries
        for change in changes { planned = try change.applying(to: planned) }
        let snapshot = Snapshot(reason: reason, entries: current.entries)
        try history.save(snapshot) // A failed backup prevents every native write.
        var expected = current.entries
        for (index, change) in changes.enumerated() {
            let before = try await backend.read()
            guard Validation.sameContents(before.entries, expected) else { throw ReplacementError.unverified("Changes arrived from another app or device. Stopped after \(index) of \(changes.count) operations. A backup is available in History.") }
            let target = try change.applying(to: expected)
            var writeError: Error?
            do { try await backend.apply(change) } catch { writeError = error }
            // Never resend an ambiguous write. Read to reconcile instead.
            var observed: ReadResult?
            for delay in [0.2, 0.6, 1.2, 2.0] {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                observed = try await backend.read()
                if Validation.sameContents(observed!.entries, target) { break }
            }
            guard let observed, Validation.sameContents(observed.entries, target) else {
                throw ReplacementError.unverified("Could not verify operation \(index+1) of \(changes.count). It may have completed partially. Refresh before continuing; a backup is in History. \(writeError?.localizedDescription ?? "The native store differs from the expected result.")")
            }
            // A non-nil private code-zero callback is not trusted alone; verified contents are the proof.
            expected = observed.entries
        }
        // Delayed verification catches immediate daemon/cloud overwrites; this is still local only.
        try await Task.sleep(nanoseconds: 1_000_000_000)
        let final = try await backend.read()
        guard Validation.sameContents(final.entries, expected) else { throw ReplacementError.unverified("The result changed during delayed verification. Refresh and inspect History before continuing.") }
        return MutationResult(read: final, snapshot: snapshot)
    }
}
