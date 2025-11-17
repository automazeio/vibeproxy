import Foundation

class ModelSwitcher: ObservableObject {
    @Published var selectedModel: String = "claude-sonnet-4-5-20250929"

    private let modelsFilePath: URL

    // Available models from each service
    private let availableModels: [String: [String]] = [
        "Claude": [
            "claude-opus-4-1-20250805",
            "claude-sonnet-4-5-20250929",
            "claude-3-5-sonnet-20241022",
            "claude-3-opus-20250219"
        ],
        "OpenAI": [
            "gpt-5",
            "gpt-5-codex",
            "gpt-4o",
            "gpt-4-turbo"
        ],
        "Gemini": [
            "gemini-2.0-flash",
            "gemini-1.5-pro",
            "gemini-1.5-flash"
        ],
        "Qwen": [
            "qwen-max",
            "qwen-plus",
            "qwen-turbo"
        ]
    ]

    init() {
        let appSupportDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cli-proxy-api")

        self.modelsFilePath = appSupportDir.appendingPathComponent("model-switcher.json")

        // Ensure directory exists
        try? FileManager.default.createDirectory(at: appSupportDir, withIntermediateDirectories: true)

        loadSelectedModel()
    }

    func loadSelectedModel() {
        do {
            if FileManager.default.fileExists(atPath: modelsFilePath.path) {
                let data = try Data(contentsOf: modelsFilePath)
                let json = try JSONSerialization.jsonObject(with: data) as? [String: String]
                if let model = json?["selectedModel"] {
                    DispatchQueue.main.async {
                        self.selectedModel = model
                    }
                    NSLog("[ModelSwitcher] Loaded selected model: %@", model)
                }
            }
        } catch {
            NSLog("[ModelSwitcher] Error loading selected model: %@", error.localizedDescription)
        }
    }

    func saveSelectedModel() {
        do {
            let data = try JSONSerialization.data(
                withJSONObject: ["selectedModel": selectedModel],
                options: [.prettyPrinted, .sortedKeys]
            )
            try data.write(to: modelsFilePath)
            NSLog("[ModelSwitcher] Saved selected model: %@", selectedModel)
        } catch {
            NSLog("[ModelSwitcher] Error saving selected model: %@", error.localizedDescription)
        }
    }

    func getAllModels() -> [String] {
        var all: [String] = []
        for (_, models) in availableModels.sorted(by: { $0.key < $1.key }) {
            all.append(contentsOf: models)
        }
        return all
    }

    func getModelsGroupedByService() -> [String: [String]] {
        return availableModels
    }
}
