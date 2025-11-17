import SwiftUI

struct ConversationHistoryView: View {
    @ObservedObject var conversationManager: ConversationManager
    @State private var searchText = ""
    @State private var selectedConversation: Conversation?
    @State private var showingDeleteAlert = false
    @State private var conversationToDelete: Conversation?

    var filteredConversations: [Conversation] {
        if searchText.isEmpty {
            return conversationManager.conversations
        }
        return conversationManager.searchConversations(query: searchText)
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Conversation History")
                    .font(.headline)
                Spacer()
                Button(action: { conversationManager.conversations.removeAll() }) {
                    Label("Clear", systemImage: "trash")
                }
                .foregroundColor(.red)
            }

            if conversationManager.conversations.isEmpty {
                VStack(spacing: 8) {
                    Text("No conversations yet")
                        .foregroundColor(.secondary)
                    Text("Your chat history will appear here")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.controlBackgroundColor))
                .cornerRadius(8)
            } else {
                VStack(spacing: 8) {
                    SearchBar(text: $searchText, placeholder: "Search conversations...")

                    List(filteredConversations) { conversation in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Text(conversation.title)
                                        .fontWeight(.semibold)
                                        .lineLimit(1)

                                    if conversation.starred {
                                        Image(systemName: "star.fill")
                                            .font(.caption)
                                            .foregroundColor(.yellow)
                                    }
                                }

                                Text(conversation.model)
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                HStack(spacing: 8) {
                                    Text("\(conversation.messages.count) messages")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)

                                    Text("•")
                                        .foregroundColor(.secondary)

                                    Text(conversation.createdAt, style: .date)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()

                            VStack(spacing: 6) {
                                HStack(spacing: 8) {
                                    Button(action: { selectedConversation = conversation }) {
                                        Image(systemName: "eye")
                                            .foregroundColor(.blue)
                                    }
                                    .buttonStyle(.plain)
                                    .help("View details")

                                    Button(action: { conversationToDelete = conversation; showingDeleteAlert = true }) {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red)
                                    }
                                    .buttonStyle(.plain)
                                    .help("Delete")
                                }
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
        .sheet(item: $selectedConversation) { conversation in
            ConversationDetailView(conversation: conversation, isPresented: .constant(selectedConversation != nil))
        }
        .alert("Delete Conversation", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let conversation = conversationToDelete {
                    conversationManager.deleteConversation(id: conversation.id)
                }
            }
        } message: {
            Text("Are you sure you want to delete \"\(conversationToDelete?.title ?? "this conversation")\"?")
        }
    }
}

struct ConversationDetailView: View {
    let conversation: Conversation
    @Binding var isPresented: Bool
    @State private var showingExportMarkdown = false
    @State private var showingExportJSON = false

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(conversation.title)
                        .font(.headline)
                    Text(conversation.model)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()

                HStack(spacing: 8) {
                    Menu {
                        Button(action: { showingExportMarkdown = true }) {
                            Label("Markdown", systemImage: "doc.text")
                        }
                        Button(action: { showingExportJSON = true }) {
                            Label("JSON", systemImage: "curlybraces")
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }

                    Button("Close") { isPresented = false }
                }
            }

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(conversation.messages) { message in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(message.role.uppercased())
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(message.role == "user" ? .blue : .green)

                                Spacer()

                                Text(message.timestamp, style: .time)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }

                            Text(message.content)
                                .font(.body)
                                .lineLimit(nil)
                                .textSelection(.enabled)
                                .padding(8)
                                .background(Color(.controlBackgroundColor))
                                .cornerRadius(6)
                        }
                    }
                }
            }

            Divider()

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Created")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(conversation.createdAt, style: .date)
                        .font(.caption2)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Messages")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(conversation.messages.count)")
                        .font(.caption2)
                }
            }
        }
        .padding()
        .frame(width: 700, height: 600)
        .sheet(isPresented: $showingExportMarkdown) {
            ExportSheet(content: conversation.exportToMarkdown(), filename: "conversation.md", isPresented: $showingExportMarkdown)
        }
        .sheet(isPresented: $showingExportJSON) {
            ExportSheet(content: conversation.exportToJSON() ?? "{}", filename: "conversation.json", isPresented: $showingExportJSON)
        }
    }
}

struct ExportSheet: View {
    let content: String
    let filename: String
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Export \(filename)")
                    .font(.headline)
                Spacer()
                Button("Close") { isPresented = false }
            }

            TextEditor(text: .constant(content))
                .font(.system(.body, design: .monospaced))
                .lineLimit(nil)

            HStack(spacing: 12) {
                Button("Copy to Clipboard") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(content, forType: .string)
                }

                Button("Save to File") {
                    saveToFile()
                }

                Spacer()

                Button("Close") { isPresented = false }
            }
        }
        .padding()
        .frame(width: 700, height: 600)
    }

    private func saveToFile() {
        let savePanel = NSSavePanel()
        savePanel.nameFieldStringValue = filename
        savePanel.allowedContentTypes = filename.hasSuffix(".json") ? [.json] : [.plainText]

        savePanel.begin { result in
            if result == .OK, let url = savePanel.url {
                try? content.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }
}
