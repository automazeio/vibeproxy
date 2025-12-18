import SwiftUI
import AppKit

/// Presents the model catalog in its own key-capable window to avoid sheet focus issues.
enum ModelCatalogWindow {
    private static var window: NSWindow?

    static func show() {
        // Reuse window if already open
        if let win = window {
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let contentView = ModelCatalogView()

        let hosting = NSHostingController(rootView: contentView)
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        win.center()
        win.title = "Available Models"
        win.contentViewController = hosting
        win.isReleasedWhenClosed = false
        win.level = .floating

        window = win
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: win, queue: .main) { _ in
            if window === win {
                window = nil
            }
        }
    }
}
