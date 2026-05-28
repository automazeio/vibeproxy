import SwiftUI
import Combine
import UniformTypeIdentifiers

// MARK: - Main Visual Node Programmer

struct VisualNodeProgrammer: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var nodeGraph = NodeGraphViewModel()
    @StateObject private var serverManager: ServerManager
    
    @State private var isExpanded = false
    @State private var showRunTest = false
    @State private var isDragging = false
    
    init(serverManager: ServerManager) {
        self._serverManager = StateObject(wrappedValue: serverManager)
    }
    
    var body: some View {
        Group {
            if isExpanded {
                expandedNodeProgrammer
            } else {
                compactNodeProgrammer
            }
        }
        .onReceive(nodeGraph.$nodes) { _ in
            // Auto-save on changes
            nodeGraph.autoSave()
        }
    }
    
    // MARK: - Compact View (Default Small Window)
    
    private var compactNodeProgrammer: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HSplitView {
                    // Node Palette (Left)
                    nodePalette
                        .frame(minWidth: 200, maxWidth: 250)
                    
                    // Canvas (Center)
                    nodeCanvas
                        .frame(minWidth: 400)
                }
                
                // Bottom Toolbar
                bottomToolbar
            }
            .navigationTitle("Visual Rules Programmer")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { isExpanded = true }) {
                        HStack {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                            Text("Expand")
                        }
                    }
                }
            }
        }
        .frame(minWidth: 650, minHeight: 500)
    }
    
    // MARK: - Expanded View (Large Window)
    
    private var expandedNodeProgrammer: some View {
        NavigationStack {
            HSplitView {
                // Node Palette (Left)
                VStack(spacing: 0) {
                    paletteHeader
                    groupedNodePalette
                }
                .frame(minWidth: 200, maxWidth: 280)
                
                // Canvas (Center)  
                VStack(spacing: 0) {
                    canvasHeader
                    nodeCanvas
                    canvasFooter
                }
                .frame(minWidth: 500)
                
                // Properties Panel (Right)
                VStack(spacing: 0) {
                    propertiesHeader
                    propertiesPanel
                }
                .frame(minWidth: 250, maxWidth: 300)
            }
            .navigationTitle("Visual Rules Programmer - Full Editor")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { isExpanded = false }) {
                        HStack {
                            Image(systemName: "arrow.down.right.and.arrow.up.left")
                            Text("Compact")
                        }
                    }
                }
            }
        }
        .frame(minWidth: 1200, minHeight: 800)
    }
    
    // MARK: - Node Palette
    
    private var nodePalette: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(FlowNodeType.allCases, id: \.self) { nodeType in
                    PaletteNodeItem(
                        nodeType: nodeType,
                        onDragNode: { dragNode(of: nodeType) }
                    )
                }
            }
            .padding(12)
        }
        .background(Color(.controlBackgroundColor))
    }
    
    private var groupedNodePalette: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                ForEach(FlowNodeCategory.allCases, id: \.self) { category in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(category.rawValue)
                            .font(.headline)
                            .foregroundColor(category.color)
                        
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(FlowNodeType.allCases.filter { $0.category == category }, id: \.self) { nodeType in
                                PaletteNodeItem(
                                    nodeType: nodeType,
                                    onDragNode: { dragNode(of: nodeType) }
                                )
                            }
                        }
                    }
                    .padding(.bottom, 16)
                }
            }
            .padding(12)
        }
        .background(Color(.controlBackgroundColor))
    }
    
    private var paletteHeader: some View {
        HStack {
            Text("Node Library")
                .font(.headline)
            Spacer()
            Button("Clear") {
                nodeGraph.clearGraph()
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color(.controlBackgroundColor))
    }
    
    // MARK: - Canvas
    
    private var nodeCanvas: some View {
        NodeCanvasView(
            nodeGraph: nodeGraph,
            onNodeSelected: { nodeId in
                nodeGraph.selectedNodeId = nodeId
            },
            onConnectionStart: { fromNodeId, outputPort in
                nodeGraph.startConnection(from: fromNodeId, outputPort: outputPort)
            },
            onConnectionEnd: { toNodeId, inputPort in
                nodeGraph.completeConnection(to: toNodeId, inputPort: inputPort)
            },
            onNodeDelete: { nodeId in
                nodeGraph.deleteNode(nodeId)
            }
        )
        .onDrop(of: [UTType.text], isTargeted: nil) { providers in
            handleCanvasDrop(providers: providers)
        }
        //.onKeyPress(.space) { _ in 
        //    // Canvas shortcuts can be added here
        //    return .ignored
        //}
    }
    
    private var canvasHeader: some View {
        HStack {
            Text("Workflow Canvas")
                .font(.headline)
            Spacer()
            
            HStack(spacing: 8) {
                Button("Zoom In") { nodeGraph.zoomIn() }
                Button("Zoom Out") { nodeGraph.zoomOut() }
                Button("Fit") { nodeGraph.fitToScreen() }
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Button("Validate") {
                    let errors = nodeGraph.validateGraph()
                    if !errors.isEmpty {
                        nodeGraph.showValidationErrors(errors)
                    }
                }
                Button("Run Test") { showRunTest = true }
                Button("Export") { nodeGraph.exportGraph() }
                Button("Import") { nodeGraph.importGraph() }
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
    }
    
    private var canvasFooter: some View {
        HStack {
            Text("Nodes: \(nodeGraph.nodes.count) | Connections: \(nodeGraph.connections.count)")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            
            HStack(spacing: 4) {
                Circle().fill(.green).frame(width: 6, height: 6)
                Text("Valid").font(.caption2)
            }
            .opacity(nodeGraph.isGraphValid() ? 1.0 : 0.0)
        }
        .padding()
        .background(Color(.controlBackgroundColor))
    }
    
    // MARK: - Properties Panel
    
    private var propertiesPanel: some View {
        ScrollView {
            if let nodeId = nodeGraph.selectedNodeId,
               let node = nodeGraph.nodes.first(where: { $0.id == nodeId }) {
                NodePropertiesView(
                    node: node,
                    onNodeUpdate: { updatedNode in
                        nodeGraph.updateNode(updatedNode)
                    }
                )
                .padding()
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "cursorarrow.click")
                        .font(.system(size: 48))
                        .foregroundColor(Color.secondary.opacity(0.6))
                    
                    Text("Select a Node")
                        .font(.headline)
                    Text("Click on any node to view and edit its properties")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            }
        }
        .background(Color(.controlBackgroundColor))
    }
    
    private var propertiesHeader: some View {
        HStack {
            Text("Properties")
                .font(.headline)
            Spacer()
            
            if nodeGraph.selectedNodeId != nil {
                Button("Delete") {
                    if let nodeId = nodeGraph.selectedNodeId {
                        nodeGraph.deleteNode(nodeId)
                    }
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
    }
    
    // MARK: - Bottom Toolbar
    
    private var bottomToolbar: some View {
        HStack {
            HStack(spacing: 12) {
                Button(action: { nodeGraph.undo() }) {
                    Image(systemName: "arrow.uturn.backward")
                }.disabled(!nodeGraph.canUndo)
                
                Button(action: { nodeGraph.redo() }) {
                    Image(systemName: "arrow.uturn.forward")
                }.disabled(!nodeGraph.canRedo)
            }
            
            Spacer()
            
            Text("\(nodeGraph.nodes.count) nodes, \(nodeGraph.connections.count) connections")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button(action: { showRunTest = true }) {
                HStack {
                    Image(systemName: "play.circle.fill")
                    Text("Run Test")
                }
            }
            .buttonStyle(.borderedProminent)
            
            Button(action: { isExpanded = true }) {
                HStack {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                    Text("Expand")
                }
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
    }
    
    // MARK: - Actions
    
    private func dragNode(of type: FlowNodeType) -> NSItemProvider {
        let provider = NSItemProvider()
        let data = try? JSONEncoder().encode(type)
        provider.registerDataRepresentation(forTypeIdentifier: "public.text", visibility: .all) { completion in
            completion(data, nil)
            return nil
        }
        return provider
    }
    
    private func handleCanvasDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        
        provider.loadObject(ofClass: NSString.self) { object, error in
            if let data = object as? Data,
               let nodeType = try? JSONDecoder().decode(FlowNodeType.self, from: data) {
                DispatchQueue.main.async {
                    let position = CGPoint(x: 200, y: 150) // Default position
                    nodeGraph.addNode(type: nodeType, at: position)
                }
            }
        }
        return true
    }
}

// MARK: - Node Canvas View

struct NodeCanvasView: View {
    @ObservedObject var nodeGraph: NodeGraphViewModel
    let onNodeSelected: (String?) -> Void
    let onConnectionStart: (String, String) -> Void
    let onConnectionEnd: (String, String) -> Void
    let onNodeDelete: (String) -> Void
    
    @State private var canvasOffset: CGSize = .zero
    @State private var canvasScale: CGFloat = 1.0
    @State private var isPanning = false
    @State private var tempEndPoint: CGPoint = .zero
    @State private var isDrawingConnection = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background grid
                canvasGrid
                
                // Connections
                Canvas { context, size in
                    drawConnections(context: context, size: size)
                }
                
                // Temporary connection while dragging
                if isDrawingConnection && nodeGraph.connectionStart != nil {
                    Canvas { context, size in
                        drawTempConnection(context: context, size: size)
                    }
                }
                
                // Nodes
                ForEach(nodeGraph.nodes) { node in
                    NodeView(
                        node: node,
                        isSelected: node.id == nodeGraph.selectedNodeId,
                        onSelected: { onNodeSelected(node.id) },
                        onPortClick: { nodeId, portType, portId in
                            handlePortClick(nodeId: nodeId, portType: portType, portId: portId)
                        },
                        onDrag: { translation in
                            nodeGraph.moveNode(node.id, by: translation)
                        },
                        onDelete: { onNodeDelete(node.id) }
                    )
                    .position(node.position)
                }
                
                // Minimap overlay
                VStack {
                    HStack {
                        Spacer()
                        minimap(geometry.size)
                            .frame(width: 120, height: 80)
                            .padding(8)
                    }
                    Spacer()
                }
            }
            .clipped()
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        canvasOffset = CGSize(
                            width: value.translation.width,
                            height: value.translation.height
                        )
                    }
            )
        }
        .scaleEffect(canvasScale)
        .offset(canvasOffset)
        .background(Color(.textBackgroundColor))
    }
    
    private var canvasGrid: some View {
        Canvas { context, size in
            let gridSize: CGFloat = 20 * canvasScale
            let offsetX = canvasOffset.width.truncatingRemainder(dividingBy: gridSize)
            let offsetY = canvasOffset.height.truncatingRemainder(dividingBy: gridSize)
            
            // Draw grid lines
            context.stroke(
                Path { path in
                    var x: CGFloat = offsetX
                    while x < size.width {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                        x += gridSize
                    }
                    
                    var y: CGFloat = offsetY
                    while y < size.height {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                        y += gridSize
                    }
                },
                with: .color(.secondary.opacity(0.2)),
                lineWidth: 0.5
            )
        }
    }
    
    private func drawConnections(context: GraphicsContext, size: CGSize) {
        for connection in nodeGraph.connections {
            if let fromNode = nodeGraph.nodes.first(where: { $0.id == connection.fromNodeId }),
               let toNode = nodeGraph.nodes.first(where: { $0.id == connection.toNodeId }) {
                let fromPoint = getPortPosition(fromNode, portId: connection.fromPortId, isOutput: true)
                let toPoint = getPortPosition(toNode, portId: connection.toPortId, isOutput: false)
                
                drawConnection(
                    context: context,
                    from: fromPoint,
                    to: toPoint,
                    color: .blue,
                    isHighlighted: connection.id == nodeGraph.selectedConnectionId
                )
            }
        }
    }
    
    private func drawTempConnection(context: GraphicsContext, size: CGSize) {
        guard let start = nodeGraph.connectionStart,
              let fromNode = nodeGraph.nodes.first(where: { $0.id == start.nodeId }) else { return }
        
        let fromPoint = getPortPosition(fromNode, portId: start.portId, isOutput: true)
        drawConnection(context: context, from: fromPoint, to: tempEndPoint, color: .green, isHighlighted: false)
    }
    
    private func drawConnection(context: GraphicsContext, from: CGPoint, to: CGPoint, color: Color, isHighlighted: Bool) {
        let controlOffset = abs(to.x - from.x) * 0.5
        let control1 = CGPoint(x: from.x + controlOffset, y: from.y)
        let control2 = CGPoint(x: to.x - controlOffset, y: to.y)
        
        let path = Path { path in
            path.move(to: from)
            path.addCurve(to: to, control1: control1, control2: control2)
        }
        
        context.stroke(
            path,
            with: .color(color.opacity(0.6)),
            lineWidth: isHighlighted ? 3 : 2
        )
        
        // Draw arrow - direction from control2 to endpoint
        let arrowDirection = CGVector(dx: to.x - control2.x, dy: to.y - control2.y)
        drawArrow(context: context, at: to, direction: arrowDirection, color: color)
    }
    
    private func drawArrow(context: GraphicsContext, at point: CGPoint, direction: CGVector, color: Color) {
        let arrowSize: CGFloat = 8
        let magnitude = sqrt(direction.dx * direction.dx + direction.dy * direction.dy)
        guard magnitude > 0 else { return }
        let dir = CGVector(dx: direction.dx / magnitude, dy: direction.dy / magnitude)
        let perpendicular = CGVector(dx: -dir.dy, dy: dir.dx)
        
        let end1 = CGPoint(x: point.x - arrowSize * dir.dx + arrowSize * 0.5 * perpendicular.dx,
                          y: point.y - arrowSize * dir.dy + arrowSize * 0.5 * perpendicular.dy)
        let end2 = CGPoint(x: point.x - arrowSize * dir.dx - arrowSize * 0.5 * perpendicular.dx,
                          y: point.y - arrowSize * dir.dy - arrowSize * 0.5 * perpendicular.dy)
        
        let arrowPath = Path { path in
            path.move(to: end1)
            path.addLine(to: point)
            path.addLine(to: end2)
        }
        
        context.fill(arrowPath, with: .color(color))
    }
    
    private func getPortPosition(_ node: FlowNode, portId: String, isOutput: Bool) -> CGPoint {
        let nodeWidth: CGFloat = 160
        
        if isOutput {
            return CGPoint(x: node.position.x + nodeWidth/2, y: node.position.y)
        } else {
            return CGPoint(x: node.position.x - nodeWidth/2, y: node.position.y)
        }
    }
    
    private func handlePortClick(nodeId: String, portType: FlowPortType, portId: String) {
        if portType == .output {
            onConnectionStart(nodeId, portId)
            isDrawingConnection = true
        } else if portType == .input && isDrawingConnection {
            onConnectionEnd(nodeId, portId)
            isDrawingConnection = false
        }
    }
    
    private func minimap(_ canvasSize: CGSize) -> some View {
        Canvas { context, size in
            // Background
            let backgroundRect = CGRect(origin: .zero, size: size)
            context.fill(Path(backgroundRect), with: .color(.black.opacity(0.8)))
            
            // Draw nodes on minimap
            let scale = 0.05
            for node in nodeGraph.nodes {
                let miniPos = CGPoint(
                    x: node.position.x * scale + size.width/2,
                    y: node.position.y * scale + size.height/2
                )
                
                let nodeRect = CGRect(x: miniPos.x-2, y: miniPos.y-1, width: 4, height: 2)
                context.fill(Path(nodeRect), with: .color(node.type.category.color))
            }
            
            // Draw viewport
            let viewportRect = CGRect(x: 10, y: 10, width: 20, height: 15)
            context.stroke(Path(viewportRect), with: .color(.white))
        }
        .border(.secondary)
        .cornerRadius(4)
    }
}

