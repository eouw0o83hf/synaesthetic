import Foundation

struct EmitterPhysics {
    private static let accelerationScale: CGFloat = 0.5
    private static let velocityMax: CGFloat = 25

    var velocity: CGFloat

    init(initialVelocity: CGFloat = 1) {
        self.velocity = initialVelocity
    }

    mutating func updateFromSwipe(from: CGPoint, to: CGPoint, center: CGPoint, deltaTime: TimeInterval) {
        let velocityDelta = calculateVelocityDelta(from: from, to: to, center: center, deltaTime: deltaTime)
        velocity += velocityDelta
        velocity = max(-Self.velocityMax, min(Self.velocityMax, velocity))
    }

    func calculateVelocityDelta(from: CGPoint, to: CGPoint, center: CGPoint, deltaTime: TimeInterval) -> CGFloat {
        let midPoint = CGPoint(x: (from.x + to.x) / 2, y: (from.y + to.y) / 2)
        let radialVector = CGPoint(x: midPoint.x - center.x, y: midPoint.y - center.y)
        let radius = hypot(radialVector.x, radialVector.y)

        guard radius > 1 else { return 0 }

        let velocityVector = CGPoint(
            x: (to.x - from.x) / deltaTime,
            y: (to.y - from.y) / deltaTime
        )

        let tangentialDir = CGPoint(x: -radialVector.y / radius, y: radialVector.x / radius)
        let tangentialSpeed = velocityVector.x * tangentialDir.x + velocityVector.y * tangentialDir.y
        let angularAcceleration = tangentialSpeed / radius
        let acceleration = angularAcceleration * Self.accelerationScale

        return acceleration * CGFloat(deltaTime)
    }
}
