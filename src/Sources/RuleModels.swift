import Foundation
import SwiftUI

// MARK: - Core Rule Types

enum NodeType: String, CaseIterable, Codable {
    // Triggers (Entry Points)
    case triggerHTTP = "trigger_http"
    case triggerScheduled = "trigger_scheduled"
    case triggerWebhook = "trigger_webhook"
    
    // Conditions (Logic)
    case conditionIf = "condition_if"
    case conditionAndOr = "condition_and_or"
    case conditionModelCompare = "condition_model_compare"
    case conditionResourceCheck = "condition_resource_check"
    
    // NLP Rules (Natural Language Processing)
    case conditionNLP = "condition_nlp"
    case transformNLP = "transform_nlp"
    case classifyIntent = "classify_intent"
    case extractEntities = "extract_entities"
    case sentimentAnalysis = "sentiment_analysis"
    
    // Actions (Execution)
    case actionRouteProvider = "action_route_provider"
    case actionCache = "action_cache"
    case actionTransform = "action_transform"
    case actionNotify = "action_notify"
    
    // Data Transforms
    case transformMap = "transform_map"
    case transformValidate = "transform_validate"
    case transformCalculate = "transform_calculate"
}

// MARK: - Node Categories

enum NodeCategory: String, CaseIterable, Codable {
    case triggers = "Triggers"
    case conditions = "Conditions"
    case nlpRules = "NLP Rules"
    case actions = "Actions"
    case transforms = "Data Transforms"
    
    var color: Color {
        switch self {
        case .triggers: return .blue
        case .conditions: return .green
        case .nlpRules: return .purple
        case .actions: return .orange
        case .transforms: return .indigo
        }
    }
    
    var icon: String {
        switch self {
        case .triggers: return "play.circle.fill"
        case .conditions: return "questionmark.circle.fill"
        case .nlpRules: return "brain.head.profile"
        case .actions: return "arrow.forward.circle.fill"
        case .transforms: return "gear.circle.fill"
        }
    }
    
    static let allCategories: [NodeCategory] = [.triggers, .conditions, .nlpRules, .actions, .transforms]
}

// MARK: - Node Data Structures

struct RuleNode: Identifiable, Codable, Equatable {
    let id: String
    var type: NodeType
    var position: CGPoint
    var data: NodeData
    var name: String
    var description: String
    var isEnabled: Bool = true
    
    // Input and output ports
    var inputPorts: [NodePort]
    var outputPorts: [NodePort]
    
    init(type: NodeType, position: CGPoint = .zero) {
        self.id = UUID().uuidString
        self.type = type
        self.position = position
        self.data = NodeData.defaultForType(type)
        self.name = type.defaultName
        self.description = type.defaultDescription
        self.inputPorts = NodePort.defaultInputs(for: type)
        self.outputPorts = NodePort.defaultOutputs(for: type)
    }
    
    var category: NodeCategory {
        switch type {
        case .triggerHTTP, .triggerScheduled, .triggerWebhook:
            return .triggers
        case .conditionIf, .conditionAndOr, .conditionModelCompare, .conditionResourceCheck:
            return .conditions
        case .conditionNLP, .transformNLP, .classifyIntent, .extractEntities, .sentimentAnalysis:
            return .nlpRules
        case .actionRouteProvider, .actionCache, .actionTransform, .actionNotify:
            return .actions
        case .transformMap, .transformValidate, .transformCalculate:
            return .transforms
        }
    }
    
    static func == (lhs: RuleNode, rhs: RuleNode) -> Bool {
        lhs.id == rhs.id
    }
}

