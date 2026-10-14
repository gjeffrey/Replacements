import Foundation
import Testing
@testable import ReplacementCore

private let exampleDetails = PersonalDetails(values: [
    "personalEmail":"alex@example.com", "workEmail":"alex@studio.example", "fullName":"Alex Rivera", "phone":"+1 555 123 4567",
    "streetAddress":"42 Example Street\nSuite 2", "cityRegionPostal":"Example City, CA 94103", "company":"Sample Studio", "jobTitle":"Designer",
    "website":"example.com", "schedulingLink":"https://example.com/calendar", "favoriteLink":"https://example.com/favorite", "socialHandle":"@alex",
    "meetingLink":"https://example.com/room", "helpLink":"https://example.com/docs"
])
@Test func everyTemplateHasUniqueIdentityAndCanRenderWithoutPlaceholders() throws {
    #expect(Set(TemplateCatalog.all.map(\.id)).count == TemplateCatalog.all.count)
    let suggested = TemplateCatalog.all.map(\.shortcut).filter { !$0.isEmpty }
    #expect(Set(suggested).count == suggested.count)
    for template in TemplateCatalog.all {
        let phrase = try template.render(with: exampleDetails)
        #expect(!phrase.contains("{{"))
        try Validation.check(Pair(shortcut: template.shortcut, phrase: phrase))
    }
}

@Test func emoticonsPreserveUnicodeAndRequireAChosenShortcut() throws {
    #expect(EmoticonCatalog.all.count == 200)
    #expect(Set(EmoticonCatalog.all.map(\.id)).count == 200)
    for face in EmoticonCatalog.all {
        #expect(face.category == .emoticons && face.fields.isEmpty && face.shortcut.isEmpty)
        #expect(face.suggestedShortcut(in: [Replacement(shortcut: ";face", phrase: "Existing")]).isEmpty)
        #expect(Data(try face.render(with: PersonalDetails()).utf8) == Data(face.body.utf8))
    }
    #expect(EmoticonCatalog.all.contains { $0.body == "(っ◕‿◕)っ" })
    #expect(EmoticonCatalog.all.first { $0.id == "emoticon-eyes" }?.body == "( ͡👁️ ͜ʖ ͡👁️)")
}
@Test func missingDetailsPreventUnfilledTemplatesFromBeingAdded() {
    let template = TemplateCatalog.all.first { $0.id == "contact-card" }!
    #expect(throws: (any Error).self) { try template.render(with: PersonalDetails()) }
}
@Test func oneRememberedEmailFillsDifferentTemplates() throws {
    let saved = try PersonalDetails().merging(exampleDetails, fields: [.personalEmail, .fullName])
    let email = TemplateCatalog.all.first { $0.id == "personal-email" }!
    let signature = TemplateCatalog.all.first { $0.id == "personal-signature" }!
    #expect(try email.render(with: saved) == "alex@example.com")
    #expect(try signature.render(with: saved) == "Best,\nAlex Rivera\nalex@example.com")
}
@Test func mergingOneTemplateKeepsOtherRememberedDetails() throws {
    var changes = PersonalDetails(); changes[.personalEmail] = "new@example.com"
    let merged = try exampleDetails.merging(changes, fields: [.personalEmail])
    #expect(merged[.personalEmail] == "new@example.com")
    #expect(merged[.workEmail] == "alex@studio.example")
    #expect(merged[.phone] == exampleDetails[.phone])
}
@Test func templateRenderingDoesNotRecursivelyInterpretPersonalData() throws {
    var details = exampleDetails; details[.fullName] = "Alex {{company}}"
    let template = TemplateCatalog.all.first { $0.id == "personal-signature" }!
    #expect(try template.render(with: details).contains("Alex {{company}}"))
}
@Test func linksNormalizeWhileEmailsAreValidated() throws {
    let template = TemplateCatalog.all.first { $0.id == "website" }!
    #expect(try template.render(with: exampleDetails) == "https://example.com")
    #expect(throws: (any Error).self) { try DetailField.personalEmail.validate("not an email") }
    #expect(throws: (any Error).self) { try DetailField.website.validate("javascript:alert(1)") }
}
@Test func shortcutSuggestionAvoidsCaseInsensitiveCollisions() {
    let template = TemplateCatalog.all.first { $0.id == "personal-email" }!
    let existing = [Replacement(shortcut: ";EMAIL",phrase: "one"),Replacement(shortcut: ";email2",phrase: "two")]
    #expect(template.suggestedShortcut(in: existing) == ";email3")
}
@Test func savedDetailsSurviveRelaunchWithPrivatePermissions() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Replacements-details-" + UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = PersonalDetailsStore(url: directory.appendingPathComponent("personal-details.json"))
    try store.save(exampleDetails)
    let restored = try PersonalDetailsStore(url: store.url).load()
    #expect(restored[.personalEmail] == exampleDetails[.personalEmail])
    #expect(restored[.website] == "https://example.com")
    let permissions = try FileManager.default.attributesOfItem(atPath: store.url.path)[.posixPermissions] as? NSNumber
    #expect(permissions?.intValue == 0o600)
    try store.forget(); #expect(try store.load().savedCount == 0)
}
@Test func corruptPersonalDetailsFailWithoutErasingTheFile() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Replacements-details-" + UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let store = PersonalDetailsStore(url: directory.appendingPathComponent("personal-details.json"))
    let bytes = Data("invalid data".utf8); try bytes.write(to: store.url)
    #expect(throws: (any Error).self) { try store.load() }
    #expect(try Data(contentsOf: store.url) == bytes)
}
@Test func galleryExamplesRenderEveryTemplateWithoutBecomingPersonalDetails() throws {
    for template in TemplateCatalog.all {
        let example = try template.render(with: TemplateCatalog.exampleDetails)
        #expect(template.examplePhrase == example)
        #expect(!example.contains("{{"))
        if !template.fields.isEmpty {
            #expect(throws: (any Error).self) { try template.render(with: PersonalDetails()) }
        }
    }
    #expect(PersonalDetails().savedCount == 0)
    let name = TemplateCatalog.all.first { $0.id == "full-name" }!
    #expect(name.examplePhrase == "John Appleseed")
}
@Test func templateSearchFindsTheVisiblePhrase() {
    let late = TemplateCatalog.all.first { $0.id == "running-late" }!
    #expect(late.matches("when I’m close"))
    let email = TemplateCatalog.all.first { $0.id == "personal-email" }!
    #expect(email.matches("john.appleseed@example.com"))
    #expect(!email.matches("not in this template"))
}
@Test func newMeetingAndHelpLinksReuseDetailsWithoutChangingTheBookingLink() throws {
    var entered = PersonalDetails(); entered[.meetingLink] = "example.com/new-room"; entered[.helpLink] = "example.com/help"
    let saved = try exampleDetails.merging(entered, fields: [.meetingLink, .helpLink])
    #expect(saved[.schedulingLink] == exampleDetails[.schedulingLink])
    for id in ["meeting-room", "join-call"] {
        let template = TemplateCatalog.all.first { $0.id == id }!
        #expect(try template.render(with: saved).contains("https://example.com/new-room"))
    }
    for id in ["help-center", "help-reply"] {
        #expect(try TemplateCatalog.all.first { $0.id == id }!.render(with: saved).contains("https://example.com/help"))
    }
    #expect(throws: (any Error).self) { try DetailField.meetingLink.validate("javascript:alert(1)") }
    #expect(throws: (any Error).self) { try DetailField.helpLink.validate("not a link") }
}
