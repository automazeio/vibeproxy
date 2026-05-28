import SwiftUI
import Combine

// MARK: - Node Types and Categories

enum FlowNodeType: String, CaseIterable, Codable {
    // Universal Service Routing
    case universalServiceRouter = "universal_service_router"
    
    // Triggers
    case httpTrigger = "http_trigger"
    case scheduledTrigger = "scheduled_trigger"
    case webhookTrigger = "webhook_trigger"
    case fileEventTrigger = "file_event_trigger"
    
    // NLP Rules (Expanded)
    case intentClassification = "intent_classification"
    case entityExtraction = "entity_extraction"
    case sentimentAnalysis = "sentiment_analysis"
    case keywordMatch = "keyword_match"
    case semanticSimilarity = "semantic_similarity"
    case languageDetection = "language_detection"
    case codePatternMatch = "code_pattern_match"
    case frameworkDetection = "framework_detection"
    
    // Service Conditions (Universal)
    case serviceHealth = "service_health"
    case modelAvailability = "model_availability"
    case serviceLoadBalance = "service_load_balance"
    case costOptimization = "cost_optimization"
    case latencyOptimization = "latency_optimization"
    case quotaManagement = "quota_management"
    
    // Provider-Specific Conditions (dynamically generated from discovered services)
    
    // Logic Operations
    case andCondition = "and_condition"
    case orCondition = "or_condition"
    case notCondition = "not_condition"
    case xorCondition = "xor_condition"
    case compareValues = "compare_values"
    case regexMatch = "regex_match"
    
    // Data Processing
    case extractJSON = "extract_json"
    case transformData = "transform_data"
    case validateData = "validate_data"
    case mergeData = "merge_data"
    case splitData = "split_data"
    case calculateExpression = "calculate_expression"
    
    // Universal Actions
    case routeToService = "route_to_service"
    case routeToModel = "route_to_model"
    case serviceFailover = "service_failover"
    case loadBalanceServices = "load_balance_services"
    case cacheResponse = "cache_response"
    case logging = "logging"
    case monitoring = "monitoring"
    
    // Provider-Specific Actions (dynamically generated from discovered services)
    
    // Control Flow
    case delayExecution = "delay_execution"
    case retryExecution = "retry_execution"
    case parallelExecution = "parallel_execution"
    case conditionalBranch = "conditional_branch"
    case loopExecution = "loop_execution"
    
    // External Integration
    case webhookCall = "webhook_call"
    case databaseQuery = "database_query"
    case apiCall = "api_call"
    case emailNotification = "email_notification"
    
    var category: FlowNodeCategory {
        switch self {
        case .universalServiceRouter: return .routing
        case .httpTrigger, .scheduledTrigger, .webhookTrigger, .fileEventTrigger: return .triggers
        case .intentClassification, .entityExtraction, .sentimentAnalysis, .keywordMatch,
             .semanticSimilarity, .languageDetection, .codePatternMatch, .frameworkDetection: return .nlp
        case .serviceHealth, .modelAvailability, .serviceLoadBalance, .costOptimization,
             .latencyOptimization, .quotaManagement: return .conditions
        case .andCondition, .orCondition, .notCondition, .xorCondition,
             .compareValues, .regexMatch: return .logic
        case .extractJSON, .transformData, .validateData, .mergeData,
             .splitData, .calculateExpression: return .data
        case .routeToService, .routeToModel, .serviceFailover, .loadBalanceServices,
             .cacheResponse, .logging, .monitoring: return .actions
        case .delayExecution, .retryExecution, .parallelExecution, .conditionalBranch,
             .loopExecution: return .control
        case .webhookCall, .databaseQuery, .apiCall, .emailNotification: return .integration
        }
    }
    
