import XCTest
@testable import CLIProxyMenuBar

final class ModelAliasMapperTests: XCTestCase {
    func testRewriteKnownCopilotAlias_opus() {
        let input = #"{"model":"ghcp-op-46","messages":[]}"#
        let result = ModelAliasMapper.rewriteModelIfAlias(in: input)

        XCTAssertTrue(result.matchedAlias)
        XCTAssertTrue(result.body.contains(#""model":"claude-opus-4.6""#))
    }

    func testRewriteKnownCopilotAlias_sonnet() {
        let input = #"{"model":"ghcp-son-46"}"#
        let result = ModelAliasMapper.rewriteModelIfAlias(in: input)

        XCTAssertTrue(result.matchedAlias)
        XCTAssertTrue(result.body.contains(#""model":"claude-sonnet-4.6""#))
    }

    func testRewriteKnownCopilotAlias_haiku() {
        let input = #"{"model":"ghcp-haik-45"}"#
        let result = ModelAliasMapper.rewriteModelIfAlias(in: input)

        XCTAssertTrue(result.matchedAlias)
        XCTAssertTrue(result.body.contains(#""model":"claude-haiku-4.5""#))
    }

    func testUnknownModelRemainsUnchanged() {
        let input = #"{"model":"gpt-5.3-codex"}"#
        let result = ModelAliasMapper.rewriteModelIfAlias(in: input)

        XCTAssertFalse(result.matchedAlias)
        XCTAssertEqual(result.body, input)
    }
}
