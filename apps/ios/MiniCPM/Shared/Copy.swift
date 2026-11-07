import Foundation
import MiniCPMCore

/// Turns the typed values of `MiniCPMCore` into words. `String(localized:)` keeps them in the String Catalog.
enum Copy {
    static func sceneName(_ scene: SceneID) -> String {
        switch scene {
        case .life: String(localized: "生活助手")
        case .work: String(localized: "工作助手")
        case .game: String(localized: "游戏助手")
        case .community: String(localized: "社区助手")
        }
    }

    static func sceneHint(_ scene: SceneID) -> String {
        switch scene {
        case .life: String(localized: "生活交流、物品观察")
        case .work: String(localized: "材料分析、工作整理")
        case .game: String(localized: "围绕游戏画面提供辅助")
        case .community: String(localized: "社区消息整理、定时通知")
        }
    }

    struct Starter: Identifiable {
        enum Action {
            case prompt(String)
            case takePhoto
        }

        var title: String
        var subtitle: String
        var systemImage: String
        var action: Action
        var id: String { title }
    }

    private static let photoStarter = Starter(title: String(localized: "拍一张问问"), subtitle: String(localized: "拍下面前的东西"), systemImage: "camera", action: .takePhoto)
    private static let imageStarter = Starter(title: String(localized: "看一张图"), subtitle: String(localized: "上传图片，问它细节"), systemImage: "photo", action: .prompt(String(localized: "帮我看看这张图")))

    /// Stage one has no live entries, so the scene's own prompts come first and the camera fills in.
    static func starters(_ scene: SceneID) -> [Starter] {
        func prompt(_ title: String, _ subtitle: String, _ image: String, _ text: String) -> Starter {
            Starter(title: title, subtitle: subtitle, systemImage: image, action: .prompt(text))
        }
        switch scene {
        case .life:
            return [prompt(String(localized: "读一张单据"), String(localized: "拍照或上传图片"), "doc.text", String(localized: "帮我看看这张单据上有什么要注意的")), photoStarter, imageStarter]
        case .work:
            return [
                prompt(String(localized: "分析一份材料"), String(localized: "上传 PDF、PPT 或图片"), "doc.text", String(localized: "帮我梳理这份材料的主要内容")),
                prompt(String(localized: "安排今天的工作"), String(localized: "按截止时间和依赖排序"), "clock", String(localized: "帮我安排今天的工作")),
                photoStarter,
            ]
        case .game:
            return [prompt(String(localized: "分析一张截图"), String(localized: "看阵容、地图或配装"), "doc.text", String(localized: "帮我分析这张游戏截图")), photoStarter, imageStarter]
        case .community:
            return [
                prompt(String(localized: "设置定时通知"), String(localized: "到点提醒你来整理消息"), "clock", String(localized: "每天早上提醒我整理社区消息")),
                prompt(String(localized: "整理一批消息"), String(localized: "粘贴或上传聊天记录"), "doc.text", String(localized: "帮我整理这批社区消息")),
                photoStarter,
            ]
        }
    }

    static func privacyLine(_ statement: PrivacyStatement) -> String {
        switch statement {
        case .onDevice: String(localized: "只在这台设备上处理，内容不会离开")
        case .onDeviceBackedUp: String(localized: "只在这台设备上处理，记录备份到你的 iCloud")
        case .remoteNotSet: String(localized: "还没设置远程服务，内容不会发送")
        case .offlineBlocksRemote: String(localized: "离线模式开着，内容不会发送")
        case .sendingTo(let host): String(localized: "内容会发送到 \(host) 处理")
        }
    }

    static func privacySummary(_ statement: PrivacyStatement) -> (title: String, detail: String) {
        switch statement {
        case .onDevice:
            (String(localized: "你的内容留在这台设备上"), String(localized: "图片、文件和对话都在本机处理，断网也能用。"))
        case .onDeviceBackedUp:
            (String(localized: "对话记录备份到你的 iCloud"), String(localized: "图片和文件在本机处理，断网也能用。备份时对话记录会离开这台设备。"))
        case .remoteNotSet:
            (String(localized: "内容现在不会发送"), String(localized: "运行位置选了远程服务，填好地址后才会发送到那里。"))
        case .offlineBlocksRemote:
            (String(localized: "内容现在不会发送"), String(localized: "离线模式开着，关闭后才会发送到远程服务。"))
        case .sendingTo(let host):
            (String(localized: "内容正发送到 \(host)"), String(localized: "处理时图片和文字会离开本机，对话记录仍保存在这里。"))
        }
    }

    static func headStatus(_ status: HeadStatus) -> String {
        switch status {
        case .switching: return String(localized: "正在换模型")
        case .preparing: return String(localized: "正在准备")
        case .temporary: return String(localized: "不保存记录")
        case .place(let model?, let remote): return remote ? String(localized: "\(model) · 远程") : String(localized: "\(model) · 本机")
        case .place(nil, let remote): return remote ? String(localized: "远程处理") : String(localized: "本机处理")
        }
    }

    @MainActor
    static func engineStatus(_ model: AppModel) -> String {
        switch model.backendState {
        case .remoteNotSet: return String(localized: "远程服务未配置")
        case .offlineMode: return String(localized: "离线模式已开")
        case .noGPU: return String(localized: "这台设备不能本机运行")
        case .notResponding: return model.isRemote ? String(localized: "连不上远程服务") : String(localized: "模型未启动")
        case .noModel:
            if let download = model.download { return String(localized: "下载中 \(percent(download.fraction))") }
            return String(localized: "模型未下载")
        case .ready: break
        }
        if model.loadingOptionID != nil { return model.loadedOptionID == nil ? String(localized: "正在准备模型") : String(localized: "正在换模型") }
        let activity = model.reply == nil ? String(localized: "空闲") : String(localized: "生成中")
        return model.isRemote ? String(localized: "远程 · \(activity)") : String(localized: "本机运行 · \(activity)")
    }

