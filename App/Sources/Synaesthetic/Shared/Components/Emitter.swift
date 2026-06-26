import SwiftUI

/// A circle with an angular gradient that wraps around with a sharp radial edge.
/// The radius is a percentage of the smaller screen dimension.
/// The emitter rotates continuously at a velocity measured in radians per second.
struct Emitter: View {
    /// The radius as a percentage of the smaller screen dimension (0.0 to 1.0).
    let radiusPercent: CGFloat

    /// The starting color of the gradient.
    let color: Color

    /// The highlight color that the gradient fades to.
    let highlightColor: Color

    /// The initial velocity in radians per second. Defaults to 1.
    let initialVelocity: CGFloat

    /// The current rotational velocity in radians per second.
    @State var velocity: CGFloat

    /// The current rotation angle in radians.
    @State private var rotation: CGFloat = 0

    /// Tracks the last drag position for velocity calculation.
    @State private var lastDragPosition: CGPoint?

    /// Tracks the last drag time for velocity calculation.
    @State private var lastDragTime: Date?

    /// Tracks whether the touch is stationary (for braking) or moving (for acceleration).
    @State private var isStationary: Bool = false

    /// Timer for applying braking force during stationary touch.
    @State private var brakingTimer: Timer?

    init(
        radiusPercent: CGFloat,
        color: Color,
        highlightColor: Color,
        initialVelocity: CGFloat = 1
    ) {
        self.radiusPercent = radiusPercent
        self.color = color
        self.highlightColor = highlightColor
        self.initialVelocity = initialVelocity
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
        .onAppear {
            startRotation()
        }
    }

    /// Calculates the diameter (2x radius) based on the radius percentage.
    private func calculateDiameter(for geometry: GeometryProxy) -> CGFloat {
        let minDimension = min(geometry.size.width, geometry.size.height)
        return minDimension * radiusPercent * 2
    }

    /// Starts the continuous rotation animation based on velocity.
    private func startRotation() {
        Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
            rotation += velocity / 60.0
        }
    }

    /// Handles drag gesture changes to detect swipes and apply acceleration or braking.
    private func handleDragChanged(value: DragGesture.Value, geometry: GeometryProxy) {
        let currentTime = Date()
        let currentPosition = value.location

        // Calculate movement since last position
        if let lastPos = lastDragPosition, let lastTime = lastDragTime {
            let deltaTime = currentTime.timeIntervalSince(lastTime)
            let distance = hypot(currentPosition.x - lastPos.x, currentPosition.y - lastPos.y)
            let speed = distance / deltaTime

            // Determine if touch is stationary (speed below threshold)
            let stationaryThreshold: CGFloat = 100 // points per second
            if speed < stationaryThreshold {
                if !isStationary {
                    isStationary = true
                    startBraking()
                }
            } else {
                // Touch is moving - directly control velocity from finger movement
                if isStationary {
                    isStationary = false
                    stopBraking()
                }

                let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                updateVelocityFromSwipe(
                    from: lastPos,
                    to: currentPosition,
                    center: center,
                    deltaTime: deltaTime
                )
            }
        }

        lastDragPosition = currentPosition
        lastDragTime = currentTime
    }

    /// Handles drag gesture end to stop braking.
    private func handleDragEnded(value: DragGesture.Value, geometry: GeometryProxy) {
        lastDragPosition = nil
        lastDragTime = nil
        isStationary = false
        stopBraking()
    }

    /// Starts applying braking force to slow down velocity.
    private func startBraking() {
        stopBraking() // Clear any existing timer

        // Apply braking at 60fps
        brakingTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
            // Braking force: reduce velocity by a percentage per frame
            // Using exponential decay: v_new = v_old * (1 - brakingRate)
            // Higher rate = faster stopping. 0.12 gives responsive braking in ~0.5 seconds
            let brakingRate: CGFloat = 0.12
            velocity *= (1 - brakingRate)

            // Stop completely if velocity is very small
            if abs(velocity) < 0.01 {
                velocity = 0
                stopBraking()
            }
        }
    }

    /// Stops the braking timer.
    private func stopBraking() {
        brakingTimer?.invalidate()
        brakingTimer = nil
    }

    /// Updates velocity to match the swipe movement, giving direct control like dragging a record.
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

        // Convert tangential speed to angular velocity (radians per second)
        let angularVelocity = tangentialSpeed / radius

        // Directly set velocity to match finger movement (with smoothing to prevent jitter)
        let smoothingFactor: CGFloat = 0.3 // Higher = more responsive, lower = smoother
        velocity = velocity * (1 - smoothingFactor) + angularVelocity * smoothingFactor
    }
}

#Preview {
    Emitter(
        radiusPercent: 0.3,
        color: .red,
        highlightColor: .orange
    )
    .background(.black)
}
