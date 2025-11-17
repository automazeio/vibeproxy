import Foundation

struct APIUsage: Codable, Identifiable {
    let id: String
    var model: String
    var service: String  // "claude", "codex", "gemini", "qwen"
    var inputTokens: Int
    var outputTokens: Int
    var totalTokens: Int
    var estimatedCost: Double?
    var timestamp: Date
    var duration: TimeInterval?  // milliseconds

    init(
        id: String = UUID().uuidString,
        model: String,
        service: String,
        inputTokens: Int,
        outputTokens: Int,
        estimatedCost: Double? = nil,
        duration: TimeInterval? = nil
    ) {
        self.id = id
        self.model = model
        self.service = service
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.totalTokens = inputTokens + outputTokens
        self.estimatedCost = estimatedCost
        self.timestamp = Date()
        self.duration = duration
    }

    enum CodingKeys: String, CodingKey {
        case id, model, service, inputTokens, outputTokens, totalTokens
        case estimatedCost, duration, timestamp
    }
}

struct UsageStats {
    var totalRequests: Int = 0
    var totalTokens: Int = 0
    var totalCost: Double = 0
    var averageTokensPerRequest: Double = 0
    var averageCostPerRequest: Double = 0
    var requestsByModel: [String: Int] = [:]
    var tokensByModel: [String: Int] = [:]
    var costByModel: [String: Double] = [:]
    var requestsByService: [String: Int] = [:]

    mutating func update(with usage: APIUsage) {
        totalRequests += 1
        totalTokens += usage.totalTokens
        if let cost = usage.estimatedCost {
            totalCost += cost
        }

        // Model stats
        requestsByModel[usage.model, default: 0] += 1
        tokensByModel[usage.model, default: 0] += usage.totalTokens
        if let cost = usage.estimatedCost {
            costByModel[usage.model, default: 0] += cost
        }

        // Service stats
        requestsByService[usage.service, default: 0] += 1

        // Calculate averages
        averageTokensPerRequest = totalRequests > 0 ? Double(totalTokens) / Double(totalRequests) : 0
        averageCostPerRequest = totalRequests > 0 ? totalCost / Double(totalRequests) : 0
    }
}

class UsageManager: ObservableObject {
    @Published var usages: [APIUsage] = []
    @Published var stats: UsageStats = UsageStats()

    private let usagesFilePath: URL

    init() {
        let appSupportDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cli-proxy-api")

        self.usagesFilePath = appSupportDir.appendingPathComponent("usage.json")

        // Ensure directory exists
        try? FileManager.default.createDirectory(at: appSupportDir, withIntermediateDirectories: true)

        loadUsages()
    }

    func loadUsages() {
        do {
            if FileManager.default.fileExists(atPath: usagesFilePath.path) {
                let data = try Data(contentsOf: usagesFilePath)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let loadedUsages = try decoder.decode([APIUsage].self, from: data)

                DispatchQueue.main.async {
                    self.usages = loadedUsages.sorted { $0.timestamp > $1.timestamp }
                    self.recalculateStats()
                }
                NSLog("[Usage] Loaded %d usage records", loadedUsages.count)
            }
        } catch {
            NSLog("[Usage] Error loading usages: %@", error.localizedDescription)
        }
    }

    func saveUsages() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(usages)
            try data.write(to: usagesFilePath)
            NSLog("[Usage] Saved %d usage records", usages.count)
        } catch {
            NSLog("[Usage] Error saving usages: %@", error.localizedDescription)
        }
    }

    func recordUsage(model: String, service: String, inputTokens: Int, outputTokens: Int, cost: Double? = nil, duration: TimeInterval? = nil) {
        let usage = APIUsage(
            model: model,
            service: service,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            estimatedCost: cost,
            duration: duration
        )

        DispatchQueue.main.async {
            self.usages.insert(usage, at: 0)
            self.stats.update(with: usage)
            self.saveUsages()
            NSLog("[Usage] Recorded usage: \(model) - \(inputTokens) input, \(outputTokens) output tokens")
        }
    }

    func getUsageStats(for timeRange: TimeRange) -> UsageStats {
        let startDate = timeRange.startDate
        let filteredUsages = usages.filter { $0.timestamp >= startDate && $0.timestamp <= Date() }

        var stats = UsageStats()
        for usage in filteredUsages {
            stats.update(with: usage)
        }
        return stats
    }

    func getUsageForModel(_ model: String) -> [APIUsage] {
        return usages.filter { $0.model == model }.sorted { $0.timestamp > $1.timestamp }
    }

    func getUsageForService(_ service: String) -> [APIUsage] {
        return usages.filter { $0.service == service }.sorted { $0.timestamp > $1.timestamp }
    }

    func recalculateStats() {
        var newStats = UsageStats()
        for usage in usages {
            newStats.update(with: usage)
        }
        DispatchQueue.main.async {
            self.stats = newStats
        }
    }

    func deleteUsage(id: String) {
        usages.removeAll { $0.id == id }
        saveUsages()
        recalculateStats()
    }

    func clearAllUsages() {
        usages.removeAll()
        stats = UsageStats()
        saveUsages()
    }
}

enum TimeRange {
    case today
    case week
    case month
    case allTime

    var startDate: Date {
        let now = Date()
        let calendar = Calendar.current

        switch self {
        case .today:
            return calendar.startOfDay(for: now)
        case .week:
            return calendar.date(byAdding: .day, value: -7, to: now) ?? now
        case .month:
            return calendar.date(byAdding: .month, value: -1, to: now) ?? now
        case .allTime:
            return Date.distantPast
        }
    }
}

// Pricing information for different models
struct ModelPricing {
    static let prices: [String: (inputPer1K: Double, outputPer1K: Double)] = [
        // Claude models (USD per 1K tokens)
        "claude-opus-4-1-20250805": (0.015, 0.045),
        "claude-sonnet-4-5-20250929": (0.003, 0.015),
        "claude-3-5-sonnet-20241022": (0.003, 0.015),
        "claude-3-opus-20250219": (0.015, 0.045),

        // GPT models
        "gpt-5": (0.03, 0.12),
        "gpt-5-codex": (0.03, 0.12),
        "gpt-4o": (0.005, 0.015),
        "gpt-4-turbo": (0.01, 0.03),

        // Gemini models
        "gemini-2.0-flash": (0.00005, 0.00015),
        "gemini-1.5-pro": (0.001, 0.005),
        "gemini-1.5-flash": (0.0375, 0.15),

        // Qwen models (approximate)
        "qwen-max": (0.001, 0.003),
        "qwen-plus": (0.0005, 0.0015),
        "qwen-turbo": (0.0002, 0.0006),
    ]

    static func estimateCost(model: String, inputTokens: Int, outputTokens: Int) -> Double? {
        guard let pricing = prices[model] else { return nil }
        let inputCost = Double(inputTokens) * pricing.inputPer1K / 1000.0
        let outputCost = Double(outputTokens) * pricing.outputPer1K / 1000.0
        return inputCost + outputCost
    }
}
