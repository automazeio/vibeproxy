import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var serverManager: ServerManager
    @StateObject private var authManager = AuthManager()
    @State private var launchAtLogin = false
    @State private var isAuthenticatingClaude = false
    @State private var isAuthenticatingCodex = false
    @State private var isAuthenticatingGemini = false
    @State private var isAuthenticatingQwen = false
    @State private var showingAuthResult = false
    @State private var authResultMessage = ""
    @State private var authResultSuccess = false
    @State private var fileMonitor: DispatchSourceFileSystemObject?
    @State private var showingQwenEmailPrompt = false
    @State private var qwenEmail = ""
    
    private enum DisconnectTiming {
        static let serverRestartDelay: TimeInterval = 0.3
    }

    // Get app version from Info.plist
    private var appVersion: String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            return "v\(version)"
        }
        return ""
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    HStack {
                        Text("Server status")
                        Spacer()
                        Button(action: {
                            if serverManager.isRunning {
                                serverManager.stop()
                            } else {
                                serverManager.start { _ in }
                            }
                        }) {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(serverManager.isRunning ? Color.green : Color.red)
                                    .frame(width: 8, height: 8)
                                Text(serverManager.isRunning ? "Running" : "Stopped")
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section {
                    Toggle("Launch at login", isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { newValue in
                            toggleLaunchAtLogin(newValue)
                        }

                    HStack {
                        Text("Auth files")
                        Spacer()
                        Button("Open Folder") {
                            openAuthFolder()
                        }
                    }
                }

                Section("Services") {
                HStack {
                    if let nsImage = IconCatalog.shared.image(named: "icon-claude.png", resizedTo: NSSize(width: 20, height: 20), template: true) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .renderingMode(.template)
                            .frame(width: 20, height: 20)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Claude Code")
                        if authManager.claudeStatus.isAuthenticated {
                            Text(authManager.claudeStatus.email ?? "Connected")
                                .font(.caption2)
                                .foregroundColor(authManager.claudeStatus.isExpired ? .red : .green)
                            if authManager.claudeStatus.isExpired {
                                Text("(expired)")
                                    .font(.caption2)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    Spacer()
                    if isAuthenticatingClaude {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        if authManager.claudeStatus.isAuthenticated {
                            if authManager.claudeStatus.isExpired {
                                Button("Reconnect") {
                                    connectClaudeCode()
                                }
                            } else {
                                Button("Disconnect") {
                                    disconnectClaudeCode()
                                }
                            }
                        } else {
                            Button("Connect") {
                                connectClaudeCode()
                            }
                        }
                    }
                }

                HStack {
                    if let nsImage = IconCatalog.shared.image(named: "icon-codex.png", resizedTo: NSSize(width: 20, height: 20), template: true) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .renderingMode(.template)
                            .frame(width: 20, height: 20)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Codex")
                        if authManager.codexStatus.isAuthenticated {
                            Text(authManager.codexStatus.email ?? "Connected")
                                .font(.caption2)
                                .foregroundColor(authManager.codexStatus.isExpired ? .red : .green)
                            if authManager.codexStatus.isExpired {
                                Text("(expired)")
                                    .font(.caption2)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    Spacer()
                    if isAuthenticatingCodex {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        if authManager.codexStatus.isAuthenticated {
                            if authManager.codexStatus.isExpired {
                                Button("Reconnect") {
                                    connectCodex()
                                }
                            } else {
                                Button("Disconnect") {
                                    disconnectCodex()
                                }
                            }
                        } else {
                            Button("Connect") {
                                connectCodex()
                            }
                        }
                    }
                }

                HStack {
                    if let nsImage = IconCatalog.shared.image(named: "icon-gemini.png", resizedTo: NSSize(width: 20, height: 20), template: true) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .renderingMode(.template)
                            .frame(width: 20, height: 20)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Gemini")
                        if authManager.geminiStatus.isAuthenticated {
                            Text(authManager.geminiStatus.email ?? "Connected")
                                .font(.caption2)
                                .foregroundColor(authManager.geminiStatus.isExpired ? .red : .green)
                            if authManager.geminiStatus.isExpired {
                                Text("(expired)")
                                    .font(.caption2)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    Spacer()
                    if isAuthenticatingGemini {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        if authManager.geminiStatus.isAuthenticated {
                            if authManager.geminiStatus.isExpired {
                                Button("Reconnect") {
                                    connectGemini()
                                }
                            } else {
                                Button("Disconnect") {
                                    disconnectGemini()
                                }
                            }
                        } else {
                            Button("Connect") {
                                connectGemini()
                            }
                        }
                    }
                }
                .help("⚠️ Note: If you're an existing Gemini user with multiple projects, authentication will use your default project. Set your desired project as default in Google AI Studio before connecting.")

                HStack {
                    if let nsImage = IconCatalog.shared.image(named: "icon-qwen.png", resizedTo: NSSize(width: 20, height: 20), template: true) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .renderingMode(.template)
                            .frame(width: 20, height: 20)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Qwen")
                        if authManager.qwenStatus.isAuthenticated {
                            Text(authManager.qwenStatus.email ?? "Connected")
                                .font(.caption2)
                                .foregroundColor(authManager.qwenStatus.isExpired ? .red : .green)
                            if authManager.qwenStatus.isExpired {
                                Text("(expired)")
                                    .font(.caption2)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    Spacer()
                    if isAuthenticatingQwen {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        if authManager.qwenStatus.isAuthenticated {
                            if authManager.qwenStatus.isExpired {
                                Button("Reconnect") {
                                    connectQwen()
                                }
                            } else {
                                Button("Disconnect") {
                                    disconnectQwen()
                                }
                            }
                        } else {
                            Button("Connect") {
                                connectQwen()
                            }
                        }
                    }
                }
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(true)

            Spacer()
                .frame(height: 12)

            // Footer outside Form
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Text("VibeProxy \(appVersion) was made possible thanks to")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Link("CLIProxyAPI", destination: URL(string: "https://github.com/router-for-me/CLIProxyAPI")!)
                        .font(.caption)
                        .underline()
                        .foregroundColor(.secondary)
                        .onHover { inside in
                            if inside {
                                NSCursor.pointingHand.push()
                            } else {
                                NSCursor.pop()
                            }
                        }
                    Text("|")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("License: MIT")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 4) {
                    Text("© 2025")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Link("Automaze, Ltd.", destination: URL(string: "https://automaze.io")!)
                        .font(.caption)
                        .underline()
                        .foregroundColor(.secondary)
                        .onHover { inside in
                            if inside {
                                NSCursor.pointingHand.push()
                            } else {
                                NSCursor.pop()
                            }
                        }
                    Text("All rights reserved.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Link("Report an issue", destination: URL(string: "https://github.com/automazeio/vibeproxy/issues")!)
                    .font(.caption)
                    .onHover { inside in
                        if inside {
                            NSCursor.pointingHand.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
            }
            .padding(.bottom, 12)
        }
        .frame(width: 480, height: 490)
        .sheet(isPresented: $showingQwenEmailPrompt) {
            VStack(spacing: 16) {
                Text("Qwen Account Email")
                    .font(.headline)
                Text("Enter your Qwen account email address")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("your.email@example.com", text: $qwenEmail)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 250)
                HStack(spacing: 12) {
                    Button("Cancel") {
                        showingQwenEmailPrompt = false
                        qwenEmail = ""
                    }
                    Button("Continue") {
                        showingQwenEmailPrompt = false
                        startQwenAuth(email: qwenEmail)
                    }
                    .disabled(qwenEmail.isEmpty)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(24)
            .frame(width: 350)
        }
        .onAppear {
            authManager.checkAuthStatus()
            checkLaunchAtLogin()
            startMonitoringAuthDirectory()
        }
        .onDisappear {
            stopMonitoringAuthDirectory()
        }
        .alert("Authentication Result", isPresented: $showingAuthResult) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(authResultMessage)
        }
    }

    private func openAuthFolder() {
        let authDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".cli-proxy-api")
        NSWorkspace.shared.open(authDir)
    }

    private func toggleLaunchAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to toggle launch at login: \(error)")
            }
        }
    }

    private func checkLaunchAtLogin() {
        if #available(macOS 13.0, *) {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    private func connectClaudeCode() {
        isAuthenticatingClaude = true
        NSLog("[SettingsView] Starting Claude Code authentication")

        serverManager.runAuthCommand(.claudeLogin) { success, output in
            NSLog("[SettingsView] Auth completed - success: %d, output: %@", success, output)
            DispatchQueue.main.async {
                self.isAuthenticatingClaude = false

                if success {
                    self.authResultSuccess = true
                    self.authResultMessage = "✓ Claude Code authenticated successfully!\n\nPlease complete the authentication in your browser, then the app will automatically detect your credentials."
                    self.showingAuthResult = true
                    // File monitor will automatically update the status
                } else {
                    self.authResultSuccess = false
                    self.authResultMessage = "Authentication failed. Please check if the browser opened and try again.\n\nDetails: \(output.isEmpty ? "No output from authentication process" : output)"
                    self.showingAuthResult = true
                }
            }
        }
    }

    private func disconnectClaudeCode() {
        isAuthenticatingClaude = true
        performDisconnect(for: "claude", serviceName: "Claude Code") { success, message in
            self.isAuthenticatingClaude = false
            self.authResultSuccess = success
            self.authResultMessage = message
            self.showingAuthResult = true
        }
    }

    private func connectCodex() {
        isAuthenticatingCodex = true
        NSLog("[SettingsView] Starting Codex authentication")

        serverManager.runAuthCommand(.codexLogin) { success, output in
            NSLog("[SettingsView] Auth completed - success: %d, output: %@", success, output)
            DispatchQueue.main.async {
                self.isAuthenticatingCodex = false

                if success {
                    self.authResultSuccess = true
                    self.authResultMessage = "✓ Codex authenticated successfully!\n\nPlease complete the authentication in your browser, then the app will automatically detect your credentials."
                    self.showingAuthResult = true
                    // File monitor will automatically update the status
                } else {
                    self.authResultSuccess = false
                    self.authResultMessage = "Authentication failed. Please check if the browser opened and try again.\n\nDetails: \(output.isEmpty ? "No output from authentication process" : output)"
                    self.showingAuthResult = true
                }
            }
        }
    }

    private func disconnectCodex() {
        isAuthenticatingCodex = true
        performDisconnect(for: "codex", serviceName: "Codex") { success, message in
            self.isAuthenticatingCodex = false
            self.authResultSuccess = success
            self.authResultMessage = message
            self.showingAuthResult = true
        }
    }

    private func connectGemini() {
        isAuthenticatingGemini = true
        NSLog("[SettingsView] Starting Gemini authentication")

        serverManager.runAuthCommand(.geminiLogin) { success, output in
            NSLog("[SettingsView] Auth completed - success: %d, output: %@", success, output)
            DispatchQueue.main.async {
                self.isAuthenticatingGemini = false

                if success {
                    self.authResultSuccess = true
                    self.authResultMessage = "✓ Gemini authenticated successfully!\n\nPlease complete the authentication in your browser, then the app will automatically detect your credentials.\n\n⚠️ Note: If you have multiple Gemini projects, the default project will be used. You can change your default project in Google AI Studio if needed."
                    self.showingAuthResult = true
                    // File monitor will automatically update the status
                } else {
                    self.authResultSuccess = false
                    self.authResultMessage = "Authentication failed. Please check if the browser opened and try again.\n\nDetails: \(output.isEmpty ? "No output from authentication process" : output)"
                    self.showingAuthResult = true
                }
            }
        }
    }

    private func disconnectGemini() {
        isAuthenticatingGemini = true
        performDisconnect(for: "gemini", serviceName: "Gemini") { success, message in
            self.isAuthenticatingGemini = false
            self.authResultSuccess = success
            self.authResultMessage = message
            self.showingAuthResult = true
        }
    }

    private func connectQwen() {
        showingQwenEmailPrompt = true
    }

    private func startQwenAuth(email: String) {
        isAuthenticatingQwen = true
        NSLog("[SettingsView] Starting Qwen authentication with email: %@", email)

        serverManager.runAuthCommand(.qwenLogin(email: email)) { success, output in
            NSLog("[SettingsView] Auth completed - success: %d, output: %@", success, output)
            DispatchQueue.main.async {
                self.isAuthenticatingQwen = false

                if success {
                    self.authResultSuccess = true
                    self.authResultMessage = "✓ Qwen authenticated successfully!\n\nPlease complete the authentication in your browser, then the app will automatically submit your email and detect your credentials."
                    self.showingAuthResult = true
                    // File monitor will automatically update the status
                } else {
                    self.authResultSuccess = false
                    self.authResultMessage = "Authentication failed. Please check if the browser opened and try again.\n\nDetails: \(output.isEmpty ? "No output from authentication process" : output)"
                    self.showingAuthResult = true
                }
            }
        }
    }

    private func disconnectQwen() {
        isAuthenticatingQwen = true
        performDisconnect(for: "qwen", serviceName: "Qwen") { success, message in
            self.isAuthenticatingQwen = false
            self.authResultSuccess = success
            self.authResultMessage = message
            self.showingAuthResult = true
        }
    }

    private func startMonitoringAuthDirectory() {
        let authDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".cli-proxy-api")

        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: authDir, withIntermediateDirectories: true)

        let fileDescriptor = open(authDir.path, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .delete, .rename],
            queue: DispatchQueue.main
        )

        let manager = authManager
        source.setEventHandler {
            // Refresh auth status when directory changes
            NSLog("[FileMonitor] Auth directory changed - refreshing status")
            manager.checkAuthStatus()
        }

        source.setCancelHandler {
            close(fileDescriptor)
        }

        source.resume()
        fileMonitor = source
    }

    private func stopMonitoringAuthDirectory() {
        fileMonitor?.cancel()
        fileMonitor = nil
    }

    private func performDisconnect(for serviceType: String, serviceName: String, completion: @escaping (Bool, String) -> Void) {
        let authDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".cli-proxy-api")
        let wasRunning = serverManager.isRunning
        let manager = serverManager

        let cleanupWork: () -> Void = {
            DispatchQueue.global(qos: .userInitiated).async {
                var disconnectResult: (Bool, String)
                
                do {
                    if let enumerator = FileManager.default.enumerator(
                        at: authDir,
                        includingPropertiesForKeys: [.isRegularFileKey],
                        options: [.skipsHiddenFiles]
                    ) {
                        var targetURL: URL?
                        
                        for case let fileURL as URL in enumerator {
                            guard fileURL.pathExtension == "json" else { continue }
                            
                            let data = try Data(contentsOf: fileURL, options: [.mappedIfSafe])
                            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                                  let type = json["type"] as? String,
                                  type.lowercased() == serviceType.lowercased() else {
                                continue
                            }
                            
                            targetURL = fileURL
                            break
                        }
                        
                        if let targetURL = targetURL {
                            try FileManager.default.removeItem(at: targetURL)
                            NSLog("[Disconnect] Deleted auth file: %@", targetURL.path)
                            disconnectResult = (true, "\(serviceName) disconnected successfully")
                        } else {
                            disconnectResult = (false, "No \(serviceName) credentials were found.")
                        }
                    } else {
                        disconnectResult = (false, "Unable to access credentials directory.")
                    }
                } catch {
                    disconnectResult = (false, "Failed to disconnect \(serviceName): \(error.localizedDescription)")
                }
                
                DispatchQueue.main.async {
                    completion(disconnectResult.0, disconnectResult.1)
                    if wasRunning {
                        DispatchQueue.main.asyncAfter(deadline: .now() + DisconnectTiming.serverRestartDelay) {
                            manager.start { _ in }
                        }
                    }
                }
            }
        }

        if wasRunning {
            serverManager.stop {
                cleanupWork()
            }
        } else {
            cleanupWork()
        }
    }
}

// Make managers observable
extension ServerManager: ObservableObject {}
