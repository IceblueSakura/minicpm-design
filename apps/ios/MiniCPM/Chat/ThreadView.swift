import MiniCPMCore
import SwiftUI
import UIKit

struct ThreadView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var position = ScrollPosition(edge: .bottom)
    @State private var isNearEnd = true

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                ForEach(model.current.items) { item in
                    ThreadItemView(item: item)
                }
                if typeSize.isAccessibilitySize { BannerView() }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .scrollPosition($position)
        // A short thread reads from the top; once it fills the screen it opens on and follows the newest.
        .defaultScrollAnchor(.top, for: .alignment)
        .defaultScrollAnchor(.bottom, for: .initialOffset)
        .defaultScrollAnchor(.bottom, for: .sizeChanges)
        .scrollDismissesKeyboard(.interactively)
        // The input is glass with gaps around it; a soft edge leaves text readable through them.
        .scrollEdgeEffectStyle(.hard, for: .bottom)
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentSize.height - geometry.visibleRect.maxY < 80
        } action: { _, near in
            isNearEnd = near
        }
        .overlay(alignment: .bottom) {
            if !isNearEnd {
                Button("回到最新", systemImage: "arrow.down") {
                    withAnimation { position.scrollTo(edge: .bottom) }
                }
                .buttonStyle(.glass)
                .padding(.bottom, 8)
            }
        }
        .accessibilityLabel("对话记录")
    }
}

private struct ThreadItemView: View {
    let item: ThreadItem

    var body: some View {
        switch item {
        case .user(let message): UserMessageView(message: message)
        case .assistant(let message): AssistantMessageView(message: message)
        case .place(let mark): PlaceMarkView(mark: mark)
        case .memory(let line): MemoryLineView(line: line)
        case .search(let card): SearchCardView(card: card)
        case .action(let card): ActionCardView(card: card)
        }
    }
}

private struct UserMessageView: View {
    @Environment(AppModel.self) private var model
    let message: UserMessage

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            ForEach(message.attachments) { attachment in
                AttachmentLabel(attachment: attachment)
            }
            if !message.text.isEmpty {
                Text(message.text)
                    .textSelection(.enabled)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(.userBubble, in: .rect(cornerRadius: 18))
                    .contextMenu {
                        Button("复制", systemImage: "doc.on.doc") { Pasteboard.copy(message.text) }
                    }
            }
            if message.failed {
                HStack(spacing: 8) {
                    Label("没有发出去", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                    Button("重试") { model.retrySend(message.id) }.inlineTarget()
                }
                .font(.footnote)
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.leading, 48)
    }
}

struct AttachmentLabel: View {
    let attachment: Attachment

    var body: some View {
        // `path()` percent-encodes, and the folder is "Application Support": the encoded path names no file.
        if attachment.kind == .image, let url = attachment.fileURL, let image = UIImage(contentsOfFile: url.path(percentEncoded: false)) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 220, maxHeight: 220)
                .clipShape(.rect(cornerRadius: 14))
                .accessibilityLabel(attachment.name)
        } else {
            Label(attachment.name, systemImage: attachment.kind == .video ? "film" : "doc")
                .font(.footnote)
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.fill.tertiary, in: .rect(cornerRadius: 10))
        }
    }
}

private struct AssistantMessageView: View {
    @Environment(AppModel.self) private var model
    @Environment(SpeechReader.self) private var reader
    let message: AssistantMessage

    private var isStreaming: Bool { model.reply?.itemID == message.id }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if message.text.isEmpty {
                if isStreaming {
                    ProgressView().accessibilityLabel("正在回应")
                } else if message.stopped {
                    Text("已停止。").foregroundStyle(.secondary)
                }
            } else {
                MarkdownView(text: message.stopped ? message.text + " …" : message.text)
            }
            if let cut = message.cut {
                HStack(spacing: 8) {
                    Text(cut == .length ? "回答太长，到这里停了" : "模型中断了，回答到这里")
                        .foregroundStyle(.secondary)
                    Button("接着写") { model.continueReply(message.id) }.inlineTarget()
                }
                .font(.footnote)
            }
            if !isStreaming && !message.text.isEmpty {
                tools
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contextMenu {
            if !isStreaming { actions }
        }
    }

