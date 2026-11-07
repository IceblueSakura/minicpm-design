import SwiftUI

extension View {
    /// System prominent buttons draw white labels, which fail contrast on the light jade of dark mode. `OnJade` is the pair for that fill.
    func prominentButton() -> some View {
        buttonStyle(.borderedProminent).foregroundStyle(.onJade)
    }

    func prominentGlassButton() -> some View {
        buttonStyle(.glassProminent).foregroundStyle(.onJade)
    }

    /// Text actions inside a line keep their small type but get a target a finger can hit.
    func inlineTarget() -> some View {
        padding(.vertical, 8).contentShape(.rect)
    }
}
