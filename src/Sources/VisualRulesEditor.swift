import SwiftUI

@available(macOS 14.0, *)
struct VisualRulesEditor: View {
    @StateObject private var viewModel = RulesViewModel()
    @State private var isExpanded = false
    @State private var showExpandButton = true
    @StateObject private var serverManager: ServerManager
    
    // Animation state
    @State private var sidebarOffset: CGFloat = -240
    @State private var configOffset: CGFloat = 300
    @State private var isAnimating = false
    
    init(serverManager: ServerManager) {
        self._serverManager = StateObject(wrappedValue: serverManager)
    }
    
    var body: some View {
        Group {
            if isExpanded {
                expandedRulesEditor
            } else {
                compactRulesEditor
            }
        }
        .onReceive(viewModel.$selectedNodeId) { nodeId in
            // Auto-expand config panel when node is selected
            if nodeId != nil && !isExpanded {
                withAnimation(.easeInOut(duration: 0.3)) {
                    configOffset = 0
                }
            }
        }
    }
    
    // MARK: - Compact Rules Editor (Default)
    
    private var compactRulesEditor: some View {
        NavigationStack {
            ZStack(alignment: .leading) {
                // Main content area
                HStack(spacing: 0) {
                    // Main canvas (flexible, fills available space)
                    RuleCanvas(viewModel: viewModel)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .overlay(
                            // Toggle sidebar button
                            VStack {
                                HStack {
                                    Button(action: toggleSidebar) {
                                        Image(systemName: sidebarOffset < 0 ? "sidebar.left" : "sidebar.left")
                                            .font(.system(size: 14))
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.leading, 8)
                                    Spacer()
                                }
                                Spacer()
                            }
                            .allowsHitTesting(true)
                        )
                    
                    // Right config panel (slide-in)
                    if viewModel.showConfigPanel {
                        NodeConfigPanel(viewModel: viewModel) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                configOffset = 300
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    viewModel.showConfigPanel = false
                                }
                            }
                        }
                        .offset(x: configOffset)
                        .animation(.easeInOut(duration: 0.3), value: configOffset)
                    }
                }
                
