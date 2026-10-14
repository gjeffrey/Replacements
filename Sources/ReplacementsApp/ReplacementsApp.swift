import SwiftUI
import AppKit

@main struct ReplacementsApp: App {
    @State private var model: AppModel
    @State private var updates: UpdateController
    @AppStorage("showMenuBarIcon") private var showMenuBarIcon = false
    init() {
        let model = AppModel()
        _model = State(initialValue: model)
        _updates = State(initialValue: UpdateController(model: model))
    }
    var body: some Scene {
        Window("Replacements", id: "main") {
            ContentView(model: model)
                .frame(minWidth: 900, minHeight: 560)
                .task { await model.refresh() }
        }.defaultSize(width: 1100, height: 700)
            .commands {
                CommandGroup(after: .appInfo) {
                    Button("Check for Updates…") { updates.check() }.disabled(!updates.ready)
                }
                CommandGroup(replacing: .newItem) {
                    Button("New Replacement…") { model.showAdd = true }.keyboardShortcut("n").disabled(!model.canWrite)
                    Button("Import…") { model.importFile() }.keyboardShortcut("i", modifiers: [.command, .shift]).disabled(!model.canWrite)
                }
                CommandMenu("Replacements") {
                    Button("Template Library") { model.navigate(.templates) }.keyboardShortcut("l", modifiers: [.command, .shift])
                    Button("Your Details") { model.navigate(.details) }
                    Divider()
                    Button("Refresh") { Task { await model.refresh() } }.keyboardShortcut("r").disabled(model.busy)
                    Button("Back Up Now") { model.backupNow() }.disabled(!model.loaded || model.busy)
                    Button("Find and Replace…") { model.showBulk = true }.keyboardShortcut("h", modifiers: [.command, .shift]).disabled(!model.canWrite)
                    Button("Open Apple Keyboard Settings") { model.openSystemSettings() }
                }
            }
        MenuBarExtra("Replacements", systemImage: "text.badge.plus", isInserted: $showMenuBarIcon) {
            QuickAddView(model: model)
        }.menuBarExtraStyle(.window)
        Settings { PreferencesView(model: model, updates: updates).frame(width: 440).padding(24) }
    }
}
struct QuickAddView: View {
    @Bindable var model: AppModel
    @Environment(\.openWindow) private var openWindow
    @State private var shortcut = ""
    @State private var phrase = ""
    @State private var message = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Quick add", systemImage: "text.badge.plus").font(.headline)
            TextField("Shortcut", text: $shortcut).textFieldStyle(.roundedBorder)
            TextField("Phrase", text: $phrase, axis: .vertical).lineLimit(3...6).textFieldStyle(.roundedBorder)
            Text(message.isEmpty ? "Saved to Apple’s native replacements." : message).font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("Open Replacements") { openWindow(id: "main"); NSApp.activate(ignoringOtherApps: true) }
                Spacer()
                Button("Add") {
                    Task { if await model.add(shortcut: shortcut, phrase: phrase) { shortcut = ""; phrase = ""; message = "Saved on this Mac." } else { message = model.error ?? "Refresh in the main window." } }
                }.buttonStyle(.borderedProminent).disabled(!model.canWrite || phrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            if model.busy { ProgressView().controlSize(.small) }
            Divider()
            Button("Quit Replacements") { NSApp.terminate(nil) }.font(.caption)
        }.padding(18).frame(width: 360)
    }
}
struct PreferencesView: View {
    @Bindable var model: AppModel
    @Bindable var updates: UpdateController
    @AppStorage("showMenuBarIcon") private var showMenuBarIcon = false
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("A little less typing.").font(.title2.bold())
            Text("Replacements uses Apple’s own text replacements. No account, subscription, or separate sync service.")
            Text("Free v1 preview. An optional tip link can be added when the product is ready to release.").foregroundStyle(.secondary)
            Divider()
            Toggle("Show quick add in the menu bar", isOn: $showMenuBarIcon)
            Toggle("Check for updates automatically", isOn: Binding(get: { updates.automaticChecks }, set: { updates.setAutomaticChecks($0) })).disabled(!updates.available)
            Button("Check for Updates…") { updates.check() }.disabled(!updates.ready)
            Text("History stays on this Mac. Up to 50 snapshots are kept; export important backups for long-term storage.").font(.callout)
            Button("Show Local Backups") { model.revealHistory() }
            Button("Apple Keyboard Settings") { model.openSystemSettings() }
            Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0") · Free preview").font(.caption).foregroundStyle(.secondary)
        }
    }
}
