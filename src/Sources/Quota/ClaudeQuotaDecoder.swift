import Foundation

enum ClaudeQuotaDecoder {
    static func decode(_ data: Data, fetchedAt: Date) throws -> QuotaSnapshot {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw QuotaFailure.invalidResponse
        }

        var windows: [QuotaWindow] = []
        let limits = root["limits"] as? [[String: Any]] ?? []

        for limit in limits {
            guard let kind = limit["kind"] as? String,
                  let usedPercent = QuotaDateParser.number(limit["percent"]) else {
                continue
            }

            switch kind {
            case "session":
                appendIfMissing(
                    QuotaWindow(kind: .fiveHour, usedPercent: usedPercent, resetsAt: optionalDate(limit["resets_at"])),
                    to: &windows
                )
            case "weekly_all":
                appendIfMissing(
                    QuotaWindow(kind: .weekly, usedPercent: usedPercent, resetsAt: optionalDate(limit["resets_at"])),
                    to: &windows
                )
            case "weekly_scoped":
                guard scopeName(limit).localizedCaseInsensitiveContains("fable") else { continue }
                appendIfMissing(
                    QuotaWindow(kind: .fable, usedPercent: usedPercent, resetsAt: optionalDate(limit["resets_at"])),
                    to: &windows
                )
            default:
                continue
            }
        }

        appendLegacyWindow(key: "five_hour", kind: .fiveHour, root: root, to: &windows)
        appendLegacyWindow(key: "seven_day", kind: .weekly, root: root, to: &windows)

        guard !windows.isEmpty else {
            throw QuotaFailure.invalidResponse
        }

        return QuotaSnapshot(provider: .anthropic, windows: windows, fetchedAt: fetchedAt)
    }

    private static func appendLegacyWindow(
        key: String,
        kind: QuotaWindowKind,
        root: [String: Any],
        to windows: inout [QuotaWindow]
    ) {
        guard !windows.contains(where: { $0.kind == kind }),
              let value = root[key] as? [String: Any],
              let usedPercent = QuotaDateParser.number(value["utilization"]) else {
            return
        }
        windows.append(QuotaWindow(
            kind: kind,
            usedPercent: usedPercent,
            resetsAt: optionalDate(value["resets_at"])
        ))
    }

    private static func appendIfMissing(_ window: QuotaWindow, to windows: inout [QuotaWindow]) {
        guard !windows.contains(where: { $0.kind == window.kind }) else { return }
        windows.append(window)
    }

    private static func scopeName(_ limit: [String: Any]) -> String {
        guard let scope = limit["scope"] as? [String: Any],
              let model = scope["model"] as? [String: Any],
              let displayName = model["display_name"] as? String else {
            return ""
        }
        return displayName
    }

    private static func optionalDate(_ value: Any?) -> Date? {
        guard !(value is NSNull) else { return nil }
        return QuotaDateParser.iso8601(value)
    }
}
