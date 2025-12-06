import SwiftUI
import ServiceManagement

/// A row displaying a service with its connected accounts and add button
struct ServiceRow: View {
    let serviceType: ServiceType
    let iconName: String
    let accounts: [AuthAccount]
    let isAuthenticating: Bool
    let helpText: String?
    let onConnect: () -> Void
    let onDisconnect: (AuthAccount) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if let nsImage = IconCatalog.shared.image(named: iconName, resizedTo: NSSize(width: 20, height: 20), template: true) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .renderingMode(.template)
                        .frame(width: 20, height: 20)
                }
                Text(serviceType.displayName)
                    .fontWeight(.medium)
                Spacer()
                if isAuthenticating {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Button("Add Account") {
                        onConnect()
                    }
                    .controlSize(.small)
                }
            }
            
            // Show connected accounts
            if !accounts.isEmpty {
                ForEach(accounts) { account in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(account.isExpired ? Color.orange : Color.green)
                            .frame(width: 6, height: 6)
                        Text(account.displayName)
                            .font(.caption)
                            .foregroundColor(account.isExpired ? .orange : .secondary)
                        if account.isExpired {
                            Text("(expired)")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                        Spacer()
                        Button("Remove") {
                            onDisconnect(account)
                        }
                        .font(.caption)
                        .controlSize(.small)
                    }
                    .padding(.leading, 28)
                }
                
                // Show account count summary
                let activeCount = accounts.filter { !$0.isExpired }.count
                if accounts.count > 1 {
                    Text("\(activeCount) active account\(activeCount == 1 ? "" : "s") • Auto-failover enabled")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.leading, 28)
                }
            } else {
                Text("No accounts connected")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 28)
            }
        }
        .padding(.vertical, 4)
        .help(helpText ?? "")
    }
}

struct SettingsView: View {
    @ObservedObject var serverManager: ServerManager
    @StateObject private var authManager = AuthManager()
    @State private var launchAtLogin = false
    @State private var authenticatingService: ServiceType? = nil
    @State private var showingAuthResult = false
    @State private var authResultMessage = ""
    @State private var authResultSuccess = false
    @State private var fileMonitor: DispatchSourceFileSystemObject?
    @State private var showingQwenEmailPrompt = false
    @State private var qwenEmail = ""
    
    private enum DisconnectTiming {
        static let serverRestartDelay: TimeInterval = 0.3
    }

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
                    ServiceRow(
                        serviceType: .antigravity,
                        iconName: "icon-antigravity.png",
                        accounts: authManager.accounts(for: .antigravity),
                        isAuthenticating: authenticatingService == .antigravity,
                        helpText: "Antigravity provides OAuth-based access to various AI models including Gemini and Claude. One login gives you access to multiple AI services.",
                        onConnect: { connectService(.antigravity) },
                        onDisconnect: { account in disconnectAccount(account) }
                    )
                    
                    ServiceRow(
                        serviceType: .claude,
                        iconName: "icon-claude.png",
                        accounts: authManager.accounts(for: .claude),
                        isAuthenticating: authenticatingService == .claude,
                        helpText: nil,
                        onConnect: { connectService(.claude) },
                        onDisconnect: { account in disconnectAccount(account) }
                    )
                    
                    ServiceRow(
                        serviceType: .codex,
                        iconName: "icon-codex.png",
                        accounts: authManager.accounts(for: .codex),
                        isAuthenticating: authenticatingService == .codex,
                        helpText: nil,
                        onConnect: { connectService(.codex) },
                        onDisconnect: { account in disconnectAccount(account) }
                    )
                    
                    ServiceRow(
                        serviceType: .copilot,
                        iconName: "icon-copilot.png",
                        accounts: authManager.accounts(for: .copilot),
                        isAuthenticating: authenticatingService == .copilot,
                        helpText: "GitHub Copilot provides access to Claude, GPT, Gemini and other models via your Copilot subscription.",
                        onConnect: { connectService(.copilot) },
                        onDisconnect: { account in disconnectAccount(account) }
                    )
                    
                    ServiceRow(
                        serviceType: .gemini,
                        iconName: "icon-gemini.png",
                        accounts: authManager.accounts(for: .gemini),
                        isAuthenticating: authenticatingService == .gemini,
                        helpText: "⚠️ Note: If you're an existing Gemini user with multiple projects, authentication will use your default project. Set your desired project as default in Google AI Studio before connecting.",
                        onConnect: { connectService(.gemini) },
                        onDisconnect: { account in disconnectAccount(account) }
                    )
                    
