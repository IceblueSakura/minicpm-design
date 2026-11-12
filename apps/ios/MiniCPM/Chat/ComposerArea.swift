import AVFoundation
import MiniCPMCore
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Everything below the thread: the banner, the starters on a blank chat, and the input.
struct ComposerArea: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dictation) private var dictation
    @Environment(\.dynamicTypeSize) private var typeSize
    @FocusState private var focused: Bool
    @State private var showsPhotos = false
    @State private var showsFiles = false
    @State private var showsCamera = false
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var listening: Task<Void, Never>?

    private var hasContent: Bool { model.draft.hasContent }
    /// Empty on a phone, the main button is the fastest way to show it something. Wide windows drag files in instead.
    private var mainIsCamera: Bool { sizeClass == .compact && !hasContent && !model.isReplyingHere }

    var body: some View {
        @Bindable var model = model
        VStack(spacing: 8) {
            // Large banners belong to the scrollable chat, not a bar that can grow over the navigation.
            if !typeSize.isAccessibilitySize { BannerView() }
            // At accessibility sizes the cards cut their own words and push the banner over the title. They are shortcuts, so they go.
            if model.current.isBlank && !hasContent && !typeSize.isAccessibilitySize {
                StartersRow(takePhoto: takePhoto, usePrompt: { text in
                    model.draftText = text
                    focused = true
                })
            }
            if model.thinking {
                Button("深度思考", systemImage: "xmark") { model.thinking = false }
                    .font(.footnote)
                    .buttonStyle(.bordered)
                    .accessibilityLabel("关闭深度思考")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if !model.draft.attachments.isEmpty {
                ScrollView(.horizontal) {
                    HStack {
                        ForEach(model.draft.attachments) { DraftChip(item: $0) }
                    }
                }
                .scrollIndicators(.hidden)
            }
            GlassEffectContainer(spacing: 8) {
                HStack(alignment: .bottom, spacing: 8) {
                    addMenu
                    HStack(alignment: .bottom, spacing: 6) {
                        TextField("问问 MiniCPM", text: $model.draftText, axis: .vertical)
                            .lineLimit(1...6)
                            .focused($focused)
                            .accessibilityLabel("消息")
                        if dictation.isAvailable && (!hasContent || listening != nil) {
                            Button("说话输入", systemImage: "mic", action: toggleDictation)
                                .labelStyle(.iconOnly)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 22))
                    .overlay {
                        // The dashed edge says this one will not be kept.
                        if model.current.isTemporary {
                            RoundedRectangle(cornerRadius: 22).strokeBorder(.secondary, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        }
                    }
                    mainButton
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
        .frame(maxWidth: 760)
        .photosPicker(isPresented: $showsPhotos, selection: $photoItems, maxSelectionCount: 5, matching: .images)
        .onChange(of: photoItems) { _, items in
            Task { await addPhotos(items) }
        }
        .fileImporter(isPresented: $showsFiles, allowedContentTypes: [.image, .movie, .pdf, .plainText, .item], allowsMultipleSelection: true) { result in
            for url in (try? result.get()) ?? [] {
                if let attachment = try? Files.store(pickedFile: url) { model.addAttachment(attachment) }
            }
        }
        .fullScreenCover(isPresented: $showsCamera) {
            CameraPicker { data in
                if let attachment = try? Files.store(data: data, name: String(localized: "照片.jpg", comment: "Default name for a new camera photo. Keep the .jpg extension."), kind: .image) { model.addAttachment(attachment) }
            }
            .ignoresSafeArea()
        }
    }

    private var addMenu: some View {
        Menu {
            Button("相机", systemImage: "camera", action: takePhoto)
            Button("相册", systemImage: "photo") { showsPhotos = true }
            Button("文件", systemImage: "doc") { showsFiles = true }
            Divider()
            Toggle(isOn: Bindable(model).thinking) {
                Label("深度思考", systemImage: "lightbulb")
            }
        } label: {
            Image(systemName: "plus").frame(width: 28, height: 28)
        }
        .accessibilityLabel("添加内容")
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
    }

    @ViewBuilder
    private var mainButton: some View {
        if mainIsCamera {
            Button(action: takePhoto) {
                Image(systemName: "camera").frame(width: 28, height: 28)
            }
            .accessibilityLabel("拍照提问")
            .prominentGlassButton()
            .buttonBorderShape(.circle)
        } else {
            Button { model.send() } label: {
                Image(systemName: model.isReplyingHere ? "stop.fill" : "arrow.up").frame(width: 28, height: 28)
            }
            .accessibilityLabel(model.isReplyingHere ? "停止生成" : "发送")
            .prominentGlassButton()
            .buttonBorderShape(.circle)
            .disabled(!model.isReplyingHere && (!hasContent || model.cannotSend || model.isQueued))
        }
    }

    private func toggleDictation() {
        if let listening {
            listening.cancel()
            self.listening = nil
            return
        }
        let start = model.draftText
        listening = Task {
            do {
                for try await text in dictation.transcribe() { model.draftText = start + text }
            } catch {
                model.permissionDenied = .microphone
            }
            listening = nil
        }
    }

    private func takePhoto() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .denied, .restricted:
            model.permissionDenied = .camera
        default:
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                showsCamera = true
            } else {
                showsPhotos = true
            }
        }
    }

    private func addPhotos(_ items: [PhotosPickerItem]) async {
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
            if let attachment = try? Files.store(data: data, name: String(localized: "图片.jpg", comment: "Default name for a newly imported photo. Keep the .jpg extension."), kind: .image) { model.addAttachment(attachment) }
        }
        photoItems = []
    }
}

