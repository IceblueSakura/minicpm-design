import Foundation
import Observation

// State and rules of the client. Words live in the app layer: everything here that reaches
// the screen is a typed value, so the rules can be tested and the copy can be translated.
// The product rules are docs/03-structure.md, docs/05-states.md and docs/08-privacy.md.

public enum BackendState: Sendable {
    case remoteNotSet, offlineMode, noGPU, notResponding, noModel, ready
}

/// The answer to "where does my content go", wherever the UI states it.
public enum PrivacyStatement: Hashable, Sendable {
    case onDevice, onDeviceBackedUp, remoteNotSet, offlineBlocksRemote
    case sendingTo(host: String)
}

public enum OnboardingStep: Sendable {
    case welcome, model, download
}

public enum SettingsPage: String, Hashable, Identifiable, Sendable {
    case index, general, reply, models, privacy, scenes, advanced, reminders, memories, network, developer
    public var id: String { rawValue }
}

public struct DownloadState: Hashable, Sendable {
    public var optionID: String
    public var fraction: Double
    public var status: DownloadStatus
}

public struct DraftAttachment: Identifiable, Hashable, Sendable {
    public var attachment: Attachment
    public var isProcessing: Bool
    public var id: UUID { attachment.id }
}

public struct Draft: Hashable, Sendable {
    public var text = ""
    public var attachments: [DraftAttachment] = []
    public var hasContent: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !attachments.isEmpty
    }
}

public struct SwapFailure: Hashable, Sendable {
    public var optionID: String
    /// What the app went back to. nil means nothing is in memory and the wait stays until a retry.
    public var restoredTo: String?
}

public enum PermissionKind: Sendable {
    case microphone, camera
}

/// In priority order, see `AppModel.banner`.
public enum Banner: Hashable, Sendable {
    case permissionDenied(PermissionKind)
    case remoteNotSet, offlineMode, noGPU
    case notResponding(remote: Bool)
    case downloading(DownloadState, ModelOption)
    case modelMissing(ModelOption)
    case swapFailed(ModelOption, restoredTo: ModelOption?)
    case crashedLoading(ModelOption)
    case preparing(ModelOption)
    case switching(ModelOption)
}

public enum HeadStatus: Hashable, Sendable {
    case switching, preparing, temporary
    case place(model: String?, remote: Bool)
}

public enum Notice: Hashable, Sendable {
    case deleted(title: String)
    case temporaryCleared
    case modelReady(name: String)
    case modelRemoved(name: String)
    case loadCancelled(backTo: String)
    case replyNotFinished
    case replyInOtherConversation
    case switchedToDevice
    case willSend(host: String, withContext: Bool)
    case offlineBlocksDownload
    case connected(remote: Bool)
    case notResponding(remote: Bool)
    case paramsReset
    case notConnectedYet
}

public struct ToastAction {
    public enum Kind: Sendable { case undo, stopAndSwitch, turnOffOffline }

    public var kind: Kind
    public var run: @MainActor () -> Void
}

public struct Toast: Identifiable {
    public var id = UUID()
    public var notice: Notice
    public var action: ToastAction?
}

public struct ReplyState: Hashable, Sendable {
    public var conversationID: UUID
    public var itemID: UUID
}

@MainActor
@Observable
public final class AppModel {
    @ObservationIgnored private let localEngine: any Engine
    @ObservationIgnored private let remoteEngine: any Engine
    @ObservationIgnored private let modelStore: any ModelStore
    @ObservationIgnored private let persistence: any Persistence

    public private(set) var onboarding: OnboardingStep?
    public private(set) var conversations: [Conversation]
    public private(set) var currentID: UUID
    public private(set) var drafts: [UUID: Draft] = [:]

    public private(set) var device: DeviceProfile?
    public private(set) var catalog: [ModelOption] = []
    public private(set) var installed: Set<String> = []
    public private(set) var download: DownloadState?

    /// The app's one current model. It belongs to the app, not to a conversation.
    public private(set) var currentOptionID: String?
    /// What the on-device engine holds. nil before the first load and after a release.
    public private(set) var loadedOptionID: String?
    public private(set) var loadingOptionID: String?
    public private(set) var swapFailure: SwapFailure?
    public private(set) var crashedLoadOptionID: String?