                // Left palette (overlay, collapsible)
                RulePalette(viewModel: viewModel)
                    .offset(x: sidebarOffset)
                    .animation(.easeInOut(duration: 0.3), value: sidebarOffset)
                    .zIndex(1)
            }
            .navigationTitle("Visual Rules")
            .toolbar {
                ToolbarItemGroup(placement: .cancellationAction) {
                    Button(action: { viewModel.importRules() }) {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .help("Import Rules")
                    
                    Button(action: { viewModel.exportRules() }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .help("Export Rules")
                    
                    Button("Close") {
                        // Close action handled by parent
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button(action: expandToFullView) {
                        HStack {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                            Text("Expand")
                        }
                    }
                }
            }
        }
        .frame(minWidth: 800, minHeight: 600)
    }
    
    // MARK: - Expanded Rules Editor (Full Window)
    
    private var expandedRulesEditor: some View {
        NavigationStack {
            HSplitView {
                // Left palette (always visible)
                RulePalette(viewModel: viewModel)
                
                // Main canvas (expanded, fills remaining space)
                RuleCanvas(viewModel: viewModel)
                
                // Right config panel (always visible)
                NodeConfigPanel(viewModel: viewModel) {
                    // In expanded mode, config panel doesn't disappear
                }
            }
            .navigationTitle("Visual Rules Editor")
            .toolbar {
                ToolbarItemGroup(placement: .cancellationAction) {
                    Button(action: { viewModel.importRules() }) {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .help("Import Rules")
                    
                    Button(action: { viewModel.exportRules() }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .help("Export Rules")
                    
                    Button("Close") {
                        collapseToCompactView()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button(action: collapseToCompactView) {
                        HStack {
                            Image(systemName: "arrow.down.right.and.arrow.up.left")
                            Text("Compact")
                        }
                    }
                }
                
                // Additional toolbar items for expanded mode
                ToolbarItemGroup {
                    Menu("File") {
                        Button("New Rule Set") { viewModel.createNewRuleSet() }
                        Button("Save") { viewModel.saveRules() }
                    }
                    
                    Menu("View") {
                        Button("Fit to Screen") { viewModel.fitToScreen() }
                        Button("Center on Nodes") { viewModel.centerOnNodes() }
                        Button("Toggle Grid") { viewModel.toggleGrid() }
                        Button("Toggle Minimap") { viewModel.toggleMinimap() }
                    }
                    
                    Button("Validate") {
                        let errors = viewModel.validateRules()
                        if !errors.isEmpty {
                            showValidationErrors(errors)
                        }
                    }
                }
            }
        }
        .frame(minWidth: 1200, minHeight: 800)
    }
    
    // MARK: - Actions
    
    private func expandToFullView() {
        withAnimation(.easeInOut(duration: 0.4)) {
            isExpanded = true
            sidebarOffset = 0
            configOffset = 0
        }
    }
    
    private func collapseToCompactView() {
        withAnimation(.easeInOut(duration: 0.4)) {
            isExpanded = false
            if !viewModel.showConfigPanel {
                configOffset = 300
            }
        }
    }
    
    private func toggleSidebar() {
        withAnimation(.easeInOut(duration: 0.3)) {
            sidebarOffset = sidebarOffset < 0 ? 0 : -240
        }
    }
}

// MARK: - RulesViewModel Extensions

extension RulesViewModel {
    func createNewRuleSet() {
        ruleSet = RuleSet(name: "New Rule Set")
        updateObservableNodes()
    }
    
    func fitToScreen() {
        // Implementation for fitting all nodes to screen
    }
    
    func centerOnNodes() {
        // Implementation for centering on nodes
    }
    
    func toggleGrid() {
        // Implementation for toggling grid visibility
    }
    
    func toggleMinimap() {
        // Implementation for toggling minimap
    }
}

// MARK: - Helper function for showing validation errors

func showValidationErrors(_ errors: [RuleValidationError]) {
    // Show validation errors in dialog or panel
}

// MARK: - Preview

@available(macOS 14.0, *)
struct VisualRulesEditor_Previews: PreviewProvider {
    static var previews: some View {
        let serverManager = ServerManager()
        
        VisualRulesEditor(serverManager: serverManager)
            .frame(width: 800, height: 600)
    }
}

// MARK: - Enhanced Connection Type

extension RuleSet {
    struct Connection: Identifiable, Codable, Hashable {
        let id: String
        var fromNodeId: String
        var fromPortId: String
        var toNodeId: String
        var toPortId: String
        var isHighlighted: Bool = false
        var color: String? = nil
        
        init(fromNodeId: String, fromPortId: String, toNodeId: String, toPortId: String) {
            self.id = UUID().uuidString
            self.fromNodeId = fromNodeId
            self.fromPortId = fromPortId
            self.toNodeId = toNodeId
            self.toPortId = toPortId
        }
    }
}

// MARK: - NLP Rule Templates

extension RuleNode {
    static func createNLPTemplate(templateType: NLPTemplateType, at position: CGPoint) -> RuleNode {
        switch templateType {
        case .intentRouting:
            return createIntentRoutingTemplate(at: position)
        case .keywordTrigger:
            return createKeywordTriggerTemplate(at: position)
        case .entityExtraction:
            return createEntityExtractionTemplate(at: position)
        case .sentimentRouting:
            return createSentimentRoutingTemplate(at: position)
        }
    }
    
    private static func createIntentRoutingTemplate(at position: CGPoint) -> RuleNode {
        var node = RuleNode(type: NodeType.classifyIntent, position: position)
        
        // Configure with sensible defaults
        node.data.parameters = [
            "model": NodeParameter(
                value: .string("gpt-4"),
                type: .string,
                options: ["gpt-4", "gpt-3.5-turbo", "claude-3"]
            ),
            "confidence_threshold": NodeParameter(
                value: .float(0.7),
                type: .float,
                range: 0.0...1.0
            ),
            "output_ports": NodeParameter(
                value: .array([.string("code"), .string("general"), .string("creative"), .string("analytical")]),
                type: .array
            )
        ]
        
        node.name = "Intent Router"
        node.description = "Routes requests based on detected intent"
        
        return node
    }
    
    private static func createKeywordTriggerTemplate(at position: CGPoint) -> RuleNode {
        var node = RuleNode(type: NodeType.conditionNLP, position: position)
        
        node.data.parameters = [
            "rule_type": NodeParameter(
                value: .string("keyword_match"),
                type: .string,
                options: ["keyword_match", "regex_match", "semantic_match"]
            ),
            "keywords": NodeParameter(
                value: .array([.string("function"), .string("class"), .string("variable")]),
                type: .array
            ),
            "match_type": NodeParameter(
                value: .string("any"),
                type: .string,
                options: ["any", "all"]
            ),
            "case_sensitive": NodeParameter(
                value: .boolean(false),
                type: .boolean
            )
        ]
        
        node.name = "Keyword Trigger"
        node.description = "Triggers when specific keywords are detected"
        
        return node
    }
    
    private static func createEntityExtractionTemplate(at position: CGPoint) -> RuleNode {
        var node = RuleNode(type: NodeType.extractEntities, position: position)
        
        node.data.parameters = [
            "entity_types": NodeParameter(
                value: .array([.string("language"), .string("framework"), .string("task")]),
                type: .array
            ),
            "extraction_model": NodeParameter(
                value: .string("spacy"),
                type: .string,
                options: ["spacy", "regex", "nltk"]
            ),
            "confidence_threshold": NodeParameter(
                value: .float(0.6),
                type: .float,
                range: 0.0...1.0
            ),
            "output_format": NodeParameter(
                value: .string("json"),
                type: .string,
                options: ["json", "key_value", "list"]
            )
        ]
        
        node.name = "Entity Extractor"
        node.description = "Extracts structured entities from text"
        
        return node
    }
    
    private static func createSentimentRoutingTemplate(at position: CGPoint) -> RuleNode {
        var node = RuleNode(type: NodeType.sentimentAnalysis, position: position)
        
        node.data.parameters = [
            "sentiment_threshold": NodeParameter(
                value: .float(0.6),
                type: .float,
                range: 0.0...1.0
            ),
            "analysis_model": NodeParameter(
                value: .string("vader"),
                type: .string,
                options: ["vader", "textblob", "transformers"]
            ),
            "neutral_threshold": NodeParameter(
                value: .float(0.4),
                type: .float,
                range: 0.0...1.0
            ),
            "output_sentiment_score": NodeParameter(
                value: .boolean(true),
                type: .boolean
            )
        ]
        
        node.name = "Sentiment Router"
        node.description = "Routes based on sentiment analysis"
        
        return node
    }
}

enum NLPTemplateType: String, CaseIterable {
    case intentRouting = "Intent Routing"
    case keywordTrigger = "Keyword Trigger"
    case entityExtraction = "Entity Extraction"
    case sentimentRouting = "Sentiment Routing"
    
    var description: String {
        switch self {
        case .intentRouting: return "Route requests by detected intent (code/general/creative)"
        case .keywordTrigger: return "Trigger on specific keywords or patterns"
        case .entityExtraction: return "Extract entities like languages, frameworks, tasks"
        case .sentimentRouting: return "Route based on sentiment (positive/negative/neutral)"
        }
    }
}
