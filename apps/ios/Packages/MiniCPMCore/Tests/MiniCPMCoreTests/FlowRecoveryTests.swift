import Foundation
import Testing
@testable import MiniCPMCore

private func attachment(in directory: URL) throws -> Attachment {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let name = "\(UUID().uuidString)-report.txt"
    try Data("private report".utf8).write(to: directory.appendingPathComponent(name))
    return Attachment(kind: .file, name: "report.txt", byteCount: 14, storedFileName: name)
}

@MainActor
@Suite struct DraftRecovery {
    @Test func backgroundFlushRestoresAnUnsentDraftAndItsFile() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let (app, engine, persistence) = await makeApp(attachmentsDirectory: directory) { $0.prefs.openTo = .last }
        let id = app.currentID
        let file = try attachment(in: directory)
        app.addAttachment(file, to: id)
        app.draftText = "还没有发出的长问题"
        app.didEnterBackground()

        // Exercise the file representation, not just a shared in-memory Draft.
        let saved = try #require(persistence.load())
        let decoded = try JSONDecoder().decode(Snapshot.self, from: JSONEncoder().encode(saved))
        let restored = AppModel(localEngine: engine, remoteEngine: engine, modelStore: StubModelStore(installed: []),
                                persistence: InMemoryPersistence(snapshot: decoded), attachmentsDirectory: directory)
        await restored.start()
        #expect(restored.currentID == id)
        #expect(restored.draftText == "还没有发出的长问题")
        #expect(restored.draft.attachments.map(\.attachment) == [file])
        #expect(FileManager.default.fileExists(atPath: try #require(file.fileURL(in: directory)).path(percentEncoded: false)))
    }

    @Test func newConversationDoesNotReuseAnUnsentDraft() async {
        let (app, _, persistence) = await makeApp()
        let id = app.currentID
        app.draftText = "稍后再发"
        app.newConversation()
        #expect(app.currentID != id)
        app.select(id)
        #expect(app.draftText == "稍后再发")
        #expect(persistence.load()?.drafts?[id]?.text == "稍后再发")
    }

    @Test func disablingHistoryAlsoExcludesDraftRecovery() async {
        let (app, _, persistence) = await makeApp { $0.prefs.keepHistory = false }
        app.draftText = "不保存"
        app.didEnterBackground()
        #expect(persistence.load()?.conversations.isEmpty == true)
        #expect(persistence.load()?.drafts?.isEmpty == true)
    }

    @Test func snapshotsWithoutDraftsRemainReadable() throws {
        let old = try JSONEncoder().encode(Snapshot())
        let decoded = try JSONDecoder().decode(Snapshot.self, from: old)
        #expect(decoded.drafts == nil)
        #expect(decoded.prefs.keepHistory)
    }
}

