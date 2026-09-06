import SwiftUI

/// Mirrored bars driven by real output levels. Idles with a slow breath when nothing plays.
struct Waveform: View {
    let levels: [Float]
    var active: Bool
    var bars = 18
    var color: Color = Theme.ink
    @State private var phase = 0.0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: active)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            GeometryReader { geo in
                let w = geo.size.width / CGFloat(bars)
                HStack(alignment: .center, spacing: 0) {
                    ForEach(0..<bars, id: \.self) { i in
                        let level = active ? Double(sample(i)) : idle(i, t)
                        Capsule()
                            .fill(color)
                            .frame(width: max(1.5, w * 0.42), height: max(2.5, geo.size.height * level))
                            .frame(width: w)
                            .animation(.easeOut(duration: 0.08), value: level)
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
    }

    private func sample(_ i: Int) -> Float {
        guard !levels.isEmpty else { return 0 }
        // Fan the bands out from the centre so the shape reads as a voice, not a spectrum.
        let center = Double(bars - 1) / 2
        let dist = abs(Double(i) - center) / center
        let idx = min(levels.count - 1, Int(dist * Double(levels.count - 1)))
        let taper = Float(1 - dist * 0.55)
        return min(1, levels[idx] * taper * 1.6 + 0.04)
    }

    private func idle(_ i: Int, _ t: Double) -> Double {
        let center = Double(bars - 1) / 2
        let dist = abs(Double(i) - center) / center
        return 0.10 + 0.08 * (1 - dist) * (0.5 + 0.5 * sin(t * 1.6 + Double(i) * 0.5))
    }
}
