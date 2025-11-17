import SwiftUI

struct ModelAliasView: View {
    @ObservedObject var aliasManager: ModelAliasManager
    @State private var showingAddSheet = false
    @State private var editingAlias: ModelAlias?
    @State private var newAliasName = ""
    @State private var newModelName = ""
    @State private var searchText = ""

    var filteredAliases: [ModelAlias] {
        if searchText.isEmpty {
            return aliasManager.aliases
        }
        return aliasManager.aliases.filter { alias in
            alias.alias.lowercased().contains(searchText.lowercased())
                || alias.modelName.lowercased().contains(searchText.lowercased())
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Model Aliases")
                    .font(.headline)
                Spacer()
                Button(action: { showingAddSheet = true }) {
                    Label("Add", systemImage: "plus")
                }
            }

            if aliasManager.aliases.isEmpty {
                VStack(spacing: 8) {
                    Text("No aliases yet")
                        .foregroundColor(.secondary)
                    Text("Create shortcuts for your favorite models")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.controlBackgroundColor))
                .cornerRadius(8)
            } else {
                VStack(spacing: 8) {
                    SearchBar(text: $searchText, placeholder: "Search aliases...")

                    List(filteredAliases) { alias in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(alias.alias)
                                    .font(.system(.body, design: .monospaced))
                                    .fontWeight(.semibold)
                                Text(alias.modelName)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            HStack(spacing: 8) {
                                Button(action: { editingAlias = alias }) {
                                    Image(systemImage: "pencil")
                                        .foregroundColor(.blue)
                                }
                                .buttonStyle(.plain)

                                Button(action: { aliasManager.deleteAlias(id: alias.id) }) {
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
            AddAliasSheet(
                isPresented: $showingAddSheet,
                aliasManager: aliasManager,
                aliasName: $newAliasName,
                modelName: $newModelName
            )
        }
        .sheet(item: $editingAlias) { alias in
            EditAliasSheet(
                isPresented: .constant(editingAlias != nil),
                aliasManager: aliasManager,
                alias: alias
            )
        }
    }
}

struct AddAliasSheet: View {
    @Binding var isPresented: Bool
    @ObservedObject var aliasManager: ModelAliasManager
    @Binding var aliasName: String
    @Binding var modelName: String

    var isFormValid: Bool {
        !aliasName.trimmingCharacters(in: .whitespaces).isEmpty
            && !modelName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Add Model Alias")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Label("Alias Name", systemImage: "tag.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("e.g., fast, smart, default", text: $aliasName)
                    .textFieldStyle(.roundedBorder)
                    .help("The shortcut you'll use to refer to this model")
            }

            VStack(alignment: .leading, spacing: 8) {
                Label("Full Model Name", systemImage: "sparkles")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("e.g., gpt-5, claude-sonnet-4-5", text: $modelName)
                    .textFieldStyle(.roundedBorder)
                    .help("The actual model identifier to use")
            }

            HStack(spacing: 12) {
                Button("Cancel") {
                    isPresented = false
                    aliasName = ""
                    modelName = ""
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Add Alias") {
                    let alias = aliasName.trimmingCharacters(in: .whitespaces)
                    let model = modelName.trimmingCharacters(in: .whitespaces)
                    aliasManager.addAlias(alias: alias, modelName: model)
                    isPresented = false
                    aliasName = ""
                    modelName = ""
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isFormValid)
            }
        }
        .padding()
        .frame(width: 350)
    }
}

struct EditAliasSheet: View {
    @Binding var isPresented: Bool
    @ObservedObject var aliasManager: ModelAliasManager
    let alias: ModelAlias
    @State private var editedAlias: String = ""
    @State private var editedModel: String = ""

    var isFormValid: Bool {
        !editedAlias.trimmingCharacters(in: .whitespaces).isEmpty
            && !editedModel.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Edit Alias")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Label("Alias Name", systemImage: "tag.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("Alias", text: $editedAlias)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                Label("Model Name", systemImage: "sparkles")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("Model", text: $editedModel)
                    .textFieldStyle(.roundedBorder)
            }

            HStack(spacing: 12) {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Update") {
                    aliasManager.updateAlias(
                        id: alias.id,
                        newAlias: editedAlias.trimmingCharacters(in: .whitespaces),
                        newModelName: editedModel.trimmingCharacters(in: .whitespaces)
                    )
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isFormValid)
            }
        }
        .padding()
        .frame(width: 350)
        .onAppear {
            editedAlias = alias.alias
            editedModel = alias.modelName
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
