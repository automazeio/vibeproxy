import SwiftUI

struct NodeConfigPanel: View {
    @ObservedObject var viewModel: RulesViewModel
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            configHeader
            
            Divider()
            
            if let selectedNode = selectedNode {
                // Node info
                nodeInfoSection(selectedNode)
                
 Divider()
                
                // Configuration form
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        if !selectedNode.data.parameters.isEmpty {
                            parametersSection(selectedNode)
                        }
                        
                        notesSection(selectedNode)
                        
                        NLPConfigSection(node: selectedNode, viewModel: viewModel)
                        
                        advancedSection(selectedNode)
                    }
                    .padding()
                }
                
                Spacer()
                
                // Footer with actions
                footerActions(selectedNode)
            } else {
                noSelectionView
            }
        }
        .frame(minWidth: 250, idealWidth: 300, maxWidth: 400)
        .background(Color(.controlBackgroundColor))
    }
    
    private var configHeader: some View {
        HStack {
            Text("Node Configuration")
                .font(.headline)
                .foregroundColor(.primary)
            
            Spacer()
            
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    private func nodeInfoSection(_ node: RuleNode) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: node.type.icon)
                    .font(.system(size: 20))
                    .foregroundColor(node.category.color)
                
                VStack(alignment: .leading) {
                    Text(node.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(node.type.defaultName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Status
                VStack {
                    if node.isEnabled {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                    } else {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 8, height: 8)
                    }
                    
                    Text(node.isEnabled ? "Active" : "Disabled")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Text(node.type.defaultDescription)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
    }
    
    private func parametersSection(_ node: RuleNode) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Parameters")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                ForEach(Array(node.data.parameters.sorted(by: { $0.key < $1.key })), id: \.key) { key, param in
                    ParameterEditor(
                        key: key,
                        parameter: param,
                        onUpdate: { newValue in
                            updateParameter(nodeId: node.id, key: key, value: newValue)
                        }
                    )
                }
            }
        }
    }
    
    private func notesSection(_ node: RuleNode) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            TextEditor(text: binding(for: node.id, key: "notes"))
                .frame(minHeight: 60)
                .font(.caption)
                .background(Color(.textBackgroundColor))
                .cornerRadius(6)
        }
    }
    
    private func advancedSection(_ node: RuleNode) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Advanced")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                Toggle("Enable node", isOn: binding(for: node.id, key: "isEnabled"))
                    .font(.caption)
                
                if node.category == .nlpRules {
                    Toggle("Debug NLP processing", isOn: binding(for: node.id, key: "debugMode"))
                        .font(.caption)
                }
                
                if node.category == .conditions {
                    Toggle("Case sensitive", isOn: binding(for: node.id, key: "caseSensitive"))
                        .font(.caption)
                }
            }
        }
    }
    
    private var noSelectionView: some View {
        VStack(spacing: 16) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 32))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("No Node Selected")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Select a node from the canvas to configure its parameters")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.5))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func footerActions(_ node: RuleNode) -> some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 8) {
                Button("Test Node") {
                    testNode(node)
                }
                .buttonStyle(.bordered)
                
                Button("Reset") {
                    resetNode(node)
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Delete", role: .destructive) {
                    viewModel.deleteNode(node.id)
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }
    
    // MARK: - Helper Methods
    
    private var selectedNode: RuleNode? {
        guard let selectedId = viewModel.selectedNodeId else { return nil }
        return viewModel.nodes.first { $0.id == selectedId }
    }
    
    private func updateParameter(nodeId: String, key: String, value: ParameterValue) {
        guard let nodeIndex = viewModel.ruleSet.nodes.firstIndex(where: { $0.id == nodeId }) else { return }
        viewModel.ruleSet.nodes[nodeIndex].data.parameters[key]?.value = value
        viewModel.ruleSet.updateTimestamp()
    }
    
    private func binding(for nodeId: String, key: String) -> Binding<Bool> {
        return Binding(
            get: {
                guard let node = viewModel.ruleSet.nodes.first(where: { $0.id == nodeId }) else { return false }
                switch key {
                case "isEnabled": return node.isEnabled
                case "debugMode": return node.data.parameters["debug_mode"]?.value.asBool ?? false
                case "caseSensitive": return node.data.parameters["case_sensitive"]?.value.asBool ?? true
                default: return false
                }
            },
            set: { newValue in
                guard let nodeIndex = viewModel.ruleSet.nodes.firstIndex(where: { $0.id == nodeId }) else { return }
                switch key {
                case "isEnabled":
                    viewModel.ruleSet.nodes[nodeIndex].isEnabled = newValue
                case "debugMode":
                    viewModel.ruleSet.nodes[nodeIndex].data.parameters["debug_mode"] = NodeParameter(value: .boolean(newValue), type: .boolean)
                case "caseSensitive":
                    viewModel.ruleSet.nodes[nodeIndex].data.parameters["case_sensitive"] = NodeParameter(value: .boolean(newValue), type: .boolean)
                default: break
                }
                viewModel.ruleSet.updateTimestamp()
            }
        )
    }
    
    private func binding(for nodeId: String, key: String) -> Binding<String> {
        return Binding(
            get: {
                guard let node = viewModel.nodes.first(where: { $0.id == nodeId }) else { return "" }
                return node.data.notes
            },
            set: { newValue in
                guard let nodeIndex = viewModel.ruleSet.nodes.firstIndex(where: { $0.id == nodeId }) else { return }
                viewModel.ruleSet.nodes[nodeIndex].data.notes = newValue
                viewModel.ruleSet.updateTimestamp()
            }
        )
    }
    
    private func testNode(_ node: RuleNode) {
        // Test node with sample data
        viewModel.showTestPanel = true
    }
    
    private func resetNode(_ node: RuleNode) {
        guard let nodeIndex = viewModel.ruleSet.nodes.firstIndex(where: { $0.id == node.id }) else { return }
        
        // Reset to default parameters
        viewModel.ruleSet.nodes[nodeIndex].data = NodeData.defaultForType(node.type)
        viewModel.ruleSet.updateTimestamp()
    }
}

