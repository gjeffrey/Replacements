import Foundation
import AppKit
import ReplacementCore
import ReplacementNative

@main struct Probe {
    @MainActor static func main() async {
        _ = NSApplication.shared
        let arguments = CommandLine.arguments
        let backend = NativeBackend()
        do {
            let baseline = try await backend.read()
            print("Read: \(baseline.entries.count) native replacements. Source: \(baseline.source). Native selectors available: \(baseline.writable).")
            guard arguments.contains("--round-trip") || arguments.contains("--cleanup-test-marker") else { return }
            guard let index = arguments.firstIndex(of: "--history-dir"), arguments.count > index+1 else { throw ReplacementError.invalid("Live tests require --history-dir <path> to preserve a recovery snapshot.") }
            let history = HistoryStore(directory: URL(fileURLWithPath: arguments[index+1], isDirectory: true))
            let engine = MutationEngine(backend: backend, history: history)
            if let cleanup = arguments.firstIndex(of: "--cleanup-test-marker"), arguments.count > cleanup+1 {
                let marker = arguments[cleanup+1]
                guard marker.hasPrefix("ReplacementsTest"), marker.count == 24 else { throw ReplacementError.invalid("Cleanup accepts only the named diagnostic test marker.") }
                let pair = Pair(shortcut: marker, phrase: marker)
                guard baseline.entries.filter({ $0.pair == pair }).count == 1 else { throw ReplacementError.invalid("The exact diagnostic marker is not uniquely present. No changes made.") }
                let result = try await engine.perform([.remove(pair)], baseline: baseline.entries, reason: "Integration test: delayed dictionary marker cleanup")
                guard Validation.sameContents(result.read.entries, baseline.entries.filter { $0.pair != pair }) else { throw ReplacementError.unverified("Cleanup result differs from the expected list.") }
                print("Exact diagnostic marker removed; all other replacement contents preserved.")
                return
            }
            let dictionary = arguments.contains("--dictionary-word")
            let marker = "ReplacementsTest" + UUID().uuidString.prefix(8)
            let shortcut = dictionary ? "" : ";rp-" + UUID().uuidString.prefix(12).lowercased()
            let first = Pair(shortcut: shortcut, phrase: dictionary ? marker : "Replacements local integration test")
            let second = Pair(shortcut: shortcut, phrase: dictionary ? marker + "Edited" : "Replacements local integration test — edited")
            print("Testing only a unique temporary \(dictionary ? "dictionary word: " + marker : "shortcut: " + shortcut)")
            do {
                let added = try await engine.perform([.add(first)], baseline: baseline.entries, reason: "Integration test: add marker")
                print("ADD verified.")
                let edited = try await engine.perform([.edit(first, second)], baseline: added.read.entries, reason: "Integration test: edit marker")
                print("EDIT verified.")
                let deleted = try await engine.perform([.remove(second)], baseline: edited.read.entries, reason: "Integration test: delete marker")
                print("DELETE verified.")
                guard Validation.sameContents(deleted.read.entries, baseline.entries) else { throw ReplacementError.unverified("The original list changed during the test. Inspect backups before continuing.") }
                print("PASS: original replacement contents preserved. Device iCloud propagation remains unverified.")
            } catch {
                print("Test stopped: \(error.localizedDescription)")
                // Reconcile once, then remove only the exact test marker if present; never resend the failed operation.
                let live = try await backend.read()
                let markers = live.entries.filter { $0.shortcut == shortcut && ($0.pair == first || $0.pair == second) }
                if !markers.isEmpty {
                    _ = try await engine.perform(markers.map { .remove($0.pair) }, baseline: live.entries, reason: "Integration test: marker cleanup")
                    print("Temporary marker cleanup verified.")
                }
                throw error
            }
        } catch { fputs("Probe failed: \(error.localizedDescription)\n", stderr); exit(1) }
    }
}
