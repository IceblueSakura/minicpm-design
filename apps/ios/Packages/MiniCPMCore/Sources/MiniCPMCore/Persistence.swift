import Foundation
import Synchronization

public enum AppPaths {
    /// Application Support rather than Documents: Documents operations can reset the backup exclusion.
    public static var root: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("MiniCPM", isDirectory: true)
    }

    public static var attachments: URL { root.appendingPathComponent("Attachments", isDirectory: true) }
}

public struct Snapshot: Codable, Sendable {
    public var version = 1
    public var onboarded = false
    public var conversations: [Conversation] = []
    public var currentID: UUID?
    public var prefs = Prefs()
    public var memories: [String] = []
    public var persona = "你是一个耐心、直接的助手。回答简短，先说结论。"
    public var preset = Preset.balanced
    public var params = Preset.balanced.params!
    public var place = Place.local
    public var remoteURL = ""
    public var optionID: String?
    public var hiddenScenes: Set<SceneID> = []
    public var networkLog: [NetworkRecord] = []

    public init() {}
}

public protocol Persistence: Sendable {
    func load() -> Snapshot?
    func save(_ snapshot: Snapshot)
    /// Written before a load starts and cleared after it ends. Still there at launch means the app died loading.
    var loadMarker: String? { get }
    func setLoadMarker(_ optionID: String?)
}

public struct JSONFilePersistence: Persistence {
    private let directory: URL
    private var stateFile: URL { directory.appendingPathComponent("state.json") }
    private var markerFile: URL { directory.appendingPathComponent("loading") }

    public init(directory: URL = AppPaths.root) {
        self.directory = directory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        // Conversations must not reach the system backup behind the user's back. iCloud backup is the app's own, opt-in.
        var url = directory
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? url.setResourceValues(values)
    }

    public func load() -> Snapshot? {
        guard let data = try? Data(contentsOf: stateFile) else { return nil }
        return try? JSONDecoder().decode(Snapshot.self, from: data)
    }

    public func save(_ snapshot: Snapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: stateFile, options: .atomic)
    }

    public var loadMarker: String? {
        (try? String(contentsOf: markerFile, encoding: .utf8)).flatMap { $0.isEmpty ? nil : $0 }
    }

    public func setLoadMarker(_ optionID: String?) {
        if let optionID {
            try? Data(optionID.utf8).write(to: markerFile, options: .atomic)
        } else {
            try? FileManager.default.removeItem(at: markerFile)
        }
    }
}

/// For previews and tests.
public final class InMemoryPersistence: Persistence {
    private struct State {
        var snapshot: Snapshot?
        var marker: String?
    }

    private let state: Mutex<State>

    public init(snapshot: Snapshot? = nil, loadMarker: String? = nil) {
        state = Mutex(State(snapshot: snapshot, marker: loadMarker))
    }

    public func load() -> Snapshot? { state.withLock { $0.snapshot } }
    public func save(_ snapshot: Snapshot) { state.withLock { $0.snapshot = snapshot } }
    public var loadMarker: String? { state.withLock { $0.marker } }
    public func setLoadMarker(_ optionID: String?) { state.withLock { $0.marker = optionID } }
}
