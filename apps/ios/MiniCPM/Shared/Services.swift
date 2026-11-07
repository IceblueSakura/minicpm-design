import AVFoundation
import MiniCPMCore
import Observation
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Dictation is offered only when the system can recognize on this device, so "本机转成文字" stays true.
/// The real one wraps `SFSpeechRecognizer` with `requiresOnDeviceRecognition`.
protocol DictationService: Sendable {
    var isAvailable: Bool { get }
}

struct UnavailableDictation: DictationService {
    var isAvailable: Bool { false }
}

extension EnvironmentValues {
    @Entry var dictation: any DictationService = UnavailableDictation()
}

/// Reading aloud runs on the system voice, so it works without any model.
@MainActor
@Observable
final class SpeechReader {
    private let synthesizer = AVSpeechSynthesizer()

    func read(_ text: String) {
        stop()
        synthesizer.speak(AVSpeechUtterance(string: text))
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}

enum Files {
    /// Copies into the app's own folder, which the system backup skips.
    static func store(data: Data, name: String, kind: Attachment.Kind) throws -> Attachment {
        try FileManager.default.createDirectory(at: AppPaths.attachments, withIntermediateDirectories: true)
        let stored = "\(UUID().uuidString)-\(name)"
        try data.write(to: AppPaths.attachments.appending(path: stored), options: .atomic)
        return Attachment(kind: kind, name: name, byteCount: Int64(data.count), storedFileName: stored)
    }

    static func store(pickedFile url: URL) throws -> Attachment {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let type = (try? url.resourceValues(forKeys: [.contentTypeKey]))?.contentType
        let kind: Attachment.Kind = type?.conforms(to: .image) == true ? .image : type?.conforms(to: .movie) == true ? .video : .file
        return try store(data: Data(contentsOf: url), name: url.lastPathComponent, kind: kind)
    }
}

/// Copy goes through UIKit because SwiftUI has no pasteboard writer.
@MainActor
enum Pasteboard {
    static func copy(_ text: String) {
        UIPasteboard.general.string = text
    }
}

@MainActor
enum SystemSettings {
    static var url: URL { URL(string: UIApplication.openSettingsURLString)! }
}
