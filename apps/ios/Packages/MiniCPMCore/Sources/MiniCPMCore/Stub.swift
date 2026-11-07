import Foundation

/// Runs no model. It behaves like a real engine (loading waits, replies stream and cancel),
/// so every UI path works now and stays unchanged when the real engine replaces it.
public struct StubOptions: Sendable {
    public var canRun = true
    public var reachable = true
    /// The next load of anything fails with `outOfMemory`.
    public var failNextLoad = false
    public var loadDelay = Duration.seconds(2)
    public var tokenDelay = Duration.milliseconds(36)

    public init() {}

    /// `-stub nogpu,offline,oom` as a launch argument opens those states.
    public init(arguments: [String]) {
        guard let flag = arguments.firstIndex(of: "-stub"), arguments.indices.contains(flag + 1) else { return }
        let names = arguments[flag + 1].split(separator: ",")
        canRun = !names.contains("nogpu")
        reachable = !names.contains("offline")
        failNextLoad = names.contains("oom")
    }

    public static let instant: StubOptions = {
        var options = StubOptions()
        options.loadDelay = .zero
        options.tokenDelay = .zero
        return options
    }()
}

public actor StubEngine: Engine {
    private var options: StubOptions

    public init(options: StubOptions = StubOptions()) { self.options = options }

    public func setFailNextLoad(_ fail: Bool) { options.failNextLoad = fail }
    public func setReachable(_ reachable: Bool) { options.reachable = reachable }

    public func probe() -> DeviceProfile {
        DeviceProfile(canRun: options.canRun, isResponding: options.reachable, memoryGB: 8, freeStorageGB: 38)
    }

    public func load(optionID: String) async throws {
        try await Task.sleep(for: options.loadDelay)
        if options.failNextLoad {
            options.failNextLoad = false
            throw EngineError.outOfMemory
        }
    }

    public func unload() {}

    public func prepareImage(_ file: URL) async throws -> PreparedImage {
        try await Task.sleep(for: options.loadDelay / 2)
        return PreparedImage()
    }

    public nonisolated func generate(_ request: GenerateRequest) -> AsyncThrowingStream<GenerationEvent, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                let options = await self.options
                guard options.reachable else {
                    continuation.finish(throwing: EngineError.unavailable)
                    return
                }
                let asked = request.messages.last?.text ?? ""
                let started = ContinuousClock.now
                do {
                    let refused = asked.hasPrefix("记住") && !request.canRemember
                    for word in refused ? "现在不能写入记忆，这条我记不下来。" : Self.placeholder(for: asked) {
                        try await Task.sleep(for: options.tokenDelay)
                        continuation.yield(.text(delta: String(word)))
                    }
                    if !refused { for event in Self.cards(for: asked) { continuation.yield(event) } }
                    let seconds = (ContinuousClock.now - started) / .seconds(1)
                    continuation.yield(.done(tokensPerSecond: 40, seconds: seconds))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func placeholder(for asked: String) -> String {
        "这是占位回答，推理后端还没接入。\n\n你刚才说的是：**\(asked.prefix(40))**"
    }

    /// Phrases that open the event paths a real model would decide on by itself.
    private static func cards(for asked: String) -> [GenerationEvent] {
        if asked.hasPrefix("记住") { return [.memory(text: String(asked.dropFirst(2)))] }
        if asked.contains("查一下") { return [.askSearch(query: asked)] }
        if asked.contains("提醒我") { return [.action(kind: .notify, when: "每天 09:00", text: asked)] }
        if asked.contains("备忘") { return [.action(kind: .memo, when: nil, text: asked)] }
        if asked.contains("写长点") { return [.cut(reason: .length)] }
        return []
    }
}

public actor StubModelStore: ModelStore {
    private var saved: Set<String>
    private let file: URL?
    private let tick: Duration

    /// Sizes and tiers are placeholders; the real store reads the hardware and returns what fits.
    public static let placeholderCatalog = [
        ModelOption(id: "minicpm-v-4.6:q4", modelID: "minicpm-v-4.6", name: "MiniCPM-V 4.6", shortName: "V 4.6", kind: .vision, capabilities: [.image, .video], specLabel: "轻量", specTag: "Q4", sizeGB: 3.7, memoryGB: 5, isRecommended: true, loadSeconds: 7),
        ModelOption(id: "minicpm-v-4.6:f16", modelID: "minicpm-v-4.6", name: "MiniCPM-V 4.6", shortName: "V 4.6", kind: .vision, capabilities: [.image, .video], specLabel: "完整", specTag: "F16", sizeGB: 11, memoryGB: 13, isRecommended: false, loadSeconds: 22),
        ModelOption(id: "minicpm-v-4.5:q4", modelID: "minicpm-v-4.5", name: "MiniCPM-V 4.5", shortName: "V 4.5", kind: .vision, capabilities: [.image, .video], specLabel: "轻量", specTag: "Q4", sizeGB: 5.1, memoryGB: 7, isRecommended: false, loadSeconds: 10),
    ]

    public init(file: URL? = nil, installed: [String] = [], tick: Duration = .milliseconds(120)) {
        self.file = file
        self.tick = tick
        let stored = file.flatMap { try? Data(contentsOf: $0) }.flatMap { try? JSONDecoder().decode([String].self, from: $0) }
        saved = Set(stored ?? installed)
    }

    public func catalog(device: DeviceProfile) -> [ModelOption] {
        guard let memory = device.memoryGB else { return Self.placeholderCatalog }
        return Self.placeholderCatalog.filter { $0.memoryGB <= memory }
    }

    public func installed() -> [String] { saved.sorted() }

    public func download(optionID: String, allowsCellular: Bool) -> any DownloadHandle {
        let handle = StubDownload(tick: tick) { [weak self] in await self?.finish(optionID) }
        Task { await handle.run() }
        return handle
    }

    public func remove(optionID: String) {
        saved.remove(optionID)
        store()
    }

    private func finish(_ optionID: String) {
        saved.insert(optionID)
        store()
    }

    private func store() {
        guard let file, let data = try? JSONEncoder().encode(saved.sorted()) else { return }
        try? data.write(to: file, options: .atomic)
    }
}

actor StubDownload: DownloadHandle {
    nonisolated let updates: AsyncStream<DownloadUpdate>
    private let continuation: AsyncStream<DownloadUpdate>.Continuation
    private let tick: Duration
    private let onFinish: @Sendable () async -> Void
    private var fraction = 0.0
    private var task: Task<Void, Never>?

    init(tick: Duration, onFinish: @escaping @Sendable () async -> Void) {
        (updates, continuation) = AsyncStream.makeStream()
        self.tick = tick
        self.onFinish = onFinish
    }

    func run() {
        task?.cancel()
        task = Task {
            while fraction < 1, !Task.isCancelled {
                try? await Task.sleep(for: tick)
                guard !Task.isCancelled else { return }
                fraction = min(1, fraction + 0.01)
                continuation.yield(DownloadUpdate(fraction: fraction, status: .running))
            }
            guard !Task.isCancelled else { return }
            continuation.yield(DownloadUpdate(fraction: 1, status: .verifying))
            try? await Task.sleep(for: tick * 8)
            await onFinish()
            continuation.yield(DownloadUpdate(fraction: 1, status: .finished))
            continuation.finish()
        }
    }

    func pause() {
        task?.cancel()
        continuation.yield(DownloadUpdate(fraction: fraction, status: .paused))
    }

    func resume(allowsCellular: Bool) { run() }

    func cancel() {
        task?.cancel()
        continuation.finish()
    }
}
