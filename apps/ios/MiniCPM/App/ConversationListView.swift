import MiniCPMCore
import SwiftUI

struct ConversationListView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Binding var column: NavigationSplitViewColumn
    @State private var query = ""
    @State private var renaming: Conversation?
    @State private var newTitle = ""

    init(column: Binding<NavigationSplitViewColumn>) {
        _column = column
    }

    private var selection: Binding<UUID?> {
        Binding {
            // On a phone a selection means "showing that one": any change would push the chat over the list, even a delete.
            sizeClass == .compact && column == .sidebar ? nil : model.currentID
        } set: { id in
            guard let id else { return }
            model.select(id)
            column = .detail
        }
    }

    private var visible: [Conversation] {
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        return model.conversations
            .filter { !$0.isTemporary && !$0.isFresh }
            .filter { needle.isEmpty || "\($0.title) \(Copy.sceneName($0.scene))".lowercased().contains(needle) }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    var body: some View {
        let rows = visible
        let today = rows.filter { Calendar.current.isDateInToday($0.updatedAt) }
        let earlier = rows.filter { !Calendar.current.isDateInToday($0.updatedAt) }
        List(selection: selection) {
            if !today.isEmpty {
                Section("今天") { ForEach(today) { row($0) } }
            }
            if !earlier.isEmpty {
                Section("更早") { ForEach(earlier) { row($0) } }
            }
        }
        .overlay {
            if rows.isEmpty {
                if query.isEmpty {
                    ContentUnavailableView("还没有对话", systemImage: "bubble.left.and.bubble.right", description: Text("开始一段新对话后，它会留在这里。"))
                } else {
                    ContentUnavailableView("没有找到“\(query)”", systemImage: "magnifyingglass", description: Text("试试场景名，比如生活助手。"))
                }
            }
        }
        .navigationTitle("MiniCPM")
        .searchable(text: $query, prompt: "搜索对话")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("设置", systemImage: "gearshape") { model.settingsRoute = .index }
            }
            ToolbarItem(placement: .topBarPinnedTrailing) {
                Button("新对话", systemImage: "square.and.pencil") {
                    model.newConversation()
                    column = .detail
                }
            }
        }
        .safeAreaBar(edge: .bottom) { EngineStatusRow() }
        .alert("重命名", item: $renaming) { conversation in
            TextField("名称", text: $newTitle)
            Button("保存") { model.rename(conversation.id, to: newTitle) }
            Button("取消", role: .cancel) {}
        }
    }

    private func row(_ conversation: Conversation) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(conversation.title).lineLimit(1)
                Text("\(Copy.sceneName(conversation.scene)) · \(conversation.updatedAt.formatted(.relative(presentation: .named)))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if model.reply?.conversationID == conversation.id {
                ProgressView().accessibilityLabel("正在生成")
            } else if conversation.hasUnread {
                Image(systemName: "circle.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.tint)
                    .accessibilityLabel("有新回复")
            }
        }
        .tag(conversation.id)
        // Deleting offers undo, so it does not ask first.
        .swipeActions {
            Button("删除", systemImage: "trash", role: .destructive) { model.delete(conversation.id) }
        }
        .contextMenu {
            Button("重命名", systemImage: "pencil") {
                newTitle = conversation.title
                renaming = conversation
            }
            Button("导出", systemImage: "square.and.arrow.up") { model.export(conversation.id) }
            Button("删除", systemImage: "trash", role: .destructive) { model.delete(conversation.id) }
        }
    }
}

/// Answers "is the model ready" at a glance. Tapping goes to the model settings.
private struct EngineStatusRow: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Button {
            model.settingsRoute = .models
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.currentOption?.name ?? "还没选模型").font(.subheadline.weight(.medium))
                Text(Copy.engineStatus(model)).font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