                    ServiceRow(
                        serviceType: .qwen,
                        iconName: "icon-qwen.png",
                        accounts: authManager.accounts(for: .qwen),
                        isAuthenticating: authenticatingService == .qwen,
                        helpText: nil,
                        onConnect: { showingQwenEmailPrompt = true },
                        onDisconnect: { account in disconnectAccount(account) }
                    )
                }
            }
            .formStyle(.grouped)

            Spacer()
                .frame(height: 12)

            // Footer
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
                            if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
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
                            if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                        }
                    Text("All rights reserved.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Link("Report an issue", destination: URL(string: "https://github.com/automazeio/vibeproxy/issues")!)
                    .font(.caption)
                    .onHover { inside in
                        if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                    }
            }
            .padding(.bottom, 12)
        }
        .frame(width: 480, height: 580)
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

    // MARK: - Actions
    
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
    
    private func connectService(_ serviceType: ServiceType) {
        authenticatingService = serviceType
        NSLog("[SettingsView] Starting %@ authentication", serviceType.displayName)
        
        let command: AuthCommand
        switch serviceType {
        case .claude: command = .claudeLogin
        case .codex: command = .codexLogin
        case .copilot: command = .copilotLogin
        case .gemini: command = .geminiLogin
        case .qwen:
            authenticatingService = nil
            return // handled separately with email prompt
        case .antigravity: command = .antigravityLogin
        }
        
        serverManager.runAuthCommand(command) { success, output in
            NSLog("[SettingsView] Auth completed - success: %d, output: %@", success, output)
            DispatchQueue.main.async {
                self.authenticatingService = nil
                
                if success {
                    self.authResultSuccess = true
                    self.authResultMessage = self.successMessage(for: serviceType)
                    self.showingAuthResult = true
                } else {
                    self.authResultSuccess = false
                    self.authResultMessage = "Authentication failed. Please check if the browser opened and try again.\n\nDetails: \(output.isEmpty ? "No output from authentication process" : output)"
                    self.showingAuthResult = true
                }
            }
        }
    }
    
    private func successMessage(for serviceType: ServiceType) -> String {
        switch serviceType {
        case .claude:
            return "✓ Claude Code authenticated successfully!\n\nPlease complete the authentication in your browser, then the app will automatically detect your credentials."
        case .codex:
            return "✓ Codex authenticated successfully!\n\nPlease complete the authentication in your browser, then the app will automatically detect your credentials."
        case .copilot:
            return "✓ GitHub Copilot authentication started!\n\nPlease visit github.com/login/device and enter the code shown in your terminal.\n\nℹ️ Copilot provides access to Claude, GPT, Gemini and other models."
        case .gemini:
            return "✓ Gemini authenticated successfully!\n\nPlease complete the authentication in your browser.\n\n⚠️ Note: If you have multiple projects, the default project will be used."
        case .qwen:
            return "✓ Qwen authenticated successfully!\n\nPlease complete the authentication in your browser."
        case .antigravity:
            return "✓ Antigravity authenticated successfully!\n\nPlease complete the authentication in your browser.\n\nℹ️ Antigravity provides unified access to multiple AI models."
        }
    }
    
    private func startQwenAuth(email: String) {
        authenticatingService = .qwen
        NSLog("[SettingsView] Starting Qwen authentication with email: %@", email)
        
        serverManager.runAuthCommand(.qwenLogin(email: email)) { success, output in
            NSLog("[SettingsView] Auth completed - success: %d, output: %@", success, output)
            DispatchQueue.main.async {
                self.authenticatingService = nil
                self.qwenEmail = ""
                
                if success {
                    self.authResultSuccess = true
                    self.authResultMessage = "✓ Qwen authenticated successfully!\n\nPlease complete the authentication in your browser."
                    self.showingAuthResult = true
                } else {
                    self.authResultSuccess = false
                    self.authResultMessage = "Authentication failed.\n\nDetails: \(output.isEmpty ? "No output" : output)"
                    self.showingAuthResult = true
                }
            }
        }
    }
    
    private func disconnectAccount(_ account: AuthAccount) {
        let wasRunning = serverManager.isRunning
        
        // Stop server, delete file, restart
        let cleanup = {
            if self.authManager.deleteAccount(account) {
                self.authResultSuccess = true
                self.authResultMessage = "✓ Removed \(account.displayName) from \(account.type.displayName)"
            } else {
                self.authResultSuccess = false
                self.authResultMessage = "Failed to remove account"
            }
            self.showingAuthResult = true
            
            if wasRunning {
                DispatchQueue.main.asyncAfter(deadline: .now() + DisconnectTiming.serverRestartDelay) {
                    self.serverManager.start { _ in }
                }
            }
        }
        
        if wasRunning {
            serverManager.stop { cleanup() }
        } else {
            cleanup()
        }
    }
    
    // MARK: - File Monitoring
    
    private func startMonitoringAuthDirectory() {
        let authDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".cli-proxy-api")
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
}

extension ServerManager: ObservableObject {}
