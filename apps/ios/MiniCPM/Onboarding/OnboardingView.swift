import MiniCPMCore
import SwiftUI

/// Discloses the download size before anything is fetched, and asks for no permissions: those come on first use.
struct OnboardingView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationStack {
            switch model.onboarding {
            case .model where model.device?.canRun == false: NoLocalRunView()
            case .model: ModelPickView()
            case .download: DownloadStepView()
            default: WelcomeView()
            }
        }
    }
}

private struct WelcomeView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                BrandMark().frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 6) {
                    Text("在你自己的设备上运行").font(.largeTitle.bold())
                    Text("MiniCPM 能看图、读文档，全部在这台设备上完成。").foregroundStyle(.secondary)
                }
                promise("checkmark.shield", "内容不离开这台设备", "图片和文件都在本机处理。只有你同意时，搜索词或备份才会离开。")
                promise("wifi.slash", "断网也能用", "模型下载好之后就不需要网络了。")
                promise("doc.text", "都由你决定", "记住了什么、联网做了什么，都能看到和删除。")
            }
            .padding(24)
            .frame(maxWidth: 560, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .safeAreaBar(edge: .bottom) {
            PrimaryAction(LocalizedStringResource("onboarding.continue", defaultValue: "继续", comment: "Continue from welcome to model selection. Not resuming a paused download.")) { model.finishWelcome() }
        }
    }

    private func promise(_ image: String, _ title: LocalizedStringKey, _ detail: LocalizedStringKey) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: image).foregroundStyle(.tint).frame(width: 28)
        }
    }
}

private struct ModelPickView: View {
    @Environment(AppModel.self) private var model
    @State private var picked: String?

    private var choice: ModelOption? { model.option(picked ?? model.currentOptionID) }
    private var missingSpace: Double? {
        guard let choice, let free = model.device?.freeStorageGB, choice.sizeGB + 0.5 > free else { return nil }
        return choice.sizeGB + 0.5 - free
    }

    var body: some View {
        List {
            Section {
                ForEach(model.catalog) { option in
                    Button {
                        picked = option.id
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(option.name).foregroundStyle(Color.primary)
                                    if option.isRecommended {
                                        Text("推荐").font(.caption2.weight(.semibold)).foregroundStyle(.tint)
                                    }
                                }
                                Text(Copy.kindSubtitle(option.kind)).font(.caption).foregroundStyle(Color.secondary)
                                Text("\(Copy.spec(option)) · \(Copy.size(option.sizeGB))").font(.caption).foregroundStyle(Color.secondary)
                            }
                            Spacer()
                            if option == choice {
                                Image(systemName: "checkmark").foregroundStyle(.tint).accessibilityLabel("已选择")
                            }
                        }
                    }
                }
            } header: {
                Text(deviceLine)
            } footer: {
                if let missingSpace {
                    Text("还差 \(Copy.size(missingSpace)) 空间。清理后回到这里继续，或者换一个小一些的模型。")
                } else {
                    Text("这是这台设备能用的模型。下载后不再需要网络。")
                }
            }
        }
        .navigationTitle("选一个模型")
        .safeAreaBar(edge: .bottom) {
            VStack(spacing: 8) {
                PrimaryAction("下载 \(Copy.size(choice?.sizeGB ?? 0))") {
                    if let choice { model.chooseOnboardingModel(choice.id) }
                }
                .disabled(missingSpace != nil || choice == nil)
                Button("我有自己的服务器") { model.useOwnServer() }.font(.footnote)
            }
        }
    }

    private var deviceLine: String {
        guard let device = model.device else { return "" }
        let memory = device.memoryGB.map { String(localized: "内存 \(Copy.size($0))", comment: "Device memory; placeholder includes the system-formatted size and unit.") }
        let storage = device.freeStorageGB.map { String(localized: "可用空间 \(Copy.size($0))", comment: "Available storage; placeholder includes the system-formatted size and unit.") }
        return ([String(localized: "这台设备")] + [memory, storage].compactMap(\.self)).joined(separator: " · ")
    }
}

private struct NoLocalRunView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ContentUnavailableView("这台设备跑不了本机模型", systemImage: "cpu", description: Text("可以连接你自己的服务器，内容会发送到那台服务器。"))
            .safeAreaBar(edge: .bottom) {
                PrimaryAction("连接远程服务") { model.useOwnServer() }
            }
    }
}

private struct DownloadStepView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let state = model.download, let option = model.option(state.optionID) {
                Text(state.status == .verifying ? "马上就好" : "正在下载 \(option.name)").font(.title.bold())
                Text("\(Copy.spec(option)) · \(Copy.size(option.sizeGB))。下载在后台继续，可以先离开这个页面。")
                    .foregroundStyle(.secondary)
                ProgressView(value: state.fraction)
                Text(Copy.downloadText(state)).font(.footnote).foregroundStyle(.secondary)
                HStack { DownloadActions(state: state) }.buttonStyle(.bordered)
            }
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: 560, alignment: .leading)
        .safeAreaBar(edge: .bottom) {
            PrimaryAction("先进去看看") { model.leaveOnboarding() }
        }
    }
}

private struct PrimaryAction: View {
    let title: LocalizedStringResource
    let action: @MainActor () -> Void

    init(_ title: LocalizedStringResource, action: @escaping @MainActor () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button {
            action()
        } label: {
            Text(title).frame(maxWidth: .infinity)
        }
        .prominentGlassButton()
        .controlSize(.large)
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
    }
}

#Preview("欢迎") {
    OnboardingView().environment(PreviewData.model(installed: [], onboarded: false))
}
