import XCTest
@testable import CLIProxyMenuBar

final class ResponsesSSEFramerTests: XCTestCase {
    func testFramesPartialResponsesEventAcrossChunks() throws {
        let framer = ResponsesSSEFramer()

        let firstOutput = framer.write(Data("event: response.output_text.delta".utf8))
        XCTAssertTrue(firstOutput.isEmpty)

        let secondOutput = framer.write(
            Data("\ndata: {\"type\":\"response.output_text.delta\",\"delta\":\"hi\"}\n\n".utf8)
        )

        XCTAssertEqual(secondOutput.count, 1)
        XCTAssertEqual(
            String(data: secondOutput[0], encoding: .utf8),
            "event: response.output_text.delta\ndata: {\"type\":\"response.output_text.delta\",\"delta\":\"hi\"}\n\n"
        )
    }

    func testRelayReframesResponsesSSEAfterHeaders() throws {
        let relay = HTTPResponseRelay(requestPath: "/v1/responses")

        let initial = Data((
            "HTTP/1.1 200 OK\r\n" +
            "Content-Type: text/event-stream\r\n" +
            "Connection: close\r\n\r\n" +
            "event: response.output_text.delta"
        ).utf8)

        let firstOutput = relay.process(initial, isComplete: false)
        XCTAssertEqual(firstOutput.count, 1)
        XCTAssertEqual(
            String(data: firstOutput[0], encoding: .utf8),
            "HTTP/1.1 200 OK\r\nContent-Type: text/event-stream\r\nConnection: close\r\n\r\n"
        )

        let secondOutput = relay.process(
            Data("\ndata: {\"type\":\"response.output_text.delta\",\"delta\":\"done\"}\n\n".utf8),
            isComplete: false
        )

        XCTAssertEqual(secondOutput.count, 1)
        XCTAssertEqual(
            String(data: secondOutput[0], encoding: .utf8),
            "event: response.output_text.delta\ndata: {\"type\":\"response.output_text.delta\",\"delta\":\"done\"}\n\n"
        )
    }

    func testRelayPassthroughForNonResponsesRequest() throws {
        let relay = HTTPResponseRelay(requestPath: "/v1/chat/completions")
        let raw = Data("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n{}".utf8)

        let output = relay.process(raw, isComplete: true)

        XCTAssertEqual(output, [raw])
    }

    func testFramerHandlesSlicedDataWithoutIndexTrap() throws {
        let framer = ResponsesSSEFramer()
        let base = Data("prefix\ndata: {\"type\":\"response.created\"}\n\n".utf8)
        let sliced = Data(base.dropFirst("prefix\n".count))

        let output = framer.write(sliced)

        XCTAssertEqual(output.count, 1)
        XCTAssertEqual(
            String(data: output[0], encoding: .utf8),
            "data: {\"type\":\"response.created\"}\n\n"
        )
    }

    func testRelayDecodesChunkedEventStreamResponses() throws {
        let relay = HTTPResponseRelay(requestPath: "/v1/chat/completions")
        let raw = Data((
            "HTTP/1.1 200 OK\r\n" +
            "Content-Type: text/event-stream\r\n" +
            "Transfer-Encoding: chunked\r\n" +
            "Connection: keep-alive\r\n\r\n" +
            "26\r\n" +
            "data: {\"type\":\"response.created\"}\n\n\r\n" +
            "0\r\n\r\n"
        ).utf8)

        let output = relay.process(raw, isComplete: true)

        XCTAssertEqual(output.count, 2)
        XCTAssertEqual(
            String(data: output[0], encoding: .utf8),
            "HTTP/1.1 200 OK\r\nContent-Type: text/event-stream\r\nConnection: close\r\n\r\n"
        )
        XCTAssertEqual(
            String(data: output[1], encoding: .utf8),
            "data: {\"type\":\"response.created\"}\n\n"
        )
    }

    func testFramerMergesEventAndDataAcrossDecodedChunks() throws {
        let framer = ResponsesSSEFramer()

        XCTAssertTrue(framer.write(Data("event: response.created\n\n".utf8)).isEmpty)

        let output = framer.write(Data("data: {\"type\":\"response.created\"}\n\n".utf8))

        XCTAssertEqual(output.count, 1)
        XCTAssertEqual(
            String(data: output[0], encoding: .utf8),
            "event: response.created\ndata: {\"type\":\"response.created\"}\n\n"
        )
    }
}