struct NodePort: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var type: PortType
    var isConnected: Bool = false
    
    init(name: String, type: PortType) {
        self.id = UUID().uuidString
        self.name = name
        self.type = type
    }
    
    static func defaultInputs(for nodeType: NodeType) -> [NodePort] {
        switch nodeType {
        case .triggerHTTP, .triggerScheduled, .triggerWebhook:
            return []
        case .conditionIf, .conditionAndOr, .conditionModelCompare, .conditionResourceCheck, 
             .conditionNLP, .transformNLP, .classifyIntent, .extractEntities, .sentimentAnalysis:
            return [NodePort(name: "input", type: PortType.input)]
        case .actionRouteProvider, .actionCache, .actionTransform, .actionNotify,
             .transformMap, .transformValidate, .transformCalculate:
            return [NodePort(name: "input", type: PortType.input)]
        }
    }
    
    static func defaultOutputs(for nodeType: NodeType) -> [NodePort] {
        switch nodeType {
        case .triggerHTTP, .triggerScheduled, .triggerWebhook:
            return [NodePort(name: "output", type: PortType.output)]
        case .conditionIf:
            return [
                NodePort(name: "true", type: PortType.output),
                NodePort(name: "false", type: PortType.output)
            ]
        case .conditionAndOr:
            return [NodePort(name: "result", type: PortType.output)]
        case .conditionModelCompare, .conditionResourceCheck:
            return [
                NodePort(name: "match", type: PortType.output),
                NodePort(name: "no_match", type: PortType.output)
            ]
        case .conditionNLP, .transformNLP:
            return [NodePort(name: "result", type: PortType.output)]
        case .classifyIntent:
            return [
                NodePort(name: "code", type: PortType.output),
                NodePort(name: "general", type: PortType.output),
                NodePort(name: "creative", type: PortType.output),
                NodePort(name: "analytical", type: PortType.output)
            ]
        case .extractEntities:
            return [NodePort(name: "entities", type: PortType.output)]
        case .sentimentAnalysis:
            return [
                NodePort(name: "positive", type: PortType.output),
                NodePort(name: "negative", type: PortType.output),
                NodePort(name: "neutral", type: PortType.output)
            ]
        case .actionRouteProvider, .actionCache, .actionTransform, .actionNotify:
            return [NodePort(name: "output", type: PortType.output)]
        case .transformMap, .transformValidate, .transformCalculate:
            return [NodePort(name: "result", type: PortType.output)]
        }
    }
}

enum PortType: String, Codable {
    case input = "input"
    case output = "output"
}

// MARK: - Node Configuration Data

struct NodeData: Codable, Equatable {
    var parameters: [String: NodeParameter]
    var notes: String = ""
    
    init(parameters: [String: NodeParameter] = [:]) {
        self.parameters = parameters
    }
    
    static func defaultForType(_ type: NodeType) -> NodeData {
        switch type {
        case .triggerHTTP:
            return NodeData(parameters: [
                "method": NodeParameter(value: .string("POST"), type: .string, options: ["GET", "POST", "PUT", "DELETE"]),
                "path": NodeParameter(value: .string("/api/chat"), type: .string),
                "headers": NodeParameter(value: .dictionary(["Content-Type": .string("application/json")]), type: .dictionary)
            ])
        case .conditionModelCompare:
            return NodeData(parameters: [
                "model_field": NodeParameter(value: .string("model"), type: .string),
                "operator": NodeParameter(value: .string("equals"), type: .string, options: ["equals", "not_equals", "contains", "regex"]),
                "target_model": NodeParameter(value: .string("gpt-4"), type: .string)
            ])
        case .actionRouteProvider:
            return NodeData(parameters: [
                "provider": NodeParameter(value: .string("auggie"), type: .string, options: ["auggie", "cursor"]),
                "priority": NodeParameter(value: .integer(1), type: .integer, range: 1...10),
                "timeout": NodeParameter(value: .integer(5000), type: .integer, range: 1000...30000),
                "retry_attempts": NodeParameter(value: .integer(3), type: .integer, range: 0...10)
            ])
        case .conditionNLP:
            return NodeData(parameters: [
                "rule_type": NodeParameter(value: .string("intent_classification"), type: .string, options: ["intent_classification", "keyword_match", "entity_required", "sentiment_filter"]),
                "pattern": NodeParameter(value: .string("code generation"), type: .string),
                "confidence_threshold": NodeParameter(value: .float(0.7), type: .float, range: 0.0...1.0)
            ])
        case .extractEntities:
            return NodeData(parameters: [
                "entity_types": NodeParameter(value: .array([.string("language"), .string("framework"), .string("task")]), type: .array),
                "minimum_confidence": NodeParameter(value: .float(0.5), type: .float, range: 0.0...1.0),
                "output_format": NodeParameter(value: .string("json"), type: .string, options: ["json", "key_value"])
            ])
        case .sentimentAnalysis:
            return NodeData(parameters: [
                "sentiment_threshold": NodeParameter(value: .float(0.6), type: .float, range: 0.0...1.0),
                "analysis_model": NodeParameter(value: .string("simple"), type: .string, options: ["simple", "advanced"])
            ])
        default:
            return NodeData()
        }
    }
}

