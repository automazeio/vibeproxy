import Foundation

struct ModelAliasMapper {
    private static let aliases: [String: String] = [
        "ghcp-op-46": "claude-opus-4.6",
        "ghcp-son-46": "claude-sonnet-4.6",
        "ghcp-haik-45": "claude-haiku-4.5"
    ]

    static func rewriteModelIfAlias(in jsonString: String) -> (body: String, matchedAlias: Bool) {
        guard let jsonData = jsonString.data(using: .utf8),
              var json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let model = json["model"] as? String,
              let canonicalModel = aliases[model] else {
            return (jsonString, false)
        }

        json["model"] = canonicalModel

        guard let modifiedData = try? JSONSerialization.data(withJSONObject: json),
              let modifiedString = String(data: modifiedData, encoding: .utf8) else {
            return (jsonString, false)
        }

        return (modifiedString, true)
    }
}
