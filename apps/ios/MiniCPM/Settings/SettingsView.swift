import AVFoundation
import MiniCPMCore
import SwiftUI
import UserNotifications
import UniformTypeIdentifiers

/// Grouped by what people want to do. Stage one leaves out live, voice and nudges; they return with the next stage.
/// Appearance and text size follow the system here, and language jumps to the system's per-app setting.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var path: [SettingsPage]

    init(start: SettingsPage) {
        path = start == .index ? [] : [start]
    }

    var body: some View {
        NavigationStack(path: $path) {
            Form {
                Section {
                    link(.general, "通用", "gearshape")
                    link(.reply, "回答与人设", "text.bubble")
                    link(.models, "模型", "cpu")
                    link(.privacy, "隐私与数据", "checkmark.shield")
                    link(.scenes, "应用场景", "square.grid.2x2")
                }
                Section {
                    link(.advanced, "高级", "ellipsis.circle")
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .close) { dismiss() }
                }
            }
            .navigationDestination(for: SettingsPage.self) { page in
                destination(page)
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
        .overlay(alignment: .bottom) { ToastView(announces: false) }
        .privacyCovered(inSheet: true)
    }

    private func link(_ page: SettingsPage, _ title: LocalizedStringKey, _ image: String) -> some View {
        NavigationLink(value: page) { Label(title, systemImage: image) }
    }

    @ViewBuilder
    private func destination(_ page: SettingsPage) -> some View {
        switch page {
        case .index, .general: GeneralSettings()
        case .reply: ReplySettings()
        case .models: ModelSettings()
        case .privacy: PrivacySettings()
        case .scenes: SceneSettings()
        case .advanced: AdvancedSettings()
        case .reminders: RemindersView()
        case .memories: MemoriesView()
        case .network: NetworkLogView()
        case .developer: DeveloperView()
        }
    }
}

/// A switch with one line of consequence under it.
struct SettingToggle: View {
    let title: LocalizedStringKey
    var detail: LocalizedStringKey?
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            Text(title)
            if let detail { Text(detail) }
        }
    }
}

/// A title, a line of consequence, and a control beside them. A system row drops the control to its own line under a long label.
struct ActionRow<Control: View>: View {
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    @ViewBuilder let control: Control

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            control.fixedSize()
        }
    }
}

private struct GeneralSettings: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL

    var body: some View {
        @Bindable var model = model
        Form {
            Section {
                Button("界面语言") { openURL(SystemSettings.url) }
            } footer: {
                Text("在系统设置里改。")
            }
            Section("打开时") {
                Picker("打开时进入", selection: $model.prefs.openTo) {
                    Text("新对话").tag(OpenTo.new)
                    Text("上次的对话").tag(OpenTo.last)
                }
                Picker("新对话的场景", selection: $model.prefs.defaultScene) {
                    ForEach(SceneID.allCases) { Text(Copy.sceneName($0)).tag($0) }
                }
            }
            Section("通知") {
                NavigationLink("定时通知", value: SettingsPage.reminders)
            }
            Section("反馈") {
                SettingToggle(title: "触感反馈", detail: "操作时轻微震动。", isOn: $model.prefs.haptics)
            }
        }
        .navigationTitle("通用")
    }
}

private struct ReplySettings: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        Form {
            Section {
                Picker("回答语言", selection: $model.prefs.replyLanguage) {
                    Text("跟随界面语言").tag(ReplyLanguage.ui)
                    Text("跟随我说的语言").tag(ReplyLanguage.speech)
                    Text(verbatim: "简体中文").tag(ReplyLanguage.zhHans)
                    Text(verbatim: "繁體中文（台灣）").tag(ReplyLanguage.zhHantTW)
                    Text(verbatim: "繁體中文（香港）").tag(ReplyLanguage.zhHantHK)
                    Text(verbatim: "English").tag(ReplyLanguage.en)
                }
                Picker("回答长度", selection: $model.prefs.replyLength) {
                    Text("简短").tag(ReplyLength.short)
                    Text("适中").tag(ReplyLength.normal)
                    Text("详细").tag(ReplyLength.long)
                }
                TextField("怎么称呼你", text: $model.prefs.callName, prompt: Text("可不填"))
            } header: {
                Text("回答")
            } footer: {
                Text("下一条消息生效。")
            }
            Section("人设") {
                TextEditor(text: $model.persona)
                    .frame(minHeight: 120)
                    .accessibilityLabel("系统提示词")
            }
        }
        .navigationTitle("回答与人设")
    }
}

