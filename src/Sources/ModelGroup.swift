import Foundation

struct ModelGroup: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var models: [String]
    var enabled: Bool

    init(id: UUID = UUID(), name: String = "", models: [String] = [], enabled: Bool = true) {
        self.id = id
        self.name = name
        self.models = models
        self.enabled = enabled
    }
}

class ModelGroupRouter {
    private var groups: [ModelGroup] = []
    private var counters: [UUID: Int] = [:]
    private let lock = NSLock()

    func updateGroups(_ newGroups: [ModelGroup]) {
        lock.lock()
        defer { lock.unlock() }
        groups = newGroups.filter { $0.enabled && !$0.models.isEmpty }
        let validIds = Set(groups.map(\.id))
        counters = counters.filter { validIds.contains($0.key) }
    }

    func resolveModel(_ model: String) -> (groupId: UUID, realModel: String)? {
        lock.lock()
        defer { lock.unlock() }
        guard let group = groups.first(where: { $0.name == model }) else { return nil }
        let index = counters[group.id, default: 0] % group.models.count
        counters[group.id] = (index + 1) % group.models.count
        return (group.id, group.models[index])
    }

    func failoverModel(groupId: UUID, excluding tried: Set<String>) -> String? {
        lock.lock()
        defer { lock.unlock() }
        guard let group = groups.first(where: { $0.id == groupId }) else { return nil }
        return group.models.first { !tried.contains($0) }
    }

    func activeGroupNames() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return groups.map(\.name)
    }
}