    public private(set) var place: Place
    public private(set) var isResponding = true
    public var remoteURL: String { didSet { persist() } }
    public var hasRemoteToken = false

    public private(set) var reply: ReplyState?
    /// A sent message waiting for the model. One at a time: a second send during the wait stays in the box.
    public private(set) var isQueued = false
    public private(set) var toast: Toast?
    public var permissionDenied: PermissionKind?
    public var thinking = false
    public var settingsRoute: SettingsPage?

    public var prefs: Prefs { didSet { persist() } }
    public var persona: String { didSet { persist() } }
    public private(set) var memories: [String]
    public var hiddenScenes: Set<SceneID> { didSet { persist() } }
    public private(set) var preset: Preset
    public private(set) var params: GenerationParams
    public private(set) var networkLog: [NetworkRecord]
    /// iCloud backup has no implementation yet, so this stays false outside tests.
    public var backupOn = false

    @ObservationIgnored private var onboarded: Bool
    @ObservationIgnored private var started = false
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    @ObservationIgnored private var replyTask: Task<Void, Never>?
    @ObservationIgnored private var pendingAfterLoad: [@MainActor () -> Void] = []
    @ObservationIgnored private var downloadHandle: (any DownloadHandle)?
    @ObservationIgnored private var prepareTasks: [UUID: Task<PreparedImage?, Never>] = [:]

    public init(localEngine: any Engine, remoteEngine: any Engine, modelStore: any ModelStore, persistence: any Persistence) {
        self.localEngine = localEngine
        self.remoteEngine = remoteEngine
        self.modelStore = modelStore
        self.persistence = persistence

        let saved = persistence.load() ?? Snapshot()
        onboarded = saved.onboarded
        prefs = saved.prefs
        persona = saved.persona
        memories = saved.memories
        hiddenScenes = saved.hiddenScenes
        preset = saved.preset
        params = saved.params
        place = saved.place
        remoteURL = saved.remoteURL
        currentOptionID = saved.optionID
        networkLog = saved.networkLog

        let blank = Conversation(scene: saved.prefs.defaultScene, isTemporary: saved.prefs.temporaryByDefault)
        if saved.prefs.openTo == .last, let last = saved.currentID, saved.conversations.contains(where: { $0.id == last }) {
            conversations = saved.conversations
            currentID = last
        } else {
            conversations = [blank] + saved.conversations
            currentID = blank.id
        }
    }

    /// The stubbed app. Swap the engines and store here when the real ones exist.
    public static func stubbed(arguments: [String] = []) -> AppModel {
        let options = StubOptions(arguments: arguments)
        let persistence = JSONFilePersistence()
        return AppModel(
            localEngine: StubEngine(options: options),
            remoteEngine: StubEngine(options: options),
            modelStore: StubModelStore(file: AppPaths.root.appendingPathComponent("stub-installed.json")),
            persistence: persistence
        )
    }

    /// Reads the device and starts preparing the model right away: the wait passes while the user types.
    public func start() async {
        guard !started else { return }
        started = true
        let profile = await localEngine.probe()
        device = profile
        isResponding = profile.isResponding
        catalog = await modelStore.catalog(device: profile)
        installed = Set(await modelStore.installed())
        if currentOptionID == nil || option(currentOptionID) == nil {
            currentOptionID = (catalog.first { installed.contains($0.id) } ?? catalog.first { $0.isRecommended } ?? catalog.first)?.id
        }
        guard onboarded else {
            onboarding = .welcome
            return
        }
        // A model too big for the device would crash every launch, so a load that died is not retried by itself.
        if let marker = persistence.loadMarker {
            crashedLoadOptionID = marker
            persistence.setLoadMarker(nil)
            return
        }
        loadModel()
    }

    // MARK: Derived state