private struct ModelSettings: View {
    @Environment(AppModel.self) private var model
    @State private var removing: ModelOption?
    @State private var asking: ModelOption?
    @State private var token = ""

    var body: some View {
        @Bindable var model = model
        Form {
            Section {
                ForEach(model.catalog) { option in
                    row(option)
                    if asking == option {
                        SwapConfirmRow(option: option) { asking = nil }
                    }
                }
            } header: {
                Text("可用模型")
            } footer: {
                Text(model.isRemote ? "所有对话共用当前模型。" : "这台设备一次只运行一个模型，所有对话共用。换模型要等它重新载入。")
            }

            Section("看图") {
                SettingToggle(title: "高清细节", detail: "看清小字和细节，响应会变慢。", isOn: $model.prefs.highDetail)
            }

            Section {
                Picker("运行方式", selection: Binding { model.preset } set: { model.setPreset($0) }) {
                    Text("省电").tag(Preset.saver)
                    Text("均衡").tag(Preset.balanced)
                    Text("细致").tag(Preset.detail)
                    if model.preset == .custom {
                        Text("自定义").tag(Preset.custom)
                    }
                }
            } footer: {
                Text(presetDetail)
            }

            Section("电量与发热") {
                Picker("空闲后释放内存", selection: $model.prefs.idleRelease) {
                    Text("5 分钟后").tag(IdleRelease.m5)
                    Text("15 分钟后").tag(IdleRelease.m15)
                    Text("1 小时后").tag(IdleRelease.h1)
                    Text("不释放").tag(IdleRelease.never)
                }
                SettingToggle(title: "发热时降低负载", detail: "响应会变慢，设备会更凉快。", isOn: $model.prefs.thermal)
                SettingToggle(title: "只在 Wi-Fi 下下载", isOn: $model.prefs.wifiOnly)
            }

            Section("运行位置") {
                Picker("运行位置", selection: Binding { model.place } set: { model.setPlace($0) }) {
                    Text("这台设备").tag(Place.local)
                    Text("远程服务").tag(Place.remote)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                if model.isRemote {
                    TextField("服务地址", text: $model.remoteURL, prompt: Text(verbatim: "wss://example.com/omni"))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    SecureField("访问令牌", text: $token, prompt: Text(model.hasRemoteToken ? "已保存" : "未设置"))
                        .onSubmit { model.setRemoteToken(token) }
                    Button("测试连接") { Task { await model.reconnect() } }
                    Text(Copy.privacyLine(model.privacy)).font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("模型")
        .confirmationDialog("移除这个模型？", item: $removing, titleVisibility: .visible) { option in
            Button("移除", role: .destructive) { model.removeModel(option.id) }
        } message: { option in
            Text("释放 \(Copy.size(option.sizeGB))，再用要重新下载。")
        }
    }

    private var presetDetail: LocalizedStringKey {
        switch model.preset {
        case .saver: "回答更短，更省电"
        case .balanced: "默认，适合大多数情况"
        case .detail: "回答更完整，响应更慢"
        case .custom: "当前使用自定义参数，可以在高级里查看。"
        }
    }

    private func row(_ option: ModelOption) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(option.name)
                Text(model.isRemote ? Copy.capabilities(option) : "\(Copy.capabilities(option)) · \(Copy.spec(option)) · \(Copy.size(option.sizeGB))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let state = model.download, state.optionID == option.id {
                    ProgressView(value: state.fraction)
                    Text(Copy.downloadText(state)).font(.caption).foregroundStyle(.secondary)
                    HStack { DownloadActions(state: state) }.buttonStyle(.bordered).font(.caption)
                }
            }
            Spacer()
            control(option)
        }
    }

    @ViewBuilder
    private func control(_ option: ModelOption) -> some View {
        if model.download?.optionID == option.id {
            EmptyView()
        } else if !model.isRemote && !model.installed.contains(option.id) {
            Button("下载") { model.startDownload(option.id) }
                .buttonStyle(.bordered)
                .disabled(model.download != nil)
        } else if option.id == model.currentOptionID {
            Text(model.loadingOptionID == option.id ? "载入中" : "使用中").font(.caption).foregroundStyle(.secondary)
        } else {
            HStack {
                Button("换用") {
                    if model.reply != nil {
                        model.setModel(option.id)
                    } else {
                        asking = option
                    }
                }
                .buttonStyle(.bordered)
                .disabled(model.loadingOptionID != nil)
                if !model.isRemote {
                    Button("移除") { removing = option }.buttonStyle(.bordered)
                }
            }
        }
    }
}

private struct PrivacySettings: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    @State private var confirmsClear = false
    @State private var camera = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var microphone = AVCaptureDevice.authorizationStatus(for: .audio)
    @State private var notifications = UNAuthorizationStatus.notDetermined