    var displayName: String {
        switch self {
        case .universalServiceRouter: return "Universal Service Router"
        case .httpTrigger: return "HTTP Trigger"
        case .scheduledTrigger: return "Scheduled Trigger"
        case .webhookTrigger: return "Webhook Trigger"
        case .fileEventTrigger: return "File Event"
        
        case .intentClassification: return "Intent Classification"
        case .entityExtraction: return "Entity Extraction"
        case .sentimentAnalysis: return "Sentiment Analysis"
        case .keywordMatch: return "Keyword Match"
        case .semanticSimilarity: return "Semantic Similarity"
        case .languageDetection: return "Language Detection"
        case .codePatternMatch: return "Code Pattern Match"
        case .frameworkDetection: return "Framework Detection"
        
        case .serviceHealth: return "Service Health Check"
        case .modelAvailability: return "Model Availability"
        case .serviceLoadBalance: return "Load Balance Services"
        case .costOptimization: return "Cost Optimization"
        case .latencyOptimization: return "Latency Optimization"
        case .quotaManagement: return "Quota Management"

        case .andCondition: return "AND Condition"
        case .orCondition: return "OR Condition"
        case .notCondition: return "NOT Condition"
        case .xorCondition: return "XOR Condition"
        case .compareValues: return "Compare Values"
        case .regexMatch: return "Regex Match"
        
        case .extractJSON: return "Extract JSON"
        case .transformData: return "Transform Data"
        case .validateData: return "Validate Data"
        case .mergeData: return "Merge Data"
        case .splitData: return "Split Data"
        case .calculateExpression: return "Calculate Expression"
        
        case .routeToService: return "Route to Service"
        case .routeToModel: return "Route to Model"
        case .serviceFailover: return "Service Failover"
        case .loadBalanceServices: return "Load Balance"
        case .cacheResponse: return "Cache Response"
        case .logging: return "Logging"
        case .monitoring: return "Monitoring"

        case .delayExecution: return "Delay Execution"
        case .retryExecution: return "Retry Execution"
        case .parallelExecution: return "Parallel Execution"
        case .conditionalBranch: return "Conditional Branch"
        case .loopExecution: return "Loop Execution"
        
        case .webhookCall: return "Webhook Call"
        case .databaseQuery: return "Database Query"
        case .apiCall: return "API Call"
        case .emailNotification: return "Email Notification"
        }
    }
    
    var defaultDescription: String {
        switch self {
        case .universalServiceRouter: return "Route between ALL available services discovered from CLIProxyAPI"
        case .httpTrigger: return "Trigger on HTTP requests to specific endpoints"
        case .scheduledTrigger: return "Trigger on scheduled time intervals"
        case .webhookTrigger: return "Trigger on external webhook events"
        case .fileEventTrigger: return "Trigger on file system events"
        
        case .intentClassification: return "Classify user intent for intelligent routing"
        case .entityExtraction: return "Extract entities (languages, frameworks, tasks)"
        case .sentimentAnalysis: return "Analyze sentiment for routing decisions"
        case .keywordMatch: return "Match specific keywords in text"
        case .semanticSimilarity: return "Find semantically similar content"
        case .languageDetection: return "Detect programming or natural language"
        case .codePatternMatch: return "Match code patterns and structures"
        case .frameworkDetection: return "Detect programming frameworks"
        
        case .serviceHealth: return "Check if services are healthy and available"
        case .modelAvailability: return "Check if specific models are available"
        case .serviceLoadBalance: return "Balance load across multiple services"
        case .costOptimization: return "Optimize for lowest cost routing"
        case .latencyOptimization: return "Optimize for lowest latency routing"
        case .quotaManagement: return "Manage and check service quotas"

        case .andCondition: return "Logical AND operation on inputs"
        case .orCondition: return "Logical OR operation on inputs"
        case .notCondition: return "Logical NOT operation on input"
        case .xorCondition: return "Logical XOR operation on inputs"
        case .compareValues: return "Compare values with various operators"
        case .regexMatch: return "Match text against regular expressions"
        
        case .extractJSON: return "Extract specific fields from JSON data"
        case .transformData: return "Transform data format and structure"
        case .validateData: return "Validate data against schema or rules"
        case .mergeData: return "Merge multiple data sources"
        case .splitData: return "Split data into multiple streams"
        case .calculateExpression: return "Calculate mathematical expressions"
        
        case .routeToService: return "Route request to specific service"
        case .routeToModel: return "Route request to specific model"
        case .serviceFailover: return "Implement failover logic between services"
        case .loadBalanceServices: return "Distribute load across services"
        case .cacheResponse: return "Cache responses for future use"
        case .logging: return "Log request and response data"
        case .monitoring: return "Monitor and track execution metrics"

        case .delayExecution: return "Add delay before next execution"
        case .retryExecution: return "Retry execution on failure"
        case .parallelExecution: return "Execute multiple paths in parallel"
        case .conditionalBranch: return "Branch execution based on conditions"
        case .loopExecution: return "Loop execution for multiple items"
        
        case .webhookCall: return "Make HTTP webhook calls"
        case .databaseQuery: return "Execute database queries"
        case .apiCall: return "Make API calls to external services"
        case .emailNotification: return "Send email notifications"
        }
    }
    
