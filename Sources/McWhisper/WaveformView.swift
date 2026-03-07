import SwiftUI

/// Animated waveform visualization drawing vertical bars via `Canvas`.
/// Bar heights are proportional to values in the `levels` ring buffer (capacity 30).
struct WaveformView: View {
    let levels: [Float]

    static let barCount = 30
    static let barSpacing: CGFloat = 2
    static let barCornerRadius: CGFloat = 1.5
    static let minimumLevel: Float = 0.05

    var body: some View {
        Canvas { context, size in
            let count = levels.count
            guard count > 0 else { return }

            let totalSpacing = WaveformView.barSpacing * CGFloat(count - 1)
            let barWidth = max((size.width - totalSpacing) / CGFloat(count), 1)
            let totalBarsWidth = barWidth * CGFloat(count) + totalSpacing
            let originX = (size.width - totalBarsWidth) / 2

            for i in 0..<count {
                let level = CGFloat(max(levels[i], WaveformView.minimumLevel))
                let barHeight = size.height * level
                let x = originX + CGFloat(i) * (barWidth + WaveformView.barSpacing)
                let y = (size.height - barHeight) / 2

                let rect = CGRect(x: x, y: y, width: barWidth, height: barHeight)
                let path = Path(roundedRect: rect, cornerRadius: WaveformView.barCornerRadius)
                context.fill(path, with: .foreground)
            }
        }
    }
}

/// A single animated bar in the waveform display.
/// Kept for backward compatibility and unit-testable scale logic.
struct WaveformBar: View {
    let level: Float

    var scale: CGFloat {
        CGFloat(max(level, WaveformView.minimumLevel))
    }

    var body: some View {
        RoundedRectangle(cornerRadius: WaveformView.barCornerRadius)
            .fill(.primary)
            .frame(width: 3, height: 32 * scale)
            .animation(.easeInOut(duration: 0.1), value: level)
    }
}
