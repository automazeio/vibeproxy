import Foundation

struct PromptTemplate: Codable, Identifiable {
    let id: String
    var name: String
    var description: String
    var promptText: String
    var systemPrompt: String?
    var tags: [String]
    var temperature: Double?
    var topP: Double?
    var maxTokens: Int?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        name: String,
        description: String = "",
        promptText: String,
        systemPrompt: String? = nil,
        tags: [String] = [],
        temperature: Double? = nil,
        topP: Double? = nil,
        maxTokens: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.promptText = promptText
        self.systemPrompt = systemPrompt
        self.tags = tags
        self.temperature = temperature
        self.topP = topP
        self.maxTokens = maxTokens
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    enum CodingKeys: String, CodingKey {
        case id, name, description, promptText, systemPrompt, tags
        case temperature, topP, maxTokens
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    func replacePlaceholders(_ values: [String: String]) -> String {
        var result = promptText
        for (key, value) in values {
            result = result.replacingOccurrences(of: "{{\\(key)}}", with: value, options: .regularExpression)
        }
        return result
    }
}

class PromptTemplateManager: ObservableObject {
    @Published var templates: [PromptTemplate] = []

    private let templatesFilePath: URL

    init() {
        let appSupportDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cli-proxy-api")

        self.templatesFilePath = appSupportDir.appendingPathComponent("templates.json")

        // Ensure directory exists
        try? FileManager.default.createDirectory(at: appSupportDir, withIntermediateDirectories: true)

        loadTemplates()
    }

    func loadTemplates() {
        do {
            if FileManager.default.fileExists(atPath: templatesFilePath.path) {
                let data = try Data(contentsOf: templatesFilePath)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                templates = try decoder.decode([PromptTemplate].self, from: data)
                NSLog("[PromptTemplate] Loaded %d templates", templates.count)
            }
        } catch {
            NSLog("[PromptTemplate] Error loading templates: %@", error.localizedDescription)
            templates = []
        }
    }

    func saveTemplates() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(templates)
            try data.write(to: templatesFilePath)
            NSLog("[PromptTemplate] Saved %d templates", templates.count)
        } catch {
            NSLog("[PromptTemplate] Error saving templates: %@", error.localizedDescription)
        }
    }

    func addTemplate(_ template: PromptTemplate) {
        templates.append(template)
        saveTemplates()
    }

    func updateTemplate(id: String, _ updatedTemplate: PromptTemplate) {
        if let index = templates.firstIndex(where: { $0.id == id }) {
            var newTemplate = updatedTemplate
            newTemplate.updatedAt = Date()
            templates[index] = newTemplate
            saveTemplates()
        }
    }

    func deleteTemplate(id: String) {
        templates.removeAll { $0.id == id }
        saveTemplates()
    }

    func searchTemplates(query: String) -> [PromptTemplate] {
        let lowercaseQuery = query.lowercased()
        return templates.filter { template in
            template.name.lowercased().contains(lowercaseQuery)
                || template.description.lowercased().contains(lowercaseQuery)
                || template.tags.contains { $0.lowercased().contains(lowercaseQuery) }
        }
    }
}