    private var tools: some View {
        HStack(spacing: 0) {
            actions
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 44)
                .contentShape(.rect)
            if model.prefs.showTechInfo, let stats = message.stats {
                Text("\(message.modelName ?? "") · \(Int(stats.tokensPerSecond)) tok/s · \(Duration.seconds(stats.seconds).formatted(.units(allowed: [.seconds], width: .abbreviated, fractionalPart: .show(length: 1))))")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
        // The icons line up with the text; their targets reach past it.
        .padding(.leading, -12)
        .padding(.vertical, -6)
    }

    @ViewBuilder
    private var actions: some View {
        Button("复制", systemImage: "doc.on.doc") { Pasteboard.copy(message.text) }
        Button("重新生成", systemImage: "arrow.clockwise") { model.regenerate(message.id) }
        Button("朗读", systemImage: "speaker.wave.2") { reader.read(message.text) }
    }
}

private struct PlaceMarkView: View {
    let mark: PlaceMark

    var body: some View {
        Group {
            if let host = mark.host {
                Text("从这里开始发送到 \(host) 处理，上文也包括在内")
            } else {
                Text("从这里开始只在这台设备上处理")
            }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
    }
}

/// Reads `memories`, so a deletion in settings reaches this line and takes the words with it.
private struct MemoryLineView: View {
    @Environment(AppModel.self) private var model
    let line: MemoryLine

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "lightbulb").foregroundStyle(.secondary).accessibilityHidden(true)
            if model.memories.contains(line.text) {
                Text("已记住：\(line.text)").foregroundStyle(.secondary)
                Button("撤销") { model.forget(line.text) }.inlineTarget()
                Button("管理") { model.settingsRoute = .memories }.inlineTarget()
            } else {
                Text("已忘掉这条").foregroundStyle(.secondary)
                if model.prefs.memory {
                    Button("重新记住") { model.remember(line.text) }.inlineTarget()
                }
            }
        }
        .font(.footnote)
    }
}

/// The one place content may leave the device on a local setup, so nothing happens before a tap.
private struct SearchCardView: View {
    @Environment(AppModel.self) private var model
    let card: SearchAsk

    var body: some View {
        switch card.state {
        case .accepted:
            Label("联网查了“\(card.query)”", systemImage: "globe").font(.footnote).foregroundStyle(.secondary)
        case .declined:
            Label("没有联网", systemImage: "wifi.slash").font(.footnote).foregroundStyle(.secondary)
        case .pending:
            AskCard(systemImage: "globe", title: "要联网查一下吗？", detail: model.prefs.offlineMode ? "离线模式开着，现在不能联网。" : "只发送下面这句话，对话内容和文件都不发。", quote: card.query) {
                if model.prefs.offlineMode {
                    Button("关闭离线模式") { model.prefs.offlineMode = false }.prominentButton()
                } else {
                    Button("查一下") { model.answerSearch(card.id, accept: true) }.prominentButton()
                }
                Button("不用") { model.answerSearch(card.id, accept: false) }.buttonStyle(.bordered)
            }
        }
    }
}

private struct ActionCardView: View {
    @Environment(AppModel.self) private var model
    let card: ActionCard

    private var isNotification: Bool { card.kind == .notify }
    private var line: String { [card.when, card.text].compactMap(\.self).joined(separator: " · ") }

    var body: some View {
        switch card.state {
        case .accepted:
            Label(isNotification ? "已添加定时通知：\(line)" : "已写到备忘录：\(line)", systemImage: isNotification ? "clock" : "doc.text")
                .font(.footnote).foregroundStyle(.secondary)
        case .declined:
            Label(isNotification ? "没有添加定时通知" : "没有写到备忘录", systemImage: isNotification ? "clock" : "doc.text")
                .font(.footnote).foregroundStyle(.secondary)
        case .pending:
            AskCard(
                systemImage: isNotification ? "clock" : "doc.text",
                title: isNotification ? "加一个定时通知？" : "写到备忘录？",
                detail: isNotification ? "到点发一条通知，点开后回到这里。它不在后台运行。" : "写到系统备忘录里，之后可以在那里修改。",
                quote: line
            ) {
                Button(isNotification ? "添加" : "写入") { model.answerAction(card.id, accept: true) }.prominentButton()
                Button("不用") { model.answerAction(card.id, accept: false) }.buttonStyle(.bordered)
            }
        }
    }
}

private struct AskCard<Actions: View>: View {
    let systemImage: String
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    let quote: String
    @ViewBuilder let actions: Actions

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage).font(.subheadline.weight(.semibold))
            Text(detail).font(.subheadline).foregroundStyle(.secondary)
            Text(quote).font(.subheadline).padding(8).frame(maxWidth: .infinity, alignment: .leading).background(.fill.tertiary, in: .rect(cornerRadius: 8))
            HStack { actions }
        }
        .padding(12)
        .background(.fill.quaternary, in: .rect(cornerRadius: 14))
    }
}
