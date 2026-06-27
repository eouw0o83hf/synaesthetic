import SwiftUI
import AVFoundation
#if canImport(UIKit)
import UIKit
#endif

/// A circle with an angular gradient that wraps around with a sharp radial edge.
/// The emitter rotates continuously at a velocity measured in radians per second.
struct Emitter: View {
    /// Radius of the solid center dot used to reposition the emitter. The emitter's
    /// frame will never shrink below this dot's diameter.
    static let centerDotRadius: CGFloat = 15

    /// The radius in pixels.
    let radius: CGFloat

    /// The starting color of the gradient.
    let color: Color

    /// The highlight color that the gradient fades to.
    let highlightColor: Color

    /// The initial velocity in radians per second. Defaults to 1.
    let initialVelocity: CGFloat

    /// The emitter's position on screen. Updated while repositioning.
    @Binding var position: CGPoint

    /// The current rotational velocity in radians per second.
    @State var velocity: CGFloat

    /// The current rotation angle in radians.
    @State private var rotation: CGFloat = 0

    /// Tracks the last drag position for velocity calculation.
    @State private var lastDragPosition: CGPoint?

    /// Tracks the last drag time for velocity calculation.
    @State private var lastDragTime: Date?

    /// Whether the user is currently repositioning the emitter via the center dot.
    @State private var isRepositioning: Bool = false

    /// Scale factor applied to the center dot for the pulse animation.
    @State private var pulseScale: CGFloat = 1.0

    /// Position captured at the moment repositioning starts.
    @State private var repositionStartPosition: CGPoint = .zero

    /// Audio engine for sound generation.
    @State private var audioEngine: AVAudioEngine?

    /// Audio source node for tone generation.
    @State private var sourceNode: AVAudioSourceNode?

    /// Current phase of the audio waveform.
    @State private var phase: Double = 0