    public var current: Conversation { conversations.first { $0.id == currentID } ?? conversations[0] }
    public var isRemote: Bool { place == .remote }
    public var currentOption: ModelOption? { option(currentOptionID) }
    public var remoteHost: String { URL(string: remoteURL)?.host ?? remoteURL }
    public var sendingOut: Bool { isRemote && !remoteURL.isEmpty && !prefs.offlineMode }
    public var isReplyingHere: Bool { reply?.conversationID == currentID }
    public var canRemember: Bool { prefs.memory && !current.isTemporary }
    public var activeScenes: [SceneID] {
        SceneID.allCases.filter { !hiddenScenes.contains($0) || $0 == current.scene }
    }

    public func option(_ id: String?) -> ModelOption? { catalog.first { $0.id == id } }

    /// One row per model: the spec on disk, or the one to suggest. Only one spec of a model stays on disk.
    public var modelChoices: [ModelOption] {
        var seen = Set<String>()
        return catalog
            .sorted { lhs, rhs in installed.contains(lhs.id) && !installed.contains(rhs.id) }
            .filter { seen.insert($0.modelID).inserted }
    }

    public func can(_ capability: Capability) -> Bool { currentOption?.capabilities.contains(capability) ?? false }

    public var backendState: BackendState {
        if isRemote && remoteURL.isEmpty { return .remoteNotSet }
        if isRemote && prefs.offlineMode { return .offlineMode }
        if !isRemote && device?.canRun == false { return .noGPU }
        if !isResponding { return .notResponding }
        if !isRemote && !installed.contains(currentOptionID ?? "") { return .noModel }
        return .ready
    }

    public var backendReady: Bool { backendState == .ready }

    /// Blocks the send button. In the other failed states the message stays in the thread with a retry.
    public var cannotSend: Bool {
        switch backendState {
        case .noModel, .noGPU, .offlineMode: true
        default: false
        }
    }

    public var privacy: PrivacyStatement {
        if isRemote {
            if remoteURL.isEmpty { return .remoteNotSet }
            return prefs.offlineMode ? .offlineBlocksRemote : .sendingTo(host: remoteHost)
        }
        return backupOn ? .onDeviceBackedUp : .onDevice
    }

    public var banner: Banner? {
        if let permissionDenied { return .permissionDenied(permissionDenied) }
        switch backendState {
        case .remoteNotSet: return .remoteNotSet
        case .offlineMode: return .offlineMode
        case .noGPU: return .noGPU
        case .notResponding: return .notResponding(remote: isRemote)
        case .noModel:
            guard let model = currentOption else { return nil }
            if let download, download.optionID == model.id { return .downloading(download, model) }
            return .modelMissing(model)
        case .ready: break
        }
        if let swapFailure, let failed = option(swapFailure.optionID) {
            return .swapFailed(failed, restoredTo: option(swapFailure.restoredTo))
        }
        if let crashed = option(crashedLoadOptionID) { return .crashedLoading(crashed) }
        if let loading = option(loadingOptionID) {
            return loadedOptionID == nil ? .preparing(loading) : .switching(loading)
        }
        return nil
    }

    public var headStatus: HeadStatus {
        if loadingOptionID != nil { return loadedOptionID == nil ? .preparing : .switching }
        if current.isTemporary { return .temporary }
        return .place(model: current.isFresh ? nil : currentOption?.shortName, remote: isRemote)
    }

    // MARK: Onboarding

    public func finishWelcome() { onboarding = .model }

    public func chooseOnboardingModel(_ id: String) {
        currentOptionID = id
        onboarding = .download
        startDownload(id)
    }

    /// The download goes on; the banner above the composer takes over.
    public func leaveOnboarding() {
        onboarding = nil
        onboarded = true
        persist()
    }

    public func useOwnServer() {
        leaveOnboarding()
        place = .remote
        settingsRoute = .models
        persist()
    }

    // MARK: Conversations

    public func select(_ id: UUID) {
        guard conversations.contains(where: { $0.id == id }) else { return }
        leaveTemporary(next: id)
        currentID = id
        edit(id) { $0.hasUnread = false }
        persist()
    }

    public func newConversation() {
        if let blank = conversations.first(where: \.isFresh) {
            select(blank.id)
            return
        }
        let fresh = Conversation(scene: prefs.defaultScene, isTemporary: prefs.temporaryByDefault)
        conversations.insert(fresh, at: 0)
        select(fresh.id)
    }