    var body: some View {
        @Bindable var model = model
        let summary = Copy.privacySummary(model.privacy)
        Form {
            Section {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(summary.title).font(.headline)
                        Text(summary.detail).font(.subheadline).foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "checkmark.shield").foregroundStyle(.tint)
                }
            }

            Section("联网") {
                SettingToggle(title: "离线模式", detail: "关闭所有联网功能，包括更新、联网搜索、远程服务和备份。", isOn: $model.prefs.offlineMode)
                ActionRow(title: "联网搜索", detail: "需要时让它上网查资料，搜索词会离开这台设备。") {
                    Picker("联网搜索", selection: $model.prefs.webSearch) {
                        Text("关闭").tag(WebSearch.off)
                        Text("每次询问").tag(WebSearch.ask)
                        Text("自动").tag(WebSearch.auto)
                    }
                    .labelsHidden()
                }
                SettingToggle(title: "自动检查更新", detail: "只发送版本号。", isOn: $model.prefs.updates)
                SettingToggle(title: "匿名使用统计", detail: "不包含对话和文件。", isOn: $model.prefs.analytics)
                Picker("崩溃报告", selection: $model.prefs.crashReports) {
                    Text("每次询问").tag(CrashReports.ask)
                    Text("不发送").tag(CrashReports.never)
                    Text("自动发送").tag(CrashReports.auto)
                }
                NavigationLink("联网记录", value: SettingsPage.network)
            }

            Section("对话记录") {
                SettingToggle(title: "保存对话记录", detail: "关闭后，对话只在打开期间存在。", isOn: $model.prefs.keepHistory)
                SettingToggle(title: "新对话默认为临时对话", detail: "临时对话结束后不留记录。", isOn: $model.prefs.temporaryByDefault)
                Picker("自动清理", selection: $model.prefs.retention) {
                    Text("不清理").tag(Retention.never)
                    Text("90 天后").tag(Retention.d90)
                    Text("30 天后").tag(Retention.d30)
                    Text("7 天后").tag(Retention.d7)
                }
            }

            Section("记忆") {
                SettingToggle(title: "记住我的偏好", detail: "从对话里记下习惯和常用信息。", isOn: $model.prefs.memory)
                NavigationLink(value: SettingsPage.memories) {
                    LabeledContent("已记住的内容", value: String(localized: "\(model.memories.count) 条"))
                }
            }

            Section("设备权限") {
                permission("摄像头", "拍照提问", label(camera))
                permission("麦克风", "说话输入", label(microphone))
                permission("通知", "定时通知", label(notifications))
            }

            Section("访问") {
                SettingToggle(title: "打开时验证", detail: "用面容、指纹或系统密码打开。", isOn: $model.prefs.appLock)
                Picker("自动锁定", selection: $model.prefs.autoLock) {
                    Text("立即").tag(AutoLock.immediately)
                    Text("1 分钟后").tag(AutoLock.m1)
                    Text("5 分钟后").tag(AutoLock.m5)
                    Text("不锁定").tag(AutoLock.never)
                }
                SettingToggle(title: "切到后台时隐藏内容", detail: "在最近使用的应用里显示空白。", isOn: $model.prefs.hidePreview)
                SettingToggle(title: "录屏时遮盖内容", isOn: $model.prefs.coverWhileRecording)
            }

            BackupSection()

