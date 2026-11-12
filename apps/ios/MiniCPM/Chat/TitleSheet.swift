import MiniCPMCore
import SwiftUI

/// Tapping the title: what the desktop header and composer show at once lives here on a phone.
struct TitleSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var asking: ModelOption?
    /// Runs after this sheet closes, because another sheet cannot open from under it.
    let after: @MainActor (@escaping @MainActor () -> Void) -> Void
    let rename: @MainActor () -> Void
    let showDetails: @MainActor () -> Void

    init(
        after: @escaping @MainActor (@escaping @MainActor () -> Void) -> Void,
        rename: @escaping @MainActor () -> Void,
        showDetails: @escaping @MainActor () -> Void
    ) {
        self.after = after
        self.rename = rename
        self.showDetails = showDetails
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(model.modelChoices) { option in
                        modelRow(option)
                        // A mistap must do nothing, so the confirm opens in place. System menus cannot expand, so it is a row here.
                        if sizeClass == .compact, asking == option {
                            SwapConfirmRow(option: option) { asking = nil }
                        }
                    }
                } header: {
                    Text(model.isRemote ? "模型 · 所有对话共用" : "模型 · 一次只运行一个，所有对话共用")
                }

                Section("运行位置") {
                    placeRow(.local, title: "这台设备", detail: model.backupOn ? "在本机处理" : "内容不离开本机")
                    placeRow(.remote, title: "远程服务", detail: model.remoteURL.isEmpty ? "还没设置，去填写地址" : "内容会发送到 \(model.remoteHost)")
                }

                Section("场景") {
                    Picker("应用场景", selection: Binding { model.current.scene } set: { model.setScene($0) }) {
                        ForEach(model.activeScenes) { Text(Copy.sceneName($0)).tag($0) }
                    }
                }

                Section {
                    let named = !model.current.isBlank
                    if named && !model.current.isTemporary {
                        Button("重命名", systemImage: "pencil") { close(then: rename) }
                    }
                    Button("对话详情", systemImage: "info.circle") { close(then: showDetails) }
                    if named {
                        Button("导出这段对话", systemImage: "square.and.arrow.up") { close { model.export(model.currentID) } }
                        Button("删除对话", systemImage: "trash", role: .destructive) {
                            model.delete(model.currentID)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("当前对话")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .close) { dismiss() }
                }
            }
            .overlay(alignment: .bottom) { ToastView(announces: false) }
            .privacyCovered(inSheet: true)
            .confirmationDialog("换用这个模型？", item: regularAsking, titleVisibility: .visible) { option in
                Button("换用") { model.setModel(option.id) }
                Button("先不换", role: .cancel) {}
            } message: { option in
                Text(Swap.message(option, model))
            }
        }
    }

    private var regularAsking: Binding<ModelOption?> {
        Binding { sizeClass == .compact ? nil : asking } set: { asking = $0 }
    }

    private func modelRow(_ option: ModelOption) -> some View {
        let missing = !model.isRemote && !model.installed.contains(option.id)
        return Button {
            if missing {
                close { model.settingsRoute = .models }
            } else if option.id != model.currentOptionID {
                if model.reply != nil {
                    model.setModel(option.id)
                } else {
                    asking = option
                }
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.name).foregroundStyle(Color.primary)
                    Text(missing ? String(localized: "未下载，去设置里下载") : model.isRemote ? Copy.capabilities(option) : "\(Copy.spec(option)) · \(Copy.capabilities(option))")
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                }
                Spacer()
                if option.id == model.currentOptionID {
                    Image(systemName: "checkmark").foregroundStyle(.tint).accessibilityLabel("使用中")
                }
            }
        }
    }

    private func placeRow(_ place: Place, title: LocalizedStringKey, detail: LocalizedStringKey) -> some View {
        Button {
            if place == .remote && model.remoteURL.isEmpty {
                close { model.setPlace(.remote) }
            } else {
                model.setPlace(place)
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).foregroundStyle(Color.primary)
                    Text(detail).font(.caption).foregroundStyle(Color.secondary)
                }
                Spacer()
                if model.place == place {
                    Image(systemName: "checkmark").foregroundStyle(.tint).accessibilityLabel("使用中")
                }
            }
        }
    }

    private func close(then action: @escaping @MainActor () -> Void) {
        after(action)
        dismiss()
    }
}

enum Swap {
    @MainActor
    static func message(_ option: ModelOption, _ model: AppModel) -> String {
        model.isRemote ? String(localized: "所有对话都会改用 \(option.name)。") : String(localized: "所有对话都会改用 \(option.name)，要等约 \(Copy.duration(option.loadSeconds))。", comment: "Model switch confirmation; placeholders are the model name and system-formatted duration.")
    }
}

struct SwapConfirmRow: View {
    @Environment(AppModel.self) private var model
    let option: ModelOption
    let close: @MainActor () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(Swap.message(option, model)).font(.footnote)
            HStack {
                Button("换用") {
                    model.setModel(option.id)
                    close()
                }
                .prominentButton()
                Button("先不换") { close() }.buttonStyle(.bordered)
            }
        }
    }
}
