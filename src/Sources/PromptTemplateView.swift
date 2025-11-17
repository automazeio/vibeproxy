import SwiftUI

struct PromptTemplateView: View {
    @ObservedObject var templateManager: PromptTemplateManager
    @State private var showingAddSheet = false
    @State private var editingTemplate: PromptTemplate?
    @State private var searchText = ""

    var filteredTemplates: [PromptTemplate] {
        if searchText.isEmpty {
            return templateManager.templates
        }
        return templateManager.searchTemplates(query: searchText)
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Prompt Templates")
                    .font(.headline)
                Spacer()
                Button(action: { showingAddSheet = true }) {
                    Label("Add", systemImage: "plus")
                }
            }

            if templateManager.templates.isEmpty {
                VStack(spacing: 8) {
                    Text("No templates yet")
                        .foregroundColor(.secondary)
                    Text("Save your favorite prompts for quick access")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.controlBackgroundColor))
                .cornerRadius(8)
            } else {
                VStack(spacing: 8) {
                    SearchBar(text: $searchText, placeholder: "Search templates...")

                    List(filteredTemplates) { template in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(template.name)
                                    .fontWeight(.semibold)
                                if !template.description.isEmpty {
                                    Text(template.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                if !template.tags.isEmpty {
                                    HStack(spacing: 4) {
                                        ForEach(template.tags.prefix(2), id: \.self) { tag in
                                            Text(tag)
                                                .font(.caption2)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.blue.opacity(0.1))
                                                .cornerRadius(4)
                                        }
                                        if template.tags.count > 2 {
                                            Text("+\(template.tags.count - 2)")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                            Spacer()
                            HStack(spacing: 8) {
                                Button(action: { editingTemplate = template }) {
                                    Image(systemImage: "pencil")
                                        .foregroundColor(.blue)
                                }
                                .buttonStyle(.plain)

                                Button(action: { templateManager.deleteTemplate(id: template.id) }) {
                                    Image(systemImage: "trash")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listStyle(.plain)
                }
            }

            Spacer()
        }
        .padding()
        .sheet(isPresented: $showingAddSheet) {
            AddTemplateSheet(
                isPresented: $showingAddSheet,
                templateManager: templateManager
            )
        }
        .sheet(item: $editingTemplate) { template in
            EditTemplateSheet(
                isPresented: .constant(editingTemplate != nil),
                templateManager: templateManager,
                template: template
            )
        }
    }
}

struct AddTemplateSheet: View {
    @Binding var isPresented: Bool
    @ObservedObject var templateManager: PromptTemplateManager
    @State private var name = ""
    @State private var description = ""
    @State private var promptText = ""
    @State private var systemPrompt = ""
    @State private var tagsText = ""
    @State private var temperature: Double = 0.7
    @State private var topP: Double = 1.0
    @State private var maxTokens = 2000

    var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !promptText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 12) {
            Text("Add Prompt Template")
                .font(.headline)

            ScrollView {
                VStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Template Name")
                            .font(.caption)
                            .fontWeight(.semibold)
                        TextField("e.g., Code Review, Documentation", text: $name)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Description")
                            .font(.caption)
                            .fontWeight(.semibold)
                        TextField("Optional description", text: $description)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Prompt Text")
                            .font(.caption)
                            .fontWeight(.semibold)
                        TextEditor(text: $promptText)
                            .frame(minHeight: 100)
                            .border(Color.gray.opacity(0.3))
                            .cornerRadius(4)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("System Prompt (Optional)")
                            .font(.caption)
                            .fontWeight(.semibold)
                        TextEditor(text: $systemPrompt)
                            .frame(minHeight: 60)
                            .border(Color.gray.opacity(0.3))
                            .cornerRadius(4)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tags (comma-separated)")
                            .font(.caption)
                            .fontWeight(.semibold)
                        TextField("e.g., code, review, python", text: $tagsText)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(spacing: 8) {
                        VStack(alignment: .leading) {
                            Text("Temperature: \(String(format: "%.2f", temperature))")
                                .font(.caption)
                            Slider(value: $temperature, in: 0...2.0, step: 0.1)
                        }

                        VStack(alignment: .leading) {
                            Text("Top P: \(String(format: "%.2f", topP))")
                                .font(.caption)
                            Slider(value: $topP, in: 0...1.0, step: 0.05)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Max Tokens")
                                .font(.caption)
                            TextField("2000", value: $maxTokens, format: .number)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                }
            }

            HStack(spacing: 12) {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Add Template") {
                    let tags = tagsText
                        .split(separator: ",")
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty }

                    let template = PromptTemplate(
                        name: name.trimmingCharacters(in: .whitespaces),
                        description: description.trimmingCharacters(in: .whitespaces),
                        promptText: promptText.trimmingCharacters(in: .whitespaces),
                        systemPrompt: systemPrompt.isEmpty ? nil : systemPrompt.trimmingCharacters(in: .whitespaces),
                        tags: tags,
                        temperature: temperature,
                        topP: topP,
                        maxTokens: maxTokens
                    )

                    templateManager.addTemplate(template)
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isFormValid)
            }
        }
        .padding()
        .frame(width: 500, height: 700)
    }
}

struct EditTemplateSheet: View {
    @Binding var isPresented: Bool
    @ObservedObject var templateManager: PromptTemplateManager
    let template: PromptTemplate
    @State private var name = ""
    @State private var description = ""
    @State private var promptText = ""
    @State private var systemPrompt = ""
    @State private var tagsText = ""
    @State private var temperature: Double = 0.7
    @State private var topP: Double = 1.0
    @State private var maxTokens = 2000

    var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !promptText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 12) {
            Text("Edit Template")
                .font(.headline)

            ScrollView {
                VStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Template Name")
                            .font(.caption)
                            .fontWeight(.semibold)
                        TextField("Name", text: $name)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Description")
                            .font(.caption)
                            .fontWeight(.semibold)
                        TextField("Description", text: $description)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Prompt Text")
                            .font(.caption)
                            .fontWeight(.semibold)
                        TextEditor(text: $promptText)
                            .frame(minHeight: 100)
                            .border(Color.gray.opacity(0.3))
                            .cornerRadius(4)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("System Prompt (Optional)")
                            .font(.caption)
                            .fontWeight(.semibold)
                        TextEditor(text: $systemPrompt)
                            .frame(minHeight: 60)
                            .border(Color.gray.opacity(0.3))
                            .cornerRadius(4)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tags (comma-separated)")
                            .font(.caption)
                            .fontWeight(.semibold)
                        TextField("Tags", text: $tagsText)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(spacing: 8) {
                        VStack(alignment: .leading) {
                            Text("Temperature: \(String(format: "%.2f", temperature))")
                                .font(.caption)
                            Slider(value: $temperature, in: 0...2.0, step: 0.1)
                        }

                        VStack(alignment: .leading) {
                            Text("Top P: \(String(format: "%.2f", topP))")
                                .font(.caption)
                            Slider(value: $topP, in: 0...1.0, step: 0.05)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Max Tokens")
                                .font(.caption)
                            TextField("Max Tokens", value: $maxTokens, format: .number)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                }
            }

            HStack(spacing: 12) {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Update") {
                    let tags = tagsText
                        .split(separator: ",")
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty }

                    var updatedTemplate = template
                    updatedTemplate.name = name.trimmingCharacters(in: .whitespaces)
                    updatedTemplate.description = description.trimmingCharacters(in: .whitespaces)
                    updatedTemplate.promptText = promptText.trimmingCharacters(in: .whitespaces)
                    updatedTemplate.systemPrompt = systemPrompt.isEmpty ? nil : systemPrompt.trimmingCharacters(in: .whitespaces)
                    updatedTemplate.tags = tags
                    updatedTemplate.temperature = temperature
                    updatedTemplate.topP = topP
                    updatedTemplate.maxTokens = maxTokens

                    templateManager.updateTemplate(id: template.id, updatedTemplate)
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isFormValid)
            }
        }
        .padding()
        .frame(width: 500, height: 700)
        .onAppear {
            name = template.name
            description = template.description
            promptText = template.promptText
            systemPrompt = template.systemPrompt ?? ""
            tagsText = template.tags.joined(separator: ", ")
            temperature = template.temperature ?? 0.7
            topP = template.topP ?? 1.0
            maxTokens = template.maxTokens ?? 2000
        }
    }
}
