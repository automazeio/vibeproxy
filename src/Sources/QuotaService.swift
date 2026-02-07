import Foundation

//  Quota Models

struct AntigravityQuotaGroup: Identifiable {
    let id: String
    let label: String
    let models: [String]
    let remainingFraction: Double
    let resetTime: Date?
}

struct CodexQuotaWindow: Identifiable {
    let id: String
    let label: String
    let usedPercent: Double?
    let resetTime: Date?

    var remainingPercent: Double? {
        guard let used = usedPercent else { return nil }
        return max(0, min(100, 100 - used))
    }
}

struct CodexQuota {
    let planType: String?
    let windows: [CodexQuotaWindow]
}

struct GeminiCliQuotaBucket: Identifiable {
    let id: String
    let label: String
    let modelIds: [String]
    let tokenType: String?
    let remainingFraction: Double?
    let remainingAmount: Int?
    let resetTime: Date?
}

enum QuotaError: Error, LocalizedError {
    case noAuthFile
    case invalidAuthFile
    case tokenExpired
    case networkError(Error)
    case apiError(Int, String)
    case parseError(String)
    case proxyError(String)
    case authIndexNotFound

    var errorDescription: String? {
        switch self {
        case .noAuthFile:
            return "No authentication file found"
        case .invalidAuthFile:
            return "Invalid authentication file"
        case .tokenExpired:
            return "Token expired - please re-authenticate"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .apiError(let code, let message):
            return "API error (\(code)): \(message)"
        case .parseError(let message):
            return "Parse error: \(message)"
        case .proxyError(let message):
            return "Proxy error: \(message)"
        case .authIndexNotFound:
            return "Auth index not found"
        }
    }
}

//  API Call Request/Response (matching backend format)

struct ApiCallRequest: Encodable {
    let authIndex: String
    let method: String
    let url: String
    let header: [String: String]?
    let data: String?
}

struct ApiCallResponse: Decodable {
    let status_code: Int?
    let statusCode: Int?
    let header: [String: [String]]?
    let headers: [String: [String]]?
    let body: AnyCodable?

    var resolvedStatusCode: Int {
        status_code ?? statusCode ?? 0
    }

    var resolvedBody: Any? {
        body?.value
    }

    /// Parse the body - handles both direct JSON objects and JSON strings
    var parsedBody: Any? {
        guard let bodyValue = body?.value else { return nil }

        // If body is already a dictionary, return it
        if let dict = bodyValue as? [String: Any] {
            return dict
        }

        // If body is a string, try to parse it as JSON
        if let jsonString = bodyValue as? String,
           let data = jsonString.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: data) {
            return parsed
        }

        return bodyValue
    }
}

// Helper for decoding arbitrary JSON
struct AnyCodable: Decodable {
    let value: Any

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if container.decodeNil() {
            value = NSNull()
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode value")
        }
    }
}

//  Auth File from API

struct AuthFileInfo: Decodable {
    let name: String
    let auth_index: String?
    let authIndex: String?
    let type: String?
    let provider: String?
    let project_id: String?
    let projectId: String?
    let chatgpt_account_id: String?
    let account_id: String?

    var resolvedAuthIndex: String? {
        auth_index ?? authIndex
    }

    var resolvedProjectId: String? {
        project_id ?? projectId
    }

    var resolvedChatgptAccountId: String? {
        chatgpt_account_id ?? account_id
    }
}

struct AuthFilesResponse: Decodable {
    let files: [AuthFileInfo]
}

//  Quota Group Definitions (matching web UI)

struct AntigravityQuotaGroupDef {
    let id: String
    let label: String
    let identifiers: [String]
    let labelFromModel: Bool

    init(id: String, label: String, identifiers: [String], labelFromModel: Bool = false) {
        self.id = id
        self.label = label
        self.identifiers = identifiers
        self.labelFromModel = labelFromModel
    }
}

struct GeminiCliQuotaGroupDef {
    let id: String
    let label: String
    let modelIds: [String]
}