// MARK: - Node View

struct NodeView: View {
    let node: FlowNode
    let isSelected: Bool
    let onSelected: () -> Void
    let onPortClick: (String, FlowPortType, String) -> Void
    let onDrag: (CGSize) -> Void
    let onDelete: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with type icon
            headerView
            
            // Body with quick parameters
            bodyView
            
            // Input/output ports
            portsView
        }
        .frame(width: 160, height: 80)
        .background(Color(.controlBackgroundColor))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? node.type.category.color : .primary.opacity(0.2), lineWidth: isSelected ? 2 : 1)
        )
        .shadow(color: isSelected ? node.type.category.color.opacity(0.3) : .black.opacity(0.1),
                radius: isSelected ? 6 : 3)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onTapGesture { onSelected() }
        .onHover { isHovered = $0 }
        .contextMenu {
            contextMenuItems
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    onDrag(value.translation)
                }
        )
    }
    
    private var headerView: some View {
        HStack(spacing: 4) {
            Image(systemName: node.type.icon)
                .foregroundColor(node.type.category.color)
                .font(.system(size: 12, weight: .medium))
            
            Text(node.type.displayName)
                .font(.caption)
                .fontWeight(.semibold)
                .lineLimit(1)
            
            Spacer()
            
            if !node.isEnabled {
                Image(systemName: "pause.circle.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.orange)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(node.type.category.color.opacity(0.1))
    }
    
    private var bodyView: some View {
        VStack(spacing: 2) {
            Text(node.config.description ?? node.type.defaultDescription)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
    }
    
    private var portsView: some View {
        HStack {
            // Input ports
            ForEach(node.inputs, id: \.id) { port in
                PortCircle(
                    port: port,
                    isInput: true,
                    onClick: { onPortClick(node.id, FlowPortType.input, port.id) }
                )
            }
            
            Spacer()
            
            // Output ports
            ForEach(node.outputs, id: \.id) { port in
                PortCircle(
                    port: port,
                    isInput: false,
                    onClick: { onPortClick(node.id, .output, port.id) }
                )
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 4)
    }
    
    private var contextMenuItems: some View {
        Group {
            Button(isSelected ? "Deselect" : "Select") {
                onSelected()
            }
            
            Divider()
            
            Button("Duplicate") {
                // TODO: Implement node duplication
            }
            
            Divider()
            
            Button("Delete", role: .destructive) {
                onDelete()
            }
        }
    }
}

// MARK: - Port Circle

struct PortCircle: View {
    let port: FlowPort
    let isInput: Bool
    let onClick: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onClick) {
            Circle()
                .fill(portColor)
                .frame(width: 10, height: 10)
                .overlay(
                    Circle()
                        .stroke(.primary.opacity(0.3), lineWidth: 1)
                )
                .scaleEffect(isHovered ? 1.2 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { isHovered = $0 }
        .help("\(port.name) \(isInput ? "in" : "out")")
    }
    
    private var portColor: Color {
        if isInput {
            return isHovered ? .blue : .gray.opacity(0.6)
        } else {
            return isHovered ? .orange : .gray.opacity(0.6)
        }
    }
}

// MARK: - Palette Node Item

struct PaletteNodeItem: View {
    let nodeType: FlowNodeType
    let onDragNode: () -> NSItemProvider
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: nodeType.icon)
                .foregroundColor(nodeType.category.color)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(nodeType.displayName)
                    .font(.caption)
                    .fontWeight(. medium)
                    .foregroundColor(.primary)
                
                Text(nodeType.defaultDescription)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            if isHovered {
                Image(systemName: "arrow.right.circle")
                    .font(.system(size: 12))
                    .foregroundColor(Color.secondary)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? Color.secondary.opacity(0.1) : Color.clear)
        )
        .onDrag { onDragNode() }
        .onHover { isHovered = $0 }
    }
}

// MARK: - Node Properties View

struct NodePropertiesView: View {
    let node: FlowNode
    let onNodeUpdate: (FlowNode) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Node info
            nodeInfoSection
            
            // Configuration
            configurationSection
            
            // Advanced
            advancedSection
            
            Spacer()
        }
    }
    
    private var nodeInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: node.type.icon)
                    .foregroundColor(node.type.category.color)
                    .font(.system(size: 20))
                
                VStack(alignment: .leading) {
                    Text(node.type.displayName)
                        .font(.headline)
                    Text(node.id)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: Binding(
                    get: { node.isEnabled },
                    set: { enabled in
                        var updatedNode = node
                        updatedNode.isEnabled = enabled
                        onNodeUpdate(updatedNode)
                    }
                ))
            }
            
            Text(node.type.defaultDescription)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var configurationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Configuration")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            // Dynamic configuration based on node type
            switch node.type.category {
            case .triggers:
                triggerConfiguration
            case .conditions:
                conditionConfiguration
            case .actions:
                actionConfiguration
            case .nlp:
                nlpConfiguration
            case .data:
                dataConfiguration
            case .routing, .logic, .control, .integration:
                EmptyView()
            }
        }
    }
    
    private var advancedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Advanced")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                HStack {
                    Text("Priority")
                    Spacer()
                    TextField("1", value: .constant(node.config.priority ?? 1), format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 60)
                }
                
                TextField("Notes", text: .constant(node.config.notes ?? ""))
                    .textFieldStyle(.roundedBorder)
            }
        }
    }
    
    // Configuration sections based on node type would go here
    private var triggerConfiguration: some View {
        VStack(alignment: .leading, spacing: 8) {
            if node.type == FlowNodeType.httpTrigger {
                TextField("Path", text: .constant(node.config.path ?? "/"))
                    .textFieldStyle(.roundedBorder)
                
                Picker("Method", selection: .constant(node.config.method ?? "POST")) {
                    Text("GET").tag("GET")
                    Text("POST").tag("POST")
                    Text("PUT").tag("PUT")
                    Text("DELETE").tag("DELETE")
                }
                .pickerStyle(.menu)
            }
        }
    }
    
    private var conditionConfiguration: some View {
        VStack(alignment: .leading, spacing: 8) {
            if node.type == FlowNodeType.modelAvailability {
                Picker("Operator", selection: .constant("==")) {
                    Text("Equals").tag("==")
                    Text("Not Equals").tag("!=")
                    Text("Contains").tag("contains")
                }
                .pickerStyle(.menu)
                
                TextField("Target Model", text: .constant(node.config.targetModel ?? ""))
                    .textFieldStyle(.roundedBorder)
            }
        }
    }
    
    private var actionConfiguration: some View {
        VStack(alignment: .leading, spacing: 8) {
            if node.type == FlowNodeType.routeToService {
                Picker("Service", selection: .constant(node.config.targetService ?? "")) {
                    Text("Claude").tag("claude")
                    Text("OpenAI").tag("openai")
                    Text("Gemini").tag("gemini")
                    Text("Qwen").tag("qwen")
                    Text("Auggie").tag("auggie")
                    Text("Cursor").tag("cursor")
                }
                .pickerStyle(.menu)
                
                HStack {
                    Text("Timeout (ms)")
                    Spacer()
                    TextField("5000", value: .constant(node.config.timeout ?? 5000), format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                }
            }
        }
    }
    
    private var nlpConfiguration: some View {
        VStack(alignment: .leading, spacing: 8) {
            if node.type == FlowNodeType.intentClassification {
               Slider(value: .constant(node.config.confidenceThreshold ?? 0.7), in: 0.0...1.0) {
                    Text("Confidence: \(String(format: "%.1f", node.config.confidenceThreshold ?? 0.7))")
                }
            }
        }
    }
    
    private var dataConfiguration: some View {
        VStack(alignment: .leading, spacing: 8) {
            if node.type == FlowNodeType.transformData {
                TextEditor(text: .constant(node.config.transformation ?? ""))
                    .frame(height: 60)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(.secondary.opacity(0.5), lineWidth: 1)
                    )
            }
        }
    }
}

// MARK: - Preview

struct VisualNodeProgrammer_Previews: PreviewProvider {
    static var previews: some View {
        VisualNodeProgrammer(serverManager: ServerManager())
            .frame(width: 800, height: 600)
    }
}