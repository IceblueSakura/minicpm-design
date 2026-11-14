import Foundation
import Testing
@testable import MiniCPMCore

private let v46 = "minicpm-v-4.6:q4"
private let v45 = "minicpm-v-4.5:q4"

@MainActor
func makeApp(
    installed: [String] = [v46, v45],
    onboarded: Bool = true,
    loadMarker: String? = nil,
    services: AppServices = .unconnected,
    attachmentsDirectory: URL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString),
    configure: (inout Snapshot) -> Void = { _ in }
) async -> (app: AppModel, engine: StubEngine, persistence: InMemoryPersistence) {
    var snapshot = Snapshot()
    snapshot.onboarded = onboarded
    snapshot.optionID = v46
    configure(&snapshot)
    let persistence = InMemoryPersistence(snapshot: snapshot, loadMarker: loadMarker)
    let engine = StubEngine(options: .instant)
    let app = AppModel(
        localEngine: engine,
        remoteEngine: StubEngine(options: .instant),
        modelStore: StubModelStore(installed: installed, tick: .zero),
        persistence: persistence,
        services: services,
        attachmentsDirectory: attachmentsDirectory
    )
    await app.start()
    await settled { app.loadingOptionID == nil }
    return (app, engine, persistence)
}

@MainActor
func settled(_ condition: () async -> Bool) async {
    for _ in 0..<2000 {
        if await condition() { return }
        await Task.yield()
        try? await Task.sleep(for: .milliseconds(1))
    }
    #expect(await condition())
}

@MainActor
@Suite struct Privacy {
    @Test func everyOnDeviceClaimNamesTheDestinationWhenRemote() async {
        let (app, _, _) = await makeApp { $0.place = .remote; $0.remoteURL = "wss://gpu.example.com/omni" }
        #expect(app.privacy == .sendingTo(host: "gpu.example.com"))
        app.prefs.offlineMode = true
        #expect(app.privacy == .offlineBlocksRemote)
    }

    @Test func remoteWithoutAddressSendsNothing() async {
        let (app, _, _) = await makeApp { $0.place = .remote }
        #expect(app.privacy == .remoteNotSet)
        #expect(!app.sendingOut)
    }

    @Test func backupChangesTheLocalClaim() async {
        let (app, _, _) = await makeApp()
        #expect(app.privacy == .onDevice)
        app.backup.isOn = true
        #expect(app.privacy == .onDeviceBackedUp)
    }

    @Test func temporaryConversationsNeverReachDisk() async {
        let (app, _, persistence) = await makeApp()
        app.toggleTemporary()
        app.draftText = "秘密"
        app.send()
        await settled { app.reply == nil && app.current.items.count >= 2 }
        #expect(persistence.load()?.conversations.isEmpty == true)
    }
}

@MainActor
@Suite struct BackendPriority {
    @Test func unsetRemoteBeatsOfflineMode() async {
        let (app, _, _) = await makeApp { $0.place = .remote; $0.prefs.offlineMode = true }
        #expect(app.backendState == .remoteNotSet)
    }

    @Test func offlineModeBlocksRemoteButNotDevice() async {
        let (remote, _, _) = await makeApp { $0.place = .remote; $0.remoteURL = "wss://a.example"; $0.prefs.offlineMode = true }
        #expect(remote.backendState == .offlineMode)
        let (local, _, _) = await makeApp { $0.prefs.offlineMode = true }
        #expect(local.backendState == .ready)
    }

    @Test func missingModelBlocksSendingAndKeepsTheDraft() async {
        let (app, _, _) = await makeApp(installed: [])
        #expect(app.backendState == .noModel)
        app.draftText = "还在"
        app.send()
        #expect(app.draftText == "还在")
        #expect(app.current.isBlank)
    }
}

@MainActor
@Suite struct ModelSwitching {
    @Test func outOfMemoryGoesBackToThePreviousModel() async {
        let (app, engine, persistence) = await makeApp()
        #expect(app.loadedOptionID == v46)
        await engine.setFailNextLoad(true)
        app.setModel(v45)
        await settled { app.swapFailure != nil && app.loadingOptionID == nil }
        #expect(app.currentOptionID == v46)
        #expect(app.loadedOptionID == v46)
        #expect(app.swapFailure == SwapFailure(optionID: v45, restoredTo: v46))
        #expect(persistence.loadMarker == nil)
    }

    @Test func aColdFailureKeepsTheSentMessageWaiting() async {
        // The crash marker stops the launch load, so nothing is in memory when the message goes out.
        let (app, engine, _) = await makeApp(loadMarker: v46)
        await engine.setFailNextLoad(true)
        app.draftText = "你好"
        app.send()
        await settled { app.swapFailure != nil }
        #expect(app.swapFailure == SwapFailure(optionID: v46, restoredTo: nil))
        #expect(app.current.items.count == 1)
        app.retryLoad()
        await settled { app.reply == nil && app.current.items.count == 2 }
        #expect(app.loadedOptionID == v46)
        #expect(app.swapFailure == nil)
    }

    @Test func aLoadThatKilledTheAppIsNotRetriedByItself() async {
        let (app, _, persistence) = await makeApp(loadMarker: v46)
        #expect(app.loadedOptionID == nil)
        #expect(app.banner == .crashedLoading(StubModelStore.placeholderCatalog[0]))
        #expect(persistence.loadMarker == nil)
    }
}

@MainActor
@Suite struct PlaceRules {
    @Test func aFailureNeverMovesContentToTheOtherPlace() async {
        let (app, engine, _) = await makeApp { $0.remoteURL = "wss://a.example" }
        await engine.setReachable(false)
        app.draftText = "别发出去"
        app.send()
        await settled { app.reply == nil && app.backendState == .notResponding }
        #expect(app.place == .local)
        guard case .user(let message)? = app.current.items.first else { return #expect(Bool(false)) }
        #expect(message.failed)
    }

    @Test func undoRestoresThePlaceAndTheFirstRemoteMessageLeavesAMark() async {
        let (app, _, _) = await makeApp { $0.remoteURL = "wss://gpu.example.com/omni" }
        app.draftText = "第一条"
        app.send()
        await settled { app.reply == nil && app.current.items.count == 2 }

        app.setPlace(.remote)
        app.runToastAction()
        #expect(app.place == .local)

        app.setPlace(.remote)
        app.draftText = "第二条"
        app.send()
        await settled { app.reply == nil && app.current.items.count == 5 }
        guard case .place(let mark) = app.current.items[2] else { return #expect(Bool(false)) }
        #expect(mark.host == "gpu.example.com")
    }
}

@Suite struct Decoding {
    @Test func unknownItemTypesAreSkipped() throws {
        var conversation = Conversation(scene: .life)
        conversation.items = [.user(UserMessage(text: "你好"))]
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(conversation)) as! [String: Any]
        var items = json["items"] as! [[String: Any]]
        items.insert(["type": "live", "turns": []], at: 0)
        json["items"] = items
        let decoded = try JSONDecoder().decode(Conversation.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(decoded.items == conversation.items)
    }

    @Test func aPrefMissingFromAnOldFileReadsItsDefault() throws {
        let decoded = try JSONDecoder().decode(Prefs.self, from: Data(#"{"thermal":false}"#.utf8))
        #expect(decoded.thermal == false)
        #expect(decoded.keepHistory == true)
    }
}

@MainActor
@Suite struct Queue {
    @Test func aSecondSendDuringTheWaitStaysInTheBox() async {
        let (app, _, _) = await makeApp()
        app.setModel(v45)
        app.draftText = "第一句"
        app.send()
        app.draftText = "第二句"
        app.send()
        #expect(app.draftText == "第二句")
        await settled { !app.isQueued && app.reply == nil }
        let sent = app.current.items.filter { if case .user = $0 { true } else { false } }
        #expect(sent.count == 1)
    }
}

/// Records what reached the service, so a test can say nothing left the device.
private actor Spy: SearchService, SystemActionService {
    private(set) var queries: [String] = []
    private(set) var memos: [String] = []
    var failure: ServiceError?

    func fail(with error: ServiceError) { failure = error }
    func search(query: String) async throws -> [SearchResult] {
        if let failure { throw failure }
        queries.append(query)
        return []
    }
    func scheduleNotification(when: String?, text: String, conversationID: UUID) async throws {}
    func writeMemo(_ text: String) async throws { memos.append(text) }
}

private struct Lock: AppLockService {
    var isAvailable: Bool { true }
    let passes: Bool
    func authenticate() async -> Bool { passes }
}

@MainActor
private func reply(_ app: AppModel, _ text: String) async {
    app.draftText = text
    app.send()
    await settled { app.reply == nil && !app.isQueued }
}

@MainActor
@Suite struct Services {
    private func searchCardID(_ app: AppModel) -> (id: UUID, state: CardState)? {
        for case .search(let card) in app.current.items { return (card.id, card.state) }
        return nil
    }

    @Test func aSearchIsLoggedOnlyAfterItWentOut() async throws {
        let spy = Spy()
        let (app, _, _) = await makeApp(services: AppServices(search: spy))
        await reply(app, "查一下 天气")
        let card = try #require(searchCardID(app))
        app.answerSearch(card.id, accept: true)
        await settled { searchCardID(app)?.state == .accepted }
        #expect(await spy.queries.count == 1)
        #expect(app.networkLog.first?.kind == .search)
    }

    @Test func anUnconnectedSearchLeavesTheCardAndTheLogAlone() async throws {
        let (app, _, _) = await makeApp()
        await reply(app, "查一下 天气")
        let before = app.networkLog.count
        let card = try #require(searchCardID(app))
        app.answerSearch(card.id, accept: true)
        await settled { app.toast?.notice == .notConnectedYet }
        #expect(searchCardID(app)?.state == .pending)
        #expect(app.networkLog.count == before)
    }

    @Test func offlineModeBlocksTheSearchEvenIfTheCardIsTapped() async throws {
        let spy = Spy()
        let (app, _, _) = await makeApp(services: AppServices(search: spy))
        await reply(app, "查一下 天气")
        app.prefs.offlineMode = true
        let card = try #require(searchCardID(app))
        app.answerSearch(card.id, accept: true)
        try await Task.sleep(for: .milliseconds(20))
        #expect(await spy.queries.isEmpty)
    }

    @Test func enablingBackupChangesTheClaimAndUploads() async {
        let (app, _, _) = await makeApp(services: .demo())
        #expect(app.privacy == .onDevice)
        await app.enableBackup()
        #expect(app.privacy == .onDeviceBackedUp)
        #expect(app.backup.hasCloudCopy)
        #expect(app.networkLog.first?.kind == .backup)
    }

    @Test func unconnectedBackupStaysOff() async {
        let (app, _, _) = await makeApp()
        await app.enableBackup()
        #expect(!app.backupOn)
        #expect(app.privacy == .onDevice)
        #expect(app.toast?.notice == .notConnectedYet)
    }

    @Test func offlineModePausesBackup() async {
        let (app, _, _) = await makeApp(services: .demo())
        app.prefs.offlineMode = true
        await app.enableBackup()
        #expect(!app.backupOn)
        #expect(app.toast?.notice == .backupPaused)
    }

    @Test func importSkipsDuplicatesAndCanBeUndone() async throws {
        let (app, _, _) = await makeApp(services: .demo())
        await reply(app, "第一段")
        app.export()
        await settled { app.exportFile != nil }
        let file = try #require(app.exportFile).url
        let existing = app.conversations.count

        await app.importFile(file)
        #expect(app.toast?.notice == .imported(added: 0, skipped: 1))

        let other = Conversation(scene: .life)
        try JSONEncoder().encode([other]).write(to: file)
        await app.importFile(file)
        #expect(app.conversations.count == existing + 1)
        app.runToastAction()
        #expect(app.conversations.count == existing)
    }

    @Test func aBadImportChangesNothing() async throws {
        let (app, _, _) = await makeApp(services: .demo())
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("not-minicpm.json")
        try Data("nope".utf8).write(to: file)
        let before = app.conversations
        await app.importFile(file)
        #expect(app.importFailed)
        #expect(app.conversations == before)
    }

    @Test func noLockServiceMeansNoLock() async {
        let (app, _, _) = await makeApp { $0.prefs.appLock = true }
        #expect(!app.isLocked)
    }

    @Test func locksAtLaunchAndAfterTheChosenTime() async {
        let (app, _, _) = await makeApp(services: AppServices(lock: Lock(passes: true))) {
            $0.prefs.appLock = true
            $0.prefs.autoLock = .m1
        }
        #expect(app.isLocked)
        await app.unlock()
        #expect(!app.isLocked)

        app.didEnterBackground()
        app.didBecomeActive(now: Date().addingTimeInterval(30))
        #expect(!app.isLocked)

        app.didEnterBackground()
        app.didBecomeActive(now: Date().addingTimeInterval(61))
        #expect(app.isLocked)
    }

    @Test func aFailedCheckKeepsItLocked() async {
        let (app, _, _) = await makeApp(services: AppServices(lock: Lock(passes: false))) { $0.prefs.appLock = true }
        await app.unlock()
        #expect(app.isLocked)
    }

    @Test func conditionsReachTheModel() async {
        let (app, _, _) = await makeApp(services: .demo(conditions: [.screenCaptured(true), .thermal(.hot)]))
        await settled { app.isScreenCaptured && app.thermal == .hot }
    }
}
