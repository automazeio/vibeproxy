import SwiftUI

struct GatewaySettingsView: View {
    @State private var providers: [GatewayProvider] = []
    @State private var isLoading = true
    @State private var error: String?
    @State private var showAddSheet = false
    
    var body: some View {
        NavigationStack {
            VStack {
                if isLoading {
                    ProgressView("Loading providers...")
                } else if providers.isEmpty {
                    Text("No providers configured")
                        .foregroundColor(.secondary)
                } else {
                    List {
                        ForEach(providers) { provider in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(provider.name)
                                        .font(.headline)
                                    Spacer()
                                    Text(provider.type)
                                        .font(.caption)
                                        .padding(4)
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(4)
                                }
                                Text(provider.baseURL)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Gateway Providers")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showAddSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .onAppear {
                loadProviders()
            }
        }
    }
    
    private func loadProviders() {
        isLoading = true
        CLIProxyAPI.shared.fetchGatewayProviders { providers, error in
            self.providers = providers ?? []
            isLoading = false
        }
    }
}

#Preview {
    GatewaySettingsView()
}
