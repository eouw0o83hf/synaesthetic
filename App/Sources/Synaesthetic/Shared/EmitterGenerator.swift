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

    /// All emitter tempos are rhythmic harmonics of 60 BPM (integer multiples: 0.5x to 4x).
    /// Stored as BPM values; convert to velocity (rad/s) via: velocity = bpm * 2π / 60
    static let harmonicTemposBPM: [Double] = [30, 60, 90, 120, 150, 180, 210, 240]

    /// Converts tempo in BPM to velocity in rad/s.
    static func tempoToVelocity(_ bpm: Double) -> CGFloat {
        CGFloat(bpm * 2.0 * .pi / 60.0)
    }

    /// Converts velocity in rad/s to tempo in BPM.
    static func velocityToTempo(_ velocity: CGFloat) -> Double {
        Double(velocity) * 60.0 / (2.0 * .pi)
    }

    /// Picks a random harmonic tempo (multiple of 60 BPM) and returns its velocity.
    static func randomHarmonicTempoVelocity() -> CGFloat {
        let bpm = harmonicTemposBPM.randomElement()!
        return tempoToVelocity(bpm)
    }

    /// Converts a frequency in Hz to the tempo value (velocity in rad/s) expected by Emitter.
    /// Inverse of: fixedFrequency = (tempo / 25) * 4000
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

    /// Generates three distinct harmonic tempos (multiples of 60 BPM) plus a major 7th.
    /// Returns tempos as velocities to maintain synesthetic audio-visual coupling.
    static func generatePythagoreanTriad() -> TriadResult {
        let chordNames = ["Major", "Minor", "Quartal"]
        let selected = chordNames.randomElement()!

        // Pick 3 distinct harmonic tempos spread across the range
        var selectedTempos = Set<Double>()
        while selectedTempos.count < 3 {
            selectedTempos.insert(harmonicTemposBPM.randomElement()!)
        }
        let triadTempos = Array(selectedTempos).sorted()
        let velocities = triadTempos.map { tempoToVelocity($0) }

        // Major 7th: pick a 4th distinct tempo
        var major7thTempo = harmonicTemposBPM.randomElement()!
        while selectedTempos.contains(major7thTempo) {
            major7thTempo = harmonicTemposBPM.randomElement()!
        }
        let major7thVelocity = tempoToVelocity(major7thTempo)

        return TriadResult(
            velocities: velocities,
            major7thVelocity: major7thVelocity,
            chordName: selected
        )
    }

    // MARK: - Emitter layout

    /// Generates a single EmitterConfig with the given tempo (velocity in rad/s),
    /// placed to avoid overlap with any existing emitters.
    /// The tempo should be a harmonic multiple of 60 BPM (converted to velocity via tempoToVelocity).
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
            position: position ?? randomScreenPosition(excludingSize: size, screenBounds: screenBounds),
            reverb: EmitterReverb.random()
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
