import SwiftUI
import AppKit
import ReplacementCore

struct ContentView: View {
    @Bindable var model: AppModel
    @FocusState private var searchFocused: Bool
    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 32, height: 32)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Replacements").font(.headline)
                        Text(model.demo ? "DEMO LIBRARY" : "MADE FOR YOUR MAC").font(.system(size: 9, weight: .semibold)).tracking(1.3).foregroundStyle(.secondary)
                    }
                    Spacer()
                }.padding(16)
                List(selection: Binding(get: { model.section }, set: { if let destination = $0 { model.navigate(destination) } else { model.section = nil } })) {
                    SwiftUI.Section("Library") {
                        sidebarRow("Shortcuts", image: "text.alignleft", count: model.shortcutCount).tag(Section.all)
                        sidebarRow("Dictionary Words", image: "character.book.closed", count: model.dictionaryCount).tag(Section.dictionary)
                        sidebarRow("Duplicates & Conflicts", image: "exclamationmark.triangle", count: model.issueIDs.count).tag(Section.issues)
                    }
                    SwiftUI.Section("Make It Yours") {
                        Label("Template Library", systemImage: "square.grid.2x2").tag(Section.templates)
                        Label("Your Details", systemImage: "person.crop.rectangle").tag(Section.details)
                    }
                    SwiftUI.Section("Tools") {
                        Label("Backups & History", systemImage: "clock.arrow.circlepath").tag(Section.history)
                        Label("Verify Device Sync", systemImage: "iphone.and.arrow.forward").tag(Section.sync)
                    }
                }.listStyle(.sidebar)
                Spacer(minLength: 0)
                Label(model.demo ? "Isolated demo" : "Apple’s native library", systemImage: model.demo ? "sparkles" : "apple.logo")
                    .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(16)
            }.navigationSplitViewColumnWidth(min: 220, ideal: 245, max: 300)
        } detail: {
            VStack(spacing: 0) {
                if model.needsRefresh {
                    HStack {
                        Label("Refresh to inspect the last operation before continuing.", systemImage: "exclamationmark.triangle")
                        Spacer(); Button("Refresh") { Task { await model.refresh() } }
                    }.padding(12).background(.orange.opacity(0.12))
                }
                switch model.section ?? .all {
                case .all, .dictionary, .issues: library
                case .templates: TemplateLibraryView(model: model)
                case .details: PersonalDetailsView(model: model)
                case .history: HistoryView(model: model)
                case .sync: SyncView(model: model)
                }
                Divider()
                HStack(spacing: 10) {
                    if model.busy { ProgressView().controlSize(.small) }
                    Text(model.status.isEmpty ? "Connecting…" : model.status).lineLimit(1)
                    Spacer()
                    Text(model.demo ? "Isolated demo" : model.loaded ? "Apple Text Replacements" : model.source).foregroundStyle(.secondary)
                }.font(.caption).padding(.horizontal, 20).padding(.vertical, 10)
            }
        }
        .toolbar {
            ToolbarItem {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField(model.section == .templates ? "Search templates" : model.section == .dictionary ? "Search dictionary words" : "Search shortcuts or phrases", text: $model.query).textFieldStyle(.plain).focused($searchFocused)
                    Button {
                        model.query = ""
                        searchFocused = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("Clear Search")
                    .accessibilityLabel("Clear Search")
                    .disabled(model.query.isEmpty)
                }
                    .frame(width: 245).padding(6)
            }
            ToolbarItem { Button { model.showAdd = true } label: { Label(model.section == .dictionary ? "New Word" : "New Replacement", systemImage: "plus") }.disabled(!model.canWrite) }
            ToolbarItem {
                Menu {
                    Button("Import JSON, CSV, or Apple Plist…") { model.importFile() }.disabled(!model.canWrite)
                    SwiftUI.Section("Export") {
                        ForEach(TransferFormat.allCases, id: \.self) { format in
                            Button("Export All as \(format.rawValue.uppercased())…") { model.exportFile(format) }
                            Button("Export Selected as \(format.rawValue.uppercased())…") { model.exportFile(format, selected: true) }.disabled(model.selection.isEmpty)
                        }
                    }
                    Divider()
                    Button("Back Up Now") { model.backupNow() }
                } label: { Label("Library Actions", systemImage: "ellipsis.circle") }
                    .help("Import, export and back up").disabled(!model.loaded || model.busy)
            }
        }
        .background {
            Button("Find") { searchFocused = true }.keyboardShortcut("f").hidden()
        }
        .sheet(item: $model.selectedTemplate) { TemplateSetupView(model: model, template: $0) }
        .sheet(isPresented: $model.showAdd) { AddView(model: model) }
        .sheet(isPresented: $model.showBulk) { BulkView(model: model) }
        .sheet(item: $model.review) { ChangeReviewView(model: model, review: $0) }
        .alert("Replacements", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button("OK", role: .cancel) { model.error = nil }
        } message: { Text(model.error ?? "") }
    }
    private func sidebarRow(_ title: String, image: String, count: Int) -> some View {
        HStack { Label(title, systemImage: image); Spacer(); Text("\(count)").font(.caption.monospacedDigit()).foregroundStyle(.secondary) }
    }
    private var library: some View {
        VStack(alignment: .leading, spacing: 0) {
            if model.section == .issues && !model.visible.isEmpty {
                Label("These entries overlap. Review them before making changes.", systemImage: "exclamationmark.triangle")
                    .font(.callout).foregroundStyle(.secondary).padding(12)
            }
            if model.loaded && model.visible.isEmpty {
                ContentUnavailableView(model.query.isEmpty ? (model.section == .issues ? "Everything looks tidy" : model.section == .dictionary ? "Your dictionary" : "Make your first shortcut") : "No matching entries", systemImage: model.section == .issues ? "checkmark.circle" : model.section == .dictionary ? "character.book.closed" : "text.magnifyingglass", description: Text(model.query.isEmpty ? (model.section == .dictionary ? "Add words you want Apple to leave as you type them." : "Use New Replacement to add a phrase.") : "Try a shorter word or phrase."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Table(model.visible, selection: $model.selection) {
                    if model.section != .dictionary {
                        TableColumn("Shortcut") { row in InlineCell(model: model, row: row, field: .shortcut) }.width(min: 100, ideal: 145, max: 240)
                    }
                    TableColumn(model.section == .dictionary ? "Word" : "Phrase") { row in InlineCell(model: model, row: row, field: .phrase) }.width(min: 300)
                    TableColumn("") { row in
                        if model.issueIDs.contains(row.id) { Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange).help("Duplicate or conflicting shortcut").accessibilityLabel("Duplicate or conflict") }
                    }.width(26)
                }
            }
            if model.selection.count == 1, let row = model.selectedRows.first {
                Divider()
                HStack(alignment: .top, spacing: 16) {
                    Text(model.drafts[row.id]?.value.phrase ?? row.phrase)
                        .font(.callout).lineLimit(4).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                        .help(row.phrase)
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(model.drafts[row.id]?.value.phrase ?? row.phrase, forType: .string)
                    } label: { Image(systemName: "doc.on.doc") }
                        .buttonStyle(.plain).help("Copy Phrase").accessibilityLabel("Copy Phrase")
                }.padding(.horizontal, 16).padding(.vertical, 10)
            }
            Divider()
            HStack {
                Text("\(model.visible.count) shown\(model.selection.isEmpty ? "" : " · \(model.selection.count) selected")").font(.caption).foregroundStyle(.secondary)
                if !model.drafts.isEmpty { Text("\(model.drafts.count) unsaved").font(.caption).foregroundStyle(.orange); Button("Discard Drafts") { model.drafts.removeAll() } }
                Spacer()
                Button("Find & Replace…") { model.showBulk = true }.disabled(!model.canWrite || model.entries.isEmpty)
                Button("Delete Selected…", role: .destructive) { model.reviewDelete() }.disabled(!model.canWrite || model.selection.isEmpty)
            }.padding(.horizontal, 16).padding(.vertical, 8)
        }
    }
}
enum EditField { case shortcut, phrase }
struct InlineCell: View {
    @Bindable var model: AppModel
    let row: Replacement
    let field: EditField
    @FocusState private var focused: Bool
    private var value: String {
        let pair = model.drafts[row.id]?.value ?? row.pair
        return field == .shortcut ? pair.shortcut : pair.phrase
    }
    var body: some View {
        HStack(spacing: 6) {
            TextField(field == .shortcut ? "Dictionary word" : "Phrase", text: Binding(get: { value }, set: { model.setDraft($0, row: row, field: field) }), axis: .vertical)
                .font(field == .shortcut ? .system(.body, design: .monospaced) : .body)
                .lineLimit(focused || model.drafts[row.id] != nil ? 1...8 : 1...1).textFieldStyle(.plain).focused($focused)
                .onSubmit { save() }.disabled(!model.canWrite)
                .accessibilityLabel(field == .shortcut ? "Shortcut" : model.section == .dictionary ? "Word" : "Phrase")
                .accessibilityValue(value)
                .help(value)
            if model.drafts[row.id] != nil && field == .phrase {
                Button { save() } label: { Image(systemName: "checkmark.circle.fill") }.buttonStyle(.plain).foregroundStyle(.tint).help("Save both cells").disabled(!model.canWrite).accessibilityLabel("Save row")
                Button { model.drafts[row.id] = nil } label: { Image(systemName: "xmark.circle") }.buttonStyle(.plain).foregroundStyle(.secondary).help("Cancel row edit").accessibilityLabel("Cancel row edit")
            }
        }.padding(.vertical, 3)
    }
    private func save() { Task { await model.saveDraft(row); focused = false } }
}