@MainActor
@Suite struct AttachmentOwnership {
    @Test func leavingAnUnsentTemporaryChatDeletesItsFile() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let (app, _, persistence) = await makeApp(attachmentsDirectory: directory)
        app.toggleTemporary()
        let id = app.currentID
        let file = try attachment(in: directory)
        app.addAttachment(file, to: id)
        app.draftText = "临时内容"
        app.newConversation()
        #expect(!app.conversations.contains { $0.id == id })
        #expect(app.drafts[id] == nil)
        #expect(persistence.load()?.drafts?[id] == nil)
        #expect(!FileManager.default.fileExists(atPath: try #require(file.fileURL(in: directory)).path(percentEncoded: false)))
    }

    @Test func aDelayedImportStaysWithItsOriginalConversation() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let (app, _, _) = await makeApp(attachmentsDirectory: directory)
        let original = app.currentID
        app.draftText = "原对话"
        app.newConversation()
        let file = try attachment(in: directory)
        app.addAttachment(file, to: original)
        #expect(app.draft.attachments.isEmpty)
        app.select(original)
        #expect(app.draft.attachments.map(\.attachment) == [file])
    }

    @Test func aLateResultForAClearedTemporaryChatIsDiscarded() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let (app, _, _) = await makeApp(attachmentsDirectory: directory)
        app.toggleTemporary()
        app.draftText = "临时内容"
        let original = app.currentID
        app.newConversation()
        let file = try attachment(in: directory)
        app.addAttachment(file, to: original)
        #expect(app.draft.attachments.isEmpty)
        #expect(app.drafts[original] == nil)
        #expect(!FileManager.default.fileExists(atPath: try #require(file.fileURL(in: directory)).path(percentEncoded: false)))
    }

    @Test func removingAnAttachmentReclaimsItsFile() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let (app, _, _) = await makeApp(attachmentsDirectory: directory)
        let file = try attachment(in: directory)
        app.addAttachment(file, to: app.currentID)
        app.removeAttachment(file.id)
        #expect(app.draft.attachments.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: try #require(file.fileURL(in: directory)).path(percentEncoded: false)))
    }

    @Test func deleteUndoRestoresTheDraftWithoutDeletingItsFile() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let (app, _, _) = await makeApp(attachmentsDirectory: directory)
        let id = app.currentID
        let file = try attachment(in: directory)
        app.addAttachment(file, to: id)
        app.draftText = "撤销后继续"
        app.delete(id)
        app.runToastAction()
        app.select(id)
        #expect(app.draftText == "撤销后继续")
        #expect(app.draft.attachments.map(\.attachment) == [file])
        #expect(FileManager.default.fileExists(atPath: try #require(file.fileURL(in: directory)).path(percentEncoded: false)))
    }

    @Test func launchRemovesFilesLeftByAnInterruptedTemporaryChat() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = try attachment(in: directory)
        _ = await makeApp(attachmentsDirectory: directory)
        #expect(!FileManager.default.fileExists(atPath: try #require(file.fileURL(in: directory)).path(percentEncoded: false)))
    }

    @Test func anUnreadableSnapshotDoesNotAuthorizeAttachmentCleanup() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = try attachment(in: directory)
        let engine = StubEngine(options: .instant)
        let app = AppModel(localEngine: engine, remoteEngine: engine, modelStore: StubModelStore(installed: []),
                           persistence: InMemoryPersistence(), attachmentsDirectory: directory)
        await app.start()
        #expect(FileManager.default.fileExists(atPath: try #require(file.fileURL(in: directory)).path(percentEncoded: false)))
    }

    @Test(arguments: ["../outside.txt", "/outside.txt", ".", "..", "folder\\outside.txt"])
    func importedFileNamesCannotEscapeTheAttachmentDirectory(_ name: String) {
        let file = Attachment(kind: .file, name: "report", byteCount: 1, storedFileName: name)
        #expect(file.fileURL == nil)
    }
}

