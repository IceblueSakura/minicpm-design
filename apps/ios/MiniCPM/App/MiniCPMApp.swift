import MiniCPMCore
import SwiftUI

@main
struct MiniCPMApp: App {
    // Real engines replace the stubs inside `AppModel.stubbed`. See apps/ios/README.md.
    @State private var model = AppModel.stubbed(arguments: ProcessInfo.processInfo.arguments)

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
        }
    }
}