    struct BannerText {
        var title: String
        var detail: String
        var isProblem = true
    }

    static func banner(_ banner: Banner) -> BannerText {
        let kept = String(localized: "你写的内容会留在这里。")
        switch banner {
        case .permissionDenied(let kind):
            let title = kind == .camera ? String(localized: "没有摄像头权限") : String(localized: "没有麦克风权限")
            return BannerText(title: title, detail: String(localized: "在系统设置里允许后重试，或者先用文字继续。"))
        case .remoteNotSet:
            return BannerText(title: String(localized: "还没配置远程服务"), detail: String(localized: "填好服务地址后才能发送。\(kept)"))
        case .offlineMode:
            return BannerText(title: String(localized: "离线模式开着，连不了远程服务"), detail: kept)
        case .noGPU:
            return BannerText(title: String(localized: "这台设备跑不了本机模型"), detail: String(localized: "可以改用远程服务。\(kept)"))
        case .notResponding(let remote):
            return BannerText(title: remote ? String(localized: "连不上远程服务") : String(localized: "连不上本机模型"), detail: String(localized: "它没有响应。\(kept)"))
        case .downloading(let state, let option):
            return BannerText(title: option.name, detail: downloadText(state), isProblem: false)
        case .modelMissing(let option):
            return BannerText(title: String(localized: "这台设备上还没有 \(option.name)"), detail: String(localized: "下载后才能用，你写的内容会留在这里。"), isProblem: false)
        case .swapFailed(let option, let restored?):
            return BannerText(title: String(localized: "载不下 \(option.name)"), detail: String(localized: "内存不够，已换回 \(restored.name)。关掉其他应用后可以重试。"))
        case .swapFailed(let option, nil):
            return BannerText(title: String(localized: "载不下 \(option.name)"), detail: String(localized: "内存不够。关掉其他应用后可以重试。\(kept)"))
        case .crashedLoading(let option):
            return BannerText(title: String(localized: "上次载入 \(option.name) 时应用退出了"), detail: String(localized: "可能是内存不够，这次没有自动载入。\(kept)"))
        case .preparing(let option):
            return BannerText(title: String(localized: "正在准备 \(option.name)"), detail: String(localized: "约 \(option.loadSeconds) 秒。可以先写，发送后会自动接上。"), isProblem: false)
        case .switching(let option):
            return BannerText(title: String(localized: "正在换到 \(option.name)"), detail: String(localized: "约 \(option.loadSeconds) 秒。可以先写，发送后会自动接上。"), isProblem: false)
        }
    }

    static func downloadText(_ state: DownloadState) -> String {
        let done = percent(state.fraction)
        switch state.status {
        case .running: return done
        case .paused: return String(localized: "已暂停 · \(done)")
        case .waitingForWiFi: return String(localized: "等待 Wi-Fi · \(done)")
        case .failed: return String(localized: "下载中断 · \(done)，已下载的部分还在")
        case .verifying, .finished: return String(localized: "正在检查文件…")
        case .badFile: return String(localized: "文件不完整，要重新下载")
        }
    }

    static func notice(_ notice: Notice) -> String {
        switch notice {
        case .deleted(let title): String(localized: "已删除“\(title)”")
        case .temporaryCleared: String(localized: "临时对话已清除")
        case .modelReady(let name): String(localized: "\(name) 准备好了")
        case .modelRemoved(let name): String(localized: "已移除 \(name)")
        case .loadCancelled(let name): String(localized: "已取消，继续用 \(name)")
        case .replyNotFinished: String(localized: "这条回答还没结束")
        case .replyInOtherConversation: String(localized: "另一个对话正在回答，结束后才能发送")
        case .switchedToDevice: String(localized: "已切换到这台设备，下一条消息生效")
        case .willSend(let host, false): String(localized: "内容会发送到 \(host) 处理")
        case .willSend(let host, true): String(localized: "这个对话的上文也会发送到 \(host)")
        case .offlineBlocksDownload: String(localized: "离线模式开着，下载不了模型")
        case .connected(let remote): remote ? String(localized: "已连接远程服务") : String(localized: "已连接本机模型")
        case .notResponding(let remote): remote ? String(localized: "连不上远程服务") : String(localized: "连不上本机模型")
        case .paramsReset: String(localized: "已恢复默认")
        case .notConnectedYet: String(localized: "这项还没接入")
        }
    }

    static func toastAction(_ kind: ToastAction.Kind) -> String {
        switch kind {
        case .undo: String(localized: "撤销")
        case .stopAndSwitch: String(localized: "停止并换")
        case .turnOffOffline: String(localized: "关闭离线模式")
        }
    }

    static func kindSubtitle(_ kind: ModelKind) -> String {
        switch kind {
        case .omni: String(localized: "能听、能说、能看，可以实时对话")
        case .vision: String(localized: "看图、读文档，用文字回答")
        }
    }

    static func capabilities(_ option: ModelOption) -> String {
        option.capabilities.map { capability in
            switch capability {
            case .image: String(localized: "看图")
            case .video: String(localized: "看视频")
            case .audio: String(localized: "听语音")
            case .speech: String(localized: "说话")
            case .live: String(localized: "实时对话")
            }
        }.joined(separator: " · ")
    }

    static func spec(_ option: ModelOption) -> String { "\(option.specLabel) \(option.specTag)" }
    static func size(_ gb: Double) -> String { String(format: "%.1f GB", gb) }
    static func percent(_ fraction: Double) -> String { fraction.formatted(.percent.precision(.fractionLength(0))) }
}
