import SwiftUI

struct ContentView: View {
    @State private var emitters: [EmitterConfig] = []

    struct EmitterConfig {
        let radius: CGFloat
        let color: Color
        let highlightColor: Color
        let initialVelocity: CGFloat
        let size: CGFloat
        let position: CGPoint
    }

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            GeometryReader { geometry in
                ZStack {
                    ForEach(0..<emitters.count, id: \.self) { index in
                        let config = emitters[index]
                        Emitter(
                            radius: config.radius,
                            color: config.color,
                            highlightColor: config.highlightColor,
                            initialVelocity: config.initialVelocity
                        )
                        .frame(width: config.size, height: config.size)
                        .position(config.position)
                    }
                }
            }
        }
        .onAppear {
            emitters = generateRandomizedEmitters()
        }
    }

    /// Generates three randomized emitters with Pythagorean triad velocities.
    private func generateRandomizedEmitters() -> [EmitterConfig] {
        let colors: [(Color, Color)] = [
            (.red, .orange),
            (.blue, .green),
            (.purple, .pink)
        ]

        let velocities = generatePythagoreanTriad()
        let shuffledVelocities = velocities.shuffled()

        var configs: [EmitterConfig] = []
        let screenBounds = UIScreen.main.bounds

        for index in 0..<3 {
            let size = CGFloat.random(in: 150...280)
            let (baseColor, highlightColor) = colors[index]

            // Try to find a non-overlapping position
            var position: CGPoint?
            var attempts = 0
            let maxAttempts = 50

            while position == nil && attempts < maxAttempts {
                let candidatePosition = randomScreenPosition(excludingSize: size, screenBounds: screenBounds)

                // Check if this position overlaps with any existing emitters
                let overlaps = configs.contains { config in
                    let distance = hypot(candidatePosition.x - config.position.x, candidatePosition.y - config.position.y)
                    let minDistance = (size + config.size) / 2 + 10 // 10pt padding between circles
                    return distance < minDistance
                }

                if !overlaps {
                    position = candidatePosition
                }
                attempts += 1
            }

            // Fallback: if we couldn't find a non-overlapping position, place it anyway
            if position == nil {
                position = randomScreenPosition(excludingSize: size, screenBounds: screenBounds)
            }

            configs.append(EmitterConfig(
                radius: size * CGFloat.random(in: 0.2...0.35),
                color: baseColor,
                highlightColor: highlightColor,
                initialVelocity: shuffledVelocities[index],
                size: size,
                position: position!
            ))
        }

        return configs
    }

    /// Generates a random screen position that fits the given size.
    private func randomScreenPosition(excludingSize size: CGFloat, screenBounds: CGRect) -> CGPoint {
        let padding = size / 2 + 20
        let x = CGFloat.random(in: padding...(screenBounds.width - padding))
        let y = CGFloat.random(in: padding...(screenBounds.height - padding))
        return CGPoint(x: x, y: y)
    }

    /// Generates three velocities forming a Pythagorean triad.
    /// Includes random inversion and octave spreading across up to three octaves.
    private func generatePythagoreanTriad() -> [CGFloat] {
        // Base Pythagorean ratios
        let ratios: [(CGFloat, CGFloat, CGFloat)] = [
            (3, 4, 5),      // Classic just major triad
            (5, 6, 8),      // Minor seventh chord ratio
            (4, 5, 6),      // Harmonic series segment
            (8, 10, 12),    // Doubled 4:5:6
        ]

        let selectedRatio = ratios.randomElement()!
        let baseFreq = CGFloat.random(in: 2...10) // Base frequency in rad/s

        // Create base velocities from ratio
        var velocities = [
            selectedRatio.0 / 3.0 * baseFreq,
            selectedRatio.1 / 3.0 * baseFreq,
            selectedRatio.2 / 3.0 * baseFreq
        ]

        // Randomize inversions by reordering and transposing
        let inversions = (0..<3).map { _ in CGFloat.random(in: 0...2).rounded() }
        velocities = velocities.enumerated().map { index, velocity in
            let octaveShift = inversions[index] // 0, 1, or 2 octaves
            return velocity * pow(2.0, octaveShift)
        }

        // Ensure all velocities are within valid range (0-25 rad/s)
        let maxVel = velocities.max()!
        if maxVel > 25 {
            velocities = velocities.map { $0 * (25.0 / maxVel) }
        }

        // Ensure no velocities are too small
        velocities = velocities.map { max($0, 0.5) }

        return velocities
    }
}

#Preview {
    ContentView()
}