// Thread-safe cache for auth files
private actor AuthFilesCache {
    private var files: [AuthFileInfo] = []
    private var cacheTime: Date?
    private let expiry: TimeInterval = 60 // 1 minute

    func getCachedFiles() -> [AuthFileInfo]? {
        guard let time = cacheTime,
              Date().timeIntervalSince(time) < expiry,
              !files.isEmpty else {
            return nil
        }
        return files
    }

    func setFiles(_ newFiles: [AuthFileInfo]) {
        files = newFiles
        cacheTime = Date()
    }

    func clear() {
        files = []
        cacheTime = nil
    }
}

//  QuotaService

class QuotaService {
    static let shared = QuotaService()

    private let session: URLSession
    private let authDir: URL

    // Backend proxy endpoint (CLIProxyAPI port, not ThinkingProxy)
    private let proxyBaseURL = "http://localhost:8318"

    // Management key for backend authorization (loaded from Keychain)
    private var managementKey: String {
        KeychainHelper.shared.getOrCreateManagementKey()
    }

    // API URLs for quota
    private let antigravityQuotaURLs = [
        "https://daily-cloudcode-pa.sandbox.googleapis.com/v1internal:fetchAvailableModels",
        "https://daily-cloudcode-pa.googleapis.com/v1internal:fetchAvailableModels",
        "https://cloudcode-pa.googleapis.com/v1internal:fetchAvailableModels"
    ]
    private let geminiCliQuotaURL = "https://cloudcode-pa.googleapis.com/v1internal:retrieveUserQuota"
    private let codexUsageURL = "https://chatgpt.com/backend-api/wham/usage"

    // Antigravity quota groups (matching web UI)
    private let antigravityQuotaGroups: [AntigravityQuotaGroupDef] = [
        AntigravityQuotaGroupDef(
            id: "claude-gpt",
            label: "Claude/GPT",
            identifiers: ["claude-sonnet-4-5-thinking", "claude-opus-4-5-thinking", "claude-sonnet-4-5", "gpt-oss-120b-medium"]
        ),
        AntigravityQuotaGroupDef(
            id: "gemini-3-pro",
            label: "Gemini 3 Pro",
            identifiers: ["gemini-3-pro-high", "gemini-3-pro-low"]
        ),
        AntigravityQuotaGroupDef(
            id: "gemini-2-5-flash",
            label: "Gemini 2.5 Flash",
            identifiers: ["gemini-2.5-flash", "gemini-2.5-flash-thinking"]
        ),
        AntigravityQuotaGroupDef(
            id: "gemini-2-5-flash-lite",
            label: "Gemini 2.5 Flash Lite",
            identifiers: ["gemini-2.5-flash-lite"]
        ),
        AntigravityQuotaGroupDef(
            id: "gemini-2-5-cu",
            label: "Gemini 2.5 CU",
            identifiers: ["rev19-uic3-1p"]
        ),
        AntigravityQuotaGroupDef(
            id: "gemini-3-flash",
            label: "Gemini 3 Flash",
            identifiers: ["gemini-3-flash"]
        ),
        AntigravityQuotaGroupDef(
            id: "gemini-image",
            label: "Gemini 3 Pro Image",
            identifiers: ["gemini-3-pro-image"],
            labelFromModel: true
        )
    ]

    // Gemini CLI quota groups (matching web UI)
    private let geminiCliQuotaGroups: [GeminiCliQuotaGroupDef] = [
        GeminiCliQuotaGroupDef(
            id: "gemini-2-5-flash-series",
            label: "Gemini 2.5 Flash Series",
            modelIds: ["gemini-2.5-flash", "gemini-2.5-flash-lite"]
        ),
        GeminiCliQuotaGroupDef(
            id: "gemini-2-5-pro",
            label: "Gemini 2.5 Pro",
            modelIds: ["gemini-2.5-pro"]
        ),
        GeminiCliQuotaGroupDef(
            id: "gemini-3-pro-preview",
            label: "Gemini 3 Pro Preview",
            modelIds: ["gemini-3-pro-preview"]
        ),
        GeminiCliQuotaGroupDef(
            id: "gemini-3-flash-preview",
            label: "Gemini 3 Flash Preview",
            modelIds: ["gemini-3-flash-preview"]
        )
    ]

