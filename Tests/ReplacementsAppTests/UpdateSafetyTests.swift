import Foundation
import Testing
@testable import ReplacementsApp

@Test @MainActor func updateRelaunchWaitsForInlineDraftAndVerifiedSave() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let model = AppModel(demo: true, supportDirectory: directory)
    await model.refresh()
    let updates = UpdateController(model: model)
    let row = model.entries.first { $0.shortcut == "brb" }!
    model.setDraft("Back in a moment.", row: row, field: .phrase)
    var installed = false
    #expect(updates.deferInstallationIfNeeded { installed = true })
    try await Task.sleep(for: .milliseconds(300))
    #expect(!installed)
    await model.saveDraft(row)
    try await Task.sleep(for: .milliseconds(350))
    #expect(installed)
    #expect(!model.updateMustWait)
    #expect(model.entries.contains { $0.phrase == "Back in a moment." })
    #expect(model.snapshots.count == 1)
}

@Test @MainActor func updateRelaunchWaitsForRememberedDetailsToPersist() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let model = AppModel(demo: true, supportDirectory: directory)
    let updates = UpdateController(model: model)
    model.setPersonalDetailDraft("alex@example.com", field: .personalEmail)
    var installed = false
    #expect(updates.deferInstallationIfNeeded { installed = true })
    try await Task.sleep(for: .milliseconds(300))
    #expect(!installed)
    #expect(model.savePersonalDetails(model.personalDetailsDraft!))
    try await Task.sleep(for: .milliseconds(350))
    #expect(installed)
    #expect(AppModel(demo: true, supportDirectory: directory).personalDetails[.personalEmail] == "alex@example.com")
}
