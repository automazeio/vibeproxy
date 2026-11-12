import Foundation

protocol QuotaManagementTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

struct URLSessionQuotaManagementTransport: QuotaManagementTransport {
    private let session: URLSession

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 20
        session = URLSession(configuration: configuration)
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw QuotaFailure.serverUnavailable
        }
        return (data, response)
    }
}

struct ProxyAuthFile: Decodable, Sendable {
    let authIndex: String
    let name: String
    let provider: String
    let chatGPTAccountID: String?

    private enum CodingKeys: String, CodingKey {
        case authIndex = "auth_index"
        case name
        case provider
        case type
        case chatGPTAccountID = "chatgpt_account_id"
        case idToken = "id_token"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        authIndex = try container.decode(String.self, forKey: .authIndex)
        name = try container.decode(String.self, forKey: .name)
        provider = try container.decodeIfPresent(String.self, forKey: .provider)
            ?? container.decode(String.self, forKey: .type)
        let topLevelAccountID = try? container.decode(String.self, forKey: .chatGPTAccountID)
        let sanitizedClaims = try? container.decode(CodexClaims.self, forKey: .idToken)
        chatGPTAccountID = topLevelAccountID ?? sanitizedClaims?.chatGPTAccountID
    }

    private struct CodexClaims: Decodable {
        let chatGPTAccountID: String?

        private enum CodingKeys: String, CodingKey {
            case chatGPTAccountID = "chatgpt_account_id"
        }
    }
}

struct CLIProxyManagementClient: Sendable {
    private let baseURL: URL
    private let managementSecret: String
    private let transport: QuotaManagementTransport
    private let now: @Sendable () -> Date

    init(
        baseURL: URL,
        managementSecret: String,
        transport: QuotaManagementTransport = URLSessionQuotaManagementTransport(),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.baseURL = baseURL
        self.managementSecret = managementSecret
        self.transport = transport
        self.now = now
    }

    func fetchAuthFiles() async throws -> [ProxyAuthFile] {
        let request = try managementRequest(path: "/v0/management/auth-files")
        let (data, response) = try await send(request)
        try validateManagementResponse(response)

        do {
            return try JSONDecoder().decode(AuthFilesResponse.self, from: data).files
        } catch {
            throw QuotaFailure.invalidResponse
        }
    }

    func fetchQuota(for authFile: ProxyAuthFile, provider: QuotaProvider) async throws -> QuotaSnapshot {
        guard authFile.provider.caseInsensitiveCompare(provider.rawValue) == .orderedSame else {
            throw QuotaFailure.accountUnavailable
        }

        let template = try quotaTemplate(provider: provider, authFile: authFile)
        let upstreamBody = try await performAPICall(
            authFile: authFile,
            method: "GET",
            url: template.url,
            headers: template.headers
        )
        return try decode(upstreamBody, provider: provider)
    }

    func fetchCodexResetCredits(for authFile: ProxyAuthFile) async throws -> [CodexResetCredit] {
        let headers = try codexHeaders(for: authFile)
        let data = try await performAPICall(
            authFile: authFile,
            method: "GET",
            url: "https://chatgpt.com/backend-api/wham/rate-limit-reset-credits",
            headers: headers
        )
        return try CodexResetCreditDecoder.decodeCredits(data)
    }

    func consumeCodexResetCredit(_ credit: CodexResetCredit, for authFile: ProxyAuthFile) async throws -> CodexResetOutcome {
        let headers = try codexHeaders(for: authFile)
        let payload: String
        do {
            let data = try JSONEncoder().encode(ConsumeResetRequest(
                redeemRequestID: UUID().uuidString,
                creditID: credit.id
            ))
            guard let value = String(data: data, encoding: .utf8) else {
                throw QuotaFailure.invalidResponse
            }
            payload = value
        } catch {
            throw QuotaFailure.invalidResponse
        }

        var postHeaders = headers
        postHeaders["Content-Type"] = "application/json"
        let data = try await performAPICall(
            authFile: authFile,
            method: "POST",
            url: "https://chatgpt.com/backend-api/wham/rate-limit-reset-credits/consume",
            headers: postHeaders,
            data: payload
        )
        return try CodexResetCreditDecoder.decodeOutcome(data)
    }

