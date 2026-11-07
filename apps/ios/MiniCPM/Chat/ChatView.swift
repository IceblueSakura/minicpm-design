import MiniCPMCore
import SwiftUI

struct ChatView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var showsTitleSheet = false
    @State private var showsDetails = false
    @State private var afterTitleSheet: (@MainActor () -> Void)?
    @State private var renaming: Conversation?
    @State private var newTitle = ""
    @State private var composerHeight: CGFloat = 0

    private var title: String {
        let conversation = model.current
        guard conversation.isFresh else { return conversation.title }
        return conversation.isTemporary ? String(localized: "临时对话") : model.currentOption?.name ?? "MiniCPM"
    }

    var body: some View {
        Group {
            if model.current.isBlank {
                EmptyConversationView()
            } else {
                ThreadView()
            }
        }
        .safeAreaBar(edge: .bottom) {
            ComposerArea().onGeometryChange(for: CGFloat.self, of: \.size.height) { composerHeight = $0 }
        }
        // Outside the bar, because a view hanging out of it shows but takes no taps. The height clears a banner of any size.
        .overlay(alignment: .bottom) { ToastView(bottomInset: composerHeight + 8) }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .sheet(isPresented: $showsTitleSheet, onDismiss: { runAfterTitleSheet() }) {
            TitleSheet(
                after: { afterTitleSheet = $0 },
                rename: { beginRename() },
                showDetails: { showsDetails = true }
            )
            .presentationDetents([.medium, .large])
        }
        .inspector(isPresented: $showsDetails) {
            ConversationDetailsView()
                .inspectorColumnWidth(296)
                .presentationDetents([.medium, .large])
        }
        .alert("重命名", item: $renaming) { conversation in
            TextField("名称", text: $newTitle)
            Button("保存") { model.rename(conversation.id, to: newTitle) }
            Button("取消", role: .cancel) {}
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Button {
                showsTitleSheet = true
            } label: {
                VStack(spacing: 0) {
                    HStack(spacing: 4) {
                        Text(title).font(.headline).lineLimit(1)
                        Image(systemName: "chevron.down").font(.caption2.weight(.semibold))
                    }
                    Text(Copy.headStatus(model.headStatus)).font(.caption).foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint("打开模型和处理位置")
        }
        if sizeClass == .regular {
            ToolbarItemGroup {
                Button("对话详情", systemImage: "sidebar.right") { showsDetails.toggle() }
            }
            .visibilityPriority(.high)
            ToolbarOverflowMenu {
                if !model.current.isBlank {
                    Button("重命名", systemImage: "pencil") { beginRename() }
                    Button("导出这段对话", systemImage: "square.and.arrow.up") { model.export(model.currentID) }
                    Button("删除对话", systemImage: "trash", role: .destructive) { model.delete(model.currentID) }
                }
            }
        }
        // A new chat means nothing on a blank one, so that spot belongs to the temporary switch until there is content.
        ToolbarItem(placement: .topBarPinnedTrailing) {
            if model.current.isFresh {
                Button("临时对话", systemImage: "eye.slash") { model.toggleTemporary() }
                    .symbolVariant(model.current.isTemporary ? .fill : .none)
                    .accessibilityValue(model.current.isTemporary ? "已开启" : "已关闭")
            } else {
                Button("新对话", systemImage: "square.and.pencil") { model.newConversation() }
            }
        }
    }

    private func beginRename() {
        newTitle = model.current.title
        renaming = model.current
    }

    private func runAfterTitleSheet() {
        afterTitleSheet?()
        afterTitleSheet = nil
    }
}

/// The first screen: you can start right away, and it says where content goes.
struct EmptyConversationView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dictation) private var dictation

    var body: some View {
        let temporary = model.current.isTemporary
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 12) {
                    // The keyboard plus a banner leaves little room, and the words matter more than the mark.
                    if proxy.size.height > 280 {
                        BrandMark().frame(width: 48, height: 48)
                    }
                    Text(temporary ? "这段对话不会留下" : "想一起做点什么？")
                        .font(.title2.weight(.semibold))
                    Text(temporary ? "离开后不保存记录，也不写入记忆。" : dictation.isAvailable ? "打字、说话，或者拍给它看。" : "打字，或者把图片和文档给它看。")
                        .foregroundStyle(.secondary)
                    Label(Copy.privacyLine(model.privacy), systemImage: "checkmark.shield")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    SceneMenu()
                }
                .multilineTextAlignment(.center)
                .padding(24)
                .frame(maxWidth: .infinity)
                // A minimum, not a fixed height: when the space is short the content has to scroll instead of sliding under the bar.
                .frame(minHeight: proxy.size.height)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }
}

struct SceneMenu: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Menu {
            Picker("应用场景", selection: Binding { model.current.scene } set: { model.setScene($0) }) {
                ForEach(model.activeScenes) { scene in
                    Text(Copy.sceneName(scene)).tag(scene)
                }
            }
        } label: {
            Label(Copy.sceneName(model.current.scene), systemImage: "chevron.up.chevron.down")
                .labelStyle(.titleAndIcon)
        }
        .buttonStyle(.bordered)
    }
}

#Preview("空白对话") {
    NavigationStack { ChatView() }.environment(PreviewData.model()).environment(SpeechReader())
}
