import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var serverManager: ServerManager
    @StateObject private var authManager = AuthManager()
    @StateObject private var serviceDiscoveryManager = ServiceDiscoveryManager.shared
    @StateObject private var modelManager = LocalModelManager.shared
    @State private var launchAtLogin = false
    @State private var showingAuthResult = false
    @State private var authResultMessage = ""
    @State private var authResultSuccess = false
    @State private var fileMonitor: DispatchSourceFileSystemObject?
    @State private var showingEmailPrompt = false
    @State private var promptedEmail = ""
    @State private var promptedServiceID = ""
    @State private var isAuthenticatingServiceID: String?
    @State private var showingSLMSettings = false
    
    private enum DisconnectTiming {
        static let serverRestartDelay: TimeInterval = 0.3
    }
    
    /// Get auth status for any service dynamically
    private func getAuthStatus(for serviceId: String) -> (isAuthenticated: Bool, email: String, isExpired: Bool) {
        // Check if it's a config-based service
        if serviceDiscoveryManager.services.first(where: { $0.id == serviceId })?.isConfigBased ?? false {
            return (true, "Local Configuration", false)
        }

        // Get from auth manager for API-based services
        if let status = authManager.getStatus(for: serviceId) {
            return (status.isAuthenticated, status.email ?? "", status.isExpired)
        }

        return (false, "", false)
    }

    /// Generic service action handler - works for any service dynamically
    private func handleServiceAction(_ action: String, for serviceId: String) {
        switch action {
        case "connect":
            initiateServiceAuth(serviceId)
        case "disconnect":
            performDisconnect(for: serviceId, serviceName: serviceId.capitalized) { _, _ in
                // Disconnect completed, status will be refreshed by file monitor
            }
        case "reconnect":
            initiateServiceAuth(serviceId)
        default:
            break
        }
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

                // Services Section - dynamically discovered
                Section("Services") {
                    if serviceDiscoveryManager.isLoading && serviceDiscoveryManager.services.isEmpty {
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Discovering services...")
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    } else if serviceDiscoveryManager.services.isEmpty {
                        Text("No services discovered. Make sure CLIProxyAPI is running.")
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding(.vertical, 8)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(serviceDiscoveryManager.services, id: \.id) { service in
                                ServiceItemView(
                                    serviceId: service.id,
                                    serviceName: service.displayName,
                                    iconName: service.icon ?? "icon-claude.png",
                                    isAuthenticated: {
                                        let status = getAuthStatus(for: service.id)
                                        return status.isAuthenticated || service.isConfigBased
                                    }(),
                                    email: {
                                        let status = getAuthStatus(for: service.id)
                                        return status.isAuthenticated ? status.email : (service.isConfigBased ? "Config-based" : "")
                                    }(),
                                    isExpired: getAuthStatus(for: service.id).isExpired,
                                    isAuthenticating: isAuthenticatingServiceID == service.id,
                                    onConnect: {
                                        isAuthenticatingServiceID = service.id
                                        handleServiceAction("connect", for: service.id)
                                    },
                                    onDisconnect: {
                                        handleServiceAction("disconnect", for: service.id)
                                    },
                                    onReconnect: {
                                        isAuthenticatingServiceID = service.id
                                        handleServiceAction("reconnect", for: service.id)
                                    },
                                    onFetchModels: {
                                        CLIProxyAPI.shared.getAvailableModels(for: service.id) { _ in
                                            // Models fetched - handled by ServiceItemView
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }

                // Local Models Section
                Section("Local Models") {
                    // Show active model instances by role
                    ForEach(ModelRole.allCases.filter { modelManager.getInstance(for: $0) != nil }) { role in
                        if let instance = modelManager.getInstance(for: role) {
                            let status = modelManager.statuses[instance.id]
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(status?.running == true ? Color.green : Color.gray)
                                            .frame(width: 8, height: 8)
                                        Text(role.displayName)
                                            .font(.headline)
                                    }
                                    Text(instance.model.components(separatedBy: "/").last ?? instance.model)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }

                                Spacer()

                                if status?.running == true {
                                    Text(":\(instance.port)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Button(action: {
                                    if status?.running == true {
                                        modelManager.stop(instance.id)
                                    } else {
                                        modelManager.start(instance.id) { _ in }
                                    }
                                }) {
                                    Image(systemName: status?.running == true ? "stop.fill" : "play.fill")
                                }
                                .buttonStyle(.borderless)
                            }
                            .padding(.vertical, 2)
                        }
                    }

                    // Settings button
                    HStack {
                        Spacer()
                        Button(action: { showingSLMSettings = true }) {
                            Label("Configure Models", systemImage: "gear")
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.vertical, 4)
                }
            }
            .formStyle(.grouped)
            // Removed .scrollDisabled(true) to allow Form scrolling

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
        .sheet(isPresented: $showingEmailPrompt) {
            VStack(spacing: 16) {
                Text(promptedServiceID.capitalized + " Account Email")
                    .font(.headline)
                Text("Enter your " + promptedServiceID.lowercased() + " account email address")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("your.email@example.com", text: $promptedEmail)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 250)
                HStack(spacing: 12) {
                    Button("Cancel") {
                        showingEmailPrompt = false
                        promptedEmail = ""
                    }
                    Button("Continue") {
                        showingEmailPrompt = false
                        completeServiceAuthWithEmail(promptedServiceID, email: promptedEmail)
                    }
                    .disabled(promptedEmail.isEmpty)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(24)
            .frame(width: 350)
        }
        .sheet(isPresented: $showingSLMSettings) {
            LocalModelSettingsView(modelManager: modelManager)
                .frame(width: 700, height: 600)
        }
        .onAppear {
            authManager.checkAuthStatus()
            checkLaunchAtLogin()
            startMonitoringAuthDirectory()
            
            // Discover services from CLIProxyAPI
            serviceDiscoveryManager.discoverServices(forceRefresh: true) {
                NSLog("[SettingsView] Service discovery completed")
            }
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

    /// Initiate authentication for any service
    private func initiateServiceAuth(_ serviceId: String) {
        isAuthenticatingServiceID = serviceId

        // Services that require email input
        if serviceId.lowercased() == "qwen" {
            showingEmailPrompt = true
            promptedServiceID = serviceId
            promptedEmail = ""
            return
        }

        // Services with local setup (config-based)
        if serviceDiscoveryManager.services.first(where: { $0.id == serviceId })?.isConfigBased ?? false {
            authResultMessage = "✓ \(serviceId) is configured locally and ready to use."
            showingAuthResult = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                isAuthenticatingServiceID = nil
            }
            return
        }

        // Generic OAuth flow for other services
        NSLog("[SettingsView] Starting authentication for service: %@", serviceId)
        CLIProxyAPI.shared.authenticateService(serviceId) { success, message in
            DispatchQueue.main.async {
                isAuthenticatingServiceID = nil
                authResultMessage = message ?? (success ? "✓ Authentication successful!" : "✗ Authentication failed")
                showingAuthResult = true
            }
        }
    }

    /// Complete service authentication with email
    private func completeServiceAuthWithEmail(_ serviceId: String, email: String) {
        NSLog("[SettingsView] Authenticating %@ with email: %@", serviceId, email)

        CLIProxyAPI.shared.authenticateService(serviceId) { success, message in
            DispatchQueue.main.async {
                isAuthenticatingServiceID = nil
                authResultMessage = message ?? (success ? "✓ Authentication successful!" : "✗ Authentication failed")
                showingAuthResult = true
                if success {
                    authManager.checkAuthStatus()
                }
            }
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
