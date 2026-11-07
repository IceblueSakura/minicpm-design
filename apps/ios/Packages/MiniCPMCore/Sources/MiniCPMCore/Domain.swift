import Foundation

/// Stable scene ids. Display names live in the app layer so translation and distribution never touch these.
public enum SceneID: String, Codable, CaseIterable, Identifiable, Sendable {
    case life, work, game, community
    public var id: String { rawValue }
}

/// Where the model runs. Only the user changes this; a failure on one side never moves to the other.
public enum Place: String, Codable, Sendable {
    case local, remote
}

public struct Attachment: Identifiable, Codable, Hashable, Sendable {
    public enum Kind: String, Codable, Sendable { case image, video, file }

    public var id: UUID
    public var kind: Kind
    public var name: String
    public var byteCount: Int64
    /// File name under `AppPaths.attachments`. Absolute paths would break when the container moves.
    public var storedFileName: String?

    public init(id: UUID = UUID(), kind: Kind, name: String, byteCount: Int64, storedFileName: String? = nil) {
        self.id = id
        self.kind = kind
        self.name = name
        self.byteCount = byteCount
        self.storedFileName = storedFileName
    }

    public var fileURL: URL? { storedFileName.map { AppPaths.attachments.appendingPathComponent($0) } }
}

public struct UserMessage: Identifiable, Codable, Hashable, Sendable {
    public var id = UUID()
    public var text: String
    public var attachments: [Attachment]
    public var failed: Bool

    public init(text: String, attachments: [Attachment] = [], failed: Bool = false) {
        self.text = text
        self.attachments = attachments
        self.failed = failed
    }
}

public enum CutReason: String, Codable, Sendable {
    case length, interrupted
}

public struct ReplyStats: Codable, Hashable, Sendable {
    public var tokensPerSecond: Double
    public var seconds: Double

    public init(tokensPerSecond: Double, seconds: Double) {
        self.tokensPerSecond = tokensPerSecond
        self.seconds = seconds
    }
}

public struct AssistantMessage: Identifiable, Codable, Hashable, Sendable {
    public var id = UUID()
    public var text = ""
    /// Which model answered, so an upgrade from vision to omni keeps old replies attributable.
    public var modelName: String?
    public var stopped = false
    public var cut: CutReason?
    public var stats: ReplyStats?

    public init(modelName: String? = nil) { self.modelName = modelName }
}

/// Marks the first message after the place changed, so a mixed conversation stays honest.
public struct PlaceMark: Identifiable, Codable, Hashable, Sendable {
    public var id = UUID()
    /// nil means this device; otherwise the host content goes to.
    public var host: String?

    public init(host: String?) { self.host = host }
}

public struct MemoryLine: Identifiable, Codable, Hashable, Sendable {
    public var id = UUID()
    public var text: String

    public init(text: String) { self.text = text }
}

public enum CardState: String, Codable, Sendable {
    case pending, accepted, declined
}

public struct SearchAsk: Identifiable, Codable, Hashable, Sendable {
    public var id = UUID()
    public var query: String
    public var state = CardState.pending

    public init(query: String) { self.query = query }
}

public enum ActionKind: String, Codable, Sendable {
    case notify, memo
}

public struct ActionCard: Identifiable, Codable, Hashable, Sendable {
    public var id = UUID()
    public var kind: ActionKind
    public var when: String?
    public var text: String
    public var state = CardState.pending

    public init(kind: ActionKind, when: String?, text: String) {
        self.kind = kind
        self.when = when
        self.text = text
    }
}

/// One entry in a conversation. New kinds arrive with later stages (live sessions first),
/// so `Conversation` drops types it cannot read instead of failing the whole file.
public enum ThreadItem: Identifiable, Hashable, Sendable {
    case user(UserMessage)
    case assistant(AssistantMessage)
    case place(PlaceMark)
    case memory(MemoryLine)
    case search(SearchAsk)
    case action(ActionCard)

    public var id: UUID {
        switch self {
        case .user(let m): m.id
        case .assistant(let m): m.id
        case .place(let m): m.id
        case .memory(let m): m.id
        case .search(let m): m.id
        case .action(let m): m.id
        }
    }
}

extension ThreadItem: Codable {
    private enum TypeKey: String, CodingKey { case type }

