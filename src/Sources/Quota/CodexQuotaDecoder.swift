import Foundation

enum CodexQuotaDecoder {
    static func decode(_ data: Data, fetchedAt: Date) throws -> QuotaSnapshot {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rateLimit = root["rate_limit"] as? [String: Any] else {
            throw QuotaFailure.invalidResponse
        }

        var windows: [QuotaWindow] = []
        appendWindow(key: "primary_window", fallbackKind: .fiveHour, from: rateLimit, to: &windows)
        appendWindow(key: "secondary_window", fallbackKind: .weekly, from: rateLimit, to: &windows)

        guard !windows.isEmpty else {
            throw QuotaFailure.invalidResponse
        }

        return QuotaSnapshot(
            provider: .openAI,
            windows: windows,
            fetchedAt: fetchedAt,
            resetCredits: resetAvailability(from: root)
        )
    }

    private static func appendWindow(
        key: String,
        fallbackKind: QuotaWindowKind,
        from rateLimit: [String: Any],
        to windows: inout [QuotaWindow]
    ) {
        guard let value = rateLimit[key] as? [String: Any],
              let usedPercent = QuotaDateParser.number(value["used_percent"]) else {
            return
        }
        let kind = windowKind(
            duration: QuotaDateParser.number(value["limit_window_seconds"]),
            fallback: fallbackKind
        )
        guard !windows.contains(where: { $0.kind == kind }) else { return }
        windows.append(QuotaWindow(
            kind: kind,
            usedPercent: usedPercent,
            resetsAt: QuotaDateParser.epoch(value["reset_at"] ?? value["resets_at"])
        ))
    }

    private static func windowKind(duration: Double?, fallback: QuotaWindowKind) -> QuotaWindowKind {
        guard let duration else { return fallback }
        if abs(duration - 18_000) < 1 { return .fiveHour }
        if abs(duration - 604_800) < 1 { return .weekly }
        return fallback
    }

    private static func resetAvailability(from root: [String: Any]) -> CodexResetAvailability? {
        guard let value = root["rate_limit_reset_credits"] as? [String: Any],
              let available = QuotaDateParser.number(value["available_count"]) else {
            return nil
        }
        let applicable = QuotaDateParser.number(value["applicable_available_count"]) ?? 0
        return CodexResetAvailability(
            availableCount: max(0, Int(available)),
            applicableAvailableCount: max(0, Int(applicable))
        )
    }
}
