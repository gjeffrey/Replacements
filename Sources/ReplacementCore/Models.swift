import Foundation

public struct Replacement: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var shortcut: String
    public var phrase: String
    public init(id: String = UUID().uuidString, shortcut: String, phrase: String) {
        self.id = id; self.shortcut = shortcut; self.phrase = phrase
    }
    public var pair: Pair { Pair(shortcut: shortcut, phrase: phrase) }
}
public struct Pair: Codable, Hashable, Sendable {
    public var shortcut: String
    public var phrase: String
    public init(shortcut: String, phrase: String) { self.shortcut = shortcut; self.phrase = phrase }
    public var key: String { shortcut.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX")) }
}
public enum ReplacementError: LocalizedError, Equatable {
    case invalid(String), stale, ambiguous, busy, unverified(String)
    public var errorDescription: String? {
        switch self {
        case .invalid(let reason): return reason
        case .stale: return "Your replacements changed elsewhere. Refresh and review the change again."
        case .ambiguous: return "Identical native rows cannot be addressed individually. Resolve them in System Settings before editing or deleting this pair."
        case .busy: return "Another operation is in progress."
        case .unverified(let reason): return reason
        }
    }
}
public enum Validation {
    public static func check(_ pair: Pair) throws {
        guard !pair.phrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ReplacementError.invalid("A phrase is required.") }
        guard pair.shortcut.count <= 256, pair.phrase.utf8.count <= 1_048_576 else { throw ReplacementError.invalid("This replacement is too large.") }
        guard !pair.shortcut.unicodeScalars.contains(where: { CharacterSet.newlines.contains($0) || CharacterSet.controlCharacters.contains($0) }) else { throw ReplacementError.invalid("Shortcuts cannot contain line breaks or control characters. Leave the shortcut empty for a dictionary word.") }
        guard !pair.phrase.contains("\0") else { throw ReplacementError.invalid("A phrase cannot contain a null character.") }
    }
    public static func counts(_ entries: [Replacement]) -> [Pair: Int] {
        Dictionary(entries.map { ($0.pair, 1) }, uniquingKeysWith: +)
    }
    public static func sameContents(_ a: [Replacement], _ b: [Replacement]) -> Bool { counts(a) == counts(b) }
    public static func issueIDs(_ entries: [Replacement]) -> Set<String> {
        let pairs = counts(entries)
        let groups = Dictionary(grouping: entries.filter { !$0.shortcut.isEmpty }, by: { $0.pair.key })
        return Set(entries.filter { pairs[$0.pair, default: 0] > 1 || (!$0.shortcut.isEmpty && groups[$0.pair.key, default: []].count > 1) }.map(\.id))
    }
    public static func canInsert(_ pair: Pair, into entries: [Replacement], excluding: String? = nil) -> Bool {
        !entries.contains { row in
            row.id != excluding && (row.pair == pair || (!pair.shortcut.isEmpty && row.pair.key == pair.key))
        }
    }
}
public enum Change: Codable, Hashable, Sendable {
    case add(Pair), remove(Pair), edit(Pair, Pair)
    public var old: Pair? { switch self { case .add: nil; case .remove(let p): p; case .edit(let p, _): p } }
    public var new: Pair? { switch self { case .remove: nil; case .add(let p): p; case .edit(_, let p): p } }
    public func applying(to entries: [Replacement]) throws -> [Replacement] {
        var result = entries
        if let old {
            let matches = result.filter { $0.pair == old }.count
            guard matches > 0 else { throw ReplacementError.stale }
            guard matches == 1 else { throw ReplacementError.ambiguous }
            result.removeAll { $0.pair == old }
        }
        if let new {
            try Validation.check(new)
            guard Validation.canInsert(new, into: result) else { throw ReplacementError.invalid("That shortcut already exists or conflicts with another replacement.") }
            result.append(Replacement(shortcut: new.shortcut, phrase: new.phrase))
        }
        return result
    }
}
public struct ImportReview: Sendable {
    public var additions: [Pair] = []
    public var duplicates = 0
    public var conflicts: [Pair] = []
    public init(pairs: [Pair], existing: [Replacement]) throws {
        var knownPairs = Set(existing.map(\.pair))
        var keys = Set(existing.filter { !$0.shortcut.isEmpty }.map { $0.pair.key })
        for pair in pairs {
            try Validation.check(pair)
            if knownPairs.contains(pair) { duplicates += 1 }
            else if !pair.shortcut.isEmpty && keys.contains(pair.key) { conflicts.append(pair) }
            else {
                additions.append(pair); knownPairs.insert(pair)
                if !pair.shortcut.isEmpty { keys.insert(pair.key) }
            }
        }
    }
}
public enum Planner {
    public static func restore(_ backup: [Replacement], over current: [Replacement]) throws -> [Change] {
        let target = Validation.counts(backup), live = Validation.counts(current)
        // Restore cannot manufacture duplicate shortcuts or guess which identical row to remove.
        guard Validation.issueIDs(backup).isEmpty else { throw ReplacementError.invalid("This backup contains duplicates or conflicts. Import it to merge safe entries, or resolve the conflicts first.") }
        let removals = live.keys.filter { target[$0] == nil }
        guard live.allSatisfy({ $0.value == 1 || target[$0.key] == $0.value }) else { throw ReplacementError.ambiguous }
        let additions = target.keys.filter { live[$0] == nil }
        return removals.sorted(by: order).map(Change.remove) + additions.sorted(by: order).map(Change.add)
    }
    private static func order(_ a: Pair, _ b: Pair) -> Bool { a.shortcut == b.shortcut ? a.phrase < b.phrase : a.shortcut < b.shortcut }
    public static func replacing(_ find: String, with replacement: String, in rows: [Replacement]) throws -> [Change] {
        guard !find.isEmpty else { throw ReplacementError.invalid("Enter the text to find.") }
        return try rows.compactMap { row in
            let phrase = row.phrase.replacingOccurrences(of: find, with: replacement)
            guard phrase != row.phrase else { return nil }
            let pair = Pair(shortcut: row.shortcut, phrase: phrase); try Validation.check(pair)
            return .edit(row.pair, pair)
        }
    }
}
