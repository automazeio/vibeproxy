import SwiftUI

struct RulePalette: View {
    @ObservedObject var viewModel: RulesViewModel
    @State private var searchText = ""
    @State private var selectedCategory: NodeCategory? = nil
    @State private var draggedNodeType: NodeType? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            searchBar
            
            // Category filters
            categoryFilters
            
            Divider()
            
            // Rule nodes list
            nodesList
        }
        .frame(minWidth: 200, idealWidth: 240)
        .frame(maxWidth: .infinity)
        .background(Color(.controlBackgroundColor))
        .onDrop(of: [.text], isTargeted: nil) { providers in
            handleDrop(providers: providers)
        }
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 14))
            
            TextField("Search rules...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(.quaternary)
        )
        .padding(8)
        .frame(maxWidth: .infinity)
    }
    
    private var categoryFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                // All categories
                CategoryChip(
                    title: "All",
                    isSelected: selectedCategory == nil,
                    color: .secondary,
                    action: { selectedCategory = nil }
                )
                
                // Individual categories
                ForEach(NodeCategory.allCases, id: \.self) { category in
                    CategoryChip(
                        title: category.rawValue,
                        isSelected: selectedCategory == category,
                        color: category.color,
                        action: { selectedCategory = category }
                    )
                }
            }
            .padding(.horizontal, 8)
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
    }
    
    private var nodesList: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(filteredNodeTypes, id: \.self) { nodeType in
                    RulePaletteItem(
                        nodeType: nodeType,
                        isDragged: draggedNodeType == nodeType,
                        onDragStart: {
                            draggedNodeType = nodeType
                            return createDragItem(for: nodeType)
                        },
                        onDragEnd: {
                            draggedNodeType = nil
                        }
                    )
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity)
        .clipped()
    }
    
    private var filteredNodeTypes: [NodeType] {
        var types = NodeType.allCases
        
        // Filter by category
        if let category = selectedCategory {
            types = types.filter { $0.defaultCategory == category }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            types = types.filter { nodeType in
                nodeType.defaultName.localizedCaseInsensitiveContains(searchText) ||
                nodeType.defaultDescription.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return types.sorted { lhs, rhs in
            lhs.defaultName.localizedCompare(rhs.defaultName) == .orderedAscending
        }
    }
    
    private func createDragItem(for nodeType: NodeType) -> NSItemProvider {
        let item = NSItemProvider()
        let data = try! JSONEncoder().encode(nodeType)
        item.registerDataRepresentation(forTypeIdentifier: "public.text", visibility: .all) { completion in
            completion(data, nil)
            return nil
        }
        return item
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        // Handle dropping nodes from palette to canvas
        return true
    }
}

// MARK: - Category Chip

struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                
                Text(title)
                    .font(.system(size: 11, weight: .medium))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? color.opacity(0.2) : Color.secondary.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? color.opacity(0.5) : .clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .foregroundColor(isSelected ? color : .primary)
    }
}

// MARK: - Rule Palette Item

