import SwiftUI

struct RuleNodeView: View {
    @ObservedObject var node: ObservableRuleNode
    @ObservedObject var viewModel: RulesViewModel
    let onPortTap: (String, String, PortType) -> Void
    let onNodeMove: (String, CGPoint) -> Void
    let onSelect: (String?) -> Void
    
    @State private var isDragging = false
    @State private var dragOffset: CGSize = .zero
    @State private var isHovered = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with drag handle
            headerView
                .background(node.node.category.color.opacity(0.1))
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(node.node.category.color.opacity(0.3)),
                    alignment: .bottom
                )
            
            // Body with configuration
            nodeBodyView
                .background(Color(.controlBackgroundColor))
            
            // Ports row
            portsView
                .frame(height: 30)
                .background(Color(.controlBackgroundColor))
        }
        .frame(width: 180)
        .background(Color(.controlBackgroundColor))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(borderColor, lineWidth: isSelected ? 2 : 1)
        )
        .shadow(
            color: isDragging ? .primary.opacity(0.3) : (isSelected ? .blue.opacity(0.2) : .black.opacity(0.1)),
            radius: isDragging ? 12 : (isSelected ? 8 : 4),
            y: isDragging ? 8 : (isSelected ? 4 : 2)
        )
        .scaleEffect(isDragging ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isDragging)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
        .position(node.node.position)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if !isDragging {
                        isDragging = true
                        onSelect(node.node.id)
                    }
                    dragOffset = value.translation
                    let newPosition = CGPoint(
                        x: node.node.position.x + value.translation.width,
                        y: node.node.position.y + value.translation.height
                    )
                    onNodeMove(node.node.id, newPosition)
                }
                .onEnded { _ in
                    isDragging = false
                    dragOffset = .zero
                    viewModel.snapToGrid(node.node.id)
                }
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
        .contextMenu {
            contextMenuItems
        }
    }
    
    private var headerView: some View {
        HStack(spacing: 8) {
            // Drag handle
            dragHandle
            
            // Icon and title
            HStack(spacing: 6) {
                Image(systemName: node.node.type.icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(node.node.category.color)
                
                Text(node.node.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Status and actions
            HStack(spacing: 4) {
                if !node.node.isEnabled {
                    Image(systemName: "pause.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                }
                
                Button(action: {}) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Node options")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(height: 32)
    }
    
    private var dragHandle: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { _ in
                Circle()
                    .fill(.tertiary)
                    .frame(width: 4, height: 4)
            }
        }
        .onHover { hovering in
            if hovering {
                NSCursor.closedHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
    
    private var nodeBodyView: some View {
        VStack(spacing: 8) {
            // Quick parameter preview
            ParamPreviewView(node: node.node)
            
            // Notes if present
            if !node.node.data.notes.isEmpty {
                Text(node.node.data.notes)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 8)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(minHeight: 40)
    }
    
    private var portsView: some View {
        HStack {
            // Input ports
            HStack(spacing: 12) {
                ForEach(node.node.inputPorts) { port in
                    PortView(
                        port: port,
                        isInput: true,
                        isConnected: port.isConnected,
                        onPortTap: { onPortTap(node.node.id, port.id, PortType.input) }
                    )
                }
            }
            
            Spacer()
            
            // Output ports
            HStack(spacing: 12) {
                ForEach(node.node.outputPorts) { port in
                    PortView(
                        port: port,
                        isInput: false,
                        isConnected: port.isConnected,
                        onPortTap: { onPortTap(node.node.id, port.id, PortType.output) }
                    )
                }
            }
        }
        .padding(.horizontal, 8)
    }
    
    private var isSelected: Bool {
        viewModel.selectedNodeId == node.node.id
    }
    
    private var borderColor: Color {
        if node.hasErrors {
            return .red
        }
        if isSelected {
            return .blue
        }
        if isHovered {
            return .primary.opacity(0.5)
        }
        return .primary.opacity(0.2)
    }
    
    private var contextMenuItems: some View {
        Group {
            Button(node.node.isEnabled ? "Disable" : "Enable") {
                node.node.isEnabled.toggle()
            }
            
            Button("Configure") {
                viewModel.selectedNodeId = node.node.id
                viewModel.showConfigPanel = true
            }
            
            Menu("Duplicate") {
                Button("With connections") {
                    viewModel.duplicateNode(node.node.id, keepConnections: true)
                }
                Button("Node only") {
                    viewModel.duplicateNode(node.node.id, keepConnections: false)
                }
            }
            
            Divider()
            
            Button("Delete", role: .destructive) {
                viewModel.deleteNode(node.node.id)
            }
        }
    }
}

// MARK: - Port View

struct PortView: View {
    let port: NodePort
    let isInput: Bool
    let isConnected: Bool
    let onPortTap: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onPortTap) {
            Circle()
                .fill(portColor)
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .stroke(.primary.opacity(0.3), lineWidth: 1)
                )
                .scaleEffect(isHovered ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: isHovered)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .help(port.name)
    }
    
    private var portColor: Color {
        if isConnected {
            return .green
        }
        if isHovered {
            return isInput ? .blue : .orange
        }
        return .gray.opacity(0.6)
    }
}

// MARK: - Parameter Preview

struct ParamPreviewView: View {
    let node: RuleNode
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(node.data.parameters.prefix(2)), id: \.key) { key, param in
                HStack {
                    Text(key.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(paramValueDisplay(param.value))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }
            }
            
            if node.data.parameters.count > 2 {
                Text("+\(node.data.parameters.count - 2) more...")
                    .font(.system(size: 9))
                    .foregroundColor(Color.secondary.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func paramValueDisplay(_ value: ParameterValue) -> String {
        switch value {
        case .string(let str): return str.count > 15 ? String(str.prefix(15)) + "..." : str
        case .integer(let int): return String(int)
        case .float(let float): return String(format: "%.1f", float)
        case .boolean(let bool): return bool ? "Yes" : "No"
        case .array(let array): return "[\(array.count) items]"
        case .dictionary(let dict): return "{\(dict.count) keys}"
        }
    }
}

// MARK: - Observable Node Wrapper

class ObservableRuleNode: ObservableObject, Identifiable {
    @Published var node: RuleNode
    
    var id: String {
        return node.id
    }
    
    init(node: RuleNode) {
        self.node = node
    }
    
    var hasErrors: Bool {
        // Check for validation errors
        return node.data.parameters.contains { _, param in
            return param.type == .string && (try? param.value.getString()) == nil
        }
    }
}

// MARK: - ParameterValue Extension

extension ParameterValue {
    func getString() throws -> String {
        switch self {
        case .string(let value): return value
        default: throw ConversionError.typeMismatch
        }
    }
    
    func getInt() throws -> Int {
        switch self {
        case .integer(let value): return value
        default: throw ConversionError.typeMismatch
        }
    }
    
    func getBool() throws -> Bool {
        switch self {
        case .boolean(let value): return value
        default: throw ConversionError.typeMismatch
        }
    }
    
    func getArray() throws -> [ParameterValue] {
        switch self {
        case .array(let value): return value
        default: throw ConversionError.typeMismatch
        }
    }
    
    func getDictionary() throws -> [String: ParameterValue] {
        switch self {
        case .dictionary(let value): return value
        default: throw ConversionError.typeMismatch
        }
    }
    
    enum ConversionError: Error {
        case typeMismatch
    }
}

// MARK: - Preview

struct RuleNodeView_Previews: PreviewProvider {
    static var previews: some View {
        let node = RuleNode(type: NodeType.conditionNLP, position: CGPoint.zero)
        let viewModel = RulesViewModel()
        
        RuleNodeView(
            node: ObservableRuleNode(node: node),
            viewModel: viewModel,
            onPortTap: { _, _, _ in },
            onNodeMove: { _, _ in },
            onSelect: { _ in }
        )
        .frame(width: 200, height: 150)
        .background(Color.gray.opacity(0.1))
    }
}
