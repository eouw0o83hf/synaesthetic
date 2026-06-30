import SwiftUI

struct EmitterGenerator {

    static let colors: [(Color, Color)] = [
        (.red, .orange),
        (.blue, .green),
        (.purple, .pink)
    ]

    /// Generates three velocities forming a Pythagorean triad with random octave spread.
    /// Velocities are guaranteed to be in the range [0.5, 25] rad/s.
    static func generatePythagoreanTriad() -> [CGFloat] {
        let ratios: [(CGFloat, CGFloat, CGFloat)] = [
            (3, 4, 5),
            (5, 6, 8),
            (4, 5, 6),
            (8, 10, 12),
        ]

        let selectedRatio = ratios.randomElement()!
        let baseFreq = CGFloat.random(in: 2...10)

        var velocities = [
            selectedRatio.0 / 3.0 * baseFreq,
            selectedRatio.1 / 3.0 * baseFreq,
            selectedRatio.2 / 3.0 * baseFreq
        ]

        let inversions = (0..<3).map { _ in CGFloat.random(in: 0...2).rounded() }
        velocities = velocities.enumerated().map { index, velocity in
            velocity * pow(2.0, inversions[index])
        }

        let maxVel = velocities.max()!
        if maxVel > 25 {
            velocities = velocities.map { $0 * (25.0 / maxVel) }
        }

        return velocities.map { max($0, 0.5) }
    }

    /// Generates a single EmitterConfig with the given velocity and color index,
    /// placed to avoid overlap with any existing emitters.
    static func generateSingleEmitter(
        velocity: CGFloat,
        colorIndex: Int,
        existingEmitters: [EmitterConfig],
        screenBounds: CGRect
    ) -> EmitterConfig {
        let (baseColor, highlightColor) = colors[colorIndex % colors.count]
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