            Section("数据") {
                SettingToggle(title: "加密保存", detail: "用设备密钥加密对话和材料。", isOn: $model.prefs.encrypt)
                Button("清除全部对话", role: .destructive) { confirmsClear = true }
            }
        }
        .navigationTitle("隐私与数据")
        // On the form, not the section: a section hands its modifiers to every row, and the rows then fight over one sheet.
        .sheet(item: $model.exportFile) { ShareSheet(url: $0.url) }
        .fileImporter(isPresented: $model.isPickingImport, allowedContentTypes: [.json]) { result in
            if let url = try? result.get() { Task { await model.importFile(url) } }
        }
        .confirmationDialog("清除全部对话？", isPresented: $confirmsClear, titleVisibility: .visible) {
            Button("清除", role: .destructive) { model.clearAll() }
        } message: {
            Text("对话和材料都会从这台设备上删除。")
        }
        .task {
            notifications = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        }
    }

    private func permission(_ title: LocalizedStringKey, _ detail: LocalizedStringKey, _ status: LocalizedStringKey) -> some View {
        LabeledContent {
            HStack {
                Text(status)
                Button("管理") { openURL(SystemSettings.url) }.buttonStyle(.borderless)
            }
        } label: {
            Text(title)
            Text(detail)
        }
    }

    private func label(_ status: AVAuthorizationStatus) -> LocalizedStringKey {
        switch status {
        case .authorized: "已允许"
        case .denied, .restricted: "已拒绝"
        default: "未决定"
        }
    }

    private func label(_ status: UNAuthorizationStatus) -> LocalizedStringKey {
        switch status {
        case .authorized, .provisional, .ephemeral: "已允许"
        case .denied: "已拒绝"
        default: "未决定"
        }
    }
}

private struct SceneSettings: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Form {
            Section {
                ForEach(SceneID.allCases) { scene in
                    Toggle(isOn: Binding {
                        !model.hiddenScenes.contains(scene)
                    } set: { shown in
                        if shown { model.hiddenScenes.remove(scene) } else { model.hiddenScenes.insert(scene) }
                    }) {
                        Text(Copy.sceneName(scene))
                        Text(Copy.sceneHint(scene))
                    }
                    .disabled(scene == model.prefs.defaultScene)
                }
            } footer: {
                Text("关闭后不再出现在新对话里，已有对话不受影响。默认场景不能关闭。")
            }
        }
        .navigationTitle("应用场景")
    }
}

private struct AdvancedSettings: View {
    @Environment(AppModel.self) private var model

    private func param(_ key: WritableKeyPath<GenerationParams, Double>) -> Binding<Double> {
        Binding { model.params[keyPath: key] } set: { value in
            var next = model.params
            next[keyPath: key] = value
            model.setParams(next)
        }
    }

    private func param(_ key: WritableKeyPath<GenerationParams, Int>) -> Binding<Double> {
        Binding { Double(model.params[keyPath: key]) } set: { value in
            var next = model.params
            next[keyPath: key] = Int(value)
            model.setParams(next)
        }
    }

    var body: some View {
        @Bindable var model = model
        Form {
            Section {
                ParamSlider(title: "回答长度上限", key: "max_tokens", detail: "回答最长能写多少。", value: param(\.maxTokens), range: 256...4096, step: 256)
                ParamSlider(title: "随机程度", key: "temperature", detail: "越高越有变化，越低越稳定。", value: param(\.temperature), range: 0...1.5, step: 0.05)
                ParamSlider(title: "选词范围", key: "top_p", detail: "越小用词越保守。", value: param(\.topP), range: 0.1...1, step: 0.05)
                ParamSlider(title: "候选词数量", key: "top_k", detail: "每一步考虑多少个候选词。", value: param(\.topK), range: 1...100, step: 1)
                ParamSlider(title: "避免重复", key: "repeat_penalty", detail: "越高越不容易重复同样的话。", value: param(\.repeatPenalty), range: 1...1.5, step: 0.01)
            } header: {
                Text("回答")
            } footer: {
                Text("大多数情况下不用改。改动后，运行方式会显示为“自定义”。")
            }

            Section("设备") {
                Picker("对话记忆长度", selection: Binding { model.params.nCtx } set: { value in
                    var next = model.params
                    next.nCtx = value
                    model.setParams(next)
                }) {
                    ForEach([2048, 4096, 8192, 16384], id: \.self) { Text(verbatim: "\($0)").tag($0) }
                }
                ParamSlider(title: "显卡加速层数", key: "n_gpu_layers", detail: "0 表示只用 CPU。层数越多越快，占用内存也越多。", value: param(\.nGPULayers), range: 0...99, step: 1)
            }

            Section("显示") {
                SettingToggle(title: "显示技术信息", detail: "在回答和对话详情里显示速度和模型。", isOn: $model.prefs.showTechInfo)
                Button("恢复默认") { model.resetParams() }
            }

            Section("开发者") {
                NavigationLink("资源服务", value: SettingsPage.developer)
            }
        }
        .navigationTitle("高级")
    }
}

