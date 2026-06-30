import SwiftUI

struct TriadResult {
    let velocities: [CGFloat]
    let major7thVelocity: CGFloat
    let chordName: String
}

struct EmitterGenerator {

    // Center 4 octaves of a piano: C3 (130.81 Hz) to C7 (2093.0 Hz).
    static let pitchRangeHz: ClosedRange<Double> = 130.81...2093.0

    // Root is capped at C5 so that all harmonics (up to the major 7th) stay within pitchRangeHz.
    private static let rootRangeHz: ClosedRange<Double> = 130.81...523.25

    /// Converts a frequency in Hz to the velocity value expected by Emitter.
    /// Inverse of: fixedFrequency = (velocity / 25) * 4000
    static func pitchToVelocity(_ hz: Double) -> CGFloat {
        CGFloat((hz / 4000.0) * 25.0)
    }

    /// Octave-shifts hz into pitchRangeHz.
    private static func clampToPitchRange(_ hz: Double) -> Double {
        var f = hz
        while f < pitchRangeHz.lowerBound { f *= 2 }
        while f > pitchRangeHz.upperBound { f /= 2 }
        return f
    }

    // MARK: - Colors

    /// Generates a harmonically related color pair using an analogous hue relationship.
    static func randomColorPair() -> (Color, Color) {
        let hue = Double.random(in: 0...1)
        let saturation = Double.random(in: 0.75...1.0)
        let brightness = Double.random(in: 0.75...1.0)
        let hueShift = Double.random(in: 0.055...0.138)  // ~20–50° analogous shift
        let highlightHue = (hue + hueShift).truncatingRemainder(dividingBy: 1.0)
        return (
            Color(hue: hue, saturation: saturation, brightness: brightness),
            Color(hue: highlightHue, saturation: Double.random(in: 0.65...1.0), brightness: min(brightness + 0.1, 1.0))
        )
    }

    // MARK: - Pitch

    /// Generates three just-intonation chord tones plus a major 7th, all within the
    /// center 4 octaves of a piano. Velocities are computed via pitchToVelocity so the
    /// same conversion is used at startup and on every new-emitter event.
    static func generatePythagoreanTriad() -> TriadResult {
        let chordTypes: [(r2: Double, r3: Double, name: String)] = [
            (5.0 / 4.0, 3.0 / 2.0, "Major"),    // major third + perfect fifth
            (6.0 / 5.0, 3.0 / 2.0, "Minor"),    // minor third + perfect fifth
            (4.0 / 3.0, 16.0 / 9.0, "Quartal"), // two stacked perfect fourths
        ]

        let selected = chordTypes.randomElement()!
        let rootHz = Double.random(in: rootRangeHz)

        let frequencies = [
            rootHz,
            clampToPitchRange(rootHz * selected.r2),
            clampToPitchRange(rootHz * selected.r3),
        ]
        let major7thHz = clampToPitchRange(rootHz * 15.0 / 8.0)

        return TriadResult(
            velocities: frequencies.map { pitchToVelocity($0) },
            major7thVelocity: pitchToVelocity(major7thHz),
            chordName: selected.name
        )
    }

    // MARK: - Emitter layout

    /// Generates a single EmitterConfig with the given velocity,
    /// placed to avoid overlap with any existing emitters.
    static func generateSingleEmitter(
        velocity: CGFloat,
        existingEmitters: [EmitterConfig],
        screenBounds: CGRect
    ) -> EmitterConfig {
        let (baseColor, highlightColor) = randomColorPair()
        let minSize = Emitter.handleRadius * 2
        let size = max(minSize, CGFloat.random(in: 150...280))

        var position: CGPoint?
        var attempts = 0

        while position == nil && attempts < 50 {
            let candidate = randomScreenPosition(excludingSize: size, screenBounds: screenBounds)
            let overlaps = existingEmitters.contains { config in
                let distance = hypot(candidate.x - config.position.x, candidate.y - config.position.y)
                return distance < (size + config.size) / 2 + 10
            }
            if !overlaps { position = candidate }
            attempts += 1
        }

        return EmitterConfig(
            radius: size * CGFloat.random(in: 0.2...0.35),
            color: baseColor,
            highlightColor: highlightColor,
            initialVelocity: velocity,
            size: size,
            position: position ?? randomScreenPosition(excludingSize: size, screenBounds: screenBounds)
        )
    }

    /// Generates a random position that keeps the emitter fully on screen.
    static func randomScreenPosition(excludingSize size: CGFloat, screenBounds: CGRect) -> CGPoint {
        let padding = size / 2 + 20
        let x = CGFloat.random(in: padding...(screenBounds.width - padding))
        let y = CGFloat.random(in: padding...(screenBounds.height - padding))
        return CGPoint(x: x, y: y)
    }
}
