import SwiftUI

@available(macOS 14.0, *)
struct RuleCanvas: View {
    @ObservedObject var viewModel: RulesViewModel
    
    @State private var canvasOffset: CGSize = .zero
    @State private var canvasScale: CGFloat = 1.0
    @State private var isPanning = false
    @State private var lastPanLocation: CGPoint = .zero
    
    @State private var connectionStart: ConnectionStart? = nil
    @State private var tempConnectionEndPoint: CGPoint = .zero
    
    // Grid settings
    private let gridSize: CGFloat = 20
    private let gridThreshold: CGFloat = 10
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background grid
                gridView
                
                // Connections layer
                connectionsLayer
                
                // Temporary connection (while dragging)
                if let start = connectionStart {
                    temporaryConnection(from: start.startPoint, to: tempConnectionEndPoint)
                }
                
                // Nodes layer
                nodesLayer
                
                // Minimap overlay
                VStack {
                    HStack {
                        Spacer()
                        minimapView
                            .frame(width: 150, height: 100)
                            .padding(8)
                    }
                    Spacer()
                }
            }
            .clipped()
            .gesture(
                // Pan gesture with option/shift keys for different modes
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        if !isPanning {
                            isPanning = true
                            lastPanLocation = value.startLocation
                        }
                        
                        let delta = CGSize(
                            width: value.translation.width,
                            height: value.translation.height
                        )
                        canvasOffset = CGSize(
                            width: lastPanLocation.x + delta.width,
                            height: lastPanLocation.y + delta.height
                        )
                    }
                    .onEnded { _ in
                        isPanning = false
                    }
            )
            .onAppear {
                centerCanvas(in: geometry.size)
            }
            .onChange(of: viewModel.nodes) { _ in
                // Auto-center if no nodes exist or if needed
                if viewModel.nodes.isEmpty {
                    centerCanvas(in: geometry.size)
                }
            }
        }
        .navigationTitle("Rules Editor")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                zoomControls
                viewControls
                ruleControls
            }
        }
        // Note: Space + drag = pan mode is handled in the gesture
    }
    
    // MARK: - Grid View
    
    private var gridView: some View {
        Canvas { context, size in
            // Create grid pattern
            let scaledGridSize = gridSize * canvasScale
            
            // Calculate grid offset based on canvas offset
            let offsetX = canvasOffset.width.truncatingRemainder(dividingBy: scaledGridSize)
            let offsetY = canvasOffset.height.truncatingRemainder(dividingBy: scaledGridSize)
            
            // Vertical lines
            var x = offsetX
            while x < size.width {
                context.stroke(
                    Path { path in
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                    },
                    with: .color(.secondary.opacity(0.2)),
                    lineWidth: 0.5
                )
                x += scaledGridSize
            }
            
            // Horizontal lines
            var y = offsetY
            while y < size.height {
                context.stroke(
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                    },
                    with: .color(.secondary.opacity(0.2)),
                    lineWidth: 0.5
                )
                y += scaledGridSize
            }
            
            // Draw origin point if we're close to (0,0)
            if canvasOffset.magnitude < 100 {
                context.fill(
                    Path(ellipseIn: CGRect(
                        x: canvasOffset.width - 4,
                        y: canvasOffset.height - 4,
                        width: 8,
                        height: 8
                    )),
                    with: .color(.red.opacity(0.5))
                )
            }
        }
    }
    
    // MARK: - Nodes Layer
    
    private var nodesLayer: some View {
        ForEach(viewModel.observableNodes) { observableNode in
            RuleNodeView(
                node: observableNode,
                viewModel: viewModel,
                onPortTap: { nodeId, portId, portType in
                    handlePortTap(nodeId: nodeId, portId: portId, portType: portType)
                },
                onNodeMove: { nodeId, newPosition in
                    moveNode(nodeId: nodeId, to: newPosition)
                },
                onSelect: { nodeId in
                    viewModel.selectedNodeId = nodeId
                    viewModel.showConfigPanel = (nodeId != nil)
                }
            )
        }
    }
    
    // MARK: - Connections Layer
    
    private var connectionsLayer: some View {
        Canvas { context, size in
            for connection in viewModel.connections {
                if let startNode = viewModel.nodes.first(where: { $0.id == connection.fromNodeId }),
                   let endNode = viewModel.nodes.first(where: { $0.id == connection.toNodeId }) {
                    
                    let startPoint = pointForNode(startNode, portId: connection.fromPortId, isInput: false)
                    let endPoint = pointForNode(endNode, portId: connection.toPortId, isInput: true)
                    
                    drawConnection(
                        context: context,
                        from: startPoint,
                        to: endPoint,
                        color: .blue,
                        isHighlighted: connection.id == viewModel.selectedConnectionId
                    )
                }
            }
        }
    }
    
    private func drawConnection(
        context: GraphicsContext,
        from start: CGPoint,
        to end: CGPoint,
        color: Color,
        isHighlighted: Bool
    ) {
        let controlPointOffset = abs(end.x - start.x) * 0.4
        
        let path = Path { path in
            path.move(to: start)
            
            // Bezier curve for smooth connections
            let control1 = CGPoint(x: start.x + controlPointOffset, y: start.y)
            let control2 = CGPoint(x: end.x - controlPointOffset, y: end.y)
            path.addCurve(to: end, control1: control1, control2: control2)
        }
        
        context.stroke(
            path,
            with: .color(color.opacity(isHighlighted ? 0.8 : 0.6)),
            lineWidth: isHighlighted ? 3 : 2
        )
        
        // Draw arrow at the end
        drawArrow(
            context: context,
            at: end,
            direction: CGVector(dx: end.x - (end.x - controlPointOffset), dy: 0),
            color: color
        )
    }
    
    private func drawArrow(
        context: GraphicsContext,
        at point: CGPoint,
        direction: CGVector,
        color: Color
    ) {
        let arrowSize: CGFloat = 8
        let normalized = 1.0 / sqrt(direction.dx * direction.dx + direction.dy * direction.dy)
        let normalizedDirection = CGVector(dx: direction.dx * normalized, dy: direction.dy * normalized)
        
        let perpendicular = CGVector(dx: -normalizedDirection.dy, dy: normalizedDirection.dx)
        
        let end1 = CGPoint(
            x: point.x - arrowSize * normalizedDirection.dx + arrowSize * 0.5 * perpendicular.dx,
            y: point.y - arrowSize * normalizedDirection.dy + arrowSize * 0.5 * perpendicular.dy
        )
        
        let end2 = CGPoint(
            x: point.x - arrowSize * normalizedDirection.dx - arrowSize * 0.5 * perpendicular.dx,
            y: point.y - arrowSize * normalizedDirection.dy - arrowSize * 0.5 * perpendicular.dy
        )
        
        let arrowPath = Path { path in
            path.move(to: end1)
            path.addLine(to: point)
            path.addLine(to: end2)
        }
        
        context.fill(arrowPath, with: .color(color))
    }
    
    // MARK: - Temporary Connection
    
    private func temporaryConnection(from start: CGPoint, to end: CGPoint) -> some View {
        Canvas { context, size in
            drawConnection(
                context: context,
                from: start,
                to: end,
                color: .green,
                isHighlighted: false
            )
        }
    }
    
    // MARK: - Minimap
    
    private var minimapView: some View {
        VStack {
            HStack {
                Spacer()
                Button("Fit") {
                    fitToScreen()
                }
                .font(.caption)
                .buttonStyle(.plain)
            }
            
            Canvas { context, size in
                // Draw background
                let backgroundRect = Path(CGRect(origin: .zero, size: size))
                context.fill(
                    backgroundRect,
                    with: .color(.black.opacity(0.8))
                )
                
                // Draw nodes
                for node in viewModel.nodes {
                    let miniPos = minimapPosition(node.position, canvasSize: size)
                    let rect = CGRect(
                        x: miniPos.x - 2,
                        y: miniPos.y - 1,
                        width: 4,
                        height: 2
                    )
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(node.category.color)
                    )
                }
                
                // Draw viewport rectangle
                let viewportRect = minimapViewportRect(canvasSize: size)
                var path = Path()
                path.addRect(viewportRect)
                context.stroke(
                    path,
                    with: .color(.white),
                    lineWidth: 1
                )
            }
            .border(.secondary, width: 1)
            .cornerRadius(4)
        }
    }
    
    // MARK: - Toolbar Controls
    
    private var zoomControls: some View {
        HStack(spacing: 4) {
            Button(action: { zoomIn() }) {
                Image(systemName: "plus.magnifyingglass")
            }
            
            Text("\(Int(canvasScale * 100))%")
                .font(.caption2)
                .monospacedDigit()
                .frame(minWidth: 35)
            
            Button(action: { zoomOut() }) {
                Image(systemName: "minus.magnifyingglass")
            }
            
            Button(action: { resetZoom() }) {
                Image(systemName: "1.magnifyingglass")
            }
        }
    }
    
    private var viewControls: some View {
        Group {
            Divider()
            
            Button(action: { centerCanvasOnNodes() }) {
                Image(systemName: "center.dashed")
            }
            
            Button(action: { toggleGrid() }) {
                Image(systemName: "grid")
            }
        }
    }
    
    private var ruleControls: some View {
        VStack {
            Divider()
            
            Button(action: { 
                let _ = viewModel.validateRules()
            }) {
                Image(systemName: "checkmark.shield")
            }
            
            Button(action: { viewModel.exportRules() }) {
                Image(systemName: "square.and.arrow.up")
            }
            
            Button(action: { viewModel.importRules() }) {
                Image(systemName: "square.and.arrow.down")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func centerCanvas(in size: CGSize) {
        canvasOffset = CGSize(
            width: size.width / 2,
            height: size.height / 2
        )
    }
    
    private func centerCanvasOnNodes() {
        guard !viewModel.nodes.isEmpty else { return }
        
        let nodesBounds = calculateNodesBounds()
        let centerX = (nodesBounds.minX + nodesBounds.maxX) / 2
        let centerY = (nodesBounds.minY + nodesBounds.maxY) / 2
        
        // This would need the parent view's size - for now we'll center on (0,0)
        canvasOffset = CGSize(
            width: -centerX * canvasScale,
            height: -centerY * canvasScale
        )
    }
    
    private func fitToScreen() {
        guard !viewModel.nodes.isEmpty else { return }
        
        let nodesBounds = calculateNodesBounds()
        let nodesWidth = nodesBounds.maxX - nodesBounds.minX
        let nodesHeight = nodesBounds.maxY - nodesBounds.minY
        
        // Calculate needed scale to fit all nodes
        let scaleX = 400 / nodesWidth  // Assuming 400pt visible area
        let scaleY = 300 / nodesHeight  // Assuming 300pt visible area
        let targetScale = min(scaleX, scaleY, 2.0)   // Max 200%
        
        canvasScale = targetScale
        centerCanvasOnNodes()
    }
    
    private func calculateNodesBounds() -> CGRect {
        guard !viewModel.nodes.isEmpty else { return .zero }
        
        let positions = viewModel.nodes.map { $0.position }
        let minX = positions.map { $0.x }.min() ?? 0
        let maxX = positions.map { $0.x }.max() ?? 0
        let minY = positions.map { $0.y }.min() ?? 0
        let maxY = positions.map { $0.y }.max() ?? 0
        
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
    
    private func moveNode(nodeId: String, to newPosition: CGPoint) {
        // Apply grid snapping
        let snappedPosition = snapToGrid(newPosition)
        
        viewModel.moveNode(nodeId, to: snappedPosition)
        
        // Update temporary connection if we're dragging one
        if var start = connectionStart,
           start.fromNodeId == nodeId {
            let node = viewModel.nodes.first { $0.id == nodeId }
            if let node = node {
                start.startPoint = pointForNode(node, portId: start.fromPortId, isInput: false)
                connectionStart = start
            }
        }
    }
    
    private func snapToGrid(_ position: CGPoint) -> CGPoint {
        let snappedX = round(position.x / gridSize) * gridSize
        let snappedY = round(position.y / gridSize) * gridSize
        
        // Only snap if we're close to a grid line
        let shouldSnapX = abs(position.x - snappedX) < gridThreshold
        let shouldSnapY = abs(position.y - snappedY) < gridThreshold
        
        return CGPoint(
            x: shouldSnapX ? snappedX : position.x,
            y: shouldSnapY ? snappedY : position.y
        )
    }
    
    private func pointForNode(_ node: RuleNode, portId: String, isInput: Bool) -> CGPoint {
        let nodeRect = CGRect(x: node.position.x - 90, y: node.position.y - 40, width: 180, height: 80)
        
        if isInput {
            return CGPoint(x: nodeRect.minX, y: nodeRect.midY)
        } else {
            return CGPoint(x: nodeRect.maxX, y: nodeRect.midY)
        }
    }
    
    private func minimapPosition(_ position: CGPoint, canvasSize: CGSize) -> CGPoint {
        // Translate world coords to minimap coords
        let scale = 0.05 * canvasScale
        return CGPoint(
            x: position.x * scale + canvasSize.width / 2,
            y: position.y * scale + canvasSize.height / 2
        )
    }
    
    private func minimapViewportRect(canvasSize: CGSize) -> CGRect {
        // This would represent the current view area in the minimap
        return CGRect(x: 10, y: 10, width: 20, height: 15)
    }
    
    private func handlePortTap(nodeId: String, portId: String, portType: PortType) {
        if let start = connectionStart {
            // Complete the connection
            if portType == .input && start.canConnectTo(nodeId: nodeId, portId: portId) {
                viewModel.addConnection(
                    from:start.fromNodeId,
                    fromPort: start.fromPortId,
                    to: nodeId,
                    toPort: portId
                )
                connectionStart = nil
            } else {
                // Cancel the connection attempt
                connectionStart = nil
            }
        } else {
            // Start a new connection
            if portType == .output,
               let node = viewModel.nodes.first(where: { $0.id == nodeId }) {
                let startPoint = pointForNode(node, portId: portId, isInput: false)
                connectionStart = ConnectionStart(
                    fromNodeId: nodeId,
                    fromPortId: portId,
                    startPoint: startPoint
                )
            }
        }
    }
    
    private func zoomIn() {
        canvasScale = min(canvasScale * 1.2, 3.0)
    }
    
    private func zoomOut() {
        canvasScale = max(canvasScale / 1.2, 0.3)
    }
    
    private func resetZoom() {
        canvasScale = 1.0
    }
    
    private func toggleGrid() {
        // This would toggle grid visibility
    }
    
    // Connection start tracking
    struct ConnectionStart {
        let fromNodeId: String
        let fromPortId: String
        var startPoint: CGPoint
        
        init(fromNodeId: String, fromPortId: String, startPoint: CGPoint) {
            self.fromNodeId = fromNodeId
            self.fromPortId = fromPortId
            self.startPoint = startPoint
        }
        
        func canConnectTo(nodeId: String, portId: String) -> Bool {
            // Prevent self-connection and other invalid connections
            return fromNodeId != nodeId
        }
    }
}

extension CGSize {
    var magnitude: Double {
        sqrt(width * width + height * height)
    }
}
