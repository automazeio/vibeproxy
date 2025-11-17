import Foundation

struct ModelAlias: Codable, Identifiable {
    let id: String
    var alias: String
    var modelName: String
    var createdAt: Date
    var updatedAt: Date

    init(id: String = UUID().uuidString, alias: String, modelName: String) {
        self.id = id
        self.alias = alias
        self.modelName = modelName
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    enum CodingKeys: String, CodingKey {
        case id, alias, modelName
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

class ModelAliasManager: ObservableObject {
    @Published var aliases: [ModelAlias] = []

    private let aliasesFilePath: URL

    init() {
        let appSupportDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cli-proxy-api")

        self.aliasesFilePath = appSupportDir.appendingPathComponent("aliases.json")

        // Ensure directory exists
        try? FileManager.default.createDirectory(at: appSupportDir, withIntermediateDirectories: true)

        loadAliases()
    }

    func loadAliases() {
        do {
            if FileManager.default.fileExists(atPath: aliasesFilePath.path) {
                let data = try Data(contentsOf: aliasesFilePath)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                aliases = try decoder.decode([ModelAlias].self, from: data)
                NSLog("[ModelAlias] Loaded %d aliases", aliases.count)
            }
        } catch {
            NSLog("[ModelAlias] Error loading aliases: %@", error.localizedDescription)
            aliases = []
        }
    }

    func saveAliases() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(aliases)
            try data.write(to: aliasesFilePath)
            NSLog("[ModelAlias] Saved %d aliases", aliases.count)
        } catch {
            NSLog("[ModelAlias] Error saving aliases: %@", error.localizedDescription)
        }
    }

    func addAlias(alias: String, modelName: String) -> ModelAlias {
        let newAlias = ModelAlias(alias: alias, modelName: modelName)
        aliases.append(newAlias)
        saveAliases()
        return newAlias
    }

    func updateAlias(id: String, newAlias: String, newModelName: String) {
        if let index = aliases.firstIndex(where: { $0.id == id }) {
            aliases[index].alias = newAlias
            aliases[index].modelName = newModelName
            aliases[index].updatedAt = Date()
            saveAliases()
        }
    }

    func deleteAlias(id: String) {
        aliases.removeAll { $0.id == id }
        saveAliases()
    }

    func resolveAlias(_ input: String) -> String {
        if let foundAlias = aliases.first(where: { $0.alias == input }) {
            return foundAlias.modelName
        }
        return input
    }
}
