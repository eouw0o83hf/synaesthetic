import SwiftUI
import AVFoundation
#if canImport(UIKit)
import UIKit
#endif

/// A circle with an angular gradient that wraps around with a sharp radial edge.
/// The emitter rotates continuously at a tempo (measured in radians per second).
/// The tempo is a harmonic multiple of 60 BPM and drives both the visual rotation
/// speed and the audio pitch.
struct Emitter: View {
    /// Radius of the handle (solid center circle) used to reposition the emitter. The emitter's
    /// frame will never shrink below this handle's diameter.
    static let handleRadius: CGFloat = 15

    /// Distance from the bottom edge of the screen that triggers deletion when dragging.
    static let deleteZoneInset: CGFloat = 10

    /// The initial radius in pixels.
    let initialRadius: CGFloat

    /// The current radius in pixels, modified by pinch/spread gestures.
    @State var radius: CGFloat

    /// The starting color of the gradient.
    let color: Color

    /// The highlight color that the gradient fades to.
    let highlightColor: Color

    /// The initial tempo in radians per second (harmonic multiple of 60 BPM).
    /// Drives both the visual rotation speed and the audio pitch.
    let initialVelocity: CGFloat

    /// The reverb effect applied to this emitter (audio + visual).
    let reverb: EmitterReverb

    /// The delay effect applied to this emitter: echoes each ping after `delay.period` seconds.
    let delay: EmitterDelay

    /// The emitter's position on screen. Updated while repositioning.
    @Binding var position: CGPoint

    /// Screen height used to determine the delete zone threshold.
    let screenHeight: CGFloat

    /// Set to true while this emitter is being repositioned, false otherwise.
    @Binding var externalIsDragging: Bool

    /// Set to true while this emitter is in the delete zone during repositioning.
    @Binding var externalIsInDeleteZone: Bool

    /// Called when this emitter is dragged into the delete zone and released.
    let onDelete: (() -> Void)?

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

    /// EQ node for equal loudness curve.
    @State private var eqNode: AVAudioUnitEQ?

    /// Current phase of the audio waveform.
    @State private var phase: Double = 0

    /// Pitch frequency fixed at instantiation from the initial velocity.
    @State private var fixedFrequency: Double = 440

    /// Incremented on the main thread each time the emitter crosses position 0.
    @State private var beepTrigger: Int = 0

    /// Sample rate stored from the audio engine for use in the rotation timer.
    @State private var audioSampleRate: Double = 44100

    /// Animated blur radius for the reverb halo — pulses to reverb.blurRadius on each ping then decays to zero.
    @State private var currentBlurRadius: CGFloat = 0

    init(
        radius: CGFloat,
        color: Color,
        highlightColor: Color,
        initialVelocity: CGFloat = 1,
        reverb: EmitterReverb = EmitterReverb(amount: 0),
        delay: EmitterDelay = EmitterDelay(period: 0),
        position: Binding<CGPoint> = .constant(.zero),
        screenHeight: CGFloat = 0,
        isDragging: Binding<Bool> = .constant(false),
        isInDeleteZone: Binding<Bool> = .constant(false),
        onDelete: (() -> Void)? = nil
    ) {
        self.initialRadius = radius
        self._radius = State(initialValue: radius)
        self._baseRadius = State(initialValue: radius)
        self.color = color
        self.highlightColor = highlightColor
        self.initialVelocity = initialVelocity
        self.reverb = reverb
        self.delay = delay
        self._position = position
        self.screenHeight = screenHeight
        self._externalIsDragging = isDragging
        self._externalIsInDeleteZone = isInDeleteZone
        self.onDelete = onDelete
        self._physics = State(initialValue: EmitterPhysics(initialVelocity: initialVelocity))
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if reverb.amount > 0 {
                    Circle()
                        .fill(
                            AngularGradient(
                                colors: [color, highlightColor],
                                center: .center
                            )
                        )
                        .frame(width: radius * 2, height: radius * 2)
                        .rotationEffect(.radians(rotation))
                        .blur(radius: currentBlurRadius)
                        .opacity(0.9)
                        .scaleEffect(pulseScale)
                        .allowsHitTesting(false)
                }

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
        .onChange(of: beepTrigger) { _, _ in
            currentBlurRadius = reverb.blurRadius
            withAnimation(.linear(duration: 0.08 * 3)) {
                currentBlurRadius = 0
            }
        }
    }

    /// Calculates the diameter (2x radius) in pixels.
    private func calculateDiameter(for geometry: GeometryProxy) -> CGFloat {
        return radius * 2
    }

    /// Starts the continuous rotation animation based on velocity.
    private func startRotation() {
        Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
            let prevCycle = Int(floor(rotation / (2.0 * .pi)))
            rotation += physics.velocity / 60.0
            let currCycle = Int(floor(rotation / (2.0 * .pi)))
            if prevCycle != currCycle {
                beepTrigger += 1
                if delay.period > 0 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay.period) {
                        beepTrigger += 1
                    }
                }
            }
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
        audioSampleRate = sampleRate

        // Pitch is derived from the initial velocity and never changes.
        let clampedVelocity = min(abs(initialVelocity), 25.0)
        fixedFrequency = (clampedVelocity / 25.0) * 4000.0

        // Beep duration: ~80 ms
        let beepDurationSamples = Int(sampleRate * 0.08)

        // These locals are only ever accessed from the audio thread.
        var lastSeenTrigger = 0
        var beepSamplesRemaining = 0

        let source = AVAudioSourceNode { [self] _, _, frameCount, audioBufferList -> OSStatus in
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)

            // Start a new beep if the main thread signalled a zero-crossing.
            let currentTrigger = beepTrigger
            if currentTrigger > lastSeenTrigger {
                lastSeenTrigger = currentTrigger
                beepSamplesRemaining = beepDurationSamples
                phase = 0.0
            }

            let excessRadius = max(0, radius - Emitter.handleRadius)
            let amplitude = min(Float(excessRadius * 0.001), 0.15)

            for frame in 0..<Int(frameCount) {
                let sample: Float
                if beepSamplesRemaining > 0 {
                    // Linear fade-out envelope over the beep duration
                    let envelope = Float(beepSamplesRemaining) / Float(beepDurationSamples)
                    sample = Float(sin(phase * 2.0 * .pi)) * amplitude * envelope
                    phase += fixedFrequency / sampleRate
                    if phase >= 1.0 { phase -= 1.0 }
                    beepSamplesRemaining -= 1
                } else {
                    sample = 0.0
                }

                for buffer in ablPointer {
                    let buf: UnsafeMutableBufferPointer<Float> = UnsafeMutableBufferPointer(buffer)
                    buf[frame] = sample
                }
            }

            return noErr
        }

        engine.attach(source)

        let reverbNode = AVAudioUnitReverb()
        let reverbPreset: AVAudioUnitReverbPreset
        switch reverb.amount {
        case ..<0.33: reverbPreset = .smallRoom
        case ..<0.67: reverbPreset = .mediumHall
        default:      reverbPreset = .cathedral
        }
        reverbNode.loadFactoryPreset(reverbPreset)
        reverbNode.wetDryMix = reverb.wetDryMix
        engine.attach(reverbNode)

        let eq = EmitterEqualLoudness.createEQNode()
        engine.attach(eq)

        engine.connect(source, to: reverbNode, format: format)
        engine.connect(reverbNode, to: eq, format: format)
        engine.connect(eq, to: mainMixer, format: format)

        self.audioEngine = engine
        self.sourceNode = source
        self.eqNode = eq
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
                    let newPosition = CGPoint(
                        x: repositionStartPosition.x + value.translation.width,
                        y: repositionStartPosition.y + value.translation.height
                    )
                    position = newPosition
                    if screenHeight > 0 {
                        externalIsInDeleteZone = newPosition.y > screenHeight - Emitter.deleteZoneInset
                    }
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
        externalIsDragging = true
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

    /// Exits repositioning mode: resets external state, then deletes if in the delete zone.
    private func endReposition() {
        isRepositioning = false
        let shouldDelete = externalIsInDeleteZone
        externalIsDragging = false
        externalIsInDeleteZone = false
        withAnimation(.easeInOut(duration: 0.2)) {
            pulseScale = 1.0
        }
        if shouldDelete {
            onDelete?()
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
