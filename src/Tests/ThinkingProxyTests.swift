import XCTest
import Network
@testable import CLIProxyMenuBar

final class ThinkingProxyTests: XCTestCase {
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