    public func toggleTemporary() {
        guard current.isFresh else { return }
        edit(currentID) { $0.isTemporary.toggle() }
    }

    public func setScene(_ scene: SceneID) {
        edit(currentID) { $0.scene = scene }
        persist()
    }

    public func rename(_ id: UUID, to title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        edit(id) {
            $0.title = trimmed
            $0.autoTitle = false
        }
        persist()
    }

    public func delete(_ id: UUID) {
        guard let index = conversations.firstIndex(where: { $0.id == id }) else { return }
        if reply?.conversationID == id { stopReply() }
        let removed = conversations.remove(at: index)
        if conversations.isEmpty { conversations = [Conversation(scene: prefs.defaultScene)] }
        if currentID == id { currentID = conversations[min(index, conversations.count - 1)].id }
        persist()
        show(.deleted(title: removed.title), action: ToastAction(kind: .undo) { [weak self] in
            guard let self else { return }
            self.conversations.insert(removed, at: min(index, self.conversations.count))
            self.persist()
        })
    }

    public func clearAll() {
        stopReply()
        let fresh = Conversation(scene: prefs.defaultScene, isTemporary: prefs.temporaryByDefault)
        conversations = [fresh]
        currentID = fresh.id
        drafts = [:]
        try? FileManager.default.removeItem(at: AppPaths.attachments)
        persist()
    }

    /// Temporary conversations leave nothing behind, so there is no undo here.
    private func leaveTemporary(next: UUID) {
        let leaving = current
        guard leaving.isTemporary, leaving.id != next, !leaving.isBlank else { return }
        if reply?.conversationID == leaving.id { stopReply() }
        conversations.removeAll { $0.id == leaving.id }
        drafts[leaving.id] = nil
        show(.temporaryCleared)
    }

    // MARK: Composer

    public var draft: Draft { drafts[currentID] ?? Draft() }

    public var draftText: String {
        get { draft.text }
        set { drafts[currentID, default: Draft()].text = newValue }
    }

    /// Images start processing the moment they arrive, so the wait passes while the user types.
    public func addAttachment(_ attachment: Attachment) {
        let needsWork = attachment.kind == .image && attachment.fileURL != nil
        let conversationID = currentID
        drafts[conversationID, default: Draft()].attachments.append(DraftAttachment(attachment: attachment, isProcessing: needsWork))
        guard needsWork, let file = attachment.fileURL else { return }
        let engine = isRemote ? remoteEngine : localEngine
        prepareTasks[attachment.id] = Task { [weak self] in
            let handle = try? await engine.prepareImage(file)
            self?.finishPreparing(attachment.id, in: conversationID)
            return handle
        }
    }

    public func removeAttachment(_ id: UUID) {
        drafts[currentID]?.attachments.removeAll { $0.id == id }
        prepareTasks[id]?.cancel()
        prepareTasks[id] = nil
    }

    private func finishPreparing(_ id: UUID, in conversationID: UUID) {
        guard let index = drafts[conversationID]?.attachments.firstIndex(where: { $0.id == id }) else { return }
        drafts[conversationID]?.attachments[index].isProcessing = false
    }

    public func send() {
        if isReplyingHere {
            stopReply()
            return
        }
        guard !cannotSend, !isQueued, draft.hasContent else { return }
        guard reply == nil else {
            show(.replyInOtherConversation)
            return
        }
        let text = draft.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let attachments = draft.attachments.map(\.attachment)
        let failed = !backendReady
        let id = currentID
        edit(id) { conversation in
            if conversation.isFresh {
                conversation.title = String((text.isEmpty ? attachments.first?.name ?? "" : text).prefix(24))
                conversation.autoTitle = false
            }
            conversation.sources += attachments.map(\.name)
            conversation.updatedAt = Date()
        }
        if !failed { markPlace(id) }
        edit(id) { $0.items.append(.user(UserMessage(text: text, attachments: attachments, failed: failed))) }
        drafts[id] = nil
        persist()
        if !failed { queueReply(in: id) }
    }

