import Foundation
import Testing
import SQLite3
import KeyboardBridge

private func fixture() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent("Replacements-fixture-" + UUID().uuidString + ".db") }
private func create(_ url: URL, sql: String) throws {
    var db: OpaquePointer?
    guard sqlite3_open(url.path, &db) == SQLITE_OK else { throw NSError(domain: "fixture", code: 1) }
    defer { sqlite3_close(db) }
    guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else { throw NSError(domain: "fixture", code: 2) }
}
@Test func readonlyBridgePreservesBytesAndExcludesTombstones() throws {
    let url = fixture(); defer { try? FileManager.default.removeItem(at: url) }
    try create(url, sql: "CREATE TABLE ZTEXTREPLACEMENTENTRY (Z_PK INTEGER, ZUNIQUENAME TEXT, ZSHORTCUT TEXT, ZPHRASE TEXT, ZWASDELETED INTEGER); INSERT INTO ZTEXTREPLACEMENTENTRY VALUES(1,'one',';hi','Hello 👋',0),(2,'two','','Dictionary word',0),(3,'deleted','gone','old',1);")
    let before = try Data(contentsOf: url)
    let rows = try RPKeyboardBridge().readDatabase(atPath: url.path)
    #expect(rows.count == 2)
    #expect(rows[0]["phrase"] as? String == "Hello 👋")
    #expect(rows[1]["shortcut"] as? String == "")
    #expect(try Data(contentsOf: url) == before)
}
@Test func missingDatabaseIsNotCreated() {
    let url = fixture()
    #expect(throws: (any Error).self) { try RPKeyboardBridge().readDatabase(atPath: url.path) }
    #expect(!FileManager.default.fileExists(atPath: url.path))
}
@Test func incompatibleSchemaFailsClosed() throws {
    let url = fixture(); defer { try? FileManager.default.removeItem(at: url) }
    try create(url, sql: "CREATE TABLE unknown (x TEXT);")
    #expect(throws: (any Error).self) { try RPKeyboardBridge().readDatabase(atPath: url.path) }
}
