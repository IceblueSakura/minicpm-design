import Foundation
import Testing
@testable import MiniCPMCore

private let v46 = "minicpm-v-4.6:q4"
private let v45 = "minicpm-v-4.5:q4"

@MainActor
private func makeApp(
    installed: [String] = [v46, v45],
    onboarded: Bool = true,
    loadMarker: String? = nil,
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
        persistence: persistence
    )
    await app.start()
    await settled { app.loadingOptionID == nil }
    return (app, engine, persistence)
}

@MainActor
private func settled(_ condition: () -> Bool) async {
    for _ in 0..<2000 where !condition() { await Task.yield() ; try? await Task.sleep(for: .milliseconds(1)) }
    #expect(condition())
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
        app.backupOn = true
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