    private func performAPICall(
        authFile: ProxyAuthFile,
        method: String,
        url: String,
        headers: [String: String],
        data: String? = nil
    ) async throws -> Data {
        let body: Data
        do {
            body = try JSONEncoder().encode(APICallRequest(
                authIndex: authFile.authIndex,
                method: method,
                url: url,
                header: headers,
                data: data
            ))
        } catch {
            throw QuotaFailure.invalidResponse
        }

        var request = try managementRequest(path: "/v0/management/api-call")
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        let (data, response) = try await send(request)
        try validateManagementResponse(response)

        let wrapper: APICallResponse
        do {
            wrapper = try JSONDecoder().decode(APICallResponse.self, from: data)
        } catch {
            throw QuotaFailure.invalidResponse
        }

        switch wrapper.statusCode {
        case 200 ..< 300:
            break
        case 401, 403:
            throw QuotaFailure.providerAuthenticationFailed
        case 429:
            throw QuotaFailure.rateLimited
        default:
            throw QuotaFailure.providerUnavailable
        }

        guard let upstreamBody = wrapper.body.data(using: .utf8) else {
            throw QuotaFailure.invalidResponse
        }
        return upstreamBody
    }

    private func managementRequest(path: String) throws -> URLRequest {
        guard let url = URL(string: path, relativeTo: baseURL)?.absoluteURL else {
            throw QuotaFailure.serverUnavailable
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(managementSecret)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            return try await transport.send(request)
        } catch let failure as QuotaFailure {
            throw failure
        } catch {
            throw QuotaFailure.serverUnavailable
        }
    }

    private func validateManagementResponse(_ response: HTTPURLResponse) throws {
        switch response.statusCode {
        case 200 ..< 300: return
        case 401, 403: throw QuotaFailure.managementAuthenticationFailed
        default: throw QuotaFailure.serverUnavailable
        }
    }

    private func quotaTemplate(provider: QuotaProvider, authFile: ProxyAuthFile) throws -> QuotaTemplate {
        switch provider {
        case .anthropic:
            return QuotaTemplate(
                url: "https://api.anthropic.com/api/oauth/usage",
                headers: [
                    "Authorization": "Bearer $TOKEN$",
                    "anthropic-beta": "oauth-2025-04-20"
                ]
            )
        case .openAI:
            return QuotaTemplate(
                url: "https://chatgpt.com/backend-api/wham/usage",
                headers: try codexHeaders(for: authFile)
            )
        }
    }

    private func codexHeaders(for authFile: ProxyAuthFile) throws -> [String: String] {
        guard authFile.provider.caseInsensitiveCompare(QuotaProvider.openAI.rawValue) == .orderedSame,
              let accountID = authFile.chatGPTAccountID,
              !accountID.isEmpty else {
            throw QuotaFailure.accountUnavailable
        }
        return [
            "Authorization": "Bearer $TOKEN$",
            "chatgpt-account-id": accountID,
            "User-Agent": "codex-cli"
        ]
    }

    private func decode(_ data: Data, provider: QuotaProvider) throws -> QuotaSnapshot {
        do {
            switch provider {
            case .anthropic: return try ClaudeQuotaDecoder.decode(data, fetchedAt: now())
            case .openAI: return try CodexQuotaDecoder.decode(data, fetchedAt: now())
            }
        } catch let failure as QuotaFailure {
            throw failure
        } catch {
            throw QuotaFailure.invalidResponse
        }
    }

    private struct AuthFilesResponse: Decodable {
        let files: [ProxyAuthFile]
    }

    private struct QuotaTemplate {
        let url: String
        let headers: [String: String]
    }

    private struct APICallRequest: Encodable {
        let authIndex: String
        let method: String
        let url: String
        let header: [String: String]
        let data: String?

        private enum CodingKeys: String, CodingKey {
            case authIndex = "auth_index"
            case method
            case url
            case header
            case data
        }
    }

    private struct ConsumeResetRequest: Encodable {
        let redeemRequestID: String
        let creditID: String

        private enum CodingKeys: String, CodingKey {
            case redeemRequestID = "redeem_request_id"
            case creditID = "credit_id"
        }
    }

    private struct APICallResponse: Decodable {
        let statusCode: Int
        let body: String

        private enum CodingKeys: String, CodingKey {
            case statusCode = "status_code"
            case body
        }
    }
}
