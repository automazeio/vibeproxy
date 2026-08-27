import XCTest
@testable import CLIProxyMenuBar

final class ThinkingProxyTests: XCTestCase {
    func testActorWebSocketAddsAmpRivetPublicTokenToUpstreamPath() throws {
        let handshake = try XCTUnwrap(AmpWebSocketHandshake.request(
            method: "GET",
            path: "/actors/gateway/threadActor/websocket/?rvt-namespace=default",
            version: "HTTP/1.1",
            headers: [("Upgrade", "websocket")],
            rivetToken: "pk_test"
        ))
        let request = try XCTUnwrap(String(data: handshake, encoding: .utf8))

        XCTAssertTrue(request.hasPrefix("GET /actors/gateway/threadActor/websocket/?rvt-namespace=default&rvt-token=pk_test HTTP/1.1\r\n"))
    }

    func testActorWebSocketDoesNotMistakeAnotherQueryValueForRivetToken() throws {
        let handshake = try XCTUnwrap(AmpWebSocketHandshake.request(
            method: "GET",
            path: "/actors/gateway/threadActor/websocket/?note=rvt-token=",
            version: "HTTP/1.1",
            headers: [("Upgrade", "websocket")],
            rivetToken: "pk_test"
        ))
        let request = try XCTUnwrap(String(data: handshake, encoding: .utf8))

        XCTAssertTrue(request.hasPrefix("GET /actors/gateway/threadActor/websocket/?note=rvt-token=&rvt-token=pk_test HTTP/1.1\r\n"))
    }

    func testActorWebSocketReplacesBlankRivetToken() throws {
        let handshake = try XCTUnwrap(AmpWebSocketHandshake.request(
            method: "GET",
            path: "/actors/gateway/threadActor/websocket/?rvt-token=&rvt-key=thread",
            version: "HTTP/1.1",
            headers: [("Upgrade", "websocket")],
            rivetToken: "pk_test"
        ))
        let request = try XCTUnwrap(String(data: handshake, encoding: .utf8))

        XCTAssertTrue(request.hasPrefix("GET /actors/gateway/threadActor/websocket/?rvt-token=pk_test&rvt-key=thread HTTP/1.1\r\n"))
    }

    func testActorWebSocketPreservesExistingRivetToken() throws {
        let handshake = try XCTUnwrap(AmpWebSocketHandshake.request(
            method: "GET",
            path: "/actors/gateway/threadActor/websocket/?rvt-token=caller-token&rvt-key=thread",
            version: "HTTP/1.1",
            headers: [("Upgrade", "websocket")],
            rivetToken: "pk_test"
        ))
        let request = try XCTUnwrap(String(data: handshake, encoding: .utf8))

        XCTAssertTrue(request.hasPrefix("GET /actors/gateway/threadActor/websocket/?rvt-token=caller-token&rvt-key=thread HTTP/1.1\r\n"))
        XCTAssertFalse(request.contains("rvt-token=pk_test"))
    }

    func testActorWebSocketCanonicalizesDuplicateRivetTokens() throws {
        let handshake = try XCTUnwrap(AmpWebSocketHandshake.request(
            method: "GET",
            path: "/actors/gateway/threadActor/websocket/?rvt-token=&rvt-token=caller-token&rvt-key=thread",
            version: "HTTP/1.1",
            headers: [("Upgrade", "websocket")],
            rivetToken: "pk_test"
        ))
        let request = try XCTUnwrap(String(data: handshake, encoding: .utf8))

        XCTAssertTrue(request.hasPrefix("GET /actors/gateway/threadActor/websocket/?rvt-token=caller-token&rvt-key=thread HTTP/1.1\r\n"))
        XCTAssertEqual(request.components(separatedBy: "rvt-token=").count - 1, 1)
        XCTAssertFalse(request.contains("rvt-token=pk_test"))
    }


    func testWebSocketUpgradeRoutesToAmpActors() throws {
        let headers = [
            ("Connection", "keep-alive, Upgrade"),
            ("Upgrade", "websocket"),
            ("Authorization", "Bearer amp-token"),
        ]

        XCTAssertEqual(
            AmpRequestRouter.upstream(method: "GET", version: "HTTP/1.1", headers: headers),
            .actors
        )

        let firstFrame = Data([0x82, 0x02, 0xFF, 0x00])
        let handshake = try XCTUnwrap(AmpWebSocketHandshake.request(
            method: "GET",
            path: "/v2/actors/thread?connection=abc",
            version: "HTTP/1.1",
            headers: headers + [
                ("Host", "localhost:8317"),
                ("Sec-WebSocket-Key", "key=="),
                ("Origin", "http://localhost:8317"),
            ],
            initialPayload: firstFrame
        ))

        let headerLength = try XCTUnwrap(handshake.range(of: Data("\r\n\r\n".utf8))?.upperBound)
        let header = try XCTUnwrap(String(data: handshake[..<headerLength], encoding: .utf8))
        XCTAssertTrue(header.contains("Authorization: Bearer amp-token\r\n"))
        XCTAssertTrue(header.contains("Sec-WebSocket-Key: key==\r\n"))
        XCTAssertTrue(header.contains("Origin: http://localhost:8317\r\n"))
        XCTAssertTrue(header.contains("Host: ampcode.com\r\n"))
        XCTAssertFalse(header.contains("Host: localhost:8317"))
        XCTAssertEqual(Data(handshake[headerLength...]), firstFrame)
    }

    func testWebSocketRoutingCombinesDuplicateHeadersCaseInsensitively() {
        let headers = [
            ("Connection", "keep-alive"),
            ("connection", "UPGRADE"),
            ("Upgrade", "h2c"),
            ("UPGRADE", "WebSocket"),
        ]

        XCTAssertEqual(
            AmpRequestRouter.upstream(method: "get", version: "HTTP/1.1", headers: headers),
            .actors
        )
    }

    func testMalformedAndNonWebSocketUpgradesRemainManagementRequests() {
        let cases: [(String, String, [(String, String)])] = [
            ("POST", "HTTP/1.1", [("Connection", "Upgrade"), ("Upgrade", "websocket")]),
            ("GET", "HTTP/1.0", [("Connection", "Upgrade"), ("Upgrade", "websocket")]),
            ("GET", "HTTP/2.0", [("Connection", "Upgrade"), ("Upgrade", "websocket")]),
            ("GET", "garbage", [("Connection", "Upgrade"), ("Upgrade", "websocket")]),
            ("GET", "HTTP/1.1", [("Connection", "keep-alive"), ("Upgrade", "websocket")]),
            ("GET", "HTTP/1.1", [("Connection", "Upgrade"), ("Upgrade", "h2c")]),
        ]

        for (method, version, headers) in cases {
            XCTAssertEqual(
                AmpRequestRouter.upstream(method: method, version: version, headers: headers),
                .management
            )
        }
    }

    func testExtractsOnlyUpstreamHandshakeStatusLine() {
        let response = Data(
            "HTTP/1.1 403 Forbidden\r\nAuthorization: secret\r\n\r\n".utf8
        )

        XCTAssertEqual(HTTPStatusLine.from(response), "HTTP/1.1 403 Forbidden")
    }
}