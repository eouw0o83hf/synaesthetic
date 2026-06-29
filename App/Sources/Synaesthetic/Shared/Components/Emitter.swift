import SwiftUI
import AVFoundation
#if canImport(UIKit)
import UIKit
#endif

/// A circle with an angular gradient that wraps around with a sharp radial edge.
/// The emitter rotates continuously at a velocity measured in radians per second.
struct Emitter: View {
    /// Radius of the handle (solid center circle) used to reposition the emitter. The emitter's
    /// frame will never shrink below this handle's diameter.
    static let handleRadius: CGFloat = 15

    /// The initial radius in pixels.
    let initialRadius: CGFloat

    /// The current radius in pixels, modified by pinch/spread gestures.
    @State var radius: CGFloat

    /// The starting color of the gradient.
    let color: Color

    /// The highlight color that the gradient fades to.
    let highlightColor: Color

    /// The initial velocity in radians per second. Defaults to 1.
    let initialVelocity: CGFloat

    /// The emitter's position on screen. Updated while repositioning.
    @Binding var position: CGPoint

    /// Physics engine for velocity calculations.
    @State private var physics: EmitterPhysics

    /// The current rotation angle in radians.
    @State private var rotation: CGFloat = 0

    /// Tracks the last drag position for velocity calculation.
    @State private var lastDragPosition: CGPoint?

    /// Tracks the last drag time for velocity calculation.
    @State private var lastDragTime: Date?

    /// Whether the user is currently repositioning the emitter via the handle.
    @State private var isRepositioning: Bool = false

    /// Scale factor applied to the handle for the pulse animation.
    @State private var pulseScale: CGFloat = 1.0

    /// Position captured at the moment repositioning starts.
    @State private var repositionStartPosition: CGPoint = .zero

    /// Global touch location at the moment the handle drag began.
    @State private var touchStartLocation: CGPoint = .zero

    /// Timer that fires to recognize a long press on the handle.
    @State private var longPressTimer: Timer? = nil

    /// Tracks the scale from the magnification gesture.
    @State private var magnificationScale: CGFloat = 1.0

    /// Base radius for magnification calculations, updated when gesture ends.
    @State private var baseRadius: CGFloat?

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
        self.initialRadius = radius
        self._radius = State(initialValue: radius)
        self._baseRadius = State(initialValue: radius)
        self.color = color
        self.highlightColor = highlightColor
        self.initialVelocity = initialVelocity
        self._position = position
        self._physics = State(initialValue: EmitterPhysics(initialVelocity: initialVelocity))
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
                    .frame(width: Emitter.handleRadius * 2, height: Emitter.handleRadius * 2)
                    .scaleEffect(pulseScale)
                    .gesture(repositionGesture)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .simultaneousGesture(magnificationGesture)
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
        .frame(minWidth: Emitter.handleRadius * 2, minHeight: Emitter.handleRadius * 2)
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
            rotation += physics.velocity / 60.0
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
            guard abs(physics.velocity) > 0.01 else {
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
            let clampedVelocity = min(abs(physics.velocity), 25.0)
            let frequency = (clampedVelocity / 25.0) * 4000.0

            // Linear volume mapping: size beyond handle scales amplitude linearly
            // 0px beyond handle (radius = 15) → amplitude = 0 (silent)
            // 1px beyond handle (radius = 15.5) → amplitude ≈ 0.001 (nearly inaudible)
            // Scales at 0.001 amplitude per pixel, capped at 0.15 (maximum)
            let excessRadius = max(0, radius - Emitter.handleRadius)
            let amplitude = min(Float(excessRadius * 0.001), 0.15)

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
            physics.updateFromSwipe(from: lastPos, to: currentPosition, center: center, deltaTime: deltaTime)
        }

        lastDragPosition = currentPosition
        lastDragTime = currentTime
    }

    /// Handles drag gesture end to clean up tracking.
    private func handleDragEnded(value: DragGesture.Value, geometry: GeometryProxy) {
        lastDragPosition = nil
        lastDragTime = nil
    }

    /// Gesture: drag on the handle starts a long-press timer. Once the timer fires (0.3s),
    /// repositioning mode activates and the emitter follows the finger for the rest of the drag.
    private var repositionGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { value in
                if longPressTimer == nil && !isRepositioning {
                    touchStartLocation = value.startLocation
                    longPressTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
                        beginReposition()
                    }
                }
                if isRepositioning {
                    position = CGPoint(
                        x: repositionStartPosition.x + value.translation.width,
                        y: repositionStartPosition.y + value.translation.height
                    )
                }
            }
            .onEnded { _ in
                longPressTimer?.invalidate()
                longPressTimer = nil
                if isRepositioning {
                    endReposition()
                }
            }
    }

    /// Gesture: pinch to shrink, spread to expand the emitter size.
    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { scale in
                let base = baseRadius ?? initialRadius
                let newRadius = base * scale
                let minRadius = Emitter.handleRadius
                radius = max(minRadius, newRadius)
            }
            .onEnded { _ in
                baseRadius = radius
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
        withAnimation(.easeOut(duration: 0.075)) {
            pulseScale = 1.25
        }
        withAnimation(.easeIn(duration: 0.125).delay(0.075)) {
            pulseScale = 1.0
        }
    }

    /// Exits repositioning mode and returns the handle to its resting scale.
    private func endReposition() {
        isRepositioning = false
        withAnimation(.easeInOut(duration: 0.2)) {
            pulseScale = 1.0
        }
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
