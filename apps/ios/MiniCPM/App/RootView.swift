import MiniCPMCore
import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @State private var reader = SpeechReader()

    var body: some View {
        @Bindable var model = model
        ZStack {
            // Locked, the content is not built at all. Covering it would hide the pixels only: VoiceOver could still
            // read and tap the conversation underneath. This also closes panels that were open on it.
            if model.isLocked {
                LockView()
            } else if model.device == nil {
                Color.clear
            } else if model.onboarding != nil {
                OnboardingView()
            } else {
                MainView()
            }
        }
        .privacyCovered()
        .overlay(alignment: .bottom) {
            if model.onboarding != nil { ToastView() }
        }
        .environment(reader)
        .sheet(item: $model.settingsRoute) { page in
            SettingsView(start: page)
        }
        // Settings shares from its own sheet: a second one cannot open from under it.
        .sheet(item: Binding { model.settingsRoute == nil ? model.exportFile : nil } set: { model.exportFile = $0 }) { file in
            ShareSheet(url: file.url)
        }
        .task { await model.start() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                model.didEnterBackground()
                reader.stop()
            } else if phase == .active {
                model.didBecomeActive()
            }
        }
    }
}

/// Keeps content out of the app switcher and out of recordings when those settings are on.
/// Sheets sit above the root, so each one carries this too; there it also stands in for the lock.
private struct PrivacyCover: ViewModifier {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    let coversLock: Bool

    private var isCovered: Bool {
        (scenePhase != .active && model.prefs.hidePreview) || (model.isScreenCaptured && model.prefs.coverWhileRecording) || (coversLock && model.isLocked)
    }

    func body(content: Content) -> some View {
        content.overlay {
            if isCovered {
                ZStack {
                    Rectangle().fill(.background)
                    BrandMark().frame(width: 56, height: 56)
                }
                .ignoresSafeArea()
                .accessibilityHidden(true)
            }
        }
    }
}

extension View {
    func privacyCovered(inSheet: Bool = false) -> some View {
        modifier(PrivacyCover(coversLock: inSheet))
    }
}

/// Only the mark and the way in, per the privacy design. Asks by itself once, then waits for the button.
private struct LockView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack {
            Rectangle().fill(.background)
            VStack(spacing: 24) {
                BrandMark().frame(width: 56, height: 56)
                Button("解锁") { Task { await model.unlock() } }
                    .prominentGlassButton()
                    .controlSize(.large)
            }
        }
        .ignoresSafeArea()
        .task { await model.unlock() }
    }
}

/// System list-detail: opening lands on the conversation, back goes to the history, wide windows get a sidebar.
struct MainView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var column = NavigationSplitViewColumn.detail

    var body: some View {
        NavigationSplitView(preferredCompactColumn: $column) {
            ConversationListView(column: $column)
                // Otherwise the composer area shows it. On a phone the history covers that.
                .overlay(alignment: .bottom) {
                    if sizeClass == .compact && column == .sidebar { ToastView() }
                }
        } detail: {
            ChatView()
                .id(model.currentID)
        }
    }
}

#Preview {
    RootView().environment(PreviewData.model())
}
