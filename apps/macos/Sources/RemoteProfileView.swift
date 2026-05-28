import SwiftUI

struct RemoteProfileView: View {
    @ObservedObject var profileManager: RemoteProfileManager
    @State private var showingAddProfile = false
    @State private var editingProfile: RemoteProfile?
    @State private var testingProfileId: UUID?
    @State private var testResult: (success: Bool, message: String)?
    
    var body: some View {
        Form {
            // Connection Status
            Section {
                HStack {
                    Text("Status")
                    Spacer()
                    connectionStatusView
                }
                
                if let profile = profileManager.activeProfile {
                    HStack {
                        Text("Active")
                        Spacer()
                        Text(profile.name)
                            .foregroundColor(.secondary)
                    }
                    
                    if profileManager.connectionStatus.isConnected {
                        Button("Disconnect") {
                            profileManager.disconnect()
                        }
                        .foregroundColor(.red)
                    }
                }
            } header: {
                Text("Connection")
            }
            
            // Profiles List
            Section {
                ForEach(profileManager.profiles) { profile in
                    profileRow(profile)
                }
                
                Button(action: { showingAddProfile = true }) {
                    Label("Add Profile", systemImage: "plus")
                }
            } header: {
                Text("Profiles")
            }
        }
        .formStyle(.grouped)
        .sheet(isPresented: $showingAddProfile) {
            ProfileEditSheet(
                profile: nil,
                onSave: { profile in
                    profileManager.addProfile(profile)
                    showingAddProfile = false
                },
                onCancel: { showingAddProfile = false }
            )
        }
        .sheet(item: $editingProfile) { profile in
            ProfileEditSheet(
                profile: profile,
                onSave: { updated in
                    profileManager.updateProfile(updated)
                    editingProfile = nil
                },
                onCancel: { editingProfile = nil }
            )
        }
    }
    
    // MARK: - Components
    
    private var connectionStatusView: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(statusText)
                .foregroundColor(statusColor)
        }
    }
    
    private var statusColor: Color {
        switch profileManager.connectionStatus {
        case .disconnected: return .gray
        case .connecting: return .orange
        case .connected: return .green
        case .error: return .red
        }
    }
    
    private var statusText: String {
        switch profileManager.connectionStatus {
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting..."
        case .connected: return "Connected"
        case .error(let msg): return msg
        }
    }
    
    private func profileRow(_ profile: RemoteProfile) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(profile.name)
                        .fontWeight(profile.isDefault ? .semibold : .regular)
                    if profile.isDefault {
                        Text("Default")
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.accentColor.opacity(0.2))
                            .cornerRadius(3)
                    }
                }
                Text("\(profile.host):\(profile.port)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if testingProfileId == profile.id {
                ProgressView()
                    .scaleEffect(0.6)
            }
            
            // Connect button
            if profileManager.activeProfile?.id != profile.id || !profileManager.connectionStatus.isConnected {
                Button("Connect") {
                    profileManager.connect(to: profile) { _ in }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            Menu {
                Button("Edit") {
                    editingProfile = profile
                }
                Button("Set as Default") {
                    profileManager.setDefaultProfile(profile)
                }
                Button("Test Connection") {
                    testConnection(profile)
                }
                Divider()
                Button("Delete", role: .destructive) {
                    profileManager.deleteProfile(profile)
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
        }
        .padding(.vertical, 4)
    }

    private func testConnection(_ profile: RemoteProfile) {
        testingProfileId = profile.id
        profileManager.testConnection(to: profile) { success, error in
            DispatchQueue.main.async {
                testingProfileId = nil
                testResult = (success, error ?? "Connection successful")
            }
        }
    }
}

// MARK: - Profile Edit Sheet

struct ProfileEditSheet: View {
    let profile: RemoteProfile?
    let onSave: (RemoteProfile) -> Void
    let onCancel: () -> Void

    @State private var name: String = ""
    @State private var host: String = ""
    @State private var port: String = "8000"

    var body: some View {
        VStack(spacing: 20) {
            Text(profile == nil ? "Add Profile" : "Edit Profile")
                .font(.headline)

            Form {
                TextField("Name", text: $name)
                TextField("Host", text: $host)
                TextField("Port", text: $port)
            }
            .formStyle(.grouped)
            .frame(height: 150)

            HStack {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.escape)

                Spacer()

                Button("Save") {
                    let p = RemoteProfile(
                        id: profile?.id ?? UUID(),
                        name: name,
                        host: host,
                        port: Int(port) ?? 8000,
                        isDefault: profile?.isDefault ?? false
                    )
                    onSave(p)
                }
                .keyboardShortcut(.return)
                .disabled(name.isEmpty || host.isEmpty)
            }
        }
        .padding()
        .frame(width: 350, height: 280)
        .onAppear {
            if let p = profile {
                name = p.name
                host = p.host
                port = String(p.port)
            }
        }
    }
}

#Preview {
    RemoteProfileView(profileManager: RemoteProfileManager.shared)
        .frame(width: 400, height: 500)
}

