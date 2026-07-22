import Foundation
import XCTest
@testable import CLIProxyMenuBar

final class QuotaTests: XCTestCase {
    func testClaudeCurrentWindowsDecodeToRemainingUsage() throws {
        let data = Data(#"""
        {"limits":[
          {"kind":"session","percent":25,"resets_at":"2030-01-01T10:00:00Z"},
          {"kind":"weekly_all","percent":40,"resets_at":"2030-01-05T10:00:00Z"},
          {"kind":"weekly_scoped","percent":100,"resets_at":"2030-01-05T10:00:00Z","scope":{"model":{"display_name":"Fable 5"}}}
        ]}
        """#.utf8)

        let snapshot = try ClaudeQuotaDecoder.decode(data, fetchedAt: Date(timeIntervalSince1970: 1))

        XCTAssertEqual(snapshot.window(.fiveHour)?.remainingPercent, 75)
        XCTAssertEqual(snapshot.window(.weekly)?.remainingPercent, 60)
        XCTAssertEqual(snapshot.window(.fable)?.remainingPercent, 0)
        XCTAssertTrue(snapshot.isExhausted)
    }

    func testClaudeLegacyWindowsDecodeToRemainingUsage() throws {
        let data = Data(#"""
        {
          "five_hour":{"utilization":10,"resets_at":null},
          "seven_day":{"utilization":20,"resets_at":"2030-01-05T10:00:00Z"}
        }
        """#.utf8)

        let snapshot = try ClaudeQuotaDecoder.decode(data, fetchedAt: Date())

        XCTAssertEqual(snapshot.window(.fiveHour)?.remainingPercent, 90)
        XCTAssertEqual(snapshot.window(.weekly)?.remainingPercent, 80)
    }

    func testCodexMapsFixedColumnsAndResetAvailability() throws {
        let snapshot = try CodexQuotaDecoder.decode(codexUsageBody(), fetchedAt: Date())

        XCTAssertEqual(snapshot.window(.fiveHour)?.remainingPercent, 71)
        XCTAssertEqual(snapshot.window(.weekly)?.remainingPercent, 20)
        XCTAssertNil(snapshot.window(.fable))
        XCTAssertEqual(snapshot.resetCredits, CodexResetAvailability(availableCount: 2, applicableAvailableCount: 1))
    }

    func testCodexClassifiesWindowsByDuration() throws {
        let data = Data(#"""
        {"rate_limit":{"primary_window":{"used_percent":6,"limit_window_seconds":604800,"reset_at":1900000000},"secondary_window":null},"rate_limit_reset_credits":{"available_count":2,"applicable_available_count":1}}
        """#.utf8)

        let snapshot = try CodexQuotaDecoder.decode(data, fetchedAt: Date())

        XCTAssertNil(snapshot.window(.fiveHour))
        XCTAssertEqual(snapshot.window(.weekly)?.remainingPercent, 94)
        XCTAssertEqual(snapshot.resetCredits, CodexResetAvailability(availableCount: 2, applicableAvailableCount: 1))
    }

    func testStringIDTokenDoesNotPoisonAuthInventory() async throws {
        let transport = QuotaTestTransport(responses: [
            QuotaTestResponse(statusCode: 200, data: Data(#"""
            {"files":[
              {"auth_index":"codex-1","name":"codex.json","provider":"codex","id_token":"header.payload.signature"},
              {"auth_index":"claude-1","name":"claude.json","provider":"claude"}
            ]}
            """#.utf8))
        ])
        let client = testClient(transport: transport)

        let files = try await client.fetchAuthFiles()

        XCTAssertEqual(files.count, 2)
        XCTAssertNil(files.first { $0.provider == "codex" }?.chatGPTAccountID)
    }

    func testCodexQuotaUsesClosedTemplateAndFailsWithoutAccountID() async throws {
        let authFiles = Data(#"""
        {"files":[{"auth_index":"auth-1","name":"codex.json","provider":"codex","id_token":{"chatgpt_account_id":"account-123"}}]}
        """#.utf8)
        let quotaBody = #"{"rate_limit":{"primary_window":{"used_percent":29,"limit_window_seconds":18000,"reset_at":1900000000}}}"#
        let wrapper = try JSONSerialization.data(withJSONObject: ["status_code": 200, "body": quotaBody])
        let transport = QuotaTestTransport(responses: [
            QuotaTestResponse(statusCode: 200, data: authFiles),
            QuotaTestResponse(statusCode: 200, data: wrapper)
        ])
        let client = testClient(transport: transport)

        let files = try await client.fetchAuthFiles()
        let file = try XCTUnwrap(files.first)
        _ = try await client.fetchQuota(for: file, provider: .openAI)
        let requests = await transport.recordedRequests()
        let requestBody = try XCTUnwrap(requests.last?.httpBody)
        let object = try XCTUnwrap(try JSONSerialization.jsonObject(with: requestBody) as? [String: Any])
        let headers = try XCTUnwrap(object["header"] as? [String: String])

        XCTAssertEqual(object["url"] as? String, "https://chatgpt.com/backend-api/wham/usage")
        XCTAssertEqual(headers["Authorization"], "Bearer $TOKEN$")
        XCTAssertEqual(headers["chatgpt-account-id"], "account-123")
        XCTAssertEqual(headers["User-Agent"], "codex-cli")
    }

    func testCodexQuotaFailsClosedWithoutAccountID() async throws {
        let authFiles = Data(#"{"files":[{"auth_index":"auth-1","name":"codex.json","provider":"codex"}]}"#.utf8)
        let transport = QuotaTestTransport(responses: [
            QuotaTestResponse(statusCode: 200, data: authFiles)
        ])
        let client = testClient(transport: transport)
        let files = try await client.fetchAuthFiles()
        let file = try XCTUnwrap(files.first)

        do {
            _ = try await client.fetchQuota(for: file, provider: .openAI)
            XCTFail("A Codex quota request without an account ID should fail")
        } catch let failure as QuotaFailure {
            XCTAssertEqual(failure, .accountUnavailable)
        }

        let requestCount = await transport.recordedRequests().count
        XCTAssertEqual(requestCount, 1)
    }

    func testProviderRateLimitRemainsDistinguishable() async throws {
        let authFiles = Data(#"{"files":[{"auth_index":"auth-1","name":"claude.json","provider":"claude"}]}"#.utf8)
        let wrapper = try JSONSerialization.data(withJSONObject: ["status_code": 429, "body": "{}"])
        let transport = QuotaTestTransport(responses: [
            QuotaTestResponse(statusCode: 200, data: authFiles),
            QuotaTestResponse(statusCode: 200, data: wrapper)
        ])
        let client = testClient(transport: transport)
        let files = try await client.fetchAuthFiles()
        let file = try XCTUnwrap(files.first)

        do {
            _ = try await client.fetchQuota(for: file, provider: .anthropic)
            XCTFail("A provider 429 should fail")
        } catch let failure as QuotaFailure {
            XCTAssertEqual(failure, .rateLimited)
        }
    }

    func testCodexResetUsesClosedTemplatesAndNestedPostBody() async throws {
        let authFiles = Data(#"""
        {"files":[{"auth_index":"auth-1","name":"codex.json","provider":"codex","id_token":{"chatgpt_account_id":"account-123"}}]}
        """#.utf8)
        let creditsBody = #"{"available_count":1,"credits":[{"id":"credit-1","reset_type":"codex_rate_limits","status":"available","granted_at":"2030-01-01T00:00:00Z","expires_at":"2030-02-01T00:00:00Z","title":"Full reset"}]}"#
        let consumeBody = #"{"code":"reset","windows_reset":2}"#
        let transport = QuotaTestTransport(responses: [
            QuotaTestResponse(statusCode: 200, data: authFiles),
            QuotaTestResponse(statusCode: 200, data: try JSONSerialization.data(withJSONObject: ["status_code": 200, "body": creditsBody])),
            QuotaTestResponse(statusCode: 200, data: try JSONSerialization.data(withJSONObject: ["status_code": 200, "body": consumeBody]))
        ])
        let client = testClient(transport: transport)

        let files = try await client.fetchAuthFiles()
        let file = try XCTUnwrap(files.first)
        let credits = try await client.fetchCodexResetCredits(for: file)
        let credit = try XCTUnwrap(credits.first)
        let outcome = try await client.consumeCodexResetCredit(credit, for: file)

        XCTAssertEqual(outcome, .reset)
        let requests = await transport.recordedRequests()
        let listEnvelope = try requestObject(requests[1])
        let consumeEnvelope = try requestObject(requests[2])
        XCTAssertEqual(listEnvelope["url"] as? String, "https://chatgpt.com/backend-api/wham/rate-limit-reset-credits")
        XCTAssertEqual(consumeEnvelope["url"] as? String, "https://chatgpt.com/backend-api/wham/rate-limit-reset-credits/consume")
        XCTAssertEqual(consumeEnvelope["method"] as? String, "POST")

        let dataString = try XCTUnwrap(consumeEnvelope["data"] as? String)
        let data = try XCTUnwrap(dataString.data(using: .utf8))
        let upstream = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: String])
        XCTAssertEqual(upstream["credit_id"], "credit-1")
        XCTAssertNotNil(UUID(uuidString: try XCTUnwrap(upstream["redeem_request_id"])))
    }

    @MainActor
    func testAutomaticRefreshUsesCachedSnapshotWhileManualRefreshBypassesIt() async throws {
        let authFiles = Data(#"{"files":[{"auth_index":"auth-1","name":"claude-test.json","provider":"claude"}]}"#.utf8)
        let quotaBody = #"{"limits":[{"kind":"session","percent":25,"resets_at":null}]}"#
        let wrapper = try JSONSerialization.data(withJSONObject: ["status_code": 200, "body": quotaBody])
        let transport = QuotaTestTransport(responses: [
            QuotaTestResponse(statusCode: 200, data: authFiles),
            QuotaTestResponse(statusCode: 200, data: wrapper),
            QuotaTestResponse(statusCode: 200, data: authFiles),
            QuotaTestResponse(statusCode: 200, data: wrapper)
        ])
        let clock = QuotaTestClock(now: Date(timeIntervalSince1970: 100))
        let store = QuotaStore(
            client: testClient(transport: transport),
            freshnessInterval: 300,
            now: { clock.now }
        )
        let account = AuthAccount(
            id: "claude-test.json",
            email: "test@example.com",
            login: nil,
            type: .claude,
            expired: nil,
            filePath: URL(fileURLWithPath: "/tmp/claude-test.json"),
            isDisabled: false
        )

        store.refresh(accounts: [account])
        await waitForRefresh(store)
        var requestCount = await transport.recordedRequests().count
        XCTAssertEqual(requestCount, 2)

        store.refresh(accounts: [account])
        await Task.yield()
        requestCount = await transport.recordedRequests().count
        XCTAssertEqual(requestCount, 2)

        store.refresh(accounts: [account], force: true)
        await waitForRefresh(store)
        requestCount = await transport.recordedRequests().count
        XCTAssertEqual(requestCount, 4)
    }

    @MainActor
    func testDisabledAccountsStillRefreshUsage() async throws {
        let authFiles = Data(#"{"files":[{"auth_index":"auth-1","name":"codex-disabled.json","provider":"codex","id_token":{"chatgpt_account_id":"account-123"}}]}"#.utf8)
        let quotaBody = #"{"rate_limit":{"primary_window":{"used_percent":100,"limit_window_seconds":604800,"reset_at":1900000000}},"rate_limit_reset_credits":{"available_count":2,"applicable_available_count":2}}"#
        let wrapper = try JSONSerialization.data(withJSONObject: ["status_code": 200, "body": quotaBody])
        let transport = QuotaTestTransport(responses: [
            QuotaTestResponse(statusCode: 200, data: authFiles),
            QuotaTestResponse(statusCode: 200, data: wrapper)
        ])
        let store = QuotaStore(client: testClient(transport: transport))
        let account = AuthAccount(
            id: "codex-disabled.json",
            email: "disabled@example.com",
            login: nil,
            type: .codex,
            expired: nil,
            filePath: URL(fileURLWithPath: "/tmp/codex-disabled.json"),
            isDisabled: true
        )

        store.refresh(accounts: [account])
        await waitForRefresh(store)

        let requestCount = await transport.recordedRequests().count
        XCTAssertEqual(requestCount, 2)
        XCTAssertEqual(store.states[account.id]?.snapshot?.resetCredits?.applicableAvailableCount, 2)
    }

    private func testClient(transport: QuotaTestTransport) -> CLIProxyManagementClient {
        CLIProxyManagementClient(
            baseURL: URL(string: "http://127.0.0.1:8318")!,
            managementSecret: "runtime-secret",
            transport: transport
        )
    }

    private func codexUsageBody() -> Data {
        Data(#"""
        {"rate_limit":{"primary_window":{"used_percent":29,"limit_window_seconds":18000,"reset_at":1900000000},"secondary_window":{"used_percent":80,"limit_window_seconds":604800,"reset_at":1900100000}},"rate_limit_reset_credits":{"available_count":2,"applicable_available_count":1}}
        """#.utf8)
    }

    private func requestObject(_ request: URLRequest) throws -> [String: Any] {
        let body = try XCTUnwrap(request.httpBody)
        return try XCTUnwrap(try JSONSerialization.jsonObject(with: body) as? [String: Any])
    }

    @MainActor
    private func waitForRefresh(_ store: QuotaStore) async {
        for _ in 0 ..< 100 {
            if !store.isRefreshing { return }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("Quota refresh did not finish")
    }
}

private final class QuotaTestClock: @unchecked Sendable {
    let now: Date

    init(now: Date) {
        self.now = now
    }
}

private struct QuotaTestResponse: Sendable {
    let statusCode: Int
    let data: Data
}

private actor QuotaTestTransport: QuotaManagementTransport {
    private var responses: [QuotaTestResponse]
    private var requests: [URLRequest] = []

    init(responses: [QuotaTestResponse]) {
        self.responses = responses
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        guard !responses.isEmpty else { throw QuotaFailure.serverUnavailable }
        let stub = responses.removeFirst()
        guard let response = HTTPURLResponse(
            url: request.url!,
            statusCode: stub.statusCode,
            httpVersion: nil,
            headerFields: nil
        ) else {
            throw QuotaFailure.serverUnavailable
        }
        return (stub.data, response)
    }

    func recordedRequests() -> [URLRequest] {
        requests
    }
}
