import Foundation

struct Message: Codable, Identifiable {
    let id: String
    var role: String // "user", "assistant", "system"
    var content: String
    var model: String?
    var timestamp: Date

    init(
        id: String = UUID().uuidString,
        role: String,
        content: String,
        model: String? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.model = model
        self.timestamp = Date()
    }

    enum CodingKeys: String, CodingKey {
        case id, role, content, model, timestamp
    }
}

struct Conversation: Codable, Identifiable {
    let id: String
    var title: String
    var messages: [Message]
    var model: String
    var systemPrompt: String?
    var tags: [String]
    var createdAt: Date
    var updatedAt: Date
    var starred: Bool

    init(
        id: String = UUID().uuidString,
        title: String,
        model: String,
        systemPrompt: String? = nil,
        tags: [String] = []
    ) {
        self.id = id
        self.title = title
        self.messages = []
        self.model = model
        self.systemPrompt = systemPrompt
        self.tags = tags
        self.createdAt = Date()
        self.updatedAt = Date()
        self.starred = false
    }

    mutating func addMessage(role: String, content: String) {
        let message = Message(role: role, content: content, model: model)
        messages.append(message)
        updatedAt = Date()
    }

    enum CodingKeys: String, CodingKey {
        case id, title, messages, model, systemPrompt, tags, starred
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

class ConversationManager: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var currentConversation: Conversation?

    private let conversationsDir: URL

    init() {
        let appSupportDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cli-proxy-api")

        self.conversationsDir = appSupportDir.appendingPathComponent("conversations")

        // Ensure directories exist
        try? FileManager.default.createDirectory(at: conversationsDir, withIntermediateDirectories: true)

        loadConversations()
    }

    func loadConversations() {
        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: conversationsDir,
                includingPropertiesForKeys: nil
            )
            var loadedConversations: [Conversation] = []

            for file in files where file.pathExtension == "json" {
                if let data = try? Data(contentsOf: file) {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    if let conversation = try? decoder.decode(Conversation.self, from: data) {
                        loadedConversations.append(conversation)
                    }
                }
            }

            // Sort by creation date (newest first)
            loadedConversations.sort { $0.createdAt > $1.createdAt }
            DispatchQueue.main.async {
                self.conversations = loadedConversations
            }
            NSLog("[Conversation] Loaded %d conversations", loadedConversations.count)
        } catch {
            NSLog("[Conversation] Error loading conversations: %@", error.localizedDescription)
        }
    }

    func saveConversation(_ conversation: Conversation) {
        do {
            let filePath = conversationsDir.appendingPathComponent("\(conversation.id).json")
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(conversation)
            try data.write(to: filePath)

            // Update in-memory list
            if let index = conversations.firstIndex(where: { $0.id == conversation.id }) {
                DispatchQueue.main.async {
                    self.conversations[index] = conversation
                }
            } else {
                DispatchQueue.main.async {
                    self.conversations.insert(conversation, at: 0)
                }
            }

            NSLog("[Conversation] Saved conversation: %@", conversation.id)
        } catch {
            NSLog("[Conversation] Error saving conversation: %@", error.localizedDescription)
        }
    }

    func deleteConversation(id: String) {
        do {
            let filePath = conversationsDir.appendingPathComponent("\(id).json")
            try FileManager.default.removeItem(at: filePath)
            DispatchQueue.main.async {
                self.conversations.removeAll { $0.id == id }
                if self.currentConversation?.id == id {
                    self.currentConversation = nil
                }
            }
            NSLog("[Conversation] Deleted conversation: %@", id)
        } catch {
            NSLog("[Conversation] Error deleting conversation: %@", error.localizedDescription)
        }
    }

    func searchConversations(query: String) -> [Conversation] {
        let lowercaseQuery = query.lowercased()
        return conversations.filter { conversation in
            conversation.title.lowercased().contains(lowercaseQuery)
                || conversation.messages.contains { $0.content.lowercased().contains(lowercaseQuery) }
                || conversation.tags.contains { $0.lowercased().contains(lowercaseQuery) }
        }
    }

    func exportToMarkdown(_ conversation: Conversation) -> String {
        var markdown = "# \(conversation.title)\n\n"
        markdown += "**Model**: \(conversation.model)\n"
        markdown += "**Created**: \(conversation.createdAt.formatted())\n"

        if let systemPrompt = conversation.systemPrompt {
            markdown += "**System Prompt**: \(systemPrompt)\n"
        }

        if !conversation.tags.isEmpty {
            markdown += "**Tags**: \(conversation.tags.joined(separator: ", "))\n"
        }

        markdown += "\n---\n\n"

        for message in conversation.messages {
            let rolePrefix = message.role.prefix(1).uppercased() + message.role.dropFirst()
            markdown += "**\(rolePrefix)**\n\n\(message.content)\n\n"
        }

        return markdown
    }

    func exportToJSON(_ conversation: Conversation) -> String? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        if let data = try? encoder.encode(conversation),
           let jsonString = String(data: data, encoding: .utf8) {
            return jsonString
        }
        return nil
    }
}
