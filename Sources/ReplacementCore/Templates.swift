import Foundation

public enum DetailField: String, CaseIterable, Codable, Identifiable, Sendable {
    case personalEmail, workEmail, fullName, phone, streetAddress, cityRegionPostal
    case company, jobTitle, website, schedulingLink, favoriteLink, socialHandle, meetingLink, helpLink
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .personalEmail: "Personal email"
        case .workEmail: "Work email"
        case .fullName: "Full name"
        case .phone: "Phone number"
        case .streetAddress: "Street address"
        case .cityRegionPostal: "City, region & postal code"
        case .company: "Company"
        case .jobTitle: "Job title"
        case .website: "Website"
        case .schedulingLink: "Scheduling link"
        case .favoriteLink: "Favorite link"
        case .socialHandle: "Social handle"
        case .meetingLink: "Meeting room link"
        case .helpLink: "Help center link"
        }
    }
    public var question: String {
        switch self {
        case .personalEmail: "What’s your personal email address?"
        case .workEmail: "What’s your work email address?"
        case .fullName: "What name would you like to use?"
        case .phone: "What phone number do you share?"
        case .streetAddress: "What’s your street address?"
        case .cityRegionPostal: "What’s your city, region and postal code?"
        case .company: "Where do you work?"
        case .jobTitle: "What’s your job title?"
        case .website: "What’s your website?"
        case .schedulingLink: "What link do you use to book time?"
        case .favoriteLink: "What link do you send all the time?"
        case .socialHandle: "What social handle do you share?"
        case .meetingLink: "What link opens your regular meeting room?"
        case .helpLink: "Where can people find your help articles?"
        }
    }
    public var help: String {
        switch self {
        case .personalEmail: "Used again in your contact card and personal signature."
        case .workEmail: "Kept separate from your personal email."
        case .fullName: "Use the name you want people to see."
        case .phone: "Include the country code if you usually share it."
        case .streetAddress: "Include your apartment or suite, if needed."
        case .cityRegionPostal: "Write this as you would on a mailing label."
        case .company: "Used in introductions and work signatures."
        case .jobTitle: "Your role, in your own words."
        case .website: "A full link or a domain name is fine."
        case .schedulingLink: "Paste your calendar or booking page link."
        case .favoriteLink: "A portfolio, playlist, article, or anything you like sharing."
        case .socialHandle: "Include the @ if you want it in the phrase."
        case .meetingLink: "Use your recurring meeting link, separate from your booking calendar."
        case .helpLink: "A help center, instructions page, or frequently asked questions."
        }
    }
    public var group: String {
        switch self {
        case .personalEmail, .fullName, .phone, .streetAddress, .cityRegionPostal: "Contact"
        case .workEmail, .company, .jobTitle: "Work"
        case .website, .schedulingLink, .favoriteLink, .socialHandle, .meetingLink, .helpLink: "Links"
        }
    }
    public var multiline: Bool { self == .streetAddress }
    public func normalized(_ raw: String) -> String {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if [.website, .schedulingLink, .favoriteLink, .meetingLink, .helpLink].contains(self), !value.isEmpty, !value.contains("://") { return "https://" + value }
        return value
    }
    public func validate(_ raw: String) throws {
        let value = normalized(raw)
        guard !value.isEmpty else { throw ReplacementError.invalid("Add your \(title.lowercased()) to complete this template.") }
        guard value.utf8.count <= 4096, !value.contains("\0") else { throw ReplacementError.invalid("Your \(title.lowercased()) is too long or contains an invalid character.") }
        if !multiline, value.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) { throw ReplacementError.invalid("Use one line for your \(title.lowercased()).") }
        if [.personalEmail, .workEmail].contains(self) {
            let parts = value.split(separator: "@", omittingEmptySubsequences: false)
            guard parts.count == 2, parts.allSatisfy({ !$0.isEmpty }), !value.unicodeScalars.contains(where: { CharacterSet.whitespacesAndNewlines.contains($0) }) else { throw ReplacementError.invalid("Enter a complete email address, including @.") }
        }
        if [.website, .schedulingLink, .favoriteLink, .meetingLink, .helpLink].contains(self) {
            guard let url = URLComponents(string: value), ["https", "http"].contains(url.scheme?.lowercased() ?? ""), let host = url.host, !host.isEmpty, !value.contains(" ") else { throw ReplacementError.invalid("Enter a complete web link or domain name.") }
        }
    }
}
public struct PersonalDetails: Codable, Equatable, Sendable {
    public var version = 1
    public var values: [String: String]
    public init(values: [String: String] = [:]) { self.values = values }
    public subscript(_ field: DetailField) -> String {
        get { values[field.rawValue] ?? "" }
        set { values[field.rawValue] = newValue }
    }
    public var savedCount: Int { DetailField.allCases.filter { !self[$0].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count }
    public func merging(_ changes: PersonalDetails, fields: [DetailField]) throws -> PersonalDetails {
        var result = self
        for field in fields {
            let value = field.normalized(changes[field])
            if value.isEmpty { result.values[field.rawValue] = nil }
            else { try field.validate(value); result[field] = value }
        }
        return result
    }
}
public struct PersonalDetailsStore: Sendable {
    public let url: URL
    public init(url: URL) { self.url = url }
    public func load() throws -> PersonalDetails {
        guard FileManager.default.fileExists(atPath: url.path) else { return PersonalDetails() }
        let data = try Data(contentsOf: url)
        guard data.count < 100_000 else { throw ReplacementError.invalid("Saved personal details could not be loaded safely.") }
        let details = try JSONDecoder().decode(PersonalDetails.self, from: data)
        guard details.version == 1 else { throw ReplacementError.invalid("This saved details format is not supported.") }
        return details
    }
    public func save(_ details: PersonalDetails) throws {
        let normalized = try PersonalDetails().merging(details, fields: DetailField.allCases)
        let manager = FileManager.default
        try manager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try manager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.deletingLastPathComponent().path)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(normalized).write(to: url, options: .atomic)
        try manager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
    public func forget() throws {
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }
}
public enum TemplateCategory: String, CaseIterable, Identifiable, Sendable {
    case essentials = "Essentials", work = "Work", everyday = "Everyday", symbols = "Symbols", fun = "Just for Fun"
    public var id: String { rawValue }
}
public struct ShortcutTemplate: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let summary: String
    public let category: TemplateCategory
    public let icon: String
    public let shortcut: String
    public let body: String
    public init(id: String, title: String, summary: String, category: TemplateCategory, icon: String, shortcut: String, body: String) {
        self.id=id; self.title=title; self.summary=summary; self.category=category; self.icon=icon; self.shortcut=shortcut; self.body=body
    }
    private var tokens: [(Range<String.Index>, DetailField?)] {
        let regex = try! NSRegularExpression(pattern: #"\{\{([A-Za-z]+)\}\}"#)
        return regex.matches(in: body, range: NSRange(body.startIndex..., in: body)).compactMap { match in
            guard let full = Range(match.range, in: body), let name = Range(match.range(at: 1), in: body) else { return nil }
            return (full, DetailField(rawValue: String(body[name])))
        }
    }
    public var fields: [DetailField] {
        var seen = Set<DetailField>()
        return tokens.compactMap(\.1).filter { seen.insert($0).inserted }
    }
    public func render(with details: PersonalDetails) throws -> String {
        var result = "", cursor = body.startIndex
        for (range, field) in tokens {
            guard let field else { throw ReplacementError.invalid("This template has an unknown detail field.") }
            try field.validate(details[field])
            result += String(body[cursor..<range.lowerBound]) + field.normalized(details[field])
            cursor = range.upperBound
        }
        result += body[cursor...]
        return result
    }
    // Gallery examples are never used as setup drafts or saved personal details.
    public var examplePhrase: String { (try? render(with: TemplateCatalog.exampleDetails)) ?? body }
    public func suggestedShortcut(in existing: [Replacement]) -> String {
        let occupied = Set(existing.filter { !$0.shortcut.isEmpty }.map { $0.pair.key })
        var candidate = shortcut, suffix = 2
        while occupied.contains(Pair(shortcut: candidate, phrase: "").key) { candidate = shortcut + String(suffix); suffix += 1 }
        return candidate
    }
    public func matches(_ query: String) -> Bool {
        query.isEmpty || [title, summary, shortcut, category.rawValue, examplePhrase].contains { $0.localizedStandardContains(query) }
    }
}
public enum TemplateCatalog {
    // John Appleseed/example.com follows Apple's WWDC identity examples;
    // phone and address follow its Contacts examples. Work/link details are adaptations.
    public static let exampleDetails = PersonalDetails(values: [
        "fullName": "John Appleseed", "personalEmail": "john.appleseed@example.com",
        "workEmail": "j.appleseed@work.example.com", "phone": "(408) 555-0126",
        "streetAddress": "One Apple Park Way", "cityRegionPostal": "Cupertino, CA 95014",
        "company": "Example Company", "jobTitle": "Designer", "website": "https://example.com",
        "schedulingLink": "https://example.com/calendar", "favoriteLink": "https://example.com/favorites",
        "socialHandle": "@johnappleseed", "meetingLink": "https://example.com/meet",
        "helpLink": "https://example.com/help"
    ])
    public static let all: [ShortcutTemplate] = [
        .init(id:"personal-email",title:"Your email",summary:"The address you type everywhere.",category:.essentials,icon:"envelope",shortcut:";email",body:"{{personalEmail}}"),
        .init(id:"work-email",title:"Work email",summary:"Keep business and personal separate.",category:.essentials,icon:"envelope.badge",shortcut:";workmail",body:"{{workEmail}}"),
        .init(id:"full-name",title:"Your full name",summary:"A tiny shortcut for your whole name.",category:.essentials,icon:"person",shortcut:";name",body:"{{fullName}}"),
        .init(id:"phone",title:"Phone number",summary:"Digits, without the double-checking.",category:.essentials,icon:"phone",shortcut:";phone",body:"{{phone}}"),
        .init(id:"home-address",title:"Mailing address",summary:"A ready-to-paste mailing label.",category:.essentials,icon:"house",shortcut:";address",body:"{{streetAddress}}\n{{cityRegionPostal}}"),
        .init(id:"contact-card",title:"Contact card",summary:"Your name, email, and phone in one go.",category:.essentials,icon:"person.crop.rectangle",shortcut:";contact",body:"{{fullName}}\n{{personalEmail}}\n{{phone}}"),
        .init(id:"website",title:"Your website",summary:"Send people straight to your work.",category:.essentials,icon:"globe",shortcut:";site",body:"{{website}}"),
        .init(id:"social-handle",title:"Your handle",summary:"Less hunting through your profile.",category:.essentials,icon:"at",shortcut:";handle",body:"{{socialHandle}}"),
        .init(id:"personal-signature",title:"Personal signature",summary:"A simple sign-off, already filled in.",category:.work,icon:"signature",shortcut:";sig",body:"Best,\n{{fullName}}\n{{personalEmail}}"),
        .init(id:"work-signature",title:"Work signature",summary:"Your name, role, company, and email.",category:.work,icon:"briefcase",shortcut:";worksig",body:"{{fullName}}\n{{jobTitle}} · {{company}}\n{{workEmail}}"),
        .init(id:"quick-introduction",title:"Quick introduction",summary:"Start with who you are and what you do.",category:.work,icon:"person.wave.2",shortcut:";intro",body:"Hi, I’m {{fullName}}, {{jobTitle}} at {{company}}. Nice to meet you."),
        .init(id:"booking-link",title:"Book some time",summary:"Share your calendar, in a sentence.",category:.work,icon:"calendar",shortcut:";book",body:"Choose a time that works for you: {{schedulingLink}}"),
        .init(id:"calendar-link",title:"Calendar link",summary:"Just the link, for anywhere you need it.",category:.work,icon:"link",shortcut:";calendar",body:"{{schedulingLink}}"),
        .init(id:"follow-up",title:"Gentle follow-up",summary:"A nudge that doesn’t shout.",category:.work,icon:"arrow.uturn.right",shortcut:";followup",body:"Just following up on this. Let me know when you’ve had a chance to look."),
        .init(id:"received",title:"Received, thank you",summary:"Close the loop in a few keystrokes.",category:.work,icon:"checkmark.circle",shortcut:";received",body:"Received, thank you. I’ll take a look and get back to you."),
        .init(id:"need-time",title:"A little more time",summary:"An honest update while you’re working.",category:.work,icon:"clock",shortcut:";working",body:"I’m on it. I’ll send an update as soon as I have one."),
        .init(id:"polite-no",title:"A kind no",summary:"A clear decline with a soft landing.",category:.work,icon:"hand.raised",shortcut:";decline",body:"Thanks for thinking of me. I can’t take this on right now, but I appreciate the invite."),
        .init(id:"on-my-way",title:"On my way",summary:"The classic, with room to make it yours.",category:.everyday,icon:"figure.walk",shortcut:";omw",body:"On my way!"),
        .init(id:"running-late",title:"Running a little late",summary:"A heads-up before the awkward arrival.",category:.everyday,icon:"clock.badge.exclamationmark",shortcut:";late",body:"Running a little late — sorry! I’ll let you know when I’m close."),
        .init(id:"call-me",title:"Call me here",summary:"A sentence that already knows your number.",category:.everyday,icon:"phone.arrow.up.right",shortcut:";callme",body:"You can reach me at {{phone}}."),
        .init(id:"favorite-link",title:"That link again",summary:"The thing you’re always sending people.",category:.everyday,icon:"link",shortcut:";link",body:"{{favoriteLink}}"),
        .init(id:"share-link",title:"Thought you’d like this",summary:"Your favorite link, with a little context.",category:.everyday,icon:"paperplane",shortcut:";share",body:"Thought you’d like this: {{favoriteLink}}"),
        .init(id:"delivery-note",title:"Delivery note",summary:"A friendly instruction for a package.",category:.everyday,icon:"shippingbox",shortcut:";delivery",body:"Please leave the package by the front door. Thank you!"),
        .init(id:"thank-you",title:"A proper thank you",summary:"A small sentence that goes a long way.",category:.everyday,icon:"heart",shortcut:";thanks",body:"Thank you — I really appreciate it."),
        .init(id:"shrug",title:"The shrug",summary:"For when the shoulders say it best.",category:.fun,icon:"person.fill.questionmark",shortcut:";shrug",body:"¯\\_(ツ)_/¯"),
        .init(id:"table-flip",title:"Flip the table",summary:"Tiny keyboard drama.",category:.fun,icon:"arrow.up.right",shortcut:";flip",body:"(╯°□°）╯︵ ┻━┻"),
        .init(id:"table-back",title:"Put it back",summary:"A little emotional cleanup.",category:.fun,icon:"arrow.down.left",shortcut:";unflip",body:"┬─┬ ノ( ゜-゜ノ)"),
        .init(id:"disapproval",title:"The look",summary:"One glance. No further questions.",category:.fun,icon:"eyes",shortcut:";look",body:"ಠ_ಠ"),
        .init(id:"tiny-bear",title:"A tiny bear",summary:"Some messages just need a bear.",category:.fun,icon:"pawprint",shortcut:";bear",body:"ʕ•ᴥ•ʔ"),
        .init(id:"cool",title:"Quietly cool",summary:"Sunglasses, without finding an emoji.",category:.fun,icon:"sunglasses",shortcut:";cool",body:"(⌐■_■)"),
        .init(id:"coffee",title:"Coffee, briefly",summary:"The most important status update.",category:.fun,icon:"cup.and.saucer",shortcut:";coffee",body:"Temporarily powered down. Applying coffee."),
        .init(id:"celebrate",title:"Small celebration",summary:"A little confetti for a little win.",category:.fun,icon:"party.popper",shortcut:";yay",body:"Small win. Big confetti. 🎉"),
        .init(id:"meeting-room",title:"Meeting room",summary:"Your regular video-call link.",category:.work,icon:"video",shortcut:";meet",body:"{{meetingLink}}"),
        .init(id:"join-call",title:"Join the call",summary:"Your meeting room, with an invitation.",category:.work,icon:"video",shortcut:";join",body:"Here’s the link for our call: {{meetingLink}}"),
        .init(id:"help-center",title:"Help center",summary:"Your frequently shared instructions.",category:.work,icon:"questionmark.circle",shortcut:";help",body:"{{helpLink}}"),
        .init(id:"help-reply",title:"Find the instructions",summary:"Point someone to your help articles.",category:.work,icon:"questionmark.circle",shortcut:";helpdocs",body:"You’ll find the instructions here: {{helpLink}}. Let me know which step you’re stuck on."),
        .init(id:"best-regards",title:"Best regards",summary:"A short sign-off with your name.",category:.work,icon:"signature",shortcut:";regards",body:"Best regards,\n{{fullName}}"),
        .init(id:"cheers",title:"Cheers",summary:"A friendly sign-off with your name.",category:.work,icon:"signature",shortcut:";cheers",body:"Cheers,\n{{fullName}}"),
        .init(id:"meeting-notes",title:"Meeting notes",summary:"Blank sections to fill after expansion. Plain text; no automatic date or cursor movement.",category:.work,icon:"note.text",shortcut:";notes",body:"Notes:\n\nDecisions:\n\nNext steps:"),
        .init(id:"meeting-agenda",title:"Meeting agenda",summary:"A short agenda outline to fill after expansion.",category:.work,icon:"list.bullet",shortcut:";agenda",body:"Topics:\nDecisions needed:\nNext steps:"),
        .init(id:"project-brief",title:"Project brief",summary:"A plain-text outline to fill after expansion.",category:.work,icon:"doc.text",shortcut:";brief",body:"Goal:\nAudience:\nDeliverables:\nDeadline:\nSuccess looks like:"),
        .init(id:"bug-report",title:"Bug report",summary:"Blank sections for a clear issue report. Fill them after expansion.",category:.work,icon:"ladybug",shortcut:";bug",body:"What I expected:\n\nWhat happened:\n\nSteps to reproduce:"),
        .init(id:"screenshot-request",title:"Send a screenshot",summary:"Ask to see the problem.",category:.work,icon:"photo",shortcut:";screenshot",body:"Could you send a screenshot of what you’re seeing? It’ll help me understand where things went wrong."),
        .init(id:"more-context",title:"A little more context",summary:"A useful follow-up when a request is unclear.",category:.work,icon:"text.bubble",shortcut:";context",body:"Could you tell me what you’re trying to accomplish and what’s getting in the way? A specific example would help."),
        .init(id:"missing-attachment",title:"Missing attachment",summary:"A polite nudge for a file.",category:.work,icon:"paperclip",shortcut:";attach",body:"I don’t see the attachment on this message. Could you send it again?"),
        .init(id:"reschedule",title:"Reschedule",summary:"Move a meeting using your saved booking link.",category:.work,icon:"calendar",shortcut:";reschedule",body:"Could we move our meeting? Sorry for the change. You can choose another time here: {{schedulingLink}}"),
        .init(id:"text-instead",title:"Text instead",summary:"When you can’t answer a call.",category:.everyday,icon:"message",shortcut:";textme",body:"I can’t pick up right now. Can you text me what you need?"),
        .init(id:"map-pin",title:"Send a map pin",summary:"Find the exact place to meet.",category:.everyday,icon:"mappin",shortcut:";pin",body:"Could you send me a map pin? I’ll meet you there."),
        .init(id:"command-symbol",title:"Command symbol",summary:"The Mac Command key symbol.",category:.symbols,icon:"command",shortcut:";cmd",body:"⌘"),
        .init(id:"option-symbol",title:"Option symbol",summary:"The Mac Option key symbol.",category:.symbols,icon:"option",shortcut:";opt",body:"⌥"),
        .init(id:"shift-symbol",title:"Shift symbol",summary:"The Shift key symbol.",category:.symbols,icon:"shift",shortcut:";shift",body:"⇧"),
        .init(id:"return-symbol",title:"Return symbol",summary:"The Return key symbol.",category:.symbols,icon:"return",shortcut:";return",body:"↵"),
        .init(id:"degree-symbol",title:"Degree symbol",summary:"For temperatures and angles.",category:.symbols,icon:"circle",shortcut:";degree",body:"°"),
        .init(id:"em-dash",title:"Em dash",summary:"A long dash for a pause or aside.",category:.symbols,icon:"minus",shortcut:";emdash",body:"—"),
        .init(id:"en-dash",title:"En dash",summary:"A shorter dash for ranges.",category:.symbols,icon:"minus",shortcut:";endash",body:"–"),
        .init(id:"bullet",title:"Bullet",summary:"A simple list marker.",category:.symbols,icon:"circle.fill",shortcut:";bullet",body:"•"),
        .init(id:"checkmark",title:"Checkmark",summary:"Mark something complete.",category:.symbols,icon:"checkmark",shortcut:";check",body:"✓"),
        .init(id:"multiplication",title:"Multiplication sign",summary:"A multiplication sign instead of the letter x.",category:.symbols,icon:"multiply",shortcut:";times",body:"×"),
        .init(id:"approximately",title:"Approximately equal",summary:"A compact symbol for an estimate.",category:.symbols,icon:"equal",shortcut:";approx",body:"≈")
    ]
}