    init(
        radius: CGFloat,
        color: Color,
        highlightColor: Color,
        initialVelocity: CGFloat = 1,
        position: Binding<CGPoint> = .constant(.zero)
    ) {
        self.radius = radius
        self.color = color
        self.highlightColor = highlightColor
        self.initialVelocity = initialVelocity
        self._position = position
        self._velocity = State(initialValue: initialVelocity)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Circle()
                    .fill(
                        AngularGradient(
                            colors: [color, highlightColor],
                            center: .center
                        )
                    )
                    .frame(
                        width: calculateDiameter(for: geometry),
                        height: calculateDiameter(for: geometry)
                    )
                    .rotationEffect(.radians(rotation))
                    .scaleEffect(pulseScale)

                Circle()
                    .fill(color)
                    .frame(width: Emitter.centerDotRadius * 2, height: Emitter.centerDotRadius * 2)
                    .scaleEffect(pulseScale)
                    .gesture(repositionGesture)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        handleDragChanged(value: value, geometry: geometry)
                    }
                    .onEnded { value in
                        handleDragEnded(value: value, geometry: geometry)
                    }
            )
        }
        .frame(minWidth: Emitter.centerDotRadius * 2, minHeight: Emitter.centerDotRadius * 2)
        .onAppear {
            startRotation()
            setupAudio()
            startAudio()
        }
        .onDisappear {
            stopAudio()
        }
    }

    /// Calculates the diameter (2x radius) in pixels.
    private func calculateDiameter(for geometry: GeometryProxy) -> CGFloat {
        return radius * 2
    }

    /// Starts the continuous rotation animation based on velocity.
    private func startRotation() {
        Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
            rotation += velocity / 60.0
        }
    }

    /// Sets up the audio engine and source node for tone generation.
    private func setupAudio() {
        // Configure audio session for playback
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
            return
        }

        let engine = AVAudioEngine()
        let mainMixer = engine.mainMixerNode
        let format = mainMixer.outputFormat(forBus: 0)

        let sampleRate = format.sampleRate

        // Create a source node that generates sine wave audio
        let source = AVAudioSourceNode { [self] _, _, frameCount, audioBufferList -> OSStatus in
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)

            // Silence when velocity is effectively zero
            guard abs(velocity) > 0.01 else {
                for buffer in ablPointer {
                    let buf: UnsafeMutableBufferPointer<Float> = UnsafeMutableBufferPointer(buffer)
                    for frame in 0..<Int(frameCount) {
                        buf[frame] = 0.0
                    }
                }
                return noErr
            }

            // Linear frequency mapping: velocity 0-25 maps to 0-4000 Hz
            // Velocity is capped at 25 maximum
            let clampedVelocity = min(abs(velocity), 25.0)
            let frequency = (clampedVelocity / 25.0) * 4000.0
            let amplitude: Float = 0.15 // Keep volume moderate

            for frame in 0..<Int(frameCount) {
                // Generate sine wave sample
                let value = sin(phase * 2.0 * .pi) * Double(amplitude)
                phase += frequency / sampleRate
                if phase >= 1.0 {
                    phase -= 1.0
                }

                // Write to all channels
                for buffer in ablPointer {
                    let buf: UnsafeMutableBufferPointer<Float> = UnsafeMutableBufferPointer(buffer)
                    buf[frame] = Float(value)
                }
            }

            return noErr
        }

        engine.attach(source)
        engine.connect(source, to: mainMixer, format: format)

        self.audioEngine = engine
        self.sourceNode = source
    }

    /// Starts the audio engine.
    private func startAudio() {
        guard let engine = audioEngine else { return }

        do {
            try engine.start()
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }

    /// Stops the audio engine.
    private func stopAudio() {
        audioEngine?.stop()

        // Deactivate audio session
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            print("Failed to deactivate audio session: \(error)")
        }
    }

    /// Handles drag gesture changes to apply acceleration based on swipe.
    private func handleDragChanged(value: DragGesture.Value, geometry: GeometryProxy) {
        guard !isRepositioning else { return }
        let currentTime = Date()
        let currentPosition = value.location

        // Calculate movement since last position
        if let lastPos = lastDragPosition, let lastTime = lastDragTime {
            let deltaTime = currentTime.timeIntervalSince(lastTime)
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            updateVelocityFromSwipe(
                from: lastPos,
                to: currentPosition,
                center: center,
                deltaTime: deltaTime
            )
        }

        lastDragPosition = currentPosition
        lastDragTime = currentTime
    }

    /// Handles drag gesture end to clean up tracking.
    private func handleDragEnded(value: DragGesture.Value, geometry: GeometryProxy) {
        lastDragPosition = nil
        lastDragTime = nil
    }

    /// Gesture: long-press the center dot to enter repositioning mode, then drag to move.
    private var repositionGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.3)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .global))
            .onChanged { value in
                switch value {
                case .first(true):
                    if !isRepositioning {
                        beginReposition()
                    }
                case .second(true, let drag):
                    if !isRepositioning {
                        beginReposition()
                    }
                    if let drag = drag {
                        position = CGPoint(
                            x: repositionStartPosition.x + drag.translation.width,
                            y: repositionStartPosition.y + drag.translation.height
                        )
                    }
                default:
                    break
                }
            }
            .onEnded { _ in
                endReposition()
            }
    }

    /// Enters repositioning mode: captures starting position, fires haptic, briefly pulses
    /// the emitter outward, then settles back to its normal size for the drag.
    private func beginReposition() {
        isRepositioning = true
        repositionStartPosition = position
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        #endif
        withAnimation(.easeOut(duration: 0.15)) {
            pulseScale = 1.25
        }
        withAnimation(.easeIn(duration: 0.25).delay(0.15)) {
            pulseScale = 1.0
        }
    }

    /// Exits repositioning mode and returns the center dot to its resting scale.
    private func endReposition() {
        isRepositioning = false
        withAnimation(.easeInOut(duration: 0.2)) {
            pulseScale = 1.0
        }
    }



    /// Updates velocity by applying swipe speed as angular acceleration.
    /// Swipe velocity controls the rate of change of the emitter's angular velocity,
    /// keeping continuous motion while small swipes create small velocity changes.
    private func updateVelocityFromSwipe(from: CGPoint, to: CGPoint, center: CGPoint, deltaTime: TimeInterval) {
        // Vector from center to touch point (average of from and to)
        let midPoint = CGPoint(x: (from.x + to.x) / 2, y: (from.y + to.y) / 2)
        let radialVector = CGPoint(x: midPoint.x - center.x, y: midPoint.y - center.y)
        let radius = hypot(radialVector.x, radialVector.y)

        guard radius > 1 else { return } // Avoid division by zero

        // Velocity vector of the touch
        let velocityVector = CGPoint(
            x: (to.x - from.x) / deltaTime,
            y: (to.y - from.y) / deltaTime
        )

        // Calculate tangential component of velocity (perpendicular to radial direction)
        // Tangential direction is perpendicular to radial: (-radialY, radialX) normalized
        let tangentialDir = CGPoint(x: -radialVector.y / radius, y: radialVector.x / radius)

        // Project velocity vector onto tangential direction (dot product)
        let tangentialSpeed = velocityVector.x * tangentialDir.x + velocityVector.y * tangentialDir.y

        // Convert tangential speed to angular acceleration (radians per second²)
        let angularAcceleration = tangentialSpeed / radius

        // Apply swipe speed as acceleration to the current velocity
        // Scale factor controls responsiveness to swipe
        let accelerationScale: CGFloat = 0.5
        let acceleration = angularAcceleration * accelerationScale
        velocity += acceleration * CGFloat(deltaTime)

        // Cap velocity at maximum of 25
        velocity = max(-25, min(25, velocity))
    }
}

#Preview {
    Emitter(
        radius: 50,
        color: .red,
        highlightColor: .orange
    )
    .background(.black)
}
