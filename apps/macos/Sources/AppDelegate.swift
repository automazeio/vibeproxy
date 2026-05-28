import Cocoa
import SwiftUI
import WebKit
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    var statusItem: NSStatusItem!
    var menu: NSMenu!
    var settingsWindow: NSWindow?
    var serverManager: ServerManager!
    var thinkingProxy: ThinkingProxy!
    private var _notificationCenter: UNUserNotificationCenter?
    
    private func getNotificationCenter() -> UNUserNotificationCenter? {
        if _notificationCenter != nil {
            return _notificationCenter
        }
        
        // Check if we're in a proper app bundle before accessing notification center
        // When running via `swift run`, we're not in a bundle and UNUserNotificationCenter.current() will crash
        // We check the executable path to see if we're running from .build/ (swift run) vs .app/ (proper bundle)
        let executablePath = ProcessInfo.processInfo.arguments.first ?? ""
        let isRunningFromBuild = executablePath.contains(".build/") || executablePath.contains("/CLIProxyMenuBar")
        
        guard !isRunningFromBuild else {
            NSLog("[Notifications] Running via swift run (path: %@) - notifications disabled", executablePath)
            return nil
        }
        
        // Only now try to get notification center
        // This will still crash if called outside bundle, but our check should prevent that
        _notificationCenter = UNUserNotificationCenter.current()
        return _notificationCenter
    }
    private var notificationPermissionGranted = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Setup menu bar
        setupMenuBar()

        // Initialize managers
        serverManager = ServerManager()
        thinkingProxy = ThinkingProxy()
        
        // Warm commonly used icons to avoid first-use disk hits
        preloadIcons()
        
        configureNotifications()

        // Start server automatically
        startServer()

        // Register for notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateMenuBarStatus),
            name: NSNotification.Name("ServerStatusChanged"),
            object: nil
        )
    }
    
    private func preloadIcons() {
        let statusIconSize = NSSize(width: 18, height: 18)
        let serviceIconSize = NSSize(width: 20, height: 20)
        
        let iconsToPreload = [
            ("icon-active.png", statusIconSize),
            ("icon-inactive.png", statusIconSize),
            ("icon-codex.png", serviceIconSize),
            ("icon-claude.png", serviceIconSize),
            ("icon-gemini.png", serviceIconSize)
        ]
        
        for (name, size) in iconsToPreload {
            if IconCatalog.shared.image(named: name, resizedTo: size, template: true) == nil {
                NSLog("[IconPreload] Warning: Failed to preload icon '%@'", name)
            }
        }
    }
    
    private func configureNotifications() {
        guard let center = getNotificationCenter() else {
            NSLog("[Notifications] Not available (not running in app bundle)")
            return
        }
        // Set delegate
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { [weak self] granted, error in
            if let error = error {
                NSLog("[Notifications] Authorization failed: %@", error.localizedDescription)
            }
            DispatchQueue.main.async {
                self?.notificationPermissionGranted = granted
                if !granted {
                    NSLog("[Notifications] Authorization not granted; notifications will be suppressed")
                }
            }
        }
    }

    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            if let icon = IconCatalog.shared.image(named: "icon-inactive.png", resizedTo: NSSize(width: 18, height: 18), template: true) {
                button.image = icon
            } else {
                let fallback = NSImage(systemSymbolName: "network.slash", accessibilityDescription: "VibeProxy")
                fallback?.isTemplate = true
                button.image = fallback
                NSLog("[MenuBar] Failed to load inactive icon from bundle; using fallback system icon")
            }
        }

        menu = NSMenu()

        // Server Status
        menu.addItem(NSMenuItem(title: "Server: Stopped", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        // Main Actions
        menu.addItem(NSMenuItem(title: "Open Settings", action: #selector(openSettings), keyEquivalent: "s"))
        menu.addItem(NSMenuItem.separator())

        // Server Control
        let startStopItem = NSMenuItem(title: "Start Server", action: #selector(toggleServer), keyEquivalent: "")
        startStopItem.tag = 100
        menu.addItem(startStopItem)

        menu.addItem(NSMenuItem.separator())

        // Copy URL
        let copyURLItem = NSMenuItem(title: "Copy Server URL", action: #selector(copyServerURL), keyEquivalent: "c")
        copyURLItem.isEnabled = false
        copyURLItem.tag = 102
        menu.addItem(copyURLItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))

        statusItem.menu = menu
    }



    @objc func openSettings() {
        if settingsWindow == nil {
            createSettingsWindow()
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func createSettingsWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 900),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "VibeProxy"
        window.center()

        let contentView = SettingsView(serverManager: serverManager)
        window.contentView = NSHostingView(rootView: contentView)

        settingsWindow = window
    }

    @objc func toggleServer() {
        if serverManager.isRunning {
            stopServer()
        } else {
            startServer()
        }
    }

    func startServer() {
        // Start the thinking proxy first (port 8317)
        thinkingProxy.start()
        
        // Poll for thinking proxy readiness with timeout
        pollForProxyReadiness(attempts: 0, maxAttempts: 60, intervalMs: 50)
    }
    
    private func pollForProxyReadiness(attempts: Int, maxAttempts: Int, intervalMs: Int) {
        // Check if proxy is running
        if thinkingProxy.isRunning {
            // Success - proceed to start backend
            serverManager.start { [weak self] success in
                DispatchQueue.main.async {
                    if success {
                        self?.updateMenuBarStatus()
                        // User always connects to 8317 (thinking proxy)
                        self?.showNotification(title: "Server Started", body: "VibeProxy is now running")
                    } else {
                        // Backend failed - stop the proxy to keep state consistent
                        self?.thinkingProxy.stop()
                        self?.showNotification(title: "Server Failed", body: "Could not start backend server on port 8318")
                    }
                }
            }
            return
        }
        
        // Check if we've exceeded timeout
        if attempts >= maxAttempts {
            DispatchQueue.main.async { [weak self] in
                // Clean up partially initialized proxy
                self?.thinkingProxy.stop()
                self?.showNotification(title: "Server Failed", body: "Could not start thinking proxy on port 8317 (timeout)")
            }
            return
        }
        
        // Schedule next poll
        let interval = Double(intervalMs) / 1000.0
        DispatchQueue.main.asyncAfter(deadline: .now() + interval) { [weak self] in
            self?.pollForProxyReadiness(attempts: attempts + 1, maxAttempts: maxAttempts, intervalMs: intervalMs)
        }
    }

    func stopServer() {
        // Stop the thinking proxy first to stop accepting new requests
        thinkingProxy.stop()
        
        // Then stop CLIProxyAPI backend
        serverManager.stop()
        
        updateMenuBarStatus()
    }

    @objc func copyServerURL() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString("http://localhost:\(thinkingProxy.proxyPort)", forType: .string)
        showNotification(title: "Copied", body: "Server URL copied to clipboard")
    }

    @objc func updateMenuBarStatus() {
        // Update status items
        if let serverStatus = menu.item(at: 0) {
            serverStatus.title = serverManager.isRunning ? "Server: Running (port \(thinkingProxy.proxyPort))" : "Server: Stopped"
        }

        // Update button states
        if let startStopItem = menu.item(withTag: 100) {
            startStopItem.title = serverManager.isRunning ? "Stop Server" : "Start Server"
        }

        if let copyURLItem = menu.item(withTag: 102) {
            copyURLItem.isEnabled = serverManager.isRunning
        }

        // Update icon based on server status
        if let button = statusItem.button {
            let iconName = serverManager.isRunning ? "icon-active.png" : "icon-inactive.png"
            let fallbackSymbol = serverManager.isRunning ? "network" : "network.slash"
            
            if let icon = IconCatalog.shared.image(named: iconName, resizedTo: NSSize(width: 18, height: 18), template: true) {
                button.image = icon
                NSLog("[MenuBar] Loaded %@ icon from cache", serverManager.isRunning ? "active" : "inactive")
            } else {
                let fallback = NSImage(systemSymbolName: fallbackSymbol, accessibilityDescription: serverManager.isRunning ? "Running" : "Stopped")
                fallback?.isTemplate = true
                button.image = fallback
                NSLog("[MenuBar] Failed to load %@ icon; using fallback", serverManager.isRunning ? "active" : "inactive")
            }
        }
    }

    func showNotification(title: String, body: String) {
        guard let center = getNotificationCenter() else {
            // Not in app bundle - just log
            NSLog("[Notifications] %@: %@", title, body)
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "io.automaze.vibeproxy.\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        
        center.add(request) { error in
            if let error = error {
                NSLog("[Notifications] Failed to deliver notification '%@': %@", title, error.localizedDescription)
            }
        }
    }

    @objc func quit() {
        // Stop server and wait for cleanup before quitting
        if serverManager.isRunning {
            thinkingProxy.stop()
            serverManager.stop()
        }
        // Give a moment for cleanup to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NSApp.terminate(nil)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("ServerStatusChanged"), object: nil)
        // Final cleanup - stop server if still running
        if serverManager.isRunning {
            thinkingProxy.stop()
            serverManager.stop()
        }
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // If server is running, stop it first
        if serverManager.isRunning {
            thinkingProxy.stop()
            serverManager.stop()
            // Give server time to stop (up to 3 seconds total with the improved stop method)
            return .terminateNow
        }
        return .terminateNow
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
