import Foundation

/// The CLI flag surface of the bundled CLIProxyAPI backend, parsed from its
/// `--help` output. Login flows use this to adapt to backend builds that
/// dropped providers' OAuth flows (issues #351, #457, #396).
struct BackendCapabilities {
    /// Flag names (without leading dashes) defined by the backend's CLI.
    let definedFlags: Set<String>

    init(helpOutput: String) {
        self.definedFlags = BackendCapabilities.parseDefinedFlagNames(inHelpOutput: helpOutput)
    }

    /// Whether the backend defines the given flag (dashless name).
    func defines(flag: String) -> Bool {
        definedFlags.contains(flag)
    }

    /// Extracts flag names from Go's standard flag usage output, e.g.
    /// `  -codex-login` or `  -config string`. Flag lines start with a dash;
    /// prose lines (version banner, "Usage of ...") do not.
    static func parseDefinedFlagNames(inHelpOutput output: String) -> Set<String> {
        var names = Set<String>()
        for line in output.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("-") else { continue }
            let token = trimmed.prefix { !$0.isWhitespace }
            let name = token.drop(while: { $0 == "-" })
            guard !name.isEmpty else { continue }
            names.insert(String(name))
        }
        return names
    }
}
