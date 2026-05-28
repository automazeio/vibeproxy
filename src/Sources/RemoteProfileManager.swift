import Foundation
import Combine

// MARK: - Remote Profile

struct RemoteProfile: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var host: String
    var port: Int
    var isDefault: Bool
    var lastConnected: Date?
    
    init(id: UUID = UUID(), name: String, host: String, port: Int = 8000, isDefault: Bool = false) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.isDefault = isDefault
        self.lastConnected = nil
    }
    
    var endpoint: String {
        "http://\(host):\(port)"
    }
}

// MARK: - Connection Status

enum ConnectionStatus {
    case disconnected
    case connecting
    case connected
    case error(String)
    
    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
}

// MARK: - Remote Profile Manager

class RemoteProfileManager: ObservableObject {
    static let shared = RemoteProfileManager()
    
    @Published var profiles: [RemoteProfile] = []
    @Published var activeProfile: RemoteProfile?
    @Published var connectionStatus: ConnectionStatus = .disconnected
    
    private let profilesPath: URL
    private var healthCheckTimer: Timer?
    
    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let configDir = appSupport.appendingPathComponent("VibeProxy", isDirectory: true)
        try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
        profilesPath = configDir.appendingPathComponent("remote-profiles.json")
        
        loadProfiles()
    }
    
    // MARK: - Persistence
    
    private func loadProfiles() {
        guard let data = try? Data(contentsOf: profilesPath),
              let loaded = try? JSONDecoder().decode([RemoteProfile].self, from: data) else {
            // Add default local profile
            profiles = [
                RemoteProfile(name: "Local", host: "127.0.0.1", port: 8000, isDefault: true)
            ]
            saveProfiles()
            return
        }
        profiles = loaded
        
        // Set active profile to default
        if let defaultProfile = profiles.first(where: { $0.isDefault }) {
            activeProfile = defaultProfile
        }
    }
    
    private func saveProfiles() {
        if let data = try? JSONEncoder().encode(profiles) {
            try? data.write(to: profilesPath)
        }
    }
    
    // MARK: - CRUD Operations
    
    func addProfile(_ profile: RemoteProfile) {
        var newProfile = profile
        if profiles.isEmpty {
            newProfile.isDefault = true
        }
        profiles.append(newProfile)
        saveProfiles()
    }
    
    func updateProfile(_ profile: RemoteProfile) {
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index] = profile
            if activeProfile?.id == profile.id {
                activeProfile = profile
            }
            saveProfiles()
        }
    }
    
    func deleteProfile(_ profile: RemoteProfile) {
        profiles.removeAll { $0.id == profile.id }
        if activeProfile?.id == profile.id {
            disconnect()
            activeProfile = profiles.first
        }
        saveProfiles()
    }
    
    func setDefaultProfile(_ profile: RemoteProfile) {
        for i in profiles.indices {
            profiles[i].isDefault = profiles[i].id == profile.id
        }
        saveProfiles()
    }
    
    // MARK: - Connection Management
    
    func connect(to profile: RemoteProfile, completion: @escaping (Bool) -> Void) {
        connectionStatus = .connecting
        activeProfile = profile
        
        // Test connection
        testConnection(to: profile) { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    self?.connectionStatus = .connected
                    self?.startHealthCheck()
                    
                    // Update last connected
                    if var updated = self?.profiles.first(where: { $0.id == profile.id }) {
                        updated.lastConnected = Date()
                        self?.updateProfile(updated)
                    }
                } else {
                    self?.connectionStatus = .error(error ?? "Connection failed")
                }
                completion(success)
            }
        }
    }
    
    func disconnect() {
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil
        connectionStatus = .disconnected
    }

    // MARK: - Health Check

    private func startHealthCheck() {
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            guard let profile = self?.activeProfile else { return }
            self?.testConnection(to: profile) { success, _ in
                DispatchQueue.main.async {
                    if !success {
                        self?.connectionStatus = .error("Connection lost")
                    }
                }
            }
        }
    }

    func testConnection(to profile: RemoteProfile, completion: @escaping (Bool, String?) -> Void) {
        let url = URL(string: "\(profile.endpoint)/health")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 5.0

        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                completion(false, error.localizedDescription)
                return
            }

            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            if statusCode == 200 {
                completion(true, nil)
            } else {
                completion(false, "Server returned status \(statusCode)")
            }
        }.resume()
    }
}

