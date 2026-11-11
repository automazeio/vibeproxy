import XCTest
import Network
@testable import CLIProxyMenuBar

final class ThinkingProxyTests: XCTestCase {
    func testForwardingPreservesCacheDirectivesAcrossModelAndPathRewrites() throws {
        let cases = [
            ("claude-sonnet-4-5-20250929", "/v1/messages", "claude-sonnet-4-5-20250929", "/v1/messages"),
            ("claude-sonnet-4-5-20250929-thinking-5000", "/api/v1/messages", "claude-sonnet-4-5-20250929", "/api/v1/messages"),
            ("ghcp-son-46", "/provider/anthropic/v1/messages", "claude-sonnet-4.6", "/api/provider/anthropic/v1/messages")
        ]
        for (model, path, expectedModel, expectedPath) in cases {
            let body = """
            {
              "model": "\(model)",
              "max_tokens": 10000,
              "system": [{"type":"text","text":"Reusable context café","cache_control":{"type":"ephemeral"}}],
              "tools": [{"name":"read_file","description":"Read a file","input_schema":{"type":"object"},"cache_control":{"type":"ephemeral"}}],
              "messages": [{"role":"user","content":[
                {"type":"text","text":"Read the context","cache_control":{"type":"ephemeral"}},
                {"type":"tool_result","tool_use_id":"tool-1","content":[
                  {"type":"text","text":"Nested result","cache_control":{"type":"ephemeral"}}
                ]}
              ]}]
            }
            """
            let original = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(body.utf8)) as? [String: Any])
            let forwarded = try forwardThroughProxy(body: body, path: path, expectedPath: expectedPath)

            XCTAssertEqual(forwarded["model"] as? String, expectedModel)
            for field in ["system", "tools", "messages"] {
                XCTAssertEqual(forwarded[field] as? NSArray, original[field] as? NSArray, "\(model): \(field) must preserve cache directives")
            }
            if model.contains("-thinking-5000") {
                XCTAssertEqual(forwarded["thinking"] as? NSDictionary, ["type": "enabled", "budget_tokens": 5000] as NSDictionary)
            }
        }
    }

    func testForwardingPreservesNativeOpenAIAndGeminiCacheFields() throws {
        let bodies = [
            #"{"model":"gpt-5","input":"Reusable context","prompt_cache_key":"session-1","prompt_cache_retention":"24h"}"#,
            #"{"model":"gemini-2.5-pro","cachedContent":"cachedContents/context-1","contents":[{"role":"user","parts":[{"text":"Reusable context"}]}]}"#
        ]
        for body in bodies {
            let original = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(body.utf8)) as? NSDictionary)
            let forwarded = try forwardThroughProxy(body: body, path: "/v1/chat/completions", expectedPath: "/v1/chat/completions")
            XCTAssertEqual(forwarded as NSDictionary, original)
        }
    }

    private func forwardThroughProxy(body: String, path: String, expectedPath: String) throws -> [String: Any] {
        let backend = try CaptureBackend()
        defer { backend.stop() }
        let backendReady = expectation(description: "Capture backend listening")
        backend.listener.stateUpdateHandler = { state in
            if case .ready = state { backendReady.fulfill() }
        }
        backend.listener.start(queue: backend.queue)
        wait(for: [backendReady], timeout: 5)

        let backendPort = try XCTUnwrap(backend.listener.port?.rawValue)
        let proxy = ThinkingProxy(proxyPort: 0, targetPort: backendPort)
        proxy.start()
        let proxyReady = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in proxy.isRunning }, object: nil)
        wait(for: [proxyReady], timeout: 5)
        defer { proxy.stop() }

        let captured = expectation(description: "Backend receives forwarded request")
        var forwardedData: Data?
        backend.onRequest = { data in
            forwardedData = data
            captured.fulfill()
        }
        let session = URLSession(configuration: .ephemeral)
        defer { session.invalidateAndCancel() }
        var request = URLRequest(url: try XCTUnwrap(URL(string: "http://127.0.0.1:\(proxy.proxyPort)\(path)")))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(body.utf8)
        let responseReceived = expectation(description: "Proxy relays backend response")
        session.dataTask(with: request) { data, response, error in
            XCTAssertNil(error)
            XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
            XCTAssertEqual(data, CaptureBackend.responseBody)
            responseReceived.fulfill()
        }.resume()
        wait(for: [captured, responseReceived], timeout: 5)

        let data = try XCTUnwrap(forwardedData)
        let separator = try XCTUnwrap(data.range(of: Data("\r\n\r\n".utf8)))
        let headers = String(decoding: data[..<separator.lowerBound], as: UTF8.self)
        let forwardedBody = Data(data[separator.upperBound...])
        XCTAssertTrue(headers.hasPrefix("POST \(expectedPath) HTTP/1.1\r\n"))
        XCTAssertTrue(headers.contains("\r\nHost: 127.0.0.1:\(backendPort)"))
        XCTAssertTrue(headers.contains("\r\nContent-Length: \(forwardedBody.count)"))
        return try XCTUnwrap(JSONSerialization.jsonObject(with: forwardedBody) as? [String: Any])
    }

    func testLoopbackListenerParametersBindIPv4LoopbackOnly() throws {
        let parameters = try XCTUnwrap(ThinkingProxy.loopbackListenerParameters(port: 8317))

        let endpoint = try XCTUnwrap(parameters.requiredLocalEndpoint)
        guard case .hostPort(let host, let port) = endpoint else {
            return XCTFail("Expected hostPort endpoint, got \(endpoint)")
        }
        guard case .ipv4(let address) = host else {
            return XCTFail("Expected an IPv4 host, got \(host)")
        }
        XCTAssertEqual(address.rawValue, Data([127, 0, 0, 1]))
        XCTAssertEqual(port.rawValue, 8317)
    }
}

private final class CaptureBackend {
    let listener: NWListener
    let queue = DispatchQueue(label: "ThinkingProxyTests.capture")
    var onRequest: ((Data) -> Void)?
    private var connections: [NWConnection] = []
    static let responseBody = Data(#"{"ok":"✓"}"#.utf8)

    init() throws {
        let parameters = try XCTUnwrap(ThinkingProxy.loopbackListenerParameters(port: 0))
        listener = try NWListener(using: parameters)
        listener.newConnectionHandler = { [weak self] connection in
            guard let self = self else { return }
            self.connections.append(connection)
            connection.start(queue: self.queue)
            self.receive(connection, accumulated: Data())
        }
    }

    func stop() {
        listener.cancel()
        queue.sync { connections.forEach { $0.cancel() } }
    }

    private func receive(_ connection: NWConnection, accumulated: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, complete, error in
            guard let self = self else { return }
            var request = accumulated
            if let data = data { request.append(data) }
            if let separator = request.range(of: Data("\r\n\r\n".utf8)) {
                let headers = String(decoding: request[..<separator.lowerBound], as: UTF8.self)
                let length = headers.components(separatedBy: "\r\n").first { $0.lowercased().hasPrefix("content-length:") }
                    .flatMap { Int($0.dropFirst("content-length:".count).trimmingCharacters(in: .whitespaces)) }
                if let length = length, request.count >= separator.upperBound + length {
                    self.onRequest?(request)
                    var response = Data("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: \(Self.responseBody.count)\r\nConnection: close\r\n\r\n".utf8)
                    response.append(Self.responseBody)
                    connection.send(content: response, completion: .contentProcessed { _ in connection.cancel() })
                    return
                }
            }
            if complete || error != nil {
                connection.cancel()
                return
            }
            self.receive(connection, accumulated: request)
        }
    }
}
