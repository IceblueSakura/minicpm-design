import Foundation

/// Field names match the engine's request fields; only advanced settings show them.
public struct GenerationParams: Codable, Hashable, Sendable {
    public var maxTokens: Int
    public var temperature: Double
    public var topP: Double
    public var topK: Int
    public var repeatPenalty: Double
    public var nCtx: Int
    public var nGPULayers: Int

    private enum CodingKeys: String, CodingKey {
        case maxTokens = "max_tokens", temperature, topP = "top_p", topK = "top_k"
        case repeatPenalty = "repeat_penalty", nCtx = "n_ctx", nGPULayers = "n_gpu_layers"
    }
}

/// The three common trade-offs. Values are placeholders until tuned on devices.
public enum Preset: String, Codable, CaseIterable, Identifiable, Sendable {
    case saver, balanced, detail, custom
    public var id: String { rawValue }

    public var params: GenerationParams? {
        let base = GenerationParams(maxTokens: 1024, temperature: 0.7, topP: 0.9, topK: 40, repeatPenalty: 1.05, nCtx: 4096, nGPULayers: 99)
        switch self {
        case .saver:
            var p = base
            p.maxTokens = 512
            p.nCtx = 2048
            return p
        case .balanced:
            return base
        case .detail:
            var p = base
            p.maxTokens = 2048
            p.nCtx = 8192
            return p
        case .custom:
            return nil
        }
    }
}

public enum OpenTo: String, Codable, CaseIterable, Sendable { case new, last }
public enum ReplyLanguage: String, Codable, CaseIterable, Sendable { case ui, speech, zhHans, zhHantTW, zhHantHK, en }
public enum ReplyLength: String, Codable, CaseIterable, Sendable { case short, normal, long }
public enum IdleRelease: String, Codable, CaseIterable, Sendable { case m5, m15, h1, never }
public enum WebSearch: String, Codable, CaseIterable, Sendable { case off, ask, auto }
public enum CrashReports: String, Codable, CaseIterable, Sendable { case ask, never, auto }
public enum Retention: String, Codable, CaseIterable, Sendable { case never, d90, d30, d7 }
public enum AutoLock: String, Codable, CaseIterable, Sendable {
    case immediately, m1, m5, never

    /// nil never locks.
    public var seconds: TimeInterval? {
        switch self {
        case .immediately: 0
        case .m1: 60
        case .m5: 300
        case .never: nil
        }
    }
}

/// Settings that only exist for the next stage (live, voice, nudges) join here when that stage lands.
public struct Prefs: Hashable, Sendable {
    public var openTo = OpenTo.new
    public var defaultScene = SceneID.life
    public var haptics = true

    public var replyLanguage = ReplyLanguage.ui
    public var replyLength = ReplyLength.normal
    public var callName = ""

    public var highDetail = false
    public var idleRelease = IdleRelease.m15
    public var thermal = true
    public var wifiOnly = true

    public var offlineMode = false
    public var webSearch = WebSearch.ask
    public var updates = true
    public var analytics = false
    public var crashReports = CrashReports.ask
    public var keepHistory = true
    public var temporaryByDefault = false
    public var retention = Retention.never
    public var memory = true
    public var appLock = false
    public var autoLock = AutoLock.m1
    public var hidePreview = true
    public var coverWhileRecording = false
    public var encrypt = true

    public var showTechInfo = true

    public init() {}
}

// Written by hand so a pref added later reads its default from an older file instead of failing it.
extension Prefs: Codable {
    private enum Key: String, CodingKey {
        case openTo, defaultScene, haptics, replyLanguage, replyLength, callName, highDetail, idleRelease, thermal, wifiOnly
        case offlineMode, webSearch, updates, analytics, crashReports, keepHistory, temporaryByDefault, retention, memory
        case appLock, autoLock, hidePreview, coverWhileRecording, encrypt, showTechInfo
    }

    public init(from decoder: any Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: Key.self)
        func read<T: Decodable>(_ key: Key, _ value: inout T) { if let v = try? c.decode(T.self, forKey: key) { value = v } }
        read(.openTo, &openTo)
        read(.defaultScene, &defaultScene)
        read(.haptics, &haptics)
        read(.replyLanguage, &replyLanguage)
        read(.replyLength, &replyLength)
        read(.callName, &callName)
        read(.highDetail, &highDetail)
        read(.idleRelease, &idleRelease)
        read(.thermal, &thermal)
        read(.wifiOnly, &wifiOnly)
        read(.offlineMode, &offlineMode)
        read(.webSearch, &webSearch)
        read(.updates, &updates)
        read(.analytics, &analytics)
        read(.crashReports, &crashReports)
        read(.keepHistory, &keepHistory)
        read(.temporaryByDefault, &temporaryByDefault)
        read(.retention, &retention)
        read(.memory, &memory)
        read(.appLock, &appLock)
        read(.autoLock, &autoLock)
        read(.hidePreview, &hidePreview)
        read(.coverWhileRecording, &coverWhileRecording)
        read(.encrypt, &encrypt)
        read(.showTechInfo, &showTechInfo)
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: Key.self)
        try c.encode(openTo, forKey: .openTo)
        try c.encode(defaultScene, forKey: .defaultScene)
        try c.encode(haptics, forKey: .haptics)
        try c.encode(replyLanguage, forKey: .replyLanguage)
        try c.encode(replyLength, forKey: .replyLength)
        try c.encode(callName, forKey: .callName)
        try c.encode(highDetail, forKey: .highDetail)
        try c.encode(idleRelease, forKey: .idleRelease)
        try c.encode(thermal, forKey: .thermal)
        try c.encode(wifiOnly, forKey: .wifiOnly)
        try c.encode(offlineMode, forKey: .offlineMode)
        try c.encode(webSearch, forKey: .webSearch)
        try c.encode(updates, forKey: .updates)
        try c.encode(analytics, forKey: .analytics)
        try c.encode(crashReports, forKey: .crashReports)
        try c.encode(keepHistory, forKey: .keepHistory)
        try c.encode(temporaryByDefault, forKey: .temporaryByDefault)
        try c.encode(retention, forKey: .retention)
        try c.encode(memory, forKey: .memory)
        try c.encode(appLock, forKey: .appLock)
        try c.encode(autoLock, forKey: .autoLock)
        try c.encode(hidePreview, forKey: .hidePreview)
        try c.encode(coverWhileRecording, forKey: .coverWhileRecording)
        try c.encode(encrypt, forKey: .encrypt)
        try c.encode(showTechInfo, forKey: .showTechInfo)
    }
}