struct NodeParameter: Codable, Equatable {
    var value: ParameterValue
    var type: ParameterType
    var options: [String]?
    var range: ClosedRange<Double>?
    
    init(value: ParameterValue, type: ParameterType, options: [String]? = nil, range: ClosedRange<Double>? = nil) {
        self.value = value
        self.type = type
        self.options = options
        self.range = range
    }
}

enum ParameterType: String, Codable {
    case string = "string"
    case integer = "integer"
    case float = "float"
    case boolean = "boolean"
    case array = "array"
    case dictionary = "dictionary"
}

enum ParameterValue: Codable, Hashable {
    case string(String)
    case integer(Int)
    case float(Double)
    case boolean(Bool)
    case array([ParameterValue])
    case dictionary([String: ParameterValue])
    
    private enum CodingKeys: String, CodingKey {
        case string, integer, float, boolean, array, dictionary
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let value = try? container.decode(String.self, forKey: .string) {
            self = .string(value)
        } else if let value = try? container.decode(Int.self, forKey: .integer) {
            self = .integer(value)
        } else if let value = try? container.decode(Double.self, forKey: .float) {
            self = .float(value)
        } else if let value = try? container.decode(Bool.self, forKey: .boolean) {
            self = .boolean(value)
        } else if let value = try? container.decode([ParameterValue].self, forKey: .array) {
            self = .array(value)
        } else if let value = try? container.decode([String: ParameterValue].self, forKey: .dictionary) {
            self = .dictionary(value)
        } else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Invalid ParameterValue"))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .string(let value):
            try container.encode(value, forKey: .string)
        case .integer(let value):
            try container.encode(value, forKey: .integer)
        case .float(let value):
            try container.encode(value, forKey: .float)
        case .boolean(let value):
            try container.encode(value, forKey: .boolean)
        case .array(let value):
            try container.encode(value, forKey: .array)
        case .dictionary(let value):
            try container.encode(value, forKey: .dictionary)
        }
    }
}

// MARK: - Connections

struct Connection: Identifiable, Codable, Hashable {
    let id: String
    var fromNodeId: String
    var fromPortId: String
    var toNodeId: String
    var toPortId: String
    
    init(fromNodeId: String, fromPortId: String, toNodeId: String, toPortId: String) {
        self.id = UUID().uuidString
        self.fromNodeId = fromNodeId
        self.fromPortId = fromPortId
        self.toNodeId = toNodeId
        self.toPortId = toPortId
    }
}

// MARK: - Rule Set

struct RuleSet: Identifiable, Codable {
    let id: String
    var name: String
    var description: String
    var isEnabled: Bool = true
    var createdAt: Date
    var updatedAt: Date
    var nodes: [RuleNode]
    var connections: [Connection]
    
    init(name: String = "New Rule", description: String = "") {
        self.id = UUID().uuidString
        self.name = name
        self.description = description
        self.createdAt = Date()
        self.updatedAt = Date()
        self.nodes = []
        self.connections = []
    }
    
    mutating func updateTimestamp() {
        updatedAt = Date()
    }
    
    var isValid: Bool {
        // Check if all connections are valid
        return connections.allSatisfy { connection in
            let fromNode = nodes.first { $0.id == connection.fromNodeId }
            let toNode = nodes.first { $0.id == connection.toNodeId }
            return fromNode != nil && toNode != nil
        }
    }
}