    var icon: String {
        switch self {
        case .universalServiceRouter: return "network"
        case .httpTrigger: return "globe"
        case .scheduledTrigger: return "clock"
        case .webhookTrigger: return "link"
        case .fileEventTrigger: return "folder"
        
        case .intentClassification: return "brain"
        case .entityExtraction: return "viewfinder"
        case .sentimentAnalysis: return "face.smiling"
        case .keywordMatch: return "textformat"
        case .semanticSimilarity: return "arrow.triangle.2.circlepath"
        case .languageDetection: return "globe.americas"
        case .codePatternMatch: return "curlybraces"
        case .frameworkDetection: return "building.columns"
        
        case .serviceHealth: return "heart.fill"
        case .modelAvailability: return "checkmark.circle"
        case .serviceLoadBalance: return "scalemass.fill"
        case .costOptimization: return "dollarsign.circle"
        case .latencyOptimization: return "speedometer"
        case .quotaManagement: return "chart.bar.fill"

        case .andCondition: return "plus.app"
        case .orCondition: return "plus"
        case .notCondition: return "minus.circle"
        case .xorCondition: return "divide"
        case .compareValues: return "lessthan"
        case .regexMatch: return "textformat.abc"
        
        case .extractJSON: return "doc.text.magnifyingglass"
        case .transformData: return "arrow.triangle.2.circlepath"
        case .validateData: return "checkmark.shield"
        case .mergeData: return "rectangle.on.rectangle"
        case .splitData: return "square.split.2x2"
        case .calculateExpression: return "function"
        
        case .routeToService: return "arrow.right.circle"
        case .routeToModel: return "brain"
        case .serviceFailover: return "arrow.clockwise"
        case .loadBalanceServices: return "scalemass"
        case .cacheResponse: return "externaldrive"
        case .logging: return "doc.text"
        case .monitoring: return "chart.line.uptrend.xyaxis"

        case .delayExecution: return "clock.badge"
        case .retryExecution: return "arrow.clockwise"
        case .parallelExecution: return "square.stack.3d.up.right"
        case .conditionalBranch: return "arrow.triangle.branch"
        case .loopExecution: return "arrow.clockwise"
        
        case .webhookCall: return "network"
        case .databaseQuery: return "externaldrive.fill"
        case .apiCall: return "globe.americas"
        case .emailNotification: return "envelope"
        }
    }
}

// MARK: - Node Categories

enum FlowNodeCategory: String, CaseIterable, Codable {
    case routing = "Routing"
    case triggers = "Triggers"
    case nlp = "NLP Rules"
    case conditions = "Conditions"
    case logic = "Logic"
    case data = "Data Processing"
    case actions = "Actions"
    case control = "Control Flow"
    case integration = "Integration"
    