    private func queueReply(in id: UUID, continuing itemID: UUID? = nil) {
        isQueued = true
        loadModel { [weak self] in
            self?.isQueued = false
            self?.startReply(in: id, continuing: itemID)
        }
    }

    public func retrySend(_ itemID: UUID) {
        guard backendReady, reply == nil, !isQueued else { return }
        let id = currentID
        edit(id) { conversation in
            guard let index = conversation.items.firstIndex(where: { $0.id == itemID }), case .user(var message) = conversation.items[index] else { return }
            message.failed = false
            conversation.items[index] = .user(message)
        }
        markPlace(id)
        queueReply(in: id)
    }

    /// Leaves a mark before the first message after the place changed. An empty conversation needs none.
    private func markPlace(_ id: UUID) {
        let destination = isRemote ? remoteHost : "local"
        edit(id) { conversation in
            if !conversation.items.isEmpty, (conversation.place ?? "local") != destination {
                conversation.items.append(.place(PlaceMark(host: self.isRemote ? destination : nil)))
            }
            conversation.place = destination
        }
    }

    // MARK: Replies

    private func makeRequest(for conversation: Conversation, images: [PreparedImage], continuing: Bool) -> GenerateRequest {
        var system = persona
        if !prefs.callName.isEmpty { system += "\n\n称呼用户：\(prefs.callName)" }
        let canRemember = prefs.memory && !conversation.isTemporary
        if canRemember, !memories.isEmpty {
            system += "\n\n关于用户：\n" + memories.joined(separator: "\n")
        }
        var messages: [GenerateRequest.Message] = conversation.items.compactMap { item in
            switch item {
            case .user(let m): GenerateRequest.Message(role: .user, text: m.text)
            case .assistant(let m) where !m.text.isEmpty: GenerateRequest.Message(role: .assistant, text: m.text)
            default: nil
            }
        }
        if continuing {
            messages.append(GenerateRequest.Message(role: .user, text: "接着写"))
        } else if let last = messages.indices.last {
            messages[last].images = images
        }
        return GenerateRequest(
            modelID: currentOption?.modelID ?? "",
            system: system,
            messages: messages,
            params: params,
            thinking: thinking,
            highDetail: prefs.highDetail,
            canRemember: canRemember
        )
    }

    private func startReply(in conversationID: UUID, continuing itemID: UUID? = nil) {
        guard reply == nil else { return }
        let targetID: UUID
        if let itemID {
            targetID = itemID
            editAssistant(conversationID, itemID) { $0.cut = nil }
        } else {
            let message = AssistantMessage(modelName: currentOption?.name)
            targetID = message.id
            edit(conversationID) { $0.items.append(.assistant(message)) }
        }
        reply = ReplyState(conversationID: conversationID, itemID: targetID)
        let engine = isRemote ? remoteEngine : localEngine
        replyTask = Task { [weak self] in
            await self?.runReply(engine, conversationID, targetID, continuing: itemID != nil)
        }
    }

    private func runReply(_ engine: any Engine, _ conversationID: UUID, _ itemID: UUID, continuing: Bool) async {
        guard let conversation = conversations.first(where: { $0.id == conversationID }) else { return }
        // Sending before an image finished processing just queues behind it.
        var images: [PreparedImage] = []
        if case .user(let message)? = conversation.items.last(where: { if case .user = $0 { true } else { false } }) {
            for attachment in message.attachments {
                if let handle = await prepareTasks[attachment.id]?.value { images.append(handle) }
                prepareTasks[attachment.id] = nil
            }
        }
        var memory: String?
        do {
            let request = makeRequest(for: conversation, images: images, continuing: continuing)
            for try await event in engine.generate(request) {
                switch event {
                case .text(let delta): editAssistant(conversationID, itemID) { $0.text += delta }
                case .memory(let text): memory = text
                case .askSearch(let query): appendCard(.search(SearchAsk(query: query)), to: conversationID, enabled: prefs.webSearch != .off)
                case .action(let kind, let when, let text): appendCard(.action(ActionCard(kind: kind, when: when, text: text)), to: conversationID, enabled: true)
                case .cut(let reason): editAssistant(conversationID, itemID) { $0.cut = reason }
                case .done(let speed, let seconds):
                    editAssistant(conversationID, itemID) { $0.stats = ReplyStats(tokensPerSecond: speed, seconds: seconds) }
                }
            }
        } catch is CancellationError {
            memory = nil
        } catch {
            memory = nil
            failReply(conversationID, itemID, error: error)
        }
        guard reply?.itemID == itemID else { return }
        reply = nil
        if let memory, prefs.memory, conversations.first(where: { $0.id == conversationID })?.isTemporary == false {
            remember(memory)
            edit(conversationID) { $0.items.append(.memory(MemoryLine(text: memory))) }
        }
        if conversationID != currentID { edit(conversationID) { $0.hasUnread = true } }
        persist()
    }

