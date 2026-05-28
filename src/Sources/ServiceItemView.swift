import SwiftUI
import Foundation
import Inject

struct ServiceItemView: View {
    @ObserveInjection var inject
    let serviceId: String
    let serviceName: String
    let iconName: String
    let isAuthenticated: Bool
    let email: String?
    let isExpired: Bool
    let isAuthenticating: Bool
    let onConnect: () -> Void
    let onDisconnect: () -> Void
    let onReconnect: () -> Void
    let onFetchModels: (() -> Void)?  // Callback to fetch models when expanded
    
    @State private var isExpanded = false
    @State private var models: [ServiceModel] = []
    @State private var isLoadingModels = false
    @State private var hasLoadedModels = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Service icon
                if let nsImage = IconCatalog.shared.image(named: iconName, resizedTo: NSSize(width: 20, height: 20), template: true) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .renderingMode(.template)
                        .frame(width: 20, height: 20)
                }
                
                // Service info
                VStack(alignment: .leading, spacing: 2) {
                    Text(serviceName)
                        .fontWeight(.semibold)
                    if isAuthenticated {
                        Text(email ?? "Connected")
                            .font(.caption2)
                            .foregroundColor(isExpired ? .red : .green)
                        if isExpired {
                            Text("(expired)")
                                .font(.caption2)
                                .foregroundColor(.red)
                        }
                    } else {
                        Text("Not connected")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Models count badge or loading indicator
                if isLoadingModels {
                    ProgressView()
                        .controlSize(.small)
                } else if !models.isEmpty {
                    Text("\(models.count) models")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Expand/collapse chevron
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Auth buttons
                if isAuthenticating {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    if isAuthenticated {
                        if isExpired {
                            Button("Reconnect", action: onReconnect)
                                .font(.caption)
                        } else {
                            Button("Disconnect", action: onDisconnect)
                                .font(.caption)
                        }
                    } else {
                        Button("Connect", action: onConnect)
                            .font(.caption)
                    }
                }
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .onTapGesture {
                if !isLoadingModels {
                    withAnimation {
                        isExpanded.toggle()
                        if isExpanded && models.isEmpty {
                            loadModels()
                        }
                    }
                }
            }
            
            // Expanded models list
            if isExpanded {
                Divider()
                    .padding(.vertical, 4)
                
                if isLoadingModels {
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                        Text("Loading models...")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 12)
                } else if !models.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(models, id: \.name) { model in
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text(model.displayName)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                        Spacer()
                                        Text(model.name)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                            .truncationMode(.tail)
                                    }
                                    
                                    if let description = model.description {
                                        Text(description)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .lineLimit(2)
                                    }
                                }
                                .padding(6)
                                .background(Color(.controlBackgroundColor))
                                .cornerRadius(4)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .frame(maxHeight: 200)
                } else if hasLoadedModels {
                    Text("No models available")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 12)
                }
            }
        }
        .padding(.vertical, 4)
        .enableInjection()
    }

    private func loadModels() {
        isLoadingModels = true
        models = [] // Clear existing models
        hasLoadedModels = false
        
        // Use CLI proxy API discovery directly
        discoverModelsFromCLI()
    }
    
    // Method to discover models from CLI proxy API
    private func discoverModelsFromCLI() {
        isLoadingModels = true
        models = []
        
        // Get the service type for model discovery
        let serviceType = getServiceType()
        
        // Call CLI proxy API to get available models
        CLIProxyAPI.shared.getAvailableModels(for: serviceType) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let modelList):
                    self.models = modelList.map { model in
                        ServiceModel(name: model.name, displayName: model.displayName, description: model.description)
                    }
                    self.isLoadingModels = false
                case .failure(let error):
                    print("Failed to load models for \(serviceType): \(error)")
                    self.isLoadingModels = false
                    // Set some fallback models for demonstration
                    self.models = [
                        ServiceModel(name: "default", displayName: "Default Model", description: "Fallback model")
                    ]
                }
            }
        }
    }
    
    private func getServiceType() -> String {
        return serviceId
    }
    
    // Public method to update models from parent view
    func updateModels(_ newModels: [ServiceModel]) {
        DispatchQueue.main.async {
            self.models = newModels
            self.isLoadingModels = false
            self.hasLoadedModels = true
        }
    }
    
    // Public method to reset model loading state
    func resetModelLoading() {
        DispatchQueue.main.async {
            self.isLoadingModels = false
            self.hasLoadedModels = false
            self.models = []
        }
    }
}

struct ServiceModel {
    let name: String
    let displayName: String
    let description: String?
    
    init(name: String, displayName: String? = nil, description: String? = nil) {
        self.name = name
        self.displayName = displayName ?? name
        self.description = description
    }
}

// Preview
#if DEBUG
struct ServiceItemView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            ServiceItemView(
                serviceId: "claude",
                serviceName: "Claude",
                iconName: "icon-claude.png",
                isAuthenticated: true,
                email: "user@example.com",
                isExpired: false,
                isAuthenticating: false,
                onConnect: {},
                onDisconnect: {},
                onReconnect: {},
                onFetchModels: nil
            )
            .padding()

            ServiceItemView(
                serviceId: "gemini",
                serviceName: "Gemini",
                iconName: "icon-gemini.png",
                isAuthenticated: false,
                email: nil,
                isExpired: false,
                isAuthenticating: false,
                onConnect: {},
                onDisconnect: {},
                onReconnect: {},
                onFetchModels: nil
            )
            .padding()
        }
        .previewLayout(.sizeThatFits)
    }
}
#endif
