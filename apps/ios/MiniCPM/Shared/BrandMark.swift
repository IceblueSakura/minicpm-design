import SwiftUI

/// The two-track waveform: you on top, the model below. One of the few drawn pieces on native platforms.
struct BrandMark: View {
    private static let upper: [(x: CGFloat, y: CGFloat)] = [(4, 9), (8, 6), (12, 3.5), (16, 7.5), (20, 9.5)]
    private static let lower: [(x: CGFloat, y: CGFloat)] = [(4, 15), (8, 16.5), (12, 16), (16, 20.5), (20, 17)]

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / 24
            func draw(_ bars: [(x: CGFloat, y: CGFloat)], from start: CGFloat, color: Color) {
                var path = Path()
                for bar in bars {
                    path.move(to: CGPoint(x: bar.x * scale, y: start * scale))
                    path.addLine(to: CGPoint(x: bar.x * scale, y: bar.y * scale))
                }
                context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 2 * scale, lineCap: .butt))
            }
            draw(Self.upper, from: 10.5, color: .youWave)
            draw(Self.lower, from: 13.5, color: .jadeWave)
        }
        .accessibilityHidden(true)
    }
}