    private func appendCard(_ item: ThreadItem, to conversationID: UUID, enabled: Bool) {
        if enabled { edit(conversationID) { $0.items.append(item) } }
    }

    /// Keeps what was written. The place stays as it is; moving content elsewhere is the user's decision.
    private func failReply(_ conversationID: UUID, _ itemID: UUID, error: any Error) {
        if let error = error as? EngineError, error == .unavailable || error == .network { isResponding = false }
        edit(conversationID) { conversation in
            guard let index = conversation.items.firstIndex(where: { $0.id == itemID }), case .assistant(var message) = conversation.items[index] else { return }
            if message.text.isEmpty {
                conversation.items.remove(at: index)
                if let user = conversation.items.lastIndex(where: { if case .user = $0 { true } else { false } }), case .user(var sent) = conversation.items[user] {
                    sent.failed = true
                    conversation.items[user] = .user(sent)
                }
            } else {
                message.cut = .interrupted
                conversation.items[index] = .assistant(message)
            }
        }
    }

    public func stopReply() {
        guard let reply else { return }
        replyTask?.cancel()
        editAssistant(reply.conversationID, reply.itemID) { $0.stopped = true }
        self.reply = nil
        persist()
    }

    public func regenerate(_ itemID: UUID) {
        guard reply == nil, !isQueued else { return }
        let id = currentID
        edit(id) { conversation in
            if let index = conversation.items.firstIndex(where: { $0.id == itemID }) { conversation.items.removeSubrange(index...) }
        }
        queueReply(in: id)
    }

    public func continueReply(_ itemID: UUID) {
        guard reply == nil, !isQueued, backendReady else { return }
        let id = currentID
        queueReply(in: id, continuing: itemID)
    }

    /// Models do not run in the background, so leaving the app ends the reply and keeps what was written.
    public func didEnterBackground() { stopReply() }

    // MARK: Cards

    public func answerSearch(_ itemID: UUID, accept: Bool) {
        guard !accept else { return show(.notConnectedYet) }
        edit(currentID) { conversation in
            guard let index = conversation.items.firstIndex(where: { $0.id == itemID }), case .search(var card) = conversation.items[index] else { return }
            card.state = .declined
            conversation.items[index] = .search(card)
        }
        persist()
    }

    public func answerAction(_ itemID: UUID, accept: Bool) {
        guard !accept else { return show(.notConnectedYet) }
        edit(currentID) { conversation in
            guard let index = conversation.items.firstIndex(where: { $0.id == itemID }), case .action(var card) = conversation.items[index] else { return }
            card.state = .declined
            conversation.items[index] = .action(card)
        }
        persist()
    }

    // MARK: Memory

    public func remember(_ text: String) {
        if !memories.contains(text) { memories.append(text) }
        persist()
    }

    /// The line in the thread reads `memories`, so a deletion anywhere takes the words with it.
    public func forget(_ text: String) {
        memories.removeAll { $0 == text }
        persist()
    }

    // MARK: Models

    /// Prepares the current model, then runs `then`. Sent messages wait here instead of being refused.
    public func loadModel(then: (@MainActor () -> Void)? = nil) {
        guard let id = currentOptionID, !isRemote, loadedOptionID != id, installed.contains(id) else {
            then?()
            return
        }
        if let then { pendingAfterLoad.append(then) }
        if loadingOptionID == id { return }
        startLoad(id, fallback: loadedOptionID)
    }

