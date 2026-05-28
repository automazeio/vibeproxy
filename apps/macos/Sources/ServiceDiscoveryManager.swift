import Foundation

// Manages dynamic service discovery with caching and periodic refresh
class ServiceDiscoveryManager: ObservableObject {
    @Published var services: [ServiceDiscoveryInfo] = []
    @Published var isLoading: Bool = false
    @Published var lastError: Error?
    @Published var lastUpdated: Date?
    
    private var refreshTimer: Timer?
    private var cacheExpiryTime: Date?
    private let cacheTTL: TimeInterval = 3600 // 1 hour in seconds
    private let refreshInterval: TimeInterval = 300 // 5 minutes
    
    static let shared = ServiceDiscoveryManager()
    
    private init() {
        // Start background refresh
        startPeriodicRefresh()
    }
    
    deinit {
        stopPeriodicRefresh()
    }
    
    /// Fetch services from the API (with caching)
    func discoverServices(forceRefresh: Bool = false, completion: @escaping () -> Void) {
        // Check if we have valid cached data and it's not being forced to refresh
        if !forceRefresh && !services.isEmpty && isCacheValid() {
            completion()
            return
        }
        
        isLoading = true
        lastError = nil
        
        CLIProxyAPI.shared.getAvailableServices { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success(let discoveredServices):
                    self?.services = discoveredServices.sorted { $0.id < $1.id }
                    self?.cacheExpiryTime = Date().addingTimeInterval(self?.cacheTTL ?? 3600)
                    self?.lastUpdated = Date()
                    self?.lastError = nil
                    completion()
                    
                case .failure(let error):
                    // Keep using previous services if discovery fails
                    if self?.services.isEmpty ?? true {
                        // If no cached services, show the error
                        self?.lastError = error
                        NSLog("[ServiceDiscovery] Failed to discover services: %@", error.localizedDescription)
                    } else {
                        // If we have cached services, log silently
                        NSLog("[ServiceDiscovery] Failed to refresh services (using cache): %@", error.localizedDescription)
                    }
                    completion()
                }
            }
        }
    }
    
    /// Get service by ID
    func getService(id: String) -> ServiceDiscoveryInfo? {
        return services.first { $0.id == id }
    }
    
    /// Check if a service is available
    func isServiceAvailable(id: String) -> Bool {
        return services.contains { $0.id == id && $0.available }
    }
    
    /// Get count of available services
    var availableServiceCount: Int {
        return services.filter { $0.available }.count
    }
    
    /// Start periodic refresh
    private func startPeriodicRefresh() {
        stopPeriodicRefresh()
        
        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            self?.discoverServices(forceRefresh: false) {
                // Silent refresh - no need to do anything
            }
        }
    }
    
    /// Stop periodic refresh
    private func stopPeriodicRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    /// Check if cache is still valid
    private func isCacheValid() -> Bool {
        guard let expiryTime = cacheExpiryTime else {
            return false
        }
        return Date() < expiryTime
    }
    
    /// Clear cache
    func clearCache() {
        services = []
        cacheExpiryTime = nil
        lastUpdated = nil
        lastError = nil
    }
    
    /// Force refresh services
    func forceRefresh(completion: @escaping () -> Void) {
        discoverServices(forceRefresh: true, completion: completion)
    }
}