    var color: Color {
        switch self {
        case .routing: return .purple
        case .triggers: return .blue
        case .nlp: return .green
        case .conditions: return .orange
        case .logic: return .red
        case .data: return .indigo
        case .actions: return .mint
        case .control: return .pink
        case .integration: return .teal
        }
    }
}

// MARK: - Port Types

enum FlowPortType: String, Codable {
    case input = "input"
    case output = "output"
}

// MARK: - Flow Node

struct FlowNode: Identifiable, Codable, Equatable {
    let id: String
    var type: FlowNodeType
    var position: CGPoint
    var config: NodeConfiguration
    var isEnabled: Bool = true
    var inputs: [FlowPort]
    var outputs: [FlowPort]
    
    init(type: FlowNodeType, position: CGPoint = .zero) {
        self.id = UUID().uuidString
        self.type = type
        self.position = position
        self.config = NodeConfiguration.defaultForType(type)
        self.inputs = Self.defaultInputs(for: type)
        self.outputs = Self.defaultOutputs(for: type)
    }
    
    static func defaultInputs(for type: FlowNodeType) -> [FlowPort] {
        switch type {
        case .httpTrigger, .scheduledTrigger, .webhookTrigger, .fileEventTrigger:
            return []
        default:
            return [FlowPort(id: UUID().uuidString, name: "input")]
        }
    }
    
    static func defaultOutputs(for type: FlowNodeType) -> [FlowPort] {
        switch type {
        case .andCondition, .orCondition, .xorCondition:
            return [FlowPort(id: UUID().uuidString, name: "result")]
        case .notCondition:
            return [FlowPort(id: UUID().uuidString, name: "result")]
        case .compareValues:
            return [
                FlowPort(id: UUID().uuidString, name: "true"),
                FlowPort(id: UUID().uuidString, name: "false")
            ]
        case .conditionalBranch:
            return [
                FlowPort(id: UUID().uuidString, name: "branch_1"),
                FlowPort(id: UUID().uuidString, name: "branch_2")
            ]
        case .intentClassification:
            return [
                FlowPort(id: UUID().uuidString, name: "code"),
                FlowPort(id: UUID().uuidString, name: "qa"),
                FlowPort(id: UUID().uuidString, name: "creative"),
                FlowPort(id: UUID().uuidString, name: "analytical")
            ]
        default:
            return [FlowPort(id: UUID().uuidString, name: "output")]
        }
    }
    
    static func == (lhs: FlowNode, rhs: FlowNode) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Flow Port

struct FlowPort: Identifiable, Codable, Hashable, Equatable {
    let id: String
    var name: String
    var dataType: PortDataType = .any
    var isConnected: Bool = false
    
    init(id: String, name: String, dataType: PortDataType = .any) {
        self.id = id
        self.name = name
        self.dataType = dataType
    }
    
    static func == (lhs: FlowPort, rhs: FlowPort) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Port Data Types

enum PortDataType: String, Codable {
    case any = "any"
    case text = "text"
    case number = "number"
    case boolean = "boolean"
    case json = "json"
    case array = "array"
}

// MARK: - Node Configuration

struct NodeConfiguration: Codable, Equatable {
    var description: String?
    var priority: Int?
    var timeout: Int?
    var retries: Int?
    var notes: String?
    
    // NLP-specific
    var confidenceThreshold: Double?
    var keywords: [String]?
    var entities: [String]?
    var pattern: String?
    
    // Service-specific
    var targetService: String?
    var targetModel: String?
    var fallbackServices: [String]?
    
    // HTTP-specific
    var method: String?
    var path: String?
    var headers: [String: String]?
    
    // Data-specific
    var transformation: String?
    var expression: String?
    var schema: String?
    
    // Control-specific
    var delay: Double?
    var maxRetries: Int?
    var loopCount: Int?
    