    private func startLoad(_ id: String, fallback: String?) {
        let previous = loadTask
        previous?.cancel()
        loadingOptionID = id
        crashedLoadOptionID = nil
        persistence.setLoadMarker(id)
        let engine = localEngine
        loadTask = Task { [weak self] in
            _ = await previous?.value
            do {
                // One model fits at a time, so the old one goes first.
                await engine.unload()
                try await engine.load(optionID: id)
                self?.loadSucceeded(id)
            } catch is CancellationError {
                return
            } catch {
                self?.loadFailed(id, fallback: fallback)
            }
        }
    }

    private func loadSucceeded(_ id: String) {
        if swapFailure?.restoredTo == nil { swapFailure = nil }
        loadedOptionID = id
        loadingOptionID = nil
        persistence.setLoadMarker(nil)
        let waiting = pendingAfterLoad
        pendingAfterLoad = []
        waiting.forEach { $0() }
    }

    private func loadFailed(_ id: String, fallback: String?) {
        loadedOptionID = nil
        if let fallback {
            swapFailure = SwapFailure(optionID: id, restoredTo: fallback)
            currentOptionID = fallback
            startLoad(fallback, fallback: nil)
            return
        }
        // With nothing to fall back on, whatever was waiting keeps waiting for a retry.
        swapFailure = SwapFailure(optionID: swapFailure?.optionID ?? id, restoredTo: nil)
        loadingOptionID = nil
        persistence.setLoadMarker(nil)
    }

    public func retryLoad() {
        swapFailure = nil
        crashedLoadOptionID = nil
        loadModel()
    }

    public func dismissSwapFailure() { swapFailure = nil }

    /// Switches every conversation to this model. The UI confirms first, in place, because a mistap costs a wait.
    public func setModel(_ id: String) {
        guard currentOptionID != id else { return }
        if reply != nil {
            show(.replyNotFinished, action: ToastAction(kind: .stopAndSwitch) { [weak self] in
                self?.stopReply()
                self?.setModel(id)
            })
            return
        }
        swapFailure = nil
        currentOptionID = id
        persist()
        loadModel()
    }

    /// Goes back to the previous model, which can also take a moment because it was released first.
    public func cancelLoad() {
        guard let back = loadedOptionID, loadingOptionID != nil else { return }
        loadedOptionID = nil
        currentOptionID = back
        startLoad(back, fallback: nil)
        persist()
        if let name = option(back)?.name { show(.loadCancelled(backTo: name)) }
    }

    public func removeModel(_ id: String) {
        guard id != currentOptionID, let model = option(id) else { return }
        installed.remove(id)
        let store = modelStore
        Task { await store.remove(optionID: id) }
        show(.modelRemoved(name: model.name))
    }

    public func startDownload(_ id: String) {
        guard download == nil else { return }
        if prefs.offlineMode {
            show(.offlineBlocksDownload, action: ToastAction(kind: .turnOffOffline) { [weak self] in
                self?.prefs.offlineMode = false
                self?.startDownload(id)
            })
            return
        }
        download = DownloadState(optionID: id, fraction: 0, status: .running)
        networkLog.insert(NetworkRecord(kind: .modelDownload, detail: option(id)?.name ?? id), at: 0)
        let store = modelStore
        let allowsCellular = !prefs.wifiOnly
        Task { [weak self] in
            let handle = await store.download(optionID: id, allowsCellular: allowsCellular)
            self?.downloadHandle = handle
            for await update in handle.updates {
                self?.download?.fraction = update.fraction
                self?.download?.status = update.status
                if update.status == .finished { self?.finishDownload(id) }
            }
        }
    }

    public func pauseDownload() {
        guard let handle = downloadHandle else { return }
        Task { await handle.pause() }
    }

    public func resumeDownload(allowsCellular: Bool = false) {
        guard let handle = downloadHandle else { return }
        let cellular = allowsCellular || !prefs.wifiOnly
        download?.status = .running
        Task { await handle.resume(allowsCellular: cellular) }
    }

