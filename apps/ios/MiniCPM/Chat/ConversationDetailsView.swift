import MiniCPMCore
import SwiftUI

struct ConversationDetailsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationStack {
            List {
                // Where content is processed always comes first.
                Section {
                    Label(model.isRemote ? (model.remoteURL.isEmpty ? String(localized: "还没设置远程服务") : model.remoteHost) : String(localized: "这台设备"), systemImage: "checkmark.shield")
                } header: {
                    Text("处理位置")
                } footer: {
                    Text(footer)
                }

                Section("材料") {
                    if model.current.sources.isEmpty {
                        Text("发送的文件会收在这里。").foregroundStyle(.secondary)
                    } else {
                        ForEach(model.current.sources, id: \.self) { Label($0, systemImage: "paperclip") }
                    }
                }

                Section("产物") {
                    Text("对话生成的文档会收在这里。").foregroundStyle(.secondary)
                }

                Section {
                    Picker("应用场景", selection: Binding { model.current.scene } set: { model.setScene($0) }) {
                        ForEach(model.activeScenes) { Text(Copy.sceneName($0)).tag($0) }
                    }
                } footer: {
                    Text(Copy.sceneHint(model.current.scene))
                }

                if let option = model.currentOption {
                    Section {
                        LabeledContent(option.name, value: option.kind == .omni ? String(localized: "全能") : String(localized: "看图"))
                    } header: {
                        Text("模型")
                    } footer: {
                        Text(model.isRemote ? Copy.capabilities(option) : "\(Copy.spec(option)) · \(Copy.capabilities(option))")
                    }
                }
            }
            .navigationTitle("对话详情")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var footer: String {
        if model.sendingOut { return String(localized: "内容会发送到这台服务器处理。") }
        if model.isRemote { return String(localized: "现在不会发送。") }
        return model.backupOn ? String(localized: "图片和文件在本机处理，记录备份到你的 iCloud。") : String(localized: "图片和文件都留在本机。")
    }
}