private struct ParamSlider: View {
    let title: LocalizedStringKey
    let key: String
    let detail: LocalizedStringKey
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Text(verbatim: key).font(.caption.monospaced()).foregroundStyle(.secondary)
                Spacer()
                Text(value.formatted(.number.precision(.fractionLength(0...2)))).monospacedDigit()
            }
            Slider(value: $value, in: range, step: step) { Text(title) }
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }
    }
}

private struct RemindersView: View {
    var body: some View {
        ContentUnavailableView("还没有定时通知", systemImage: "clock", description: Text("在对话里说“每天早上提醒我……”就能添加。到点由系统发一条通知，模型不在后台运行。"))
            .navigationTitle("定时通知")
    }
}

private struct MemoriesView: View {
    @Environment(AppModel.self) private var model

    /// "只" holds only while nothing goes out: not with a remote service, not with the backup on.
    private var intro: String {
        if model.sendingOut {
            return model.backupOn
                ? String(localized: "这些内容保存在这台设备上，也会备份到你的 iCloud，用来让回答更贴合你。用远程服务时，用得上的内容会随请求发送到 \(model.remoteHost)。")
                : String(localized: "这些内容保存在这台设备上，用来让回答更贴合你。用远程服务时，用得上的内容会随请求发送到 \(model.remoteHost)。")
        }
        if model.backupOn { return String(localized: "这些内容保存在这台设备上，也会备份到你的 iCloud，用来让回答更贴合你。") }
        return String(localized: "这些内容只保存在这台设备上，用来让回答更贴合你。")
    }

    var body: some View {
        List {
            Section {
                ForEach(model.memories, id: \.self) { memory in
                    Text(memory).swipeActions {
                        Button("删除", systemImage: "trash", role: .destructive) { model.forget(memory) }
                    }
                }
            } footer: {
                Text(intro)
            }
        }
        .overlay {
            if model.memories.isEmpty {
                ContentUnavailableView("还没有记住任何内容", systemImage: "lightbulb")
            }
        }
        .navigationTitle("已记住的内容")
    }
}

/// The claim on top has to agree with the rows below it: once a search or a backup went out, "nothing left" is false.
private struct NetworkLogView: View {
    @Environment(AppModel.self) private var model

    private var searches: Int { model.networkLog.filter { $0.kind == .search }.count }
    private var backedUp: Bool { model.backupOn || model.networkLog.contains { $0.kind == .backup } }

    private var claim: String {
        if model.sendingOut { return String(localized: "内容正发送到 \(model.remoteHost)") }
        if model.backupOn { return String(localized: "对话记录备份到你的 iCloud") }
        if backedUp { return String(localized: "对话记录备份到过你的 iCloud") }
        if searches > 0 { return String(localized: "只有 \(searches) 句搜索词离开过这台设备") }
        return String(localized: "没有内容离开这台设备")
    }

    private var detail: LocalizedStringKey {
        if model.sendingOut || backedUp { return "下面写明了发送什么、发到哪里。" }
        if searches > 0 { return "除了这些搜索词，下面的请求不包含你的对话或文件。" }
        return "下面的请求不包含你的对话或文件。"
    }

