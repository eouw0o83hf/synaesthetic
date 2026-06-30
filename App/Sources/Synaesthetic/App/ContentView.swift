import SwiftUI

struct ContentView: View {
    @State private var emitters: [EmitterConfig] = []
    @State private var isDraggingEmitter: Bool = false
    @State private var isInDeleteZone: Bool = false
    @State private var chordVelocities: [CGFloat] = []

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            GeometryReader { geometry in
                let glowOpacity: Double = isDraggingEmitter ? (isInDeleteZone ? 0.9 : 0.5) : 0
                ZStack {
                    ForEach(0..<emitters.count, id: \.self) { index in
                        let config = emitters[index]
                        Emitter(
                            radius: config.radius,
                            color: config.color,
                            highlightColor: config.highlightColor,
                            initialVelocity: config.initialVelocity,
                            position: $emitters[index].position,
                            screenHeight: geometry.size.height,
                            isDragging: $isDraggingEmitter,
                            isInDeleteZone: $isInDeleteZone,
                            onDelete: { emitters.remove(at: index) }
                        )
                        .frame(width: config.size, height: config.size)
                        .position(emitters[index].position)
                    }

                    VStack {
                        Spacer()
                        LinearGradient(
                            colors: [.clear, Color(red: 0.5, green: 0, blue: 0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 48)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .opacity(glowOpacity)
                    .animation(.easeInOut(duration: 0.2), value: glowOpacity)
                    .allowsHitTesting(false)
                }
            }

            VStack {
                Spacer()
                HStack {
                    Button(action: addEmitter) {
                        Image(systemName: "plus")
                            .font(.system(size: 28, weight: .ultraLight))
                            .foregroundColor(.white.opacity(0.6))
                            .frame(width: 60, height: 60)
                    }
                    .padding(.leading, 20)
                    Spacer()
                }
                .padding(.bottom, 12)
            }
            .opacity(isDraggingEmitter ? 0 : 1)
            .animation(.easeInOut(duration: 0.2), value: isDraggingEmitter)
        }
        .onAppear {
            let velocities = EmitterGenerator.generatePythagoreanTriad()
            chordVelocities = velocities
            emitters = generateStartupEmitters(velocities: velocities.shuffled())
        }
    }

    /// Generates three randomized emitters using a given set of velocities.
    private func generateStartupEmitters(velocities: [CGFloat]) -> [EmitterConfig] {
        let screenBounds = UIScreen.main.bounds
        var configs: [EmitterConfig] = []
        for index in 0..<3 {
            let config = EmitterGenerator.generateSingleEmitter(
                velocity: velocities[index],
                colorIndex: index,
                existingEmitters: configs,
                screenBounds: screenBounds
            )
            configs.append(config)
        }
        return configs
    }

    /// Appends a new emitter whose velocity is drawn from the stored chord.
    private func addEmitter() {
        guard !chordVelocities.isEmpty else { return }
        let velocity = chordVelocities.randomElement()!
        let config = EmitterGenerator.generateSingleEmitter(
            velocity: velocity,
            colorIndex: emitters.count,
            existingEmitters: emitters,
            screenBounds: UIScreen.main.bounds
        )
        emitters.append(config)
    }
}

#Preview {
    ContentView()
}