// MARK: - Parameter Editor

struct ParameterEditor: View {
    let key: String
    let parameter: NodeParameter
    let onUpdate: (ParameterValue) -> Void
    
    @State private var stringValue: String = ""
    @State private var intValue: Double = 0
    @State private var arrayValue: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(parameterName(key))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            switch parameter.type {
            case .string:
                if let options = parameter.options {
                    Picker("", selection: stringBinding) {
                        ForEach(options, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    TextField("Enter value", text: stringBinding)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                }
                
            case .integer:
                if let range = parameter.range {
                    Slider(value: intBinding, in: range, step: 1) {
                        Text(String(Int(intValue)))
                    }
                } else {
                    TextField("0", value: intBinding, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                }
                
            case .float:
                TextField("0.0", value: floatBinding, format: .number.precision(.fractionLength(2)))
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                
            case .boolean:
                Toggle("", isOn: boolBinding)
                    .toggleStyle(.switch)
                
            case .array, .dictionary:
                // Simple editor for complex types
                TextEditor(text: arrayBinding)
                    .frame(height: 60)
                    .font(.caption.monospaced())
                    .background(Color(.textBackgroundColor))
                    .cornerRadius(6)
            }
        }
    }
    
    private var binding: Binding<ParameterValue> {
        Binding(
            get: { parameter.value },
            set: { onUpdate($0) }
        )
    }
    
    private var stringBinding: Binding<String> {
        Binding(
            get: {
                switch parameter.value {
                case .string(let string): return string
                default: return ""
                }
            },
            set: { onUpdate(.string($0)) }
        )
    }
    
    private var intBinding: Binding<Double> {
        Binding(
            get: {
                switch parameter.value {
                case .integer(let int): return Double(int)
                case .float(let float): return float
                default: return 0
                }
            },
            set: { onUpdate(.integer(Int($0))) }
        )
    }
    
    private var floatBinding: Binding<Double> {
        Binding(
            get: {
                switch parameter.value {
                case .integer(let int): return Double(int)
                case .float(let float): return float
                default: return 0
                }
            },
            set: { onUpdate(.float($0)) }
        )
    }
    
    private var boolBinding: Binding<Bool> {
        Binding(
            get: {
                switch parameter.value {
                case .boolean(let bool): return bool
                default: return false
                }
            },
            set: { onUpdate(.boolean($0)) }
        )
    }
    
    private var arrayBinding: Binding<String> {
        Binding(
            get: {
                switch parameter.value {
                case .array(let array):
                    return array.map { element in
                        switch element {
                        case .string(let string): return "\"\(string)\""
                        default: return String(describing: element)
                        }
                    }.joined(separator: ",\n")
                default:
                    return ""
                }
            },
            set: { newValue in
                // Simple parsing - in production would use proper JSON parsing
                let elements = newValue.split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .map { ParameterValue.string(String($0).trimmingCharacters(in: CharacterSet(charactersIn: "\""))) }
                onUpdate(.array(elements))
            }
        )
    }
    
    private func parameterName(_ key: String) -> String {
        return key.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

// MARK: - NLP Configuration Section

struct NLPConfigSection: View {
    let node: RuleNode
    let viewModel: RulesViewModel
    
    var body: some View {
        if node.category == .nlpRules {
            VStack(alignment: .leading, spacing: 12) {
                Text("NLP Configuration")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                switch node.type {
                case .conditionNLP:
                    NLPConditionConfig(node: node)
                case .classifyIntent:
                    IntentClassifierConfig(node: node)
                case .extractEntities:
                    EntityExtractorConfig(node: node)
                case .sentimentAnalysis:
                    SentimentAnalysisConfig(node: node)
                default:
                    EmptyView()
                }
            }
        }
    }
}

struct NLPConditionConfig: View {
    let node: RuleNode
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Natural Language Condition")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if let pattern = node.data.parameters["pattern"]?.value.asString {
                Text("\"\(pattern)\"")
                    .font(.caption.monospaced())
                    .padding(8)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(6)
            }
            
            if let confidence = node.data.parameters["confidence_threshold"]?.value.asFloat {
                HStack {
                    Text("Confidence Threshold:")
                        .font(.caption)
                    Spacer()
                    Text(String(format: "%.1f", confidence))
                        .font(.caption.monospaced())
                }
            }
        }
    }
}

