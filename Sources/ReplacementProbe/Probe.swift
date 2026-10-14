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
            guard arguments.contains("--round-trip") else { return }
            guard let index = arguments.firstIndex(of: "--history-dir"), arguments.count > index+1 else { throw ReplacementError.invalid("Live tests require --history-dir <path> to preserve a recovery snapshot.") }
            let history = HistoryStore(directory: URL(fileURLWithPath: arguments[index+1], isDirectory: true))
            let engine = MutationEngine(backend: backend, history: history)
            let shortcut = ";rp-" + UUID().uuidString.prefix(12).lowercased()
            let first = Pair(shortcut: shortcut, phrase: "Replacements local integration test")
            let second = Pair(shortcut: shortcut, phrase: "Replacements local integration test — edited")
            print("Testing only a unique temporary marker: \(shortcut)")
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
