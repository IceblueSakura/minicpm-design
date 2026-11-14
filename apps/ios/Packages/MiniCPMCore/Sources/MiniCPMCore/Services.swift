import Foundation

// Everything the app does outside the model. `Engine` and `ModelStore` stay the seam for inference; these are the
// seams for the rest. Each has a real rule in `AppModel` already, so connecting one means swapping it in `AppServices`.

public enum ServiceError: Error, Hashable, Sendable {
    /// No implementation yet. Rules turn this into "这项还没接入" and change nothing.
    case notConnected
    case unavailable, network, unreadableFile
}

public struct SearchResult: Hashable, Sendable {
    public var title: String
    public var snippet: String

    public init(title: String, snippet: String) {
        self.title = title
        self.snippet = snippet
    }
}

/// Sends the query and nothing else. It is the one thing that leaves the device on a local setup.
public protocol SearchService: Sendable {
    func search(query: String) async throws -> [SearchResult]
}

/// System features only: nothing here runs a model, because nothing computes in the background.
public protocol SystemActionService: Sendable {
    func scheduleNotification(when: String?, text: String, conversationID: UUID) async throws
    func writeMemo(_ text: String) async throws
}

public enum BackupStatus: Hashable, Sendable {
    /// The platform has no cloud, so only export and import show.
    case noCloud
    case signedOut
    case idle(last: Date?)
    case running(fraction: Double)
    case full(missingGB: Double, last: Date?)
}

public struct BackupState: Hashable, Sendable {
    public var isOn = false
    public var status = BackupStatus.idle(last: nil)
    public var hasCloudCopy = false

    public init(isOn: Bool = false, status: BackupStatus = .idle(last: nil), hasCloudCopy: Bool = false) {
        self.isOn = isOn
        self.status = status
        self.hasCloudCopy = hasCloudCopy
    }
}

/// The same content goes up and comes back. Local drafts, preferences, models and tokens are not backup data.
public struct BackupContents: Sendable {
    public var conversations: [Conversation]
    public var memories: [String]

    public init(conversations: [Conversation] = [], memories: [String] = []) {
        self.conversations = conversations
        self.memories = memories
    }
}

/// The app's own backup, off by default.
public protocol BackupService: Sendable {
    func state() async -> BackupState
    func enable() async throws
    func disable() async
    /// Follows this device: what was deleted here goes from the cloud too. Yields the fraction done.
    /// Includes attachment files referenced by conversations; cancellation stops the transfer.
    func backUp(_ contents: BackupContents) -> AsyncThrowingStream<Double, any Error>
    /// Materializes referenced attachment files before returning. No local records are overwritten.
    func restore() async throws -> BackupContents
    /// Called after disabling backup. A failed deletion must leave backup disabled and the copy retryable.
    func deleteCloudCopy() async throws
}

/// The file format is undecided, so it stays behind this.
public protocol ArchiveService: Sendable {
    var isConnected: Bool { get }
    func export(_ conversations: [Conversation]) async throws -> URL
    /// Throws `ServiceError.unreadableFile` for anything this app did not write.
    func read(_ file: URL) async throws -> [Conversation]
}

public protocol AppLockService: Sendable {
    /// False means the app never locks, so a missing implementation cannot shut anyone out.
    var isAvailable: Bool { get }
    func authenticate() async -> Bool
}

public enum ThermalLevel: Int, Comparable, Sendable {
    case nominal, warm, hot

    public static func < (a: ThermalLevel, b: ThermalLevel) -> Bool { a.rawValue < b.rawValue }
}

public enum DeviceCondition: Hashable, Sendable {
    case screenCaptured(Bool)
    case thermal(ThermalLevel)
}

public protocol DeviceConditionService: Sendable {
    var updates: AsyncStream<DeviceCondition> { get }
}

public struct AppServices: Sendable {
    public var search: any SearchService
    public var actions: any SystemActionService
    public var backup: any BackupService
    public var archive: any ArchiveService
    public var lock: any AppLockService
    public var conditions: any DeviceConditionService

    public init(
        search: any SearchService = UnconnectedServices(),
        actions: any SystemActionService = UnconnectedServices(),
        backup: any BackupService = UnconnectedServices(),
        archive: any ArchiveService = UnconnectedServices(),
        lock: any AppLockService = UnconnectedServices(),
        conditions: any DeviceConditionService = UnconnectedServices()
    ) {
        self.search = search
        self.actions = actions
        self.backup = backup
        self.archive = archive
        self.lock = lock
        self.conditions = conditions
    }