    public init(from decoder: any Decoder) throws {
        let type = try decoder.container(keyedBy: TypeKey.self).decode(String.self, forKey: .type)
        switch type {
        case "user": self = .user(try UserMessage(from: decoder))
        case "assistant": self = .assistant(try AssistantMessage(from: decoder))
        case "place": self = .place(try PlaceMark(from: decoder))
        case "memory": self = .memory(try MemoryLine(from: decoder))
        case "search": self = .search(try SearchAsk(from: decoder))
        case "action": self = .action(try ActionCard(from: decoder))
        default:
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Unknown item type \(type)"))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: TypeKey.self)
        switch self {
        case .user(let m): try container.encode("user", forKey: .type); try m.encode(to: encoder)
        case .assistant(let m): try container.encode("assistant", forKey: .type); try m.encode(to: encoder)
        case .place(let m): try container.encode("place", forKey: .type); try m.encode(to: encoder)
        case .memory(let m): try container.encode("memory", forKey: .type); try m.encode(to: encoder)
        case .search(let m): try container.encode("search", forKey: .type); try m.encode(to: encoder)
        case .action(let m): try container.encode("action", forKey: .type); try m.encode(to: encoder)
        }
    }
}

public struct Conversation: Identifiable, Codable, Hashable, Sendable {
    public var id = UUID()
    public var title = ""
    public var autoTitle = true
    public var isTemporary = false
    public var scene: SceneID
    public var items: [ThreadItem] = []
    /// Where the last message went: "local" or a host. Compared to decide when to leave a `PlaceMark`.
    public var place: String?
    public var updatedAt = Date()
    public var hasUnread = false
    /// Names of files sent here, shown in the conversation details.
    public var sources: [String] = []

    public init(scene: SceneID, isTemporary: Bool = false) {
        self.scene = scene
        self.isTemporary = isTemporary
    }

    public var isBlank: Bool { items.isEmpty }
    /// A blank conversation nobody has named; the title shows the model instead.
    public var isFresh: Bool { isBlank && autoTitle }

    private enum CodingKeys: String, CodingKey {
        case id, title, autoTitle, isTemporary, scene, items, place, updatedAt, hasUnread, sources
    }

    private struct Lossy: Decodable {
        let item: ThreadItem?
        init(from decoder: any Decoder) throws { item = try? ThreadItem(from: decoder) }
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        autoTitle = try c.decode(Bool.self, forKey: .autoTitle)
        isTemporary = try c.decode(Bool.self, forKey: .isTemporary)
        scene = try c.decode(SceneID.self, forKey: .scene)
        items = try c.decode([Lossy].self, forKey: .items).compactMap(\.item)
        place = try c.decodeIfPresent(String.self, forKey: .place)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
        hasUnread = try c.decodeIfPresent(Bool.self, forKey: .hasUnread) ?? false
        sources = try c.decodeIfPresent([String].self, forKey: .sources) ?? []
    }
}

public enum ModelKind: String, Codable, Sendable {
    case vision, omni
}

public enum Capability: String, Codable, Sendable {
    case image, video, audio, speech, live
}

/// One downloadable choice. The backend reads the hardware and lists what this device can pick,
/// so name, size and spec words are data rather than constants in the UI.
public struct ModelOption: Identifiable, Hashable, Sendable {
    public var id: String
    public var modelID: String
    public var name: String
    public var shortName: String
    public var kind: ModelKind
    public var capabilities: [Capability]
    public var specLabel: String
    public var specTag: String
    public var sizeGB: Double
    public var memoryGB: Double
    public var isRecommended: Bool
    public var loadSeconds: Int

    public init(id: String, modelID: String, name: String, shortName: String, kind: ModelKind, capabilities: [Capability], specLabel: String, specTag: String, sizeGB: Double, memoryGB: Double, isRecommended: Bool, loadSeconds: Int) {
        self.id = id
        self.modelID = modelID
        self.name = name
        self.shortName = shortName
        self.kind = kind
        self.capabilities = capabilities
        self.specLabel = specLabel
        self.specTag = specTag
        self.sizeGB = sizeGB
        self.memoryGB = memoryGB
        self.isRecommended = isRecommended
        self.loadSeconds = loadSeconds
    }
}

public struct NetworkRecord: Identifiable, Codable, Hashable, Sendable {
    public enum Kind: String, Codable, Sendable { case modelDownload, search, backup }

    public var id = UUID()
    public var kind: Kind
    public var date: Date
    public var detail: String

    public init(kind: Kind, date: Date = Date(), detail: String) {
        self.kind = kind
        self.date = date
        self.detail = detail
    }
}
