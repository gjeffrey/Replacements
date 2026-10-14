import Foundation
import Testing
@testable import ReplacementCore

private func row(_ shortcut: String, _ phrase: String) -> Replacement { Replacement(shortcut: shortcut, phrase: phrase) }
private func temporaryHistory() -> HistoryStore { HistoryStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent("Replacements-tests-" + UUID().uuidString)) }

@Test(arguments: TransferFormat.allCases)
func roundTripComplexText(_ format: TransferFormat) throws {
    let rows = [row(";hi", "Hello, \"world\"!\r\nLine 2\n👩🏽‍💻 café 中文"), row("", "A dictionary word"), row(";address", "  preserve spaces  ")]
    let decoded = try Transfer.decode(Transfer.encode(rows, format: format), format: format)
    #expect(decoded == rows.map(\.pair))
}
@Test func CSVRejectsBrokenQuotesAndColumns() {
    for text in ["shortcut,phrase\na,\"unclosed", "shortcut,phrase\na,\"b\"oops", "shortcut,phrase\na,b,c", "shortcut,phrase\na,b\"c", "wrong,header\na,b"] {
        #expect(throws: (any Error).self) { try Transfer.decode(Data(text.utf8), format: .csv) }
    }
}
@Test func CSVAcceptsBOMCRLFAndEmptyShortcut() throws {
    let input = "\u{FEFF}shortcut,phrase\r\n,\"Dictionary\r\nWord\"\r\n;ok,yes\r\n"
    #expect(try Transfer.decode(Data(input.utf8), format: .csv) == [Pair(shortcut: "", phrase: "Dictionary\r\nWord"), Pair(shortcut: ";ok", phrase: "yes")])
}
@Test func futureJSONVersionRejected() {
    #expect(throws: (any Error).self) { try Transfer.decode(Data("{\"version\":2,\"entries\":[]}".utf8), format: .json) }
}
@Test func malformedPlistRejected() throws {
    let data = try PropertyListSerialization.data(fromPropertyList: [["replace": "a"]], format: .xml, options: 0)
    #expect(throws: (any Error).self) { try Transfer.decode(data, format: .plist) }
}
@Test func importPreservesExistingAndDetectsInternalConflicts() throws {
    let existing = [row("omw", "On my way!")]
    let pairs = [Pair(shortcut: "omw", phrase: "On my way!"), Pair(shortcut: "OMW", phrase: "Different"), Pair(shortcut: "new", phrase: "first"), Pair(shortcut: "new", phrase: "second"), Pair(shortcut: "", phrase: "word")]
    let result = try ImportReview(pairs: pairs, existing: existing)
    #expect(result.duplicates == 1); #expect(result.conflicts.count == 2); #expect(result.additions.count == 2)
    #expect(existing.first?.phrase == "On my way!")
}
@Test func duplicateAndConflictIDsIncludeAllAffectedRows() {
    let rows = [row("x", "one"), row("X", "two"), row("", "word"), row("", "different"), row("z", "same"), row("z", "same")]
    #expect(Validation.issueIDs(rows) == Set([rows[0].id, rows[1].id, rows[4].id, rows[5].id]))
}
@Test func duplicatePairCannotBeRemovedIndividually() {
    let rows = [row("x", "same"), row("x", "same")]
    #expect(throws: ReplacementError.ambiguous) { try Change.remove(rows[0].pair).applying(to: rows) }
}
@Test func restoreRemovesBeforeAddingConflictingShortcut() throws {
    let current = [row("x", "old"), row("stay", "untouched")], target = [row("x", "new"), row("stay", "untouched")]
    let changes = try Planner.restore(target, over: current)
    let restored = try changes.reduce(current) { try $1.applying(to: $0) }
    #expect(Validation.sameContents(restored, target)); #expect(changes.first?.new == nil)
}
@Test func restoreRefusesAmbiguousMultiplicity() {
    let current = [row("x", "same"), row("x", "same")], target = [row("x", "same")]
    #expect(throws: ReplacementError.ambiguous) { try Planner.restore(target, over: current) }
}
@Test func literalBulkReplacePreservesUnicodeAndShortcuts() throws {
    let input = [row(";one", "a.$ 🐈 a.$"), row(";two", "other")]
    let changes = try Planner.replacing("a.$", with: "café", in: input)
    #expect(changes.count == 1); #expect(changes[0].new == Pair(shortcut: ";one", phrase: "café 🐈 café"))
}
@Test func invalidInputsRejectedButDictionaryWordsAllowed() throws {
    try Validation.check(Pair(shortcut: "", phrase: "A word"))
    try Validation.check(Pair(shortcut: "A phrase", phrase: "A native multiword replacement"))
    for pair in [Pair(shortcut: "a\t", phrase: "valid"), Pair(shortcut: "a\n", phrase: "valid"), Pair(shortcut: "x", phrase: " \n"), Pair(shortcut: "x", phrase: "a\0b")] {
        #expect(throws: (any Error).self) { try Validation.check(pair) }
    }
}
@Test func snapshotsRoundTripAndUsePrivatePermissions() throws {
    let history = temporaryHistory(); defer { try? FileManager.default.removeItem(at: history.directory) }
    let snapshot = Snapshot(reason: "Before edit", entries: [row(";a", "personal phrase")])
    try history.save(snapshot)
    #expect(try history.list().first?.entries == snapshot.entries)
    let path = history.directory.appendingPathComponent(snapshot.id.uuidString + ".json").path
    let permissions = try FileManager.default.attributesOfItem(atPath: path)[.posixPermissions] as? NSNumber
    #expect(permissions?.intValue == 0o600)
}
private actor FakeBackend: ReplacementBackend {
    enum Mode { case normal, acceptThenError, ignoreWrites, concurrentAfterWrite }
    var rows: [Replacement]; var writes = 0; let mode: Mode
    init(rows: [Replacement], mode: Mode = .normal) { self.rows = rows; self.mode = mode }
    func read() async throws -> ReadResult { ReadResult(entries: rows, source: "test", writable: true) }
    func apply(_ change: Change) async throws {
        writes += 1
        if mode != .ignoreWrites { rows = try change.applying(to: rows) }
        if mode == .acceptThenError { throw ReplacementError.unverified("Ambiguous completion") }
        if mode == .concurrentAfterWrite { rows.append(row("remote", "Arrived from device")) }
    }
}
@Test func staleBaselinePreventsAllWritesAndBackups() async throws {
    let backend = FakeBackend(rows: [row("remote", "changed")]), history = temporaryHistory()
    let engine = MutationEngine(backend: backend, history: history)
    await #expect(throws: ReplacementError.stale) { try await engine.perform([.add(Pair(shortcut: "new", phrase: "value"))], baseline: [], reason: "test") }
    #expect(await backend.writes == 0); #expect(try history.list().isEmpty)
}
@Test func backupFailurePreventsWrite() async throws {
    let backend = FakeBackend(rows: [])
    let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try Data("not a directory".utf8).write(to: file); defer { try? FileManager.default.removeItem(at: file) }
    let history = HistoryStore(directory: file.appendingPathComponent("History"))
    let engine = MutationEngine(backend: backend, history: history)
    await #expect(throws: (any Error).self) { try await engine.perform([.add(Pair(shortcut: "new", phrase: "value"))], baseline: [], reason: "test") }
    #expect(await backend.writes == 0)
}
@Test func ambiguousCompletionReconcilesWithoutResending() async throws {
    let backend = FakeBackend(rows: [], mode: .acceptThenError), history = temporaryHistory()
    defer { try? FileManager.default.removeItem(at: history.directory) }
    let engine = MutationEngine(backend: backend, history: history)
    let result = try await engine.perform([.add(Pair(shortcut: "new", phrase: "value"))], baseline: [], reason: "test")
    #expect(result.read.entries.count == 1); #expect(await backend.writes == 1); #expect(try history.list().count == 1)
}
@Test func failedFirstWriteStopsBatchAndPreservesSnapshot() async throws {
    let backend = FakeBackend(rows: [], mode: .ignoreWrites), history = temporaryHistory()
    defer { try? FileManager.default.removeItem(at: history.directory) }
    let engine = MutationEngine(backend: backend, history: history)
    await #expect(throws: (any Error).self) { try await engine.perform([.add(Pair(shortcut: "one", phrase: "1")), .add(Pair(shortcut: "two", phrase: "2"))], baseline: [], reason: "test") }
    #expect(await backend.writes == 1); #expect(try history.list().count == 1)
}
@Test func concurrentArrivalStopsBatchWithoutOverwritingIt() async throws {
    let backend = FakeBackend(rows: [], mode: .concurrentAfterWrite), history = temporaryHistory()
    defer { try? FileManager.default.removeItem(at: history.directory) }
    let engine = MutationEngine(backend: backend, history: history)
    await #expect(throws: (any Error).self) { try await engine.perform([.add(Pair(shortcut: "one", phrase: "1")), .add(Pair(shortcut: "two", phrase: "2"))], baseline: [], reason: "test") }
    #expect(await backend.writes == 1); #expect(try await backend.read().entries.contains { $0.shortcut == "remote" })
}
@Test func wholePlanValidationPreventsPartialWriteForDuplicateShortcut() async throws {
    let backend = FakeBackend(rows: []), history = temporaryHistory()
    let engine = MutationEngine(backend: backend, history: history)
    await #expect(throws: (any Error).self) { try await engine.perform([.add(Pair(shortcut: "one", phrase: "1")), .add(Pair(shortcut: "ONE", phrase: "2"))], baseline: [], reason: "test") }
    #expect(await backend.writes == 0)
}
