import Combine
import Foundation

extension QuotaProvider {
    init?(serviceType: ServiceType) {
        switch serviceType {
        case .claude: self = .anthropic
        case .codex: self = .openAI
        default: return nil
        }
    }
}

final class QuotaStore: ObservableObject {
    @Published private(set) var states: [String: AccountQuotaState] = [:]
    @Published private(set) var isRefreshing = false
    @Published private(set) var isManualRefreshCoolingDown = false
    @Published private(set) var lastUpdated: Date?

    private let client: CLIProxyManagementClient
    private let freshnessInterval: TimeInterval
    private let manualRefreshCooldown: TimeInterval
    private let now: @Sendable () -> Date
    private var refreshTask: Task<Void, Never>?
    private var manualRefreshCooldownTask: Task<Void, Never>?
    private var monitoringCancellables: Set<AnyCancellable> = []
    private var monitoredAccounts: [AuthAccount] = []
    private var monitoredServerIsRunning = false

    init(
        client: CLIProxyManagementClient,
        freshnessInterval: TimeInterval = 300,
        manualRefreshCooldown: TimeInterval = 15,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.client = client
        self.freshnessInterval = freshnessInterval
        self.manualRefreshCooldown = manualRefreshCooldown
        self.now = now
    }

    @MainActor
    func startMonitoring(authManager: AuthManager, serverManager: ServerManager) {
        guard monitoringCancellables.isEmpty else { return }

        Publishers.CombineLatest(authManager.$serviceAccounts, serverManager.$isRunning)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] serviceAccounts, serverIsRunning in
                guard let self else { return }
                let accounts = (serviceAccounts[.claude]?.accounts ?? [])
                    + (serviceAccounts[.codex]?.accounts ?? [])
                let accountsChanged = accounts != self.monitoredAccounts
                let serverBecameRunning = serverIsRunning && !self.monitoredServerIsRunning
                self.monitoredAccounts = accounts
                self.monitoredServerIsRunning = serverIsRunning
                if serverIsRunning {
                    self.refresh(
                        accounts: accounts,
                        force: accountsChanged || serverBecameRunning
                    )
                } else {
                    self.markServerStopped(accounts: accounts)
                }
            }
            .store(in: &monitoringCancellables)

        Timer.publish(every: 300, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, self.monitoredServerIsRunning else { return }
                self.refresh(accounts: self.monitoredAccounts)
            }
            .store(in: &monitoringCancellables)

        NotificationCenter.default.publisher(for: .serverStatusChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, self.monitoredServerIsRunning else { return }
                self.refresh(accounts: self.monitoredAccounts)
            }
            .store(in: &monitoringCancellables)
    }

    @MainActor
    func refreshManually(accounts: [AuthAccount]) {
        guard !isRefreshing, !isManualRefreshCoolingDown else { return }

        isManualRefreshCoolingDown = true
        refresh(accounts: accounts, force: true)

        manualRefreshCooldownTask?.cancel()
        let cooldownNanoseconds = UInt64(max(manualRefreshCooldown, 0) * 1_000_000_000)
        manualRefreshCooldownTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: cooldownNanoseconds)
            guard !Task.isCancelled, let self else { return }
            self.isManualRefreshCoolingDown = false
            self.manualRefreshCooldownTask = nil
        }
    }

    @MainActor
    func refresh(accounts: [AuthAccount], force: Bool = false) {
        if !force {
            guard !isRefreshing else { return }
            if let lastUpdated, now().timeIntervalSince(lastUpdated) < freshnessInterval {
                return
            }
        }

        refreshTask?.cancel()

        let references = accounts.compactMap { account -> QuotaAccountReference? in
            guard let provider = QuotaProvider(serviceType: account.type) else {
                return nil
            }
            return QuotaAccountReference(id: account.id, provider: provider)
        }
        guard !references.isEmpty else {
            states = states.filter { id, _ in accounts.contains { $0.id == id } }
            isRefreshing = false
            refreshTask = nil
            return
        }

        isRefreshing = true
        let client = client
        refreshTask = Task { @MainActor [weak self] in
            let results = await Self.load(references: references, client: client)
            guard !Task.isCancelled, let self else { return }
            let accountIDs = Set(accounts.map(\.id))
            var nextStates = self.states.filter { accountIDs.contains($0.key) }
            for result in results {
                let previousSnapshot = nextStates[result.id]?.snapshot
                nextStates[result.id] = AccountQuotaState(
                    snapshot: result.snapshot ?? previousSnapshot,
                    failure: result.failure
                )
            }
            self.states = nextStates
            self.lastUpdated = results.compactMap(\.snapshot?.fetchedAt).max() ?? self.lastUpdated
            self.isRefreshing = false
            self.refreshTask = nil
        }
    }

    @MainActor
    func markServerStopped(accounts: [AuthAccount]) {
        refreshTask?.cancel()
        refreshTask = nil
        isRefreshing = false
        let ids = Set(accounts.map(\.id))
        states = states
            .filter { ids.contains($0.key) }
            .mapValues { AccountQuotaState(snapshot: $0.snapshot, failure: .serverUnavailable) }
    }

    @MainActor
    func resetCredit(for account: AuthAccount) async throws -> CodexResetCredit {
        guard account.type == .codex else {
            throw QuotaFailure.accountUnavailable
        }
        let authFile = try await authFile(for: account)
        let credits = try await client.fetchCodexResetCredits(for: authFile)
        guard let credit = credits.min(by: {
            ($0.expiresAt ?? .distantFuture) < ($1.expiresAt ?? .distantFuture)
        }) else {
            throw QuotaFailure.accountUnavailable
        }
        return credit
    }

    @MainActor
    func consumeResetCredit(_ credit: CodexResetCredit, for account: AuthAccount) async throws -> CodexResetOutcome {
        guard account.type == .codex else {
            throw QuotaFailure.accountUnavailable
        }
        let authFile = try await authFile(for: account)
        let outcome = try await client.consumeCodexResetCredit(credit, for: authFile)
        if outcome == .reset {
            refresh(accounts: monitoredAccounts, force: true)
        }
        return outcome
    }

    @MainActor
    private func authFile(for account: AuthAccount) async throws -> ProxyAuthFile {
        let files = try await client.fetchAuthFiles()
        guard let authFile = files.first(where: { $0.name == account.id }) else {
            throw QuotaFailure.accountUnavailable
        }
        return authFile
    }

    private static func load(
        references: [QuotaAccountReference],
        client: CLIProxyManagementClient
    ) async -> [RefreshResult] {
        let authFiles: [ProxyAuthFile]
        do {
            authFiles = try await client.fetchAuthFiles()
        } catch {
            let failure = (error as? QuotaFailure) ?? .serverUnavailable
            return references.map { RefreshResult(id: $0.id, snapshot: nil, failure: failure) }
        }

        let filesByName = Dictionary(
            authFiles.map { ($0.name, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        return await withTaskGroup(of: RefreshResult.self) { group in
            for reference in references {
                group.addTask {
                    guard let authFile = filesByName[reference.id] else {
                        return RefreshResult(id: reference.id, snapshot: nil, failure: .accountUnavailable)
                    }
                    do {
                        let snapshot = try await client.fetchQuota(for: authFile, provider: reference.provider)
                        return RefreshResult(id: reference.id, snapshot: snapshot, failure: nil)
                    } catch {
                        return RefreshResult(
                            id: reference.id,
                            snapshot: nil,
                            failure: (error as? QuotaFailure) ?? .providerUnavailable
                        )
                    }
                }
            }

            var results: [RefreshResult] = []
            for await result in group {
                results.append(result)
            }
            return results
        }
    }

    private struct RefreshResult: Sendable {
        let id: String
        let snapshot: QuotaSnapshot?
        let failure: QuotaFailure?
    }
}