    public static let unconnected = AppServices()

    /// Pretends everything works, so the screens behind each service can be walked. `-stub services` turns it on.
    public static func demo(backup status: BackupStatus = .idle(last: nil), conditions: [DeviceCondition] = [], lockPasses: Bool = true) -> AppServices {
        let demo = DemoServices(status: status, conditions: conditions, lockPasses: lockPasses)
        return AppServices(search: demo, actions: demo, backup: demo, archive: demo, lock: demo, conditions: demo)
    }
}

/// What ships until a service is written: every action reports `notConnected`, and nothing locks or leaves the device.
public struct UnconnectedServices: SearchService, SystemActionService, BackupService, ArchiveService, AppLockService, DeviceConditionService {
    public init() {}

    public func search(query: String) async throws -> [SearchResult] { throw ServiceError.notConnected }
    public func scheduleNotification(when: String?, text: String, conversationID: UUID) async throws { throw ServiceError.notConnected }
    public func writeMemo(_ text: String) async throws { throw ServiceError.notConnected }

    public func state() async -> BackupState { BackupState() }
    public func enable() async throws { throw ServiceError.notConnected }
    public func disable() async {}
    public func backUp(_ contents: BackupContents) -> AsyncThrowingStream<Double, any Error> {
        AsyncThrowingStream { $0.finish(throwing: ServiceError.notConnected) }
    }
    public func restore() async throws -> BackupContents { throw ServiceError.notConnected }
    public func deleteCloudCopy() async throws { throw ServiceError.notConnected }

    public var isConnected: Bool { false }
    public func export(_ conversations: [Conversation]) async throws -> URL { throw ServiceError.notConnected }
    public func read(_ file: URL) async throws -> [Conversation] { throw ServiceError.notConnected }

    public var isAvailable: Bool { false }
    public func authenticate() async -> Bool { false }

    public var updates: AsyncStream<DeviceCondition> { AsyncStream { $0.finish() } }
}

/// Nothing here reaches a network or the system. It only makes the states reachable.
public actor DemoServices: SearchService, SystemActionService, BackupService, ArchiveService, AppLockService, DeviceConditionService {
    private var backup: BackupState
    private var backupContents = BackupContents()
    private let conditions: [DeviceCondition]
    private let lockPasses: Bool

    public init(status: BackupStatus = .idle(last: nil), conditions: [DeviceCondition] = [], lockPasses: Bool = true) {
        let failing = status != .idle(last: nil)
        backup = BackupState(isOn: failing, status: status, hasCloudCopy: failing)
        self.conditions = conditions
        self.lockPasses = lockPasses
    }

    public func search(query: String) async throws -> [SearchResult] { [SearchResult(title: query, snippet: "占位结果")] }
    public func scheduleNotification(when: String?, text: String, conversationID: UUID) async throws {}
    public func writeMemo(_ text: String) async throws {}

    public func state() -> BackupState { backup }
    public func enable() { backup.isOn = true }
    public func disable() { backup.isOn = false }
    private func finishBackup(_ contents: BackupContents) {
        backupContents = contents
        backup.status = .idle(last: Date())
        backup.hasCloudCopy = true
    }
    public nonisolated func backUp(_ contents: BackupContents) -> AsyncThrowingStream<Double, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for step in 1...10 {
                        try await Task.sleep(for: .milliseconds(150))
                        continuation.yield(Double(step) / 10)
                    }
                    await self.finishBackup(contents)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
    public func restore() -> BackupContents { backupContents }
    public func deleteCloudCopy() {
        backupContents = BackupContents()
        backup.hasCloudCopy = false
    }

    public nonisolated var isConnected: Bool { true }
    public func export(_ conversations: [Conversation]) throws -> URL {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("MiniCPM 对话.json")
        try JSONEncoder().encode(conversations).write(to: file, options: .atomic)
        return file
    }
    public func read(_ file: URL) throws -> [Conversation] {
        let scoped = file.startAccessingSecurityScopedResource()
        defer { if scoped { file.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: file), let conversations = try? JSONDecoder().decode([Conversation].self, from: data) else {
            throw ServiceError.unreadableFile
        }
        return conversations
    }

    public nonisolated var isAvailable: Bool { true }
    public func authenticate() -> Bool { lockPasses }

    public nonisolated var updates: AsyncStream<DeviceCondition> {
        let conditions = conditions
        return AsyncStream { continuation in
            conditions.forEach { continuation.yield($0) }
            continuation.finish()
        }
    }
}
