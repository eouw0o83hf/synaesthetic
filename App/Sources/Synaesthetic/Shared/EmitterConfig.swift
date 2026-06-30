import SwiftUI

/// Configuration for an Emitter. The tempo (initialVelocity in rad/s) is a harmonic
/// multiple of 60 BPM and drives both visual rotation speed and audio pitch.
struct EmitterConfig {
    let radius: CGFloat
    let color: Color
    let highlightColor: Color
    /// Tempo in rad/s (harmonic multiple of 60 BPM). Drives rotation speed and audio pitch.
    let initialVelocity: CGFloat
    let size: CGFloat
    var position: CGPoint
    let reverb: EmitterReverb

    init(
        radius: CGFloat,
        color: Color,
        highlightColor: Color,
        initialVelocity: CGFloat,
        size: CGFloat,
        position: CGPoint,
        reverb: EmitterReverb = EmitterReverb(amount: 0)
    ) {
        self.radius = radius
        self.color = color
        self.highlightColor = highlightColor
        self.initialVelocity = initialVelocity
        self.size = size
        self.position = position
        self.reverb = reverb
    }
}
