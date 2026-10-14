import Foundation
import Testing
import ReplacementCore
@testable import ReplacementsApp

private actor RejectingBackend: ReplacementBackend {
    private(set) var writes = 0
    func read() async throws -> ReadResult { ReadResult(entries: [], source: "test", writable: true) }
    func apply(_ change: Change) async throws {
        writes += 1
        throw NSError(domain: "KSTextReplacementErrorDomain", code: 0)
    }
}

@Test @MainActor func failedAddStaysWithTheSheetAndRefreshDoesNotResend() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let backend = RejectingBackend()
    let model = AppModel(demo: true, supportDirectory: directory, backend: backend)
    await model.refresh()
    model.showAdd = true
    #expect(await model.add(shortcut: ";test", phrase: "Entered phrase") == false)
    #expect(model.showAdd)
    #expect(model.error != nil)
    #expect(!model.showsWindowError)
    #expect(model.needsRefresh && !model.canWrite)
    #expect(model.snapshots.count == 1)
    #expect(await backend.writes == 1)
    await model.refresh()
    #expect(model.error == nil && !model.needsRefresh && model.canWrite)
    #expect(await backend.writes == 1)
}

@Test @MainActor func noShortcutIsRejectedBeforeNativeWriteAndPreservesReadOnlyWords() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let model = AppModel(demo: true, supportDirectory: directory)
    await model.refresh()
    let baseline = model.entries
    #expect(await model.add(shortcut: "", phrase: "Appleseed") == false)
    #expect(model.error?.contains("shortcut is required") == true)
    #expect(!model.needsRefresh)
    #expect(model.snapshots.isEmpty)
    #expect(Validation.sameContents(model.entries, baseline))
    model.entries.append(Replacement(shortcut: "", phrase: "Synced word"))
    #expect(model.visible.contains { $0.phrase == "Synced word" })
}

@Test @MainActor func failedReviewedOperationKeepsTheReviewOpen() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let backend = RejectingBackend()
    let model = AppModel(demo: true, supportDirectory: directory, backend: backend)
    await model.refresh()
    let review = ChangeReview(title: "Review import", detail: "One entry", changes: [.add(Pair(shortcut: ";review", phrase: "Test"))], baseline: [])
    model.review = review
    await model.executeReview(review)
    #expect(model.review?.id == review.id)
    #expect(model.error != nil && !model.showsWindowError)
    #expect(model.needsRefresh && !model.canWrite)
    #expect(await backend.writes == 1)
}

@Test @MainActor func emoticonWaitsForCustomShortcutThenSavesExactFace() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let model = AppModel(demo: true, supportDirectory: directory)
    await model.refresh()
    let face = EmoticonCatalog.all.first { $0.body == "(っ◕‿◕)っ" }!
    #expect(await model.useTemplate(face, details: PersonalDetails(), shortcut: "", remember: false) == false)
    #expect(model.snapshots.isEmpty)
    await model.refresh()
    #expect(await model.useTemplate(face, details: PersonalDetails(), shortcut: ";hug", remember: false))
    #expect(model.entries.contains { $0.shortcut == ";hug" && Data($0.phrase.utf8) == Data(face.body.utf8) })
    #expect(model.snapshots.count == 1)
    #expect(model.query.isEmpty && model.section == .all)
    #expect(model.personalDetails.savedCount == 0)
}
