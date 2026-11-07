import Foundation

// The contract is docs/11-client-architecture.md. Web mirrors it in apps/web/src/engine/types.ts.

/// nil means the value could not be read, which is different from zero.
public struct DeviceProfile: Hashable, Sendable {
    public var canRun: Bool
    /// False when the engine or server does not answer right now, which a retry can fix. `canRun` is about the device.
    public var isResponding: Bool
    public var memoryGB: Double?
    public var freeStorageGB: Double?

    public init(canRun: Bool, isResponding: Bool = true, memoryGB: Double? = nil, freeStorageGB: Double? = nil) {
        self.canRun = canRun
        self.isResponding = isResponding
        self.memoryGB = memoryGB
        self.freeStorageGB = freeStorageGB
    }
}

/// Opaque handle to an image the engine already encoded.
public struct PreparedImage: Hashable, Sendable {
    public var id: UUID

    public init(id: UUID = UUID()) { self.id = id }
}

public enum EngineError: Error, Hashable, Sendable {
    case unavailable, outOfMemory, network, notInstalled
}

public enum GenerationEvent: Hashable, Sendable {
    case text(delta: String)
    case memory(text: String)
    case askSearch(query: String)
    case action(kind: ActionKind, when: String?, text: String)
    case cut(reason: CutReason)
    case done(tokensPerSecond: Double, seconds: Double)
}

public struct GenerateRequest: Hashable, Sendable {
    public struct Message: Hashable, Sendable {
        public enum Role: String, Sendable { case user, assistant }

        public var role: Role
        public var text: String
        public var images: [PreparedImage]

        public init(role: Role, text: String, images: [PreparedImage] = []) {
            self.role = role
            self.text = text
            self.images = images
        }
    }

    public var modelID: String
    public var system: String
    public var messages: [Message]
    public var params: GenerationParams
    public var thinking: Bool
    public var highDetail: Bool
    /// False in temporary chats or with memory off: the model has to say it cannot remember.
    public var canRemember: Bool

    public init(modelID: String, system: String, messages: [Message], params: GenerationParams, thinking: Bool, highDetail: Bool, canRemember: Bool) {
        self.modelID = modelID
        self.system = system
        self.messages = messages
        self.params = params
        self.thinking = thinking
        self.highDetail = highDetail
        self.canRemember = canRemember
    }
}

/// One instance per place. `AppModel` picks by the user's choice and never falls over to the other.
public protocol Engine: Sendable {
    func probe() async -> DeviceProfile
    /// Throws `EngineError.outOfMemory` when the model does not fit; the rules layer restores the previous one.
    func load(optionID: String) async throws
    func unload() async
    func prepareImage(_ file: URL) async throws -> PreparedImage
    /// Cancelling the consuming task cancels generation. Text already produced stays in the reply.
    func generate(_ request: GenerateRequest) -> AsyncThrowingStream<GenerationEvent, any Error>
}

public enum DownloadStatus: String, Sendable {
    case running, paused, waitingForWiFi, failed, verifying, badFile, finished
}

public struct DownloadUpdate: Hashable, Sendable {
    public var fraction: Double
    public var status: DownloadStatus

    public init(fraction: Double, status: DownloadStatus) {
        self.fraction = fraction
        self.status = status
    }
}

public protocol DownloadHandle: Sendable {
    var updates: AsyncStream<DownloadUpdate> { get }
    func pause() async
    /// Also retries after a failure and starts over after a bad file.
    func resume(allowsCellular: Bool) async
    func cancel() async
}

public protocol ModelStore: Sendable {
    func catalog(device: DeviceProfile) async -> [ModelOption]
    func installed() async -> [String]
    func download(optionID: String, allowsCellular: Bool) async -> any DownloadHandle
    func remove(optionID: String) async
}