    var body: some View {
        List {
            Section {
                Label(claim, systemImage: "checkmark.shield")
            } footer: {
                Text(detail)
            }
            Section("最近 7 天") {
                if model.sendingOut {
                    LabeledContent("远程服务", value: String(localized: "图片和文字发送到 \(model.remoteHost)"))
                }
                ForEach(model.networkLog) { record in
                    LabeledContent {
                        Text(record.date.formatted(date: .abbreviated, time: .shortened))
                    } label: {
                        switch record.kind {
                        case .modelDownload:
                            Text("模型下载")
                            Text("只请求模型文件")
                        case .search:
                            Text("联网搜索")
                            Text("只发送“\(record.detail)”")
                        case .backup:
                            Text("iCloud 备份")
                            Text("对话记录上传到你的 iCloud")
                        }
                    }
                }
                if model.networkLog.isEmpty && !model.sendingOut {
                    Text("最近 7 天没有请求。").foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("联网记录")
    }
}

/// Uploading and deleting cannot be undone, so they confirm in place. Turning off can, so it uses the toast.
private struct BackupSection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    @State private var asking: Ask?

    private enum Ask { case enable, delete }

    private var isRunning: Bool { if case .running = model.backup.status { true } else { false } }

    private var status: String {
        let last = { (date: Date?) in date.map { $0.formatted(date: .abbreviated, time: .shortened) } ?? String(localized: "还没有") }
        if !model.backup.isOn { return String(localized: "对话和已记住的内容上传到你的 iCloud。不包括模型文件和临时对话。") }
        if model.prefs.offlineMode { return String(localized: "离线模式开着，备份已暂停。") }
        switch model.backup.status {
        case .noCloud: return ""
        case .signedOut: return String(localized: "这台设备没有登录 iCloud，登录后会接着备份。")
        case .idle(let date): return String(localized: "上次备份：\(last(date))")
        case .running: return String(localized: "正在备份，可以继续用。")
        case .full(let missing, let date): return String(localized: "iCloud 空间不够，还差 \(Copy.size(missing))。上次备份：\(last(date))。")
        }
    }

    var body: some View {
        Section("备份与迁移") {
            if model.backup.status != .noCloud {
                Toggle(isOn: Binding { model.backup.isOn || asking == .enable } set: { on in
                    if on {
                        asking = .enable
                    } else if asking == .enable {
                        asking = nil
                    } else {
                        Task { await model.disableBackup() }
                    }
                }) {
                    Text("备份到 iCloud")
                    Text(status)
                }
                if asking == .enable {
                    confirm("开启后，对话记录会离开这台设备，存到你的 iCloud。之后会自动备份。", "开启备份") {
                        await model.enableBackup()
                    }
                }
                if case .running(let fraction) = model.backup.status {
                    ProgressView(value: fraction) { Text("已备份 \(Copy.percent(fraction))").font(.footnote) }
                }
                if model.backup.isOn && !model.prefs.offlineMode {
                    switch model.backup.status {
                    case .idle:
                        Button("立即备份") { Task { await model.backUpNow() } }
                    case .full:
                        Button("管理 iCloud 空间") { openURL(SystemSettings.url) }
                    case .signedOut:
                        Button("去系统设置") { openURL(SystemSettings.url) }
                    default:
                        EmptyView()
                    }
                }
                if model.backup.hasCloudCopy && !isRunning {
                    ActionRow(title: "从备份恢复", detail: "把这台设备上没有的对话取回来。") {
                        Button("恢复") { Task { await model.restoreBackup() } }
                    }
                    ActionRow(title: "删除 iCloud 里的备份", detail: "这台设备上的对话不受影响。") {
                        Button("删除", role: .destructive) { asking = .delete }
                    }
                    if asking == .delete {
                        confirm("删除后不能恢复。", "删除备份", role: .destructive) {
                            await model.deleteCloudCopy()
                        }
                    }
                }
            }
            ActionRow(title: "导出对话", detail: "把 \(model.exportableCount) 个对话存成一个文件，换设备时可以导入。文件里有对话全文，由你保管。") {
                Button("导出") { model.export() }.disabled(model.exportableCount == 0)
            }
            ActionRow(title: "导入对话", detail: "从导出的文件恢复。不覆盖现有对话，重复的会跳过。") {
                Button("导入") { model.beginImport() }
            }
            if model.importFailed {
                VStack(alignment: .leading, spacing: 8) {
                    Label("读不了这个文件", systemImage: "exclamationmark.triangle.fill").font(.subheadline.weight(.semibold))
                    Text("它不是 MiniCPM 导出的，或者来自更新的版本。现有对话没有变化。").font(.footnote).foregroundStyle(.secondary)
                    Button("知道了") { model.dismissImportFailure() }.font(.footnote).buttonStyle(.bordered)
                }
            }
        }
    }

    private func confirm(_ message: LocalizedStringKey, _ title: LocalizedStringKey, role: ButtonRole? = nil, action: @escaping @MainActor () async -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(message).font(.footnote)
            HStack {
                Button(title, role: role) {
                    asking = nil
                    Task { await action() }
                }
                .prominentButton()
                Button("先不") { asking = nil }.buttonStyle(.bordered)
            }
        }
    }
}

/// The only page that uses developer vocabulary.
private struct DeveloperView: View {
    var body: some View {
        Form {
            Section {
                LabeledContent("Multimedia Adapter", value: "未配置")
                LabeledContent("Online Service", value: "未配置")
                LabeledContent("Computer Use", value: "未配置")
                LabeledContent("Scheduler", value: "未配置")
                LabeledContent("Gateway", value: "未配置")
            } footer: {
                Text("Resource 层对接媒体、工具与外部通道。")
            }
        }
        .navigationTitle("资源服务")
    }
}

#Preview {
    SettingsView(start: .index).environment(PreviewData.model())
}