struct RulePaletteItem: View {
    let nodeType: NodeType
    let isDragged: Bool
    let onDragStart: () -> NSItemProvider
    let onDragEnd: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 8) {
            // Category color indicator
            Rectangle()
                .fill(nodeType.defaultCategory.color)
                .frame(width: 3)
                .cornerRadius(1.5)
            
            // Icon
            Image(systemName: nodeType.icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(nodeType.defaultCategory.color)
                .frame(width: 20)
            
            // Node info
            VStack(alignment: .leading, spacing: 2) {
                Text(nodeType.defaultName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(nodeType.defaultDescription)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer()
            
            // Drag indicator
            if isDragged || isHovered {
                Image(systemName: "arrow.up.circle")
                    .font(.system(size: 12))
                    .foregroundColor(Color.secondary.opacity(0.6))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(.primary.opacity(isHovered ? 0.05 : 0.0))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(isHovered ? 0.5 : 0.2), lineWidth: 1)
                )
        )
        .contentShape(Rectangle())
        .scaleEffect(isDragged ? 0.95 : 1.0)
        .opacity(isDragged ? 0.7 : 1.0)
        .onDrag {
            onDragStart()
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .help("Drag to add to canvas")
    }
}

// MARK: - Rules ViewModel

@MainActor
class RulesViewModel: ObservableObject {
    @Published var ruleSet: RuleSet = RuleSet(name: "My Rules")
    @Published var selectedNodeId: String?
    @Published var selectedConnectionId: String?
    @Published var showConfigPanel: Bool = false
    @Published var showTestPanel: Bool = false
    
    // Computed properties for convenience
    var nodes: [RuleNode] { ruleSet.nodes }
    var connections: [RuleSet.Connection] { ruleSet.connections }
    
    // Observable wrapper for nodes
    @Published var observableNodes: [ObservableRuleNode] = []
    
    init() {
        updateObservableNodes()
        // Load saved rules if available
        loadRules()
    }
    
    // MARK: - Node Management
    
    func addNode(type: NodeType, at position: CGPoint) {
        let node = RuleNode(type: type, position: position)
        ruleSet.nodes.append(node)
        ruleSet.updateTimestamp()
        
        updateObservableNodes()
        
        // Auto-select new node
        selectedNodeId = node.id
        showConfigPanel = true
    }
    
    func deleteNode(_ nodeId: String) {
        // Remove connections to this node first
        ruleSet.connections.removeAll { connection in
            connection.fromNodeId == nodeId || connection.toNodeId == nodeId
        }
        
        // Remove the node
        ruleSet.nodes.removeAll { $0.id == nodeId }
        
        // Clear selection if this node was selected
        if selectedNodeId == nodeId {
            selectedNodeId = nil
            showConfigPanel = false
        }
        
        ruleSet.updateTimestamp()
        updateObservableNodes()
    }
    
    func duplicateNode(_ nodeId: String, keepConnections: Bool) {
        guard let originalNode = nodes.first(where: { $0.id == nodeId }) else { return }
        
        // Create new node with new ID and offset position
        let newPosition = CGPoint(
            x: originalNode.position.x + 40,
            y: originalNode.position.y + 40
        )
        var duplicateNode = RuleNode(
            type: originalNode.type,
            position: newPosition
        )
        duplicateNode.name = originalNode.name
        duplicateNode.description = originalNode.description
        duplicateNode.data = originalNode.data
        duplicateNode.isEnabled = originalNode.isEnabled
        duplicateNode.inputPorts = originalNode.inputPorts
        duplicateNode.outputPorts = originalNode.outputPorts
        
        ruleSet.nodes.append(duplicateNode)
        
        if keepConnections {
            // Duplicate connections too
            let connectionsToDuplicate = connections.filter { connection in
                connection.fromNodeId == nodeId || connection.toNodeId == nodeId
            }
            
            for connection in connectionsToDuplicate {
                let newConnection = RuleSet.Connection(
                    fromNodeId: connection.fromNodeId == nodeId ? duplicateNode.id : connection.fromNodeId,
                    fromPortId: connection.fromPortId,
                    toNodeId: connection.toNodeId == nodeId ? duplicateNode.id : connection.toNodeId,
                    toPortId: connection.toPortId
                )
                ruleSet.connections.append(newConnection)
            }
        }
        
        ruleSet.updateTimestamp()
        updateObservableNodes()
        
        // Select the duplicated node
        selectedNodeId = duplicateNode.id
    }
    
    func moveNode(_ nodeId: String, to position: CGPoint) {
        guard let index = ruleSet.nodes.firstIndex(where: { $0.id == nodeId }) else { return }
        ruleSet.nodes[index].position = position
        ruleSet.updateTimestamp()
    }
    
    func snapToGrid(_ nodeId: String) {
        guard let node = nodes.first(where: { $0.id == nodeId }) else { return }
        let gridSize: CGFloat = 20
        
        let snappedPosition = CGPoint(
            x: round(node.position.x / gridSize) * gridSize,
            y: round(node.position.y / gridSize) * gridSize
        )
        
        moveNode(nodeId, to: snappedPosition)
    }
    
    // MARK: - Connection Management
    
    func addConnection(from nodeId: String, fromPort: String, to toNodeId: String, toPort: String) {
        let newConnection = RuleSet.Connection(
            fromNodeId: nodeId,
            fromPortId: fromPort,
            toNodeId: toNodeId,
            toPortId: toPort
        )
        
        ruleSet.connections.append(newConnection)
        ruleSet.updateTimestamp()
    }
    
    func deleteConnection(_ connectionId: String) {
        ruleSet.connections.removeAll { $0.id == connectionId }
        ruleSet.updateTimestamp()
        
        if selectedConnectionId == connectionId {
            selectedConnectionId = nil
        }
    }
    
    // MARK: - Validation & Testing
    
    func validateRules() -> [RuleValidationError] {
        var errors: [RuleValidationError] = []
        
        // Check for orphaned connections
        for connection in connections {
            let fromNodeExists = nodes.contains { $0.id == connection.fromNodeId }
            let toNodeExists = nodes.contains { $0.id == connection.toNodeId }
            
            if !fromNodeExists {
                errors.append(RuleValidationError(
                    id: UUID().uuidString,
                    type: .orphanedConnection,
                    message: "Connection from missing node \(connection.fromNodeId)"
                ))
            }
            
            if !toNodeExists {
                errors.append(RuleValidationError(
                    id: UUID().uuidString,
                    type: .orphanedConnection,
                    message: "Connection to missing node \(connection.toNodeId)"
                ))
            }
        }
        
        // Check for trigger nodes (rule sets should start with triggers)
        let hasTrigger = nodes.contains { (node: RuleNode) in
            node.type.defaultCategory == NodeCategory.triggers
        }
        if !hasTrigger {
            errors.append(RuleValidationError(
                id: UUID().uuidString,
                type: .missingTrigger,
                message: "Rule set should start with a trigger node"
            ))
        }
        
        return errors
    }
    
    // MARK: - Serialization
    
    func saveRules() {
        if let data = try? JSONEncoder().encode(ruleSet),
           let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = documentsPath.appendingPathComponent("vibeproxy_rules.json")
            try? data.write(to: fileURL)
        }
    }
    
    func loadRules() {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let fileURL = documentsPath.appendingPathComponent("vibeproxy_rules.json")
        
        guard let data = try? Data(contentsOf: fileURL) else { return }
        
        if let loaded = try? JSONDecoder().decode(RuleSet.self, from: data) {
            ruleSet = loaded
            updateObservableNodes()
        }
    }
    
    func exportRules() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "vibeproxy_rules_\(ruleSet.name.lowercased().replacingOccurrences(of: " ", with: "_")).json"
        
        if panel.runModal() == .OK, let url = panel.url {
            if let data = try? JSONEncoder().encode(ruleSet) {
                try? data.write(to: url)
            }
        }
    }
    
    func importRules() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        
        if panel.runModal() == .OK, let url = panel.url {
            if let data = try? Data(contentsOf: url),
               let imported = try? JSONDecoder().decode(RuleSet.self, from: data) {
                ruleSet = imported
                updateObservableNodes()
            }
        }
    }
    
    // MARK: - Helpers
    
    func updateObservableNodes() {
        observableNodes = ruleSet.nodes.map { ObservableRuleNode(node: $0) }
    }
}

// Note: Extensions for NodeType and NodeCategory are in RuleModels.swift

// MARK: - Validation

struct RuleValidationError: Identifiable {
    let id: String
    let type: RuleValidationErrorType
    let message: String
}

enum RuleValidationErrorType {
    case orphanedConnection
    case missingTrigger
    case loopDetected
    case invalidConfiguration
}
