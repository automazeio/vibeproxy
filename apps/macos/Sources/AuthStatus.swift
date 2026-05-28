import Foundation

struct AuthStatus {
    var isAuthenticated: Bool
    var email: String?
    var type: String
    var expired: Date?

    var isExpired: Bool {
        guard let expired = expired else { return false }
        return expired < Date()
    }

    var statusText: String {
        if !isAuthenticated {
            return "Not Connected"
        } else if isExpired {
            return "Expired - Reconnect Required"
        } else if let email = email {
            return "Connected as \(email)"
        } else {
            return "Connected"
        }
    }
}

class AuthManager: ObservableObject {
    @Published var authStatuses: [String: AuthStatus] = [:]

    func checkAuthStatus() {
        let authDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".cli-proxy-api")

        var foundServices: [String: AuthStatus] = [:]

        // Check for auth files
        do {
            let files = try FileManager.default.contentsOfDirectory(at: authDir, includingPropertiesForKeys: nil)
            NSLog("[AuthStatus] Scanning %d files in auth directory", files.count)

            for file in files where file.pathExtension == "json" {
                NSLog("[AuthStatus] Checking file: %@", file.lastPathComponent)
                if let data = try? Data(contentsOf: file),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let type = json["type"] as? String {
                    NSLog("[AuthStatus] Found type '%@' in %@", type, file.lastPathComponent)

                    let email = json["email"] as? String
                    var expiredDate: Date?

                    if let expiredStr = json["expired"] as? String {
                        let formatter = ISO8601DateFormatter()
                        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                        expiredDate = formatter.date(from: expiredStr)
                    }

                    let status = AuthStatus(
                        isAuthenticated: true,
                        email: email,
                        type: type,
                        expired: expiredDate
                    )

                    let serviceKey = type.lowercased()
                    foundServices[serviceKey] = status
                    NSLog("[AuthStatus] Found auth for service '%@': %@", serviceKey, email ?? "unknown")
                }
            }

            // Update with discovered services
            DispatchQueue.main.async {
                self.authStatuses = foundServices
                NSLog("[AuthStatus] Auth status check complete. Found %d authenticated services", foundServices.count)
            }
        } catch {
            NSLog("[AuthStatus] Error checking auth status: %@", error.localizedDescription)
            DispatchQueue.main.async {
                self.authStatuses = [:]
            }
        }
    }

    /// Get auth status for a specific service
    func getStatus(for serviceId: String) -> AuthStatus? {
        return authStatuses[serviceId.lowercased()]
    }

    /// Check if a service is authenticated
    func isAuthenticated(serviceId: String) -> Bool {
        return getStatus(for: serviceId)?.isAuthenticated ?? false
    }

    /// Get email for a service
    func getEmail(for serviceId: String) -> String? {
        return getStatus(for: serviceId)?.email
    }

    /// Check if a service's auth is expired
    func isExpired(serviceId: String) -> Bool {
        return getStatus(for: serviceId)?.isExpired ?? false
    }
}
