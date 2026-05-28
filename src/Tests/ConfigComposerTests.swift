import XCTest
@testable import CLIProxyMenuBar

final class ConfigComposerTests: XCTestCase {
    func testPreservesRuntimeEditedTopLevelAPIKeysWhenBaseDoesNotDefineThem() {
        let root: [String: Any] = ["port": 8318]
        let runtimeRoot: [String: Any] = [
            "api-keys": ["local-key"],
            "port": 9000
        ]

        let result = ConfigComposer.preservingRuntimeEditableTopLevelKeys(
            in: root,
            from: runtimeRoot
        )

        XCTAssertEqual(result["api-keys"] as? [String], ["local-key"])
        XCTAssertEqual(result["port"] as? Int, 8318)
    }

    func testDoesNotOverwriteExplicitTopLevelAPIKeys() {
        let root: [String: Any] = ["api-keys": ["configured-key"]]
        let runtimeRoot: [String: Any] = ["api-keys": ["runtime-key"]]

        let result = ConfigComposer.preservingRuntimeEditableTopLevelKeys(
            in: root,
            from: runtimeRoot
        )

        XCTAssertEqual(result["api-keys"] as? [String], ["configured-key"])
    }
}