struct IntentClassifierConfig: View {
    let node: RuleNode
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Intent Classification")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 12) {
                IntentOutputPort(name: "code", color: .blue)
                IntentOutputPort(name: "general", color: .green)
                IntentOutputPort(name: "creative", color: .purple)
                IntentOutputPort(name: "analytical", color: .orange)
            }
        }
    }
}

struct EntityExtractorConfig: View {
    let node: RuleNode
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Entity Extraction")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if let entities = node.data.parameters["entity_types"]?.value.asArray {
                HStack {
                    ForEach(entities.map { $0.asString ?? "" }, id: \.self) { entity in
                        Text(entity)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
            }
        }
    }
}

struct SentimentAnalysisConfig: View {
    let node: RuleNode
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Sentiment Analysis")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 8) {
                Circle().fill(Color.green).frame(width: 8)
                Text("Positive").font(.caption2)
                
                Circle().fill(Color.red).frame(width: 8)
                Text("Negative").font(.caption2)
                
                Circle().fill(Color.gray).frame(width: 8)
                Text("Neutral").font(.caption2)
            }
        }
    }
}

struct IntentOutputPort: View {
    let name: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
            
            Text(name)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Parameter Value Extensions

extension ParameterValue {
    var asString: String? {
        switch self {
        case .string(let value): return value
        default: return nil
        }
    }
    
    var asInt: Int? {
        switch self {
        case .integer(let value): return value
        default: return nil
        }
    }
    
    var asFloat: Double? {
        switch self {
        case .float(let value): return value
        case .integer(let value): return Double(value)
        default: return nil
        }
    }
    
    var asBool: Bool? {
        switch self {
        case .boolean(let value): return value
        default: return nil
        }
    }
    
    var asArray: [ParameterValue]? {
        switch self {
        case .array(let value): return value
        default: return nil
        }
    }
}