// MARK: - Extensions for NodeType

extension NodeType {
    var defaultCategory: NodeCategory {
        switch self {
        case .triggerHTTP, .triggerScheduled, .triggerWebhook:
            return .triggers
        case .conditionIf, .conditionAndOr, .conditionModelCompare, .conditionResourceCheck:
            return .conditions
        case .conditionNLP, .transformNLP, .classifyIntent, .extractEntities, .sentimentAnalysis:
            return .nlpRules
        case .actionRouteProvider, .actionCache, .actionTransform, .actionNotify:
            return .actions
        case .transformMap, .transformValidate, .transformCalculate:
            return .transforms
        }
    }
    
    var defaultName: String {
        switch self {
        case .triggerHTTP: return "HTTP Request"
        case .triggerScheduled: return "Scheduled Task"
        case .triggerWebhook: return "Webhook"
        case .conditionIf: return "If/Then"
        case .conditionAndOr: return "And/Or"
        case .conditionModelCompare: return "Model Compare"
        case .conditionResourceCheck: return "Resource Check"
        case .conditionNLP: return "NLP Condition"
        case .transformNLP: return "NLP Transform"
        case .classifyIntent: return "Classify Intent"
        case .extractEntities: return "Extract Entities"
        case .sentimentAnalysis: return "Sentiment Analysis"
        case .actionRouteProvider: return "Route to Provider"
        case .actionCache: return "Cache Response"
        case .actionTransform: return "Transform Data"
        case .actionNotify: return "Send Notification"
        case .transformMap: return "Map Fields"
        case .transformValidate: return "Validate Data"
        case .transformCalculate: return "Calculate"
        }
    }
    
    var defaultDescription: String {
        switch self {
        case .triggerHTTP: return "Triggers on HTTP requests to specific endpoints"
        case .triggerScheduled: return "Triggers on a time-based schedule"
        case .triggerWebhook: return "Triggers on external webhook events"
        case .conditionIf: return "Conditional logic with if/then branches"
        case .conditionAndOr: return "Combine multiple conditions with AND/OR"
        case .conditionModelCompare: return "Compare request model against criteria"
        case .conditionResourceCheck: return "Check system resources or quotas"
        case .conditionNLP: return "Natural language processing conditions"
        case .transformNLP: return "Transform data using NLP techniques"
        case .classifyIntent: return "Classify user intent for routing"
        case .extractEntities: return "Extract entities from text"
        case .sentimentAnalysis: return "Analyze sentiment of input text"
        case .actionRouteProvider: return "Route request to specific provider"
        case .actionCache: return "Cache the response for future use"
        case .actionTransform: return "Transform response data"
        case .actionNotify: return "Send notifications or alerts"
        case .transformMap: return "Map fields between different formats"
        case .transformValidate: return "Validate data against schema"
        case .transformCalculate: return "Perform calculations on data"
        }
    }
    
    var icon: String {
        switch self {
        case .triggerHTTP: return "network"
        case .triggerScheduled: return "clock"
        case .triggerWebhook: return "link"
        case .conditionIf: return "arrow.triangle.branch"
        case .conditionAndOr: return "link.badge.plus"
        case .conditionModelCompare: return "doc.text.magnifyingglass"
        case .conditionResourceCheck: return "gauge"
        case .conditionNLP: return "brain"
        case .transformNLP: return "brain.head.profile"
        case .classifyIntent: return "tag"
        case .extractEntities: return "viewfinder"
        case .sentimentAnalysis: return "face.dashed"
        case .actionRouteProvider: return "arrow.right.circle"
        case .actionCache: return "externaldrive"
        case .actionTransform: return "arrow.triangle.2.circlepath"
        case .actionNotify: return "bell"
        case .transformMap: return "arrow.swap"
        case .transformValidate: return "checkmark.shield"
        case .transformCalculate: return "function"
        }
    }
}