    public func cancelDownload() {
        guard let handle = downloadHandle else { return }
        Task { await handle.cancel() }
        download = nil
        downloadHandle = nil
        if onboarding == .download { onboarding = .model }
    }

    private func finishDownload(_ id: String) {
        // One spec per model: the new file replaces the old one.
        let replaced = installed.first { option($0)?.modelID == option(id)?.modelID && $0 != id }
        installed.insert(id)
        if let replaced {
            installed.remove(replaced)
            let store = modelStore
            Task { await store.remove(optionID: replaced) }
            if currentOptionID == replaced { currentOptionID = id }
            if loadedOptionID == replaced { loadedOptionID = nil }
        }
        download = nil
        downloadHandle = nil
        if onboarding != nil { leaveOnboarding() }
        persist()
        if let name = option(id)?.name { show(.modelReady(name: name)) }
        loadModel()
    }

    // MARK: Place

    /// Place is global and changes only here. Nothing has left yet, so the switch offers undo instead of asking first.
    public func setPlace(_ next: Place) {
        guard place != next else { return }
        if next == .remote, remoteURL.isEmpty {
            place = .remote
            // Already inside settings, the address field is right there. Changing the route would reopen the sheet.
            if settingsRoute == nil { settingsRoute = .models }
            persist()
            return
        }
        let before = place
        applyPlace(next)
        guard backendReady else { return }
        let undo = ToastAction(kind: .undo) { [weak self] in self?.applyPlace(before) }
        if isRemote {
            show(.willSend(host: remoteHost, withContext: !current.isBlank), action: undo)
        } else {
            loadModel()
            show(.switchedToDevice, action: undo)
        }
    }

    private func applyPlace(_ next: Place) {
        place = next
        isResponding = true
        persist()
    }

    public func reconnect() async {
        let remote = isRemote
        let profile = await (remote ? remoteEngine : localEngine).probe()
        isResponding = profile.isResponding
        show(profile.isResponding ? .connected(remote: remote) : .notResponding(remote: remote))
    }

    public func setRemoteToken(_ token: String) {
        // The value belongs in the Keychain once the remote engine exists. It is never kept in state.
        hasRemoteToken = !token.isEmpty
    }

    // MARK: Parameters

    public func setPreset(_ next: Preset) {
        guard let values = next.params else { return }
        preset = next
        params = values
        persist()
    }

    public func setParams(_ next: GenerationParams) {
        params = next
        preset = Preset.allCases.first { $0.params == next } ?? .custom
        persist()
    }

    public func resetParams() {
        setPreset(.balanced)
        show(.paramsReset)
    }

    // MARK: Toast

    public func show(_ notice: Notice, action: ToastAction? = nil) { toast = Toast(notice: notice, action: action) }
    public func dismissToast() { toast = nil }

    public func runToastAction() {
        let action = toast?.action
        toast = nil
        action?.run()
    }

    // MARK: Helpers

    private func edit(_ id: UUID, _ change: (inout Conversation) -> Void) {
        guard let index = conversations.firstIndex(where: { $0.id == id }) else { return }
        change(&conversations[index])
    }

    private func editAssistant(_ conversationID: UUID, _ itemID: UUID, _ change: (inout AssistantMessage) -> Void) {
        edit(conversationID) { conversation in
            guard let index = conversation.items.firstIndex(where: { $0.id == itemID }), case .assistant(var message) = conversation.items[index] else { return }
            change(&message)
            conversation.items[index] = .assistant(message)
        }
    }

    private func persist() {
        var snapshot = Snapshot()
        snapshot.onboarded = onboarded
        // Blank conversations are free to recreate. Temporary ones must never reach the disk.
        snapshot.conversations = prefs.keepHistory ? conversations.filter { !$0.isTemporary && !$0.isBlank } : []
        snapshot.currentID = currentID
        snapshot.prefs = prefs
        snapshot.memories = memories
        snapshot.persona = persona
        snapshot.preset = preset
        snapshot.params = params
        snapshot.place = place
        snapshot.remoteURL = remoteURL
        snapshot.optionID = currentOptionID
        snapshot.hiddenScenes = hiddenScenes
        snapshot.networkLog = networkLog
        persistence.save(snapshot)
    }
}