private actor ImageEngine: Engine {
    private var failPreparation = true
    private(set) var requests: [GenerateRequest] = []
    func probe() -> DeviceProfile { DeviceProfile(canRun: true) }
    func load(optionID: String) {}
    func unload() {}
    func prepareImage(_ file: URL) throws -> PreparedImage {
        if failPreparation {
            failPreparation = false
            throw ServiceError.unreadableFile
        }
        return PreparedImage()
    }
    private func record(_ request: GenerateRequest) { requests.append(request) }
    nonisolated func generate(_ request: GenerateRequest) -> AsyncThrowingStream<GenerationEvent, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                await self.record(request)
                continuation.yield(.done(tokensPerSecond: 1, seconds: 1))
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

@MainActor
@Suite struct MessageRecovery {
    @Test func retryAnswersTheSelectedMessageNotTheNewestFailure() async throws {
        let (app, engine, persistence) = await makeApp()
        await engine.setReachable(false)
        await app.reconnect()
        app.draftText = "问题 A"
        app.send()
        app.draftText = "问题 B"
        app.send()
        guard case .user(let first) = app.current.items[0] else { return #expect(Bool(false)) }
        await engine.setReachable(true)
        await app.reconnect()
        app.retrySend(first.id)
        await settled { app.reply == nil && !app.isQueued && app.current.items.count == 3 }
        guard case .assistant(let answer) = app.current.items[1],
              case .user(let second) = app.current.items[2] else { return #expect(Bool(false)) }
        #expect(answer.text.contains("问题 A"))
        #expect(!answer.text.contains("问题 B"))
        #expect(second.text == "问题 B")
        #expect(second.failed)
        app.regenerate(answer.id)
        await settled { app.reply == nil && !app.isQueued }
        #expect(app.current.items.count == 3)
        #expect(app.current.items.last == .user(second))
        #expect(persistence.load()?.conversations.first { $0.id == app.currentID }?.items.last == .user(second))
    }

    @Test func undoingDeletionRestoresAQueuedMessageAsRetryable() async {
        let option = StubModelStore.placeholderCatalog[0].id
        let (app, engine, _) = await makeApp(loadMarker: option)
        await engine.setFailNextLoad(true)
        app.draftText = "删除后撤销"
        let id = app.currentID
        app.send()
        await settled { app.swapFailure != nil }
        app.delete(id)
        app.runToastAction()
        app.select(id)
        guard case .user(let sent) = app.current.items[0] else { return #expect(Bool(false)) }
        #expect(sent.failed)
        #expect(!app.isQueued)
        app.retrySend(sent.id)
        await settled { app.reply == nil && !app.isQueued && app.current.items.count == 2 }
    }

    @Test func aRemoteRetryLeavesTheDestinationBeforeTheRetriedMessage() async {
        let (app, engine, _) = await makeApp { $0.remoteURL = "wss://gpu.example.com" }
        app.draftText = "本机历史"
        app.send()
        await settled { app.reply == nil && !app.isQueued }
        await engine.setReachable(false)
        await app.reconnect()
        app.draftText = "重试这条"
        app.send()
        guard case .user(let sent)? = app.current.items.last else { return #expect(Bool(false)) }
        app.setPlace(.remote)
        app.retrySend(sent.id)
        await settled { app.reply == nil && !app.isQueued }
        guard case .place(let mark) = app.current.items[2],
              case .user(let retried) = app.current.items[3],
              case .assistant = app.current.items[4] else { return #expect(Bool(false)) }
        #expect(mark.host == "gpu.example.com")
        #expect(retried.id == sent.id)
    }

    @Test func leavingTheForegroundDoesNotStartAQueuedAnswerLater() async {
        let option = StubModelStore.placeholderCatalog[0].id
        let (app, engine, _) = await makeApp(loadMarker: option)
        await engine.setFailNextLoad(true)
        app.draftText = "留待重试"
        app.send()
        await settled { app.swapFailure != nil }
        app.didEnterBackground()
        app.retryLoad()
        await settled { app.loadingOptionID == nil }
        #expect(!app.isQueued)
        #expect(app.reply == nil)
        #expect(app.current.items.count == 1)
        guard case .user(let sent) = app.current.items[0] else { return #expect(Bool(false)) }
        #expect(sent.failed)
    }

    @Test func preparationFailureNeverGeneratesWithoutTheImageAndCanBeRetried() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        var saved = Snapshot()
        saved.onboarded = true
        saved.optionID = StubModelStore.placeholderCatalog[0].id
        let engine = ImageEngine()
        let app = AppModel(localEngine: engine, remoteEngine: engine,
                           modelStore: StubModelStore(installed: [saved.optionID!], tick: .zero),
                           persistence: InMemoryPersistence(snapshot: saved), attachmentsDirectory: directory)
        await app.start()
        await settled { app.loadingOptionID == nil }
        var file = try attachment(in: directory)
        file.kind = .image
        app.addAttachment(file, to: app.currentID)
        app.draftText = "请看附件"
        app.send()
        await settled { app.reply == nil && !app.isQueued && app.current.items.count == 1 }
        #expect(await engine.requests.isEmpty)
        guard case .user(let sent) = app.current.items[0] else { return #expect(Bool(false)) }
        #expect(sent.failed)
        #expect(sent.attachments == [file])
        app.retrySend(sent.id)
        await settled { app.reply == nil && !app.isQueued && app.current.items.count == 2 }
        let requests = await engine.requests
        #expect(requests.count == 1)
        #expect(requests.first?.messages.last?.images.count == 1)
    }
}

private actor BackupSpy: BackupService {
    private typealias Continuation = AsyncThrowingStream<Double, any Error>.Continuation
    private var backup = BackupState(isOn: true, hasCloudCopy: true)
    private(set) var contents: BackupContents
    private(set) var calls: [String] = []
    private let failsDeletion: Bool
    private let holdsUploads: Bool
    private var heldUploads: [UUID: Continuation] = [:]
    init(contents: BackupContents = BackupContents(), failsDeletion: Bool = false, holdsUploads: Bool = false) {
        self.contents = contents
        self.failsDeletion = failsDeletion
        self.holdsUploads = holdsUploads
    }
    func state() -> BackupState { backup }
    func enable() { calls.append("enable"); backup.isOn = true }
    func disable() { calls.append("disable"); backup.isOn = false }
    private func store(_ contents: BackupContents, id: UUID, continuation: Continuation) {
        calls.append("upload")
        self.contents = contents
        if holdsUploads { heldUploads[id] = continuation }
        else { continuation.yield(1); continuation.finish() }
    }
    private func release(_ id: UUID) { heldUploads[id] = nil }
    nonisolated func backUp(_ contents: BackupContents) -> AsyncThrowingStream<Double, any Error> {
        AsyncThrowingStream { continuation in
            let id = UUID()
            let task = Task {
                guard !Task.isCancelled else { return }
                await self.store(contents, id: id, continuation: continuation)
            }
            continuation.onTermination = { _ in
                task.cancel()
                Task { await self.release(id) }
            }
        }
    }
    func restore() -> BackupContents { calls.append("restore"); return contents }
    func deleteCloudCopy() throws {
        calls.append("delete")
        if failsDeletion { throw ServiceError.network }
        backup.hasCloudCopy = false
    }
}

@MainActor
@Suite struct BackupRecovery {
    @Test func offlineModeBlocksRestoreAndCloudDeletionAtTheServiceBoundary() async {
        let spy = BackupSpy()
        let (app, _, _) = await makeApp(services: AppServices(backup: spy))
        app.prefs.offlineMode = true
        await app.restoreBackup()
        await app.deleteCloudCopy()
        #expect(await spy.calls.isEmpty)
        #expect(app.backupOn)
        #expect(app.backup.hasCloudCopy)
        #expect(app.toast?.notice == .backupPaused)
    }

    @Test func uploadsExcludeLocalDraftsAndTemporaryConversations() async {
        let spy = BackupSpy()
        let (app, _, persistence) = await makeApp(services: AppServices(backup: spy))
        app.draftText = "普通对话"
        app.send()
        await settled { app.reply == nil && !app.isQueued }
        let kept = app.currentID
        app.remember("恢复这条记忆")
        app.draftText = "不要备份这份草稿"
        app.newConversation()
        app.toggleTemporary()
        app.draftText = "临时秘密"
        await app.backUpNow()
        let sent = await spy.contents
        #expect(sent.conversations.map(\.id) == [kept])
        #expect(sent.memories == ["恢复这条记忆"])
        #expect(persistence.load()?.drafts?[kept]?.text == "不要备份这份草稿")
    }

    @Test func restoreMergesMemoriesAndConversationsWithoutOverwritingOrDuplicating() async {
        let existing = Conversation(scene: .life)
        var duplicate = existing
        duplicate.title = "不应覆盖本机"
        let added = Conversation(scene: .work)
        let contents = BackupContents(conversations: [duplicate, added, added], memories: ["已有", "取回", "取回"])
        let spy = BackupSpy(contents: contents)
        let (app, _, persistence) = await makeApp(services: AppServices(backup: spy)) {
            $0.conversations = [existing]
            $0.memories = ["已有"]
        }
        await app.restoreBackup()
        #expect(app.conversations.first { $0.id == existing.id } == existing)
        #expect(app.conversations.filter { $0.id == added.id }.count == 1)
        #expect(app.memories == ["已有", "取回"])
        #expect(persistence.load()?.memories == ["已有", "取回"])
    }

    @Test func deletingTheCloudCopyDisablesBackupFirst() async {
        let spy = BackupSpy()
        let (app, _, _) = await makeApp(services: AppServices(backup: spy))
        await app.deleteCloudCopy()
        #expect(await spy.calls == ["disable", "delete"])
        #expect(!app.backupOn)
        #expect(!app.backup.hasCloudCopy)
        #expect(app.toast?.notice == .cloudCopyDeleted)
    }

    @Test func aFailedDeletionKeepsTheCopyRetryableAndBackupDisabled() async {
        let spy = BackupSpy(failsDeletion: true)
        let (app, _, _) = await makeApp(services: AppServices(backup: spy))
        await app.deleteCloudCopy()
        #expect(!app.backupOn)
        #expect(app.backup.hasCloudCopy)
        #expect(app.toast?.notice != .cloudCopyDeleted)
    }

    @Test func disablingAnUploadAndImmediatelyUndoingRestartsBackup() async {
        let spy = BackupSpy(holdsUploads: true)
        let (app, _, _) = await makeApp(services: AppServices(backup: spy))
        let first = Task { await app.backUpNow() }
        await settled { await spy.calls.filter { $0 == "upload" }.count == 1 }
        await app.disableBackup()
        await first.value
        app.runToastAction()
        await settled { await spy.calls.filter { $0 == "upload" }.count == 2 }
        #expect(app.backupOn)
        await app.disableBackup()
    }

    @Test func leavingOfflineModeResumesAnInterruptedBackup() async {
        let spy = BackupSpy(holdsUploads: true)
        let (app, _, _) = await makeApp(services: AppServices(backup: spy))
        let first = Task { await app.backUpNow() }
        await settled { await spy.calls.filter { $0 == "upload" }.count == 1 }
        app.prefs.offlineMode = true
        await first.value
        app.prefs.offlineMode = false
        await settled { await spy.calls.filter { $0 == "upload" }.count == 2 }
        #expect(app.backupOn)
        await app.disableBackup()
    }
}
