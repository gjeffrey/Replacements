import SwiftUI
import ReplacementCore

extension TemplateCategory {
    var tint: Color {
        switch self { case .essentials: .blue; case .work: .indigo; case .everyday: .orange; case .symbols: .teal; case .fun: .pink }
    }
}
struct TemplateLibraryView: View {
    @Bindable var model: AppModel
    @State private var category: TemplateCategory?
    private var templates: [ShortcutTemplate] {
        TemplateCategory.allCases.flatMap { category in TemplateCatalog.all.filter { $0.category == category } }
            .filter { (category == nil || $0.category == category) && $0.matches(model.query) }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 7) {
                Text("Good shortcuts start here.").font(.system(size: 27, weight: .semibold))
                Text("Choose a phrase. Personalize it, then add it.").foregroundStyle(.secondary)
            }.padding(.top, 24)
            Picker("Category", selection: $category) {
                Text("All").tag(TemplateCategory?.none)
                ForEach(TemplateCategory.allCases) { value in Text(value.rawValue).tag(Optional(value)) }
            }.pickerStyle(.segmented)
            ScrollView {
                if templates.isEmpty {
                    ContentUnavailableView("No matching templates", systemImage: "text.magnifyingglass", description: Text("Try another word or category.")).padding(.top, 50)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 250, maximum: 420), spacing: 14)], spacing: 14) {
                        ForEach(templates) { template in
                            TemplateCard(template: template, shortcut: template.suggestedShortcut(in: model.entries)) {
                                model.selectedTemplate = template
                            }
                        }
                    }.padding(.bottom, 20)
                }
            }
            HStack(spacing: 10) {
                Image(systemName: "person.crop.rectangle").foregroundStyle(.secondary)
                Text(model.personalDetails.savedCount == 0 ? "Add your details once. Reuse them in other templates." : "Your saved details are ready for other templates.").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Your Details") { model.navigate(.details) }
            }.padding(.bottom, 18)
        }.padding(.horizontal, 24)
    }
}
struct TemplateCard: View {
    let template: ShortcutTemplate
    let shortcut: String
    let action: () -> Void
    private var phrase: String { template.examplePhrase }
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 16) {
                Text(phrase)
                    .font(.system(size: template.category == .symbols ? 28 : 16)).foregroundStyle(.primary)
                    .lineSpacing(3).lineLimit(5).truncationMode(.tail)
                    .frame(maxWidth: .infinity, minHeight: 104, maxHeight: 104, alignment: .topLeading)
                HStack {
                    Text(shortcut).font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
                    Spacer()
                    Text(template.fields.isEmpty ? "Add…" : "Personalize…").font(.caption).foregroundStyle(.secondary)
                }
            }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 15))
                .overlay(RoundedRectangle(cornerRadius: 15).strokeBorder(.quaternary, lineWidth: 1))
                .contentShape(RoundedRectangle(cornerRadius: 15))
        }.buttonStyle(.plain).help(template.category == .symbols ? template.title : phrase)
            .accessibilityLabel("\(template.title). \(phrase). Shortcut \(shortcut).")
            .accessibilityHint(template.fields.isEmpty ? "Review before adding." : "Example details shown. Enter your own details and review before adding.")
    }
}
struct DetailInput: View {
    let field: DetailField
    @Binding var value: String
    let remembered: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(field.question).font(.callout.weight(.medium))
                Spacer()
                if remembered { Label("Remembered", systemImage: "checkmark.circle").font(.caption).foregroundStyle(.secondary) }
            }
            TextField(field.title, text: $value, axis: field.multiline ? .vertical : .horizontal)
                .lineLimit(field.multiline ? 2...4 : 1...1).textFieldStyle(.roundedBorder).autocorrectionDisabled()
                .accessibilityLabel(field.question)
            Text(field.help).font(.caption).foregroundStyle(.secondary)
        }
    }
}
struct TemplateSetupView: View {
    @Bindable var model: AppModel
    let template: ShortcutTemplate
    @Environment(\.dismiss) private var dismiss
    @State private var details: PersonalDetails
    @State private var shortcut: String
    @State private var remember = true
    // Intentional one-time draft seed: each opening starts with the latest saved personal details.
    init(model: AppModel, template: ShortcutTemplate) {
        self.model = model; self.template = template
        _details = State(initialValue: model.personalDetails)
        _shortcut = State(initialValue: template.suggestedShortcut(in: model.entries))
    }
    private var phrase: String? { try? template.render(with: details) }
    private var problem: String? {
        for field in template.fields where !details[field].isEmpty {
            do { try field.validate(details[field]) } catch { return error.localizedDescription }
        }
        guard let phrase else { return nil }
        guard !shortcut.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return "A shortcut is required on macOS." }
        let pair = Pair(shortcut: shortcut, phrase: phrase)
        do { try Validation.check(pair) } catch { return error.localizedDescription }
        return Validation.canInsert(pair, into: model.entries) ? nil : "This shortcut is already in your library. Choose another one."
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 13) {
                Image(systemName: template.icon).font(.title2).foregroundStyle(template.category.tint).frame(width: 48, height: 48).background(template.category.tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 5) { Text(template.title).font(.title2.bold()); Text(template.summary).foregroundStyle(.secondary) }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(template.fields) { field in
                        DetailInput(field: field, value: Binding(get: { details[field] }, set: { details[field] = $0 }), remembered: !model.personalDetails[field].isEmpty)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("What would you like to type?").font(.callout.weight(.medium))
                        TextField("Shortcut", text: $shortcut).textFieldStyle(.roundedBorder).font(.system(.body, design: .monospaced)).autocorrectionDisabled()
                        Text("The ; prefix helps keep it out of ordinary sentences. You can choose your own shortcut.").font(.caption).foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Your phrase", systemImage: "text.alignleft").font(.callout.weight(.semibold)).foregroundStyle(.secondary)
                        if let phrase { Text(phrase).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
                        else { Text("Add your details above to see the exact phrase you’ll save.").foregroundStyle(.secondary) }
                    }.padding(16).frame(maxWidth: .infinity, alignment: .leading).background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
                }.padding(.vertical, 2)
            }
            if !template.fields.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    Toggle("Remember these details for other templates", isOn: $remember)
                    Text("Your saved details stay on this Mac. Only phrases you add follow Apple’s sync.").font(.caption).foregroundStyle(.secondary)
                }
            }
            if let problem { Text(problem).font(.caption).foregroundStyle(.orange) }
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction).disabled(model.busy)
                Spacer()
                if model.busy { ProgressView().controlSize(.small) }
                Button("Add to My Replacements") {
                    Task { if await model.useTemplate(template, details: details, shortcut: shortcut, remember: remember) { dismiss() } }
                }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction).disabled(!model.canWrite || phrase == nil || problem != nil)
            }
        }.padding(26).frame(width: 560, height: template.fields.isEmpty ? 410 : 650)
            .modifier(SheetOperationFeedback(model: model))
    }
}
struct PersonalDetailsView: View {
    @Bindable var model: AppModel
    @State private var confirmForget = false
    private var current: PersonalDetails { model.personalDetailsDraft ?? model.personalDetails }
    private var hasDraft: Bool { model.personalDetailsDraft != nil && model.personalDetailsDraft != model.personalDetails }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 7) {
                Text("A few details. Less repeating.").font(.system(size: 27, weight: .semibold))
                Text("Save the information you use often. Templates will have it ready next time.").foregroundStyle(.secondary)
            }.padding(.top, 24)
            if let problem = model.personalDetailsProblem { Text(problem).font(.callout).foregroundStyle(.orange) }
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    ForEach(["Contact", "Work", "Links"], id: \.self) { group in
                        VStack(alignment: .leading, spacing: 16) {
                            Text(group.uppercased()).font(.caption.weight(.semibold)).tracking(1.1).foregroundStyle(.secondary)
                            ForEach(DetailField.allCases.filter { $0.group == group }) { field in
                                DetailInput(field: field, value: Binding(get: { current[field] }, set: { model.setPersonalDetailDraft($0, field: field) }), remembered: false)
                            }
                        }
                        Divider()
                    }
                }.padding(.vertical, 8).frame(maxWidth: 620, alignment: .leading).frame(maxWidth: .infinity, alignment: .leading)
            }
            Text("Stored on this Mac. Changing details fills future templates; it doesn’t rewrite replacements you’ve already added.").font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("Forget All Details…", role: .destructive) { confirmForget = true }.disabled(model.personalDetails.savedCount == 0 && model.personalDetailsProblem == nil)
                Spacer()
                if hasDraft {
                    Text("Unsaved changes").font(.caption).foregroundStyle(.secondary)
                    Button("Revert") { model.personalDetailsDraft = nil }
                }
                Button("Save Details") { model.savePersonalDetails(current) }.buttonStyle(.borderedProminent).disabled(!hasDraft)
            }.padding(.bottom, 18)
        }.padding(.horizontal, 24)
            .confirmationDialog("Forget all saved personal details?", isPresented: $confirmForget, titleVisibility: .visible) {
                Button("Forget All Details", role: .destructive) { model.forgetPersonalDetails() }
                Button("Cancel", role: .cancel) {}
            } message: { Text("This clears the details remembered on this Mac. Your existing Apple text replacements will stay in your library.") }
    }
}
