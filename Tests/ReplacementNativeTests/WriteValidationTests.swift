import Foundation
import Testing
import ReplacementNative
import ReplacementCore

@Test func emptyShortcutBatchStopsBeforeBackupAndEveryWrite() async throws {
    // The demo has the same Mac write restrictions as the native adapter.
    let backend = DemoBackend()
    let baseline = try await backend.read()
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let history = HistoryStore(directory: directory)
    let engine = MutationEngine(backend: backend, history: history)
    await #expect(throws: (any Error).self) {
        try await engine.perform([
            .add(Pair(shortcut: ";safe", phrase: "Valid")),
            .add(Pair(shortcut: "", phrase: "Appleseed"))
        ], baseline: baseline.entries, reason: "test")
    }
    #expect(Validation.sameContents(try await backend.read().entries, baseline.entries))
    #expect(try history.list().isEmpty)
}

@Test func nativeAdapterRejectsUnsupportedWordsWithoutCallingTheService() async throws {
    let backend = NativeBackend()
    for change in [Change.add(Pair(shortcut: "", phrase: "Appleseed")),
                   .add(Pair(shortcut: "  ", phrase: "Appleseed")),
                   .remove(Pair(shortcut: "", phrase: "Existing")),
                   .edit(Pair(shortcut: "", phrase: "Existing"), Pair(shortcut: "new", phrase: "Existing")),
                   .edit(Pair(shortcut: "old", phrase: "Existing"), Pair(shortcut: "", phrase: "Existing"))] {
        await #expect(throws: (any Error).self) { try await backend.validate([change]) }
    }
    try await backend.validate([.add(Pair(shortcut: "brb", phrase: "Be right back."))])
}
