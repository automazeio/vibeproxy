import SwiftUI
import AppKit

struct GrokLoginSheet: View {
    @ObservedObject var login: GrokLoginController
    let retry: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var browserError = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sign in to Grok Build").font(.headline)
            switch login.state {
            case .starting:
                ProgressView("Requesting a device code…")
            case .awaitingAuthorization(let url, let code):
                Text("Complete sign-in in your browser. If prompted, enter this code:")
                if let code {
                    Text(code)
                        .font(.title2.monospaced())
                        .textSelection(.enabled)
                        .accessibilityLabel("Device code: \(code)")
                    Button("Copy Code") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(code, forType: .string)
                    }
                }
                if let url {
                    Text(url.absoluteString)
                        .font(.caption)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Open Browser") {
                        browserError = !NSWorkspace.shared.open(url)
                    }
                }
                if browserError {
                    Text("Could not open a browser. Copy the link above into your browser.")
                        .foregroundColor(.secondary)
                }
                ProgressView("Waiting for authorization…")
            case .authenticated(let account):
                Label("Connected as \(account)", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .failed(let message):
                Text(message).foregroundColor(.red)
            case .cancelled:
                Text("Sign-in cancelled.")
            }
            HStack {
                Spacer()
                if login.state.isActive {
                    Button("Cancel", role: .cancel) {
                        login.cancel()
                        dismiss()
                    }
                } else {
                    if case .authenticated = login.state {
                        Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
                    } else {
                        Button("Close", role: .cancel) { dismiss() }
                        Button("Try Again") {
                            browserError = false
                            retry()
                        }.keyboardShortcut(.defaultAction)
                    }
                }
            }
        }
        .padding(24)
        .frame(width: 440)
        .interactiveDismissDisabled(login.state.isActive)
    }
}