private struct DraftChip: View {
    @Environment(AppModel.self) private var model
    let item: DraftAttachment

    var body: some View {
        HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 0) {
                Text(item.attachment.name).font(.footnote).lineLimit(1)
                if item.isProcessing {
                    Text("正在处理").font(.caption2).foregroundStyle(.secondary)
                }
            }
            Button("移除 \(item.attachment.name)", systemImage: "xmark") { model.removeAttachment(item.id) }
                .labelStyle(.iconOnly)
                .font(.caption)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.fill.tertiary, in: .rect(cornerRadius: 10))
    }
}

private struct StartersRow: View {
    @Environment(AppModel.self) private var model
    let takePhoto: @MainActor () -> Void
    let usePrompt: @MainActor (String) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(Copy.starters(model.current.scene)) { starter in
                    Button {
                        switch starter.action {
                        case .prompt(let text): usePrompt(text)
                        case .takePhoto: takePhoto()
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Image(systemName: starter.systemImage).foregroundStyle(.tint)
                            Text(starter.title).font(.subheadline.weight(.medium))
                            Text(starter.subtitle).font(.caption).foregroundStyle(.secondary)
                        }
                        .frame(width: 148, alignment: .leading)
                        .padding(10)
                        .background(.fill.quaternary, in: .rect(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .scrollIndicators(.hidden)
    }
}

/// What is wrong or in progress, what was kept, and the next step. Only the user moves content to the other place.
struct BannerView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL

    var body: some View {
        if let banner = model.banner {
            let text = Copy.banner(banner)
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: text.isProblem ? "exclamationmark.triangle.fill" : "clock")
                        .foregroundStyle(text.isProblem ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        // Grows instead of truncating: what went wrong and what was kept are never cut.
                        Text(text.title).font(.subheadline.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
                        Text(text.detail).font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                }
                if case .downloading(let state, _) = banner {
                    ProgressView(value: state.fraction)
                }
                // Side by side while they fit; stacked for long translations and large text, never cut.
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) { actions(banner) }
                    VStack(alignment: .leading, spacing: 8) { actions(banner) }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: .rect(cornerRadius: 18))
        }
    }

    /// The way out is filled, the rest are bordered. Nothing that sends content off the device is the filled one.
    @ViewBuilder
    private func actions(_ banner: Banner) -> some View {
        switch banner {
        case .permissionDenied:
            primary("去系统设置") { openURL(SystemSettings.url) }
            secondary("用文字") { model.permissionDenied = nil }
        case .remoteNotSet:
            primary("去设置") { model.settingsRoute = .models }
            secondary("改用这台设备") { model.setPlace(.local) }
        case .offlineMode:
            primary("改用这台设备") { model.setPlace(.local) }
            secondary("关闭离线模式") { model.prefs.offlineMode = false }
        case .noGPU:
            secondary("改用远程服务") { model.setPlace(.remote) }
        case .notResponding(let remote):
            primary("重试") { Task { await model.reconnect() } }
            if remote {
                secondary("改用这台设备") { model.setPlace(.local) }
            } else if !model.remoteURL.isEmpty {
                secondary("改用远程服务") { model.setPlace(.remote) }
            } else {
                secondary("检查设置") { model.settingsRoute = .models }
            }
        case .downloading(let state, _):
            DownloadActions(state: state).buttonStyle(.bordered)
        case .modelMissing(let option):
            primary("下载") { model.startDownload(option.id) }
            secondary("换模型") { model.settingsRoute = .models }
        case .swapFailed(let option, let restored):
            if restored != nil {
                primary("重试") { model.setModel(option.id) }
                secondary("知道了") { model.dismissSwapFailure() }
            } else {
                primary("重试") { model.retryLoad() }
            }
        case .crashedLoading:
            primary("再试一次") { model.retryLoad() }
            secondary("换模型") { model.settingsRoute = .models }
        case .switching:
            secondary("取消") { model.cancelLoad() }
        case .preparing:
            EmptyView()
        }
    }

    private func primary(_ title: LocalizedStringKey, action: @escaping @MainActor () -> Void) -> some View {
        Button(title, action: action).prominentButton()
    }

    private func secondary(_ title: LocalizedStringKey, action: @escaping @MainActor () -> Void) -> some View {
        Button(title, action: action).buttonStyle(.bordered)
    }
}

/// The actions of each download state, shared by the banner, onboarding and model settings.
struct DownloadActions: View {
    @Environment(AppModel.self) private var model
    let state: DownloadState

    var body: some View {
        switch state.status {
        case .running:
            Button("暂停") { model.pauseDownload() }
        case .paused:
            Button("继续") { model.resumeDownload() }
            Button("取消下载") { model.cancelDownload() }
        case .waitingForWiFi:
            Button("用移动网络继续") { model.resumeDownload(allowsCellular: true) }
            Button("取消下载") { model.cancelDownload() }
        case .failed:
            Button("重试") { model.resumeDownload() }
            Button("取消下载") { model.cancelDownload() }
        case .badFile:
            Button("重新下载") { model.resumeDownload() }
            Button("取消下载") { model.cancelDownload() }
        case .verifying, .finished:
            EmptyView()
        }
    }
}
