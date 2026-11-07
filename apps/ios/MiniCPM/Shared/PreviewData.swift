import MiniCPMCore

/// Previews use the in-memory stack, so they never touch the app's real files.
enum PreviewData {
    @MainActor
    static func model(installed: [String] = ["minicpm-v-4.6:q4"], onboarded: Bool = true) -> AppModel {
        var snapshot = Snapshot()
        snapshot.onboarded = onboarded
        let model = AppModel(
            localEngine: StubEngine(),
            remoteEngine: StubEngine(),
            modelStore: StubModelStore(installed: installed),
            persistence: InMemoryPersistence(snapshot: snapshot)
        )
        return model
    }
}
