import Foundation

enum CodexResetCreditDecoder {
    static func decodeCredits(_ data: Data) throws -> [CodexResetCredit] {
        let response: CreditsResponse
        do {
            response = try JSONDecoder().decode(CreditsResponse.self, from: data)
        } catch {
            throw QuotaFailure.invalidResponse
        }

        return response.credits.compactMap { credit in
            guard credit.status == "available",
                  credit.resetType == "codex_rate_limits",
                  !credit.id.isEmpty else {
                return nil
            }
            return CodexResetCredit(
                id: credit.id,
                title: credit.title?.nonEmpty ?? "Full reset",
                expiresAt: credit.expiresAt.flatMap { try? Date($0, strategy: .iso8601) }
            )
        }
    }

    static func decodeOutcome(_ data: Data) throws -> CodexResetOutcome {
        do {
            return try JSONDecoder().decode(ConsumeResponse.self, from: data).code
        } catch {
            throw QuotaFailure.invalidResponse
        }
    }

    private struct CreditsResponse: Decodable {
        let credits: [Credit]
    }

    private struct Credit: Decodable {
        let id: String
        let resetType: String
        let status: String
        let expiresAt: String?
        let title: String?

        private enum CodingKeys: String, CodingKey {
            case id
            case resetType = "reset_type"
            case status
            case expiresAt = "expires_at"
            case title
        }
    }

    private struct ConsumeResponse: Decodable {
        let code: CodexResetOutcome
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