    // Request headers (backend replaces $TOKEN$ with actual token)
    private let antigravityHeaders = [
        "Authorization": "Bearer $TOKEN$",
        "Content-Type": "application/json",
        "User-Agent": "antigravity/1.11.5 darwin/arm64"
    ]
    private let geminiCliHeaders = [
        "Authorization": "Bearer $TOKEN$",
        "Content-Type": "application/json"
    ]
    private let codexHeaders = [
        "Authorization": "Bearer $TOKEN$",
        "Content-Type": "application/json",
        "User-Agent": "codex_cli_rs/0.76.0 (macOS; arm64)"
    ]

    private let defaultAntigravityProjectId = "bamboo-precept-lgxtn"

    // Thread-safe cache using actor
    private let cache = AuthFilesCache()

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        session = URLSession(configuration: config)
        authDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".cli-proxy-api")
    }

    //  Fetch Auth Files from Backend

    private func fetchAuthFiles() async throws -> [AuthFileInfo] {
        // Return cached if valid
        if let cached = await cache.getCachedFiles() {
            return cached
        }

        guard let url = URL(string: "\(proxyBaseURL)/v0/management/auth-files") else {
            throw QuotaError.parseError("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(managementKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw QuotaError.networkError(NSError(domain: "QuotaService", code: -1))
        }

        if httpResponse.statusCode < 200 || httpResponse.statusCode >= 300 {
            let message = String(data: data, encoding: .utf8) ?? "Failed to fetch auth files"
            throw QuotaError.proxyError(message)
        }

        let decoder = JSONDecoder()
        let result = try decoder.decode(AuthFilesResponse.self, from: data)

        await cache.setFiles(result.files)

        return result.files
    }

    private func getAuthFileInfo(for account: AuthAccount) async throws -> AuthFileInfo {
        let files = try await fetchAuthFiles()

        // Match by filename
        let filename = account.filePath.lastPathComponent

        guard let info = files.first(where: { $0.name == filename }) else {
            throw QuotaError.authIndexNotFound
        }

        return info
    }

    //  Backend Proxy Call

    private func proxyRequest(_ request: ApiCallRequest) async throws -> (statusCode: Int, body: Any?) {
        guard let url = URL(string: "\(proxyBaseURL)/v0/management/api-call") else {
            throw QuotaError.parseError("Invalid proxy URL")
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(managementKey)", forHTTPHeaderField: "Authorization")

        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw QuotaError.networkError(NSError(domain: "QuotaService", code: -1))
        }

        // Check proxy response status (not the proxied request status)
        if httpResponse.statusCode < 200 || httpResponse.statusCode >= 300 {
            let message = String(data: data, encoding: .utf8) ?? "Proxy request failed"
            throw QuotaError.proxyError(message)
        }

        // Parse response
        let decoder = JSONDecoder()
        let apiResponse = try decoder.decode(ApiCallResponse.self, from: data)

        return (apiResponse.resolvedStatusCode, apiResponse.parsedBody)
    }

    //  Antigravity Quota

    func fetchAntigravityQuota(account: AuthAccount) async throws -> [AntigravityQuotaGroup] {
        let authInfo = try await getAuthFileInfo(for: account)

        guard let authIndex = authInfo.resolvedAuthIndex else {
            throw QuotaError.authIndexNotFound
        }

        let projectId = authInfo.resolvedProjectId ?? getProjectIdFromFile(account: account) ?? defaultAntigravityProjectId

        // Try both request body formats
        let requestBodies = [
            ["projectId": projectId],
            ["project": projectId]
        ]

        var lastError: QuotaError?

        for urlString in antigravityQuotaURLs {
            for body in requestBodies {
                do {
                    let bodyData = try JSONSerialization.data(withJSONObject: body)
                    let bodyString = String(data: bodyData, encoding: .utf8) ?? "{}"

                    let request = ApiCallRequest(
                        authIndex: authIndex,
                        method: "POST",
                        url: urlString,
                        header: antigravityHeaders,
                        data: bodyString
                    )

                    let (statusCode, responseBody) = try await proxyRequest(request)

                    if statusCode < 200 || statusCode >= 300 {
                        let message = extractErrorMessage(from: responseBody) ?? "HTTP \(statusCode)"
                        lastError = .apiError(statusCode, message)

                        // For 400 with unknown field error, try next body format
                        if statusCode == 400 && isUnknownFieldError(message) {
                            continue
                        }
                        break
                    }

                    guard let bodyDict = responseBody as? [String: Any],
                          let models = bodyDict["models"] as? [String: Any] else {
                        lastError = .parseError("Invalid response format")
                        continue
                    }

                    let groups = parseAntigravityModels(models)
                    if groups.isEmpty {
                        lastError = .parseError("No quota data")
                        continue
                    }

                    return groups
                } catch let error as QuotaError {
                    lastError = error
                } catch {
                    lastError = .networkError(error)
                }
            }
        }

        throw lastError ?? .noAuthFile
    }

    private func getProjectIdFromFile(account: AuthAccount) -> String? {
        guard let data = try? Data(contentsOf: account.filePath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return (json["project_id"] as? String) ?? (json["projectId"] as? String)
    }

    private func isUnknownFieldError(_ message: String) -> Bool {
        let normalized = message.lowercased()
        return normalized.contains("unknown name") && normalized.contains("cannot find field")
    }

    private func extractErrorMessage(from body: Any?) -> String? {
        guard let dict = body as? [String: Any] else {
            if let str = body as? String { return str }
            return nil
        }

        if let error = dict["error"] as? [String: Any] {
            return error["message"] as? String
        }
        if let error = dict["error"] as? String {
            return error
        }
        if let message = dict["message"] as? String {
            return message
        }
        return nil
    }

    private func parseAntigravityModels(_ models: [String: Any]) -> [AntigravityQuotaGroup] {
        var groups: [AntigravityQuotaGroup] = []

        // Build lookup: model identifier -> quota info
        var modelQuotaInfo: [String: (fraction: Double, resetTime: Date?)] = [:]
        for (modelName, modelData) in models {
            guard let modelDict = modelData as? [String: Any] else { continue }

            // quotaInfo is nested inside model data
            let quotaDict = (modelDict["quotaInfo"] as? [String: Any]) ?? modelDict

            let remainingFraction = (quotaDict["remainingFraction"] as? Double)
                ?? (quotaDict["remaining_fraction"] as? Double)
                ?? 1.0

            var resetTime: Date?
            if let resetStr = (quotaDict["resetTime"] as? String) ?? (quotaDict["reset_time"] as? String) {
                resetTime = parseISO8601Date(resetStr)
            }

            modelQuotaInfo[modelName] = (remainingFraction, resetTime)
        }

        // Map predefined groups
        for groupDef in antigravityQuotaGroups {
            var matchedModels: [String] = []
            var groupFraction: Double?
            var groupResetTime: Date?

            for identifier in groupDef.identifiers {
                if let info = modelQuotaInfo[identifier] {
                    matchedModels.append(identifier)
                    if groupFraction == nil {
                        groupFraction = info.fraction
                        groupResetTime = info.resetTime
                    }
                }
            }

            // Only add group if at least one model matched
            if let fraction = groupFraction {
                let label = groupDef.labelFromModel ? matchedModels.first ?? groupDef.label : groupDef.label

                groups.append(AntigravityQuotaGroup(
                    id: groupDef.id,
                    label: label,
                    models: matchedModels,
                    remainingFraction: fraction,
                    resetTime: groupResetTime
                ))
            }
        }

        return groups.sorted { $0.remainingFraction < $1.remainingFraction }
    }

    //  Gemini CLI Quota

    func fetchGeminiCliQuota(account: AuthAccount) async throws -> [GeminiCliQuotaBucket] {
        let authInfo = try await getAuthFileInfo(for: account)

        guard let authIndex = authInfo.resolvedAuthIndex else {
            throw QuotaError.authIndexNotFound
        }

        guard let projectId = authInfo.resolvedProjectId ?? getProjectIdFromFile(account: account) else {
            throw QuotaError.parseError("Missing project_id")
        }

        let body = ["project": projectId]
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        let bodyString = String(data: bodyData, encoding: .utf8) ?? "{}"

        let request = ApiCallRequest(
            authIndex: authIndex,
            method: "POST",
            url: geminiCliQuotaURL,
            header: geminiCliHeaders,
            data: bodyString
        )

        let (statusCode, responseBody) = try await proxyRequest(request)

        if statusCode < 200 || statusCode >= 300 {
            let message = extractErrorMessage(from: responseBody) ?? "HTTP \(statusCode)"
            throw QuotaError.apiError(statusCode, message)
        }

        guard let bodyDict = responseBody as? [String: Any],
              let buckets = bodyDict["buckets"] as? [[String: Any]] else {
            throw QuotaError.parseError("Invalid response format")
        }

        return parseGeminiCliBuckets(buckets)
    }

    private func parseGeminiCliBuckets(_ buckets: [[String: Any]]) -> [GeminiCliQuotaBucket] {
        var result: [GeminiCliQuotaBucket] = []
        var bucketsByModel: [String: [(tokenType: String?, fraction: Double?, amount: Int?, resetTime: Date?)]] = [:]

        for bucket in buckets {
            let modelId = (bucket["modelId"] as? String) ?? (bucket["model_id"] as? String) ?? ""
            if modelId.isEmpty { continue }

            let tokenType = (bucket["tokenType"] as? String) ?? (bucket["token_type"] as? String)
            let remainingFraction = (bucket["remainingFraction"] as? Double) ?? (bucket["remaining_fraction"] as? Double)
            let remainingAmount = (bucket["remainingAmount"] as? Int) ?? (bucket["remaining_amount"] as? Int)

            var resetTime: Date?
            if let resetStr = (bucket["resetTime"] as? String) ?? (bucket["reset_time"] as? String) {
                resetTime = parseISO8601Date(resetStr)
            }

            if bucketsByModel[modelId] == nil {
                bucketsByModel[modelId] = []
            }
            bucketsByModel[modelId]?.append((tokenType, remainingFraction, remainingAmount, resetTime))
        }

        for (modelId, items) in bucketsByModel {
            let minFraction = items.compactMap { $0.fraction }.min()
            let minAmount = items.compactMap { $0.amount }.min()
            let tokenTypes = items.compactMap { $0.tokenType }
            let resetTime = items.compactMap { $0.resetTime }.min()

            result.append(GeminiCliQuotaBucket(
                id: modelId,
                label: formatModelLabel(modelId),
                modelIds: [modelId],
                tokenType: tokenTypes.first,
                remainingFraction: minFraction,
                remainingAmount: minAmount,
                resetTime: resetTime
            ))
        }

        return result.sorted { ($0.remainingFraction ?? 1) < ($1.remainingFraction ?? 1) }
    }

    //  Codex Quota

    func fetchCodexQuota(account: AuthAccount) async throws -> CodexQuota {
        let authInfo = try await getAuthFileInfo(for: account)

        guard let authIndex = authInfo.resolvedAuthIndex else {
            throw QuotaError.authIndexNotFound
        }

        let accountId = authInfo.resolvedChatgptAccountId ?? getChatgptAccountIdFromFile(account: account)

        var headers = codexHeaders
        if let accountId = accountId, !accountId.isEmpty {
            headers["Chatgpt-Account-Id"] = accountId
        }

        let request = ApiCallRequest(
            authIndex: authIndex,
            method: "GET",
            url: codexUsageURL,
            header: headers,
            data: nil
        )

        let (statusCode, responseBody) = try await proxyRequest(request)

        if statusCode < 200 || statusCode >= 300 {
            let message = extractErrorMessage(from: responseBody) ?? "HTTP \(statusCode)"
            throw QuotaError.apiError(statusCode, message)
        }

        guard let bodyDict = responseBody as? [String: Any] else {
            throw QuotaError.parseError("Invalid response format")
        }

        return parseCodexUsage(bodyDict)
    }

    private func getChatgptAccountIdFromFile(account: AuthAccount) -> String? {
        guard let data = try? Data(contentsOf: account.filePath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return (json["chatgpt_account_id"] as? String) ?? (json["account_id"] as? String)
    }

    private func parseCodexUsage(_ json: [String: Any]) -> CodexQuota {
        let planType = (json["plan_type"] as? String) ?? (json["planType"] as? String)

        var windows: [CodexQuotaWindow] = []

        if let rateLimit = json["rate_limit"] as? [String: Any] ?? json["rateLimit"] as? [String: Any] {
            if let primary = rateLimit["primary_window"] as? [String: Any] ?? rateLimit["primaryWindow"] as? [String: Any] {
                windows.append(parseCodexWindow(primary, id: "primary", label: "Primary"))
            }

            if let secondary = rateLimit["secondary_window"] as? [String: Any] ?? rateLimit["secondaryWindow"] as? [String: Any] {
                windows.append(parseCodexWindow(secondary, id: "secondary", label: "Secondary"))
            }
        }

        if let codeReview = json["code_review_rate_limit"] as? [String: Any] ?? json["codeReviewRateLimit"] as? [String: Any] {
            if let primary = codeReview["primary_window"] as? [String: Any] ?? codeReview["primaryWindow"] as? [String: Any] {
                windows.append(parseCodexWindow(primary, id: "code-review", label: "Code Review"))
            }
        }

        return CodexQuota(planType: planType, windows: windows)
    }

    private func parseCodexWindow(_ window: [String: Any], id: String, label: String) -> CodexQuotaWindow {
        let usedPercent = (window["used_percent"] as? Double) ?? (window["usedPercent"] as? Double)

        var resetTime: Date?
        if let resetStr = (window["reset_time"] as? String) ?? (window["resetTime"] as? String) {
            resetTime = parseISO8601Date(resetStr)
        } else if let resetSeconds = (window["reset_seconds"] as? Int) ?? (window["resetSeconds"] as? Int) {
            resetTime = Date().addingTimeInterval(TimeInterval(resetSeconds))
        }

        return CodexQuotaWindow(
            id: id,
            label: label,
            usedPercent: usedPercent,
            resetTime: resetTime
        )
    }

    //  Helpers

    private func parseISO8601Date(_ string: String) -> Date? {
        let formatters: [ISO8601DateFormatter] = {
            let withFractional = ISO8601DateFormatter()
            withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let standard = ISO8601DateFormatter()
            standard.formatOptions = [.withInternetDateTime]
            return [withFractional, standard]
        }()

        for formatter in formatters {
            if let date = formatter.date(from: string) {
                return date
            }
        }
        return nil
    }

    private func formatModelLabel(_ modelId: String) -> String {
        let simplified = modelId
            .replacingOccurrences(of: "models/", with: "")
            .replacingOccurrences(of: "gemini-", with: "Gemini ")
            .replacingOccurrences(of: "claude-", with: "Claude ")
            .replacingOccurrences(of: "-latest", with: "")

        return simplified
    }

    func formatResetTime(_ date: Date?) -> String {
        guard let date = date else { return "-" }

        let now = Date()
        let diff = date.timeIntervalSince(now)

        if diff <= 0 {
            return "Now"
        } else if diff < 60 {
            return "\(Int(diff))s"
        } else if diff < 3600 {
            return "\(Int(diff / 60))m"
        } else if diff < 86400 {
            let hours = Int(diff / 3600)
            let mins = Int((diff.truncatingRemainder(dividingBy: 3600)) / 60)
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
        } else {
            let days = Int(diff / 86400)
            return "\(days)d"
        }
    }

    // Clear cache (call when auth files change)
    func clearCache() {
        Task {
            await cache.clear()
        }
    }
}
