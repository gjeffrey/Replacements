import Foundation

public enum TransferFormat: String, CaseIterable, Sendable { case json, csv, plist }
public enum Transfer {
    private struct Document: Codable { var version: Int; var entries: [Pair] }
    public static func encode(_ rows: [Replacement], format: TransferFormat) throws -> Data {
        let pairs = rows.map(\.pair)
        switch format {
        case .json:
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            return try encoder.encode(Document(version: 1, entries: pairs))
        case .plist:
            return try PropertyListSerialization.data(fromPropertyList: pairs.map { ["replace": $0.shortcut, "with": $0.phrase] }, format: .xml, options: 0)
        case .csv:
            func quote(_ value: String) -> String { "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
            return Data((["shortcut,phrase"] + pairs.map { quote($0.shortcut) + "," + quote($0.phrase) }).joined(separator: "\r\n").utf8)
        }
    }
    public static func decode(_ data: Data, format: TransferFormat) throws -> [Pair] {
        guard data.count <= 20_000_000 else { throw ReplacementError.invalid("Import files must be smaller than 20 MB.") }
        let pairs: [Pair]
        switch format {
        case .json:
            let decoder = JSONDecoder()
            if let document = try? decoder.decode(Document.self, from: data) {
                guard document.version == 1 else { throw ReplacementError.invalid("This JSON version is not supported.") }
                pairs = document.entries
            } else { pairs = try decoder.decode([Pair].self, from: data) }
        case .plist:
            guard let array = try PropertyListSerialization.propertyList(from: data, format: nil) as? [[String: Any]] else { throw ReplacementError.invalid("Expected Apple's text replacement plist array.") }
            pairs = try array.map {
                guard let shortcut = $0["replace"] as? String, let phrase = $0["with"] as? String else { throw ReplacementError.invalid("Every plist row needs replace and with fields.") }
                return Pair(shortcut: shortcut, phrase: phrase)
            }
        case .csv:
            guard var text = String(data: data, encoding: .utf8) else { throw ReplacementError.invalid("CSV files must use UTF-8.") }
            if text.first == "\u{FEFF}" { text.removeFirst() }
            let rows = try parseCSV(text)
            guard rows.first == ["shortcut", "phrase"] else { throw ReplacementError.invalid("CSV must begin with the header shortcut,phrase.") }
            pairs = try rows.dropFirst().map { row in
                guard row.count == 2 else { throw ReplacementError.invalid("Every CSV row must have two columns.") }
                return Pair(shortcut: row[0], phrase: row[1])
            }
        }
        guard pairs.count <= 10_000 else { throw ReplacementError.invalid("Import at most 10,000 replacements at a time.") }
        try pairs.forEach(Validation.check)
        return pairs
    }
    // RFC 4180-style parser, preserving quoted newlines, commas, emoji and doubled quotes.
    private static func parseCSV(_ text: String) throws -> [[String]] {
        let chars = Array(text.unicodeScalars)
        var rows: [[String]] = [], row: [String] = [], field = "", i = 0
        var quoted = false, closed = false, touched = false
        func finishField() { row.append(field); field = ""; closed = false; touched = false }
        func finishRow() { finishField(); rows.append(row); row = [] }
        while i < chars.count {
            let c = chars[i]
            if quoted {
                if c == "\"" {
                    if i+1 < chars.count && chars[i+1] == "\"" { field.append("\""); i += 1 }
                    else { quoted = false; closed = true }
                } else { field.unicodeScalars.append(c) }
            } else if c == "," { finishField() }
            else if c == "\r" || c == "\n" {
                finishRow()
                if c == "\r", i+1 < chars.count, chars[i+1] == "\n" { i += 1 }
            } else if c == "\"", field.isEmpty, !touched, !closed { quoted = true; touched = true }
            else {
                guard !closed && c != "\"" else { throw ReplacementError.invalid("Malformed CSV quoting.") }
                field.unicodeScalars.append(c); touched = true
            }
            i += 1
        }
        guard !quoted else { throw ReplacementError.invalid("An imported CSV quote was never closed.") }
        if !row.isEmpty || !field.isEmpty || touched || closed { finishRow() }
        return rows
    }
}