    static func defaultForType(_ type: FlowNodeType) -> NodeConfiguration {
        switch type {
        case .httpTrigger:
            return NodeConfiguration(
                timeout: 5000,
                method: "POST",
                path: "/api/chat"
            )
        case .intentClassification:
            return NodeConfiguration(
                priority: 1,
                confidenceThreshold: 0.7
            )
        case .routeToService:
            return NodeConfiguration(
                timeout: 5000,
                targetService: "claude",
                fallbackServices: ["openai", "gemini"]
            )
        case .delayExecution:
            return NodeConfiguration(delay: 1.0)
        default:
            return NodeConfiguration()
        }
    }
    
    static func == (lhs: NodeConfiguration, rhs: NodeConfiguration) -> Bool {
        // Simplified equality for now
        lhs.description == rhs.description &&
        lhs.priority == rhs.priority &&
        lhs.targetService == rhs.targetService
    }
}

// MARK: - Connection

struct FlowConnection: Identifiable, Codable, Hashable, Equatable {
    let id: String
    var fromNodeId: String
    var fromPortId: String
    var toNodeId: String
    var toPortId: String
    var condition: String?
    
    init(fromNodeId: String, fromPortId: String, toNodeId: String, toPortId: String) {
        self.id = UUID().uuidString
        self.fromNodeId = fromNodeId
        self.fromPortId = fromPortId
        self.toNodeId = toNodeId
        self.toPortId = toPortId
    }
    
    static func == (lhs: FlowConnection, rhs: FlowConnection) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Graph Validation

struct FlowValidationError: Identifiable, Equatable {
    let id: String
    let type: ValidationErrorType
    let nodeIds: [String]
    let message: String
    let severity: ValidationSeverity
    
    enum ValidationErrorType: String, Codable {
        case orphanedNode = "orphaned_node"
        case missingTrigger = "missing_trigger"
        case invalidConnection = "invalid_connection"
        case circularDependency = "circular_dependency"
        case missingDestination = "missing_destination"
        case invalidPort = "invalid_port"
        case missingConfiguration = "missing_configuration"
    }
    
    enum ValidationSeverity: String, Codable {
        case error = "error"
        case warning = "warning"
        case info = "info"
    }
    
    static func == (lhs: FlowValidationError, rhs: FlowValidationError) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Node Graph View Model

@MainActor
class NodeGraphViewModel: ObservableObject {
    @Published var nodes: [FlowNode] = []
    @Published var connections: [FlowConnection] = []
    @Published var selectedNodeId: String?
    @Published var selectedConnectionId: String?
    
    struct ConnectionStart {
        let nodeId: String
        let portId: String
    }
    var connectionStart: ConnectionStart?
    
    // Undo/Redo support
    private var undoStack: [[FlowNode]] = []
    private var redoStack: [[FlowNode]] = []
    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }
    
    init() {
        loadGraph()
    }
    
    func addNode(type: FlowNodeType, at position: CGPoint) {
        saveState()
        let node = FlowNode(type: type, position: position)
        nodes.append(node)
    }
    
    func deleteNode(_ nodeId: String) {
        saveState()
        connections.removeAll { $0.fromNodeId == nodeId || $0.toNodeId == nodeId }
        nodes.removeAll { $0.id == nodeId }
        if selectedNodeId == nodeId {
            selectedNodeId = nil
        }
    }
    
    func updateNode(_ node: FlowNode) {
        saveState()
        if let index = nodes.firstIndex(where: { $0.id == node.id }) {
            nodes[index] = node
        }
    }
    
    func moveNode(_ nodeId: String, by translation: CGSize) {
        if let index = nodes.firstIndex(where: { $0.id == nodeId }) {
            nodes[index].position.x += translation.width
            nodes[index].position.y += translation.height
        }
    }
    
    func startConnection(from nodeId: String, outputPort: String) {
        connectionStart = ConnectionStart(nodeId: nodeId, portId: outputPort)
    }
    
