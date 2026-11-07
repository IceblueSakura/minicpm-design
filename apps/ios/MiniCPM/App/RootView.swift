import MiniCPMCore
import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @State private var reader = SpeechReader()

    var body: some View {
        @Bindable var model = model
        ZStack {
            if model.device == nil {
                Color.clear
            } else if model.onboarding != nil {
                OnboardingView()
            } else {
                MainView()
            }
            if scenePhase != .active && model.prefs.hidePreview {
                PrivacyCover()
            }
        }
        .overlay(alignment: .bottom) { ToastView() }
        .environment(reader)
        .sheet(item: $model.settingsRoute) { page in
            SettingsView(start: page)
        }
        .task { await model.start() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                model.didEnterBackground()
                reader.stop()
            }
        }
    }
}

/// Keeps content out of the app switcher when "切到后台时隐藏内容" is on.
private struct PrivacyCover: View {
    var body: some View {
        ZStack {
            Rectangle().fill(.background)
            BrandMark().frame(width: 56, height: 56)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// System list-detail: opening lands on the conversation, back goes to the history, wide windows get a sidebar.
struct MainView: View {
    @Environment(AppModel.self) private var model
    @State private var column = NavigationSplitViewColumn.detail

    var body: some View {
        NavigationSplitView(preferredCompactColumn: $column) {
            ConversationListView(column: $column)
        } detail: {
            ChatView()
                .id(model.currentID)
        }
    }
}

#Preview {
    RootView().environment(PreviewData.model())
}
