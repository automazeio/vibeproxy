import Foundation
import AppKit

class TunnelManager {
    private var process: Process?
    private(set) var isRunning = false
    private(set) var publicURL: String?
    private let urlFoundLock = NSLock()
    
    func start(port: Int, completion: @escaping (Bool, String?) -> Void) {
        guard !isRunning else {
            completion(true, publicURL)
            return
        }
        
        // Check if cloudflared is installed
        let cloudflaredPaths = [
            "/usr/local/bin/cloudflared",
            "/opt/homebrew/bin/cloudflared",
            "/usr/bin/cloudflared"
        ]
        
        var cloudflaredPath: String?
        for path in cloudflaredPaths {
            if FileManager.default.fileExists(atPath: path) {
                cloudflaredPath = path
                break
            }
        }
        
        // If not found, try using 'which'
        if cloudflaredPath == nil {
            let whichProcess = Process()
            whichProcess.executableURL = URL(fileURLWithPath: "/usr/bin/which")
            whichProcess.arguments = ["cloudflared"]
            
            let pipe = Pipe()
            whichProcess.standardOutput = pipe
            
            do {
                try whichProcess.run()
                whichProcess.waitUntilExit()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !path.isEmpty {
                    cloudflaredPath = path
                }
            } catch {
                NSLog("[TunnelManager] Failed to locate cloudflared: %@", error.localizedDescription)
            }
        }
        
        guard let execPath = cloudflaredPath else {
            // Cloudflared not installed, provide instructions
            DispatchQueue.main.async {
                self.showCloudflaredInstallInstructions()
            }
            completion(false, nil)
            return
        }
        
        process = Process()
        process?.executableURL = URL(fileURLWithPath: execPath)
        process?.arguments = ["tunnel", "--url", "http://localhost:\(port)"]
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process?.standardOutput = outputPipe
        process?.standardError = errorPipe
        
        // Parse output for URL with thread-safe flag
        var urlFound = false
        
        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            guard let self = self else { return }
            let data = handle.availableData
            if let output = String(data: data, encoding: .utf8) {
                // Look for the tunnel URL
                if let range = output.range(of: "https://[a-zA-Z0-9-]+\\.trycloudflare\\.com", options: .regularExpression) {
                    let url = String(output[range])
                    self.urlFoundLock.lock()
                    let shouldComplete = !urlFound
                    if shouldComplete { urlFound = true }
                    self.urlFoundLock.unlock()
                    
                    DispatchQueue.main.async {
                        self.publicURL = url
                        if shouldComplete {
                            completion(true, url)
                        }
                        NotificationCenter.default.post(name: .serverStatusChanged, object: nil)
                    }
                }
            }
        }
        
        errorPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            guard let self = self else { return }
            let data = handle.availableData
            if let output = String(data: data, encoding: .utf8) {
                // Also check stderr for URL
                if let range = output.range(of: "https://[a-zA-Z0-9-]+\\.trycloudflare\\.com", options: .regularExpression) {
                    let url = String(output[range])
                    self.urlFoundLock.lock()
                    let shouldComplete = !urlFound
                    if shouldComplete { urlFound = true }
                    self.urlFoundLock.unlock()
                    
                    DispatchQueue.main.async {
                        self.publicURL = url
                        if shouldComplete {
                            completion(true, url)
                        }
                        NotificationCenter.default.post(name: .serverStatusChanged, object: nil)
                    }
                }
            }
        }
        
        process?.terminationHandler = { [weak self] _ in
            // Clear pipe handlers to prevent memory leaks
            outputPipe.fileHandleForReading.readabilityHandler = nil
            errorPipe.fileHandleForReading.readabilityHandler = nil
            
            DispatchQueue.main.async {
                self?.isRunning = false
                self?.publicURL = nil
                NotificationCenter.default.post(name: .serverStatusChanged, object: nil)
            }
        }
        
        do {
            try process?.run()
            isRunning = true
            
            // Timeout if URL not found in 10 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
                if !urlFound {
                    completion(false, nil)
                }
            }
        } catch {
            completion(false, nil)
        }
    }
    
    func stop() {
        guard isRunning else { return }
        
        process?.terminate()
        process = nil
        isRunning = false
        publicURL = nil
        
        NotificationCenter.default.post(name: .serverStatusChanged, object: nil)
    }
    
    private func showCloudflaredInstallInstructions() {
        let alert = NSAlert()
        alert.messageText = "Cloudflared Not Installed"
        alert.informativeText = """
        To expose your server to the internet, you need to install cloudflared.
        
        Install via Homebrew:
        brew install cloudflared
        
        Or download from:
        https://github.com/cloudflare/cloudflared/releases
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Copy Install Command")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString("brew install cloudflared", forType: .string)
        }
    }
}