    func completeConnection(to nodeId: String, inputPort: String) {
        guard let start = connectionStart else { return }
        let connection = FlowConnection(
            fromNodeId: start.nodeId,
            fromPortId: start.portId,
            toNodeId: nodeId,
            toPortId: inputPort
        )
        connections.append(connection)
        connectionStart = nil
    }
    
    func clearGraph() {
        saveState()
        nodes.removeAll()
        connections.removeAll()
        selectedNodeId = nil
    }
    
    func zoomIn() {
        // Implementation for zoom in
    }
    
    func zoomOut() {
        // Implementation for zoom out
    }
    
    func fitToScreen() {
        // Implementation for fit to screen
    }
    
    func validateGraph() -> [FlowValidationError] {
        var errors: [FlowValidationError] = []
        
        // Check for orphaned nodes
        for node in nodes {
            let hasIncoming = connections.contains { $0.toNodeId == node.id }
            let hasOutgoing = connections.contains { $0.fromNodeId == node.id }
            if !hasIncoming && !hasOutgoing && node.type != .httpTrigger {
                errors.append(FlowValidationError(
                    id: UUID().uuidString,
                    type: .orphanedNode,
                    nodeIds: [node.id],
                    message: "Node \(node.id) is not connected",
                    severity: .warning
                ))
            }
        }
        
        // Check for missing trigger
        let hasTrigger = nodes.contains { node in
            switch node.type {
            case .httpTrigger, .scheduledTrigger, .webhookTrigger, .fileEventTrigger:
                return true
            default:
                return false
            }
        }
        if !hasTrigger && !nodes.isEmpty {
            errors.append(FlowValidationError(
                id: UUID().uuidString,
                type: .missingTrigger,
                nodeIds: [],
                message: "Graph should start with a trigger node",
                severity: .error
            ))
        }
        
        return errors
    }
    
    func isGraphValid() -> Bool {
        return validateGraph().isEmpty
    }
    
    func showValidationErrors(_ errors: [FlowValidationError]) {
        // Show validation errors
    }
    
    func exportGraph() {
        // Implementation for export
    }
    
    func importGraph() {
        // Implementation for import
    }
    
    func autoSave() {
        saveGraph()
    }
    
    private func saveState() {
        undoStack.append(nodes)
        redoStack.removeAll()
    }
    
    func undo() {
        guard !undoStack.isEmpty else { return }
        redoStack.append(nodes)
        nodes = undoStack.removeLast()
    }
    
    func redo() {
        guard !redoStack.isEmpty else { return }
        undoStack.append(nodes)
        nodes = redoStack.removeLast()
    }
    
    private func saveGraph() {
        // Save to UserDefaults or file
    }
    
    private func loadGraph() {
        // Load from UserDefaults or file
    }
}

// Note: NodeType, NodeCategory, and PortType are defined separately in RuleModels.swift
// for the Rules system. FlowNodeType, FlowNodeCategory, and FlowPortType are used
// for the Flow/Visual Node Programmer system.

// MARK: - Helper Extensions

// CGPoint and CGSize already conform to Codable in CoreGraphics, so we don't need these extensions
/*
extension CGPoint: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let x = try container.decode(CGFloat.self, forKey: .x)
        let y = try container.decode(CGFloat.self, forKey: .y)
        self.init(x: x, y: y)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(x, forKey: .x)
        try container.encode(y, forKey: .y)
    }
    
    private enum CodingKeys: String, CodingKey {
        case x, y
    }
}

extension CGSize: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let width = try container.decode(CGFloat.self, forKey: .width)
        let height = try container.decode(CGFloat.self, forKey: .height)
        self.init(width: width, height: height)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(width, forKey: .width)
        try container.encode(height, forKey: .height)
    }
    
    private enum CodingKeys: String, CodingKey {
        case width, height
    }
}
*/
