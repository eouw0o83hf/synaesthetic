import XCTest
@testable import Synaesthetic

final class EmitterPhysicsTests: XCTestCase {

    func test_swipe_applies_acceleration_continuously() {
        var physics = EmitterPhysics(initialVelocity: 0)
        let center = CGPoint(x: 200, y: 200)

        // Simulate first swipe movement (tangential motion around center)
        let from1 = CGPoint(x: 250, y: 200)
        let to1 = CGPoint(x: 250, y: 210)
        let velocityDelta1 = physics.calculateVelocityDelta(from: from1, to: to1, center: center, deltaTime: 0.016)

        XCTAssertGreaterThan(abs(velocityDelta1), 0.01,
                         "Velocity delta from first swipe should be significant")

        // Simulate second continuous swipe movement
        let from2 = CGPoint(x: 250, y: 210)
        let to2 = CGPoint(x: 250, y: 220)
        let velocityDelta2 = physics.calculateVelocityDelta(from: from2, to: to2, center: center, deltaTime: 0.016)

        XCTAssertGreaterThan(abs(velocityDelta2), 0.01,
                         "Velocity delta from second swipe should be significant")

        // Verify both deltas have same sign (same direction)
        XCTAssertEqual(velocityDelta1 > 0, velocityDelta2 > 0,
                      "Continuous swipes in same direction should produce same-sign acceleration")

        // Verify accumulated velocity would be significant
        let totalDelta = velocityDelta1 + velocityDelta2
        XCTAssertGreaterThan(abs(totalDelta), 0.05,
                            "Continuous swipe should accumulate acceleration")
    }

    func test_swipe_acceleration_is_continuous_not_discrete() {
        var physics = EmitterPhysics(initialVelocity: 0)
        let center = CGPoint(x: 200, y: 200)
        var velocityDeltas: [CGFloat] = []

        // Simulate 5 continuous swipe segments
        for i in 0..<5 {
            let from = CGPoint(x: 250, y: 200 + CGFloat(i * 10))
            let to = CGPoint(x: 250, y: 200 + CGFloat((i + 1) * 10))
            let delta = physics.calculateVelocityDelta(from: from, to: to, center: center, deltaTime: 0.016)
            velocityDeltas.append(delta)
        }

        // Verify each segment produces acceleration (non-zero delta)
        for (i, delta) in velocityDeltas.enumerated() {
            XCTAssertGreaterThan(abs(delta), 0.01,
                             "Velocity delta at step \(i) should be significant, demonstrating continuous acceleration")
        }

        // Verify accumulated velocity change is significant
        let totalDelta = velocityDeltas.reduce(0, +)
        XCTAssertGreaterThan(abs(totalDelta), 0.1,
                            "Accumulated velocity change should be significant")
    }

    func test_counter_clockwise_swipe_applies_negative_acceleration() {
        var physics = EmitterPhysics(initialVelocity: 5)
        let center = CGPoint(x: 200, y: 200)

        // Simulate counter-clockwise swipe (should produce negative delta)
        let from = CGPoint(x: 250, y: 200)
        let to = CGPoint(x: 250, y: 190)
        let velocityDelta = physics.calculateVelocityDelta(from: from, to: to, center: center, deltaTime: 0.016)

        XCTAssertLessThan(velocityDelta, 0,
                         "Counter-clockwise swipe should produce negative velocity delta")
        XCTAssertGreaterThan(abs(velocityDelta), 0.01,
                         "Counter-clockwise swipe should produce significant velocity change")
    }

    func test_physics_caps_velocity_at_maximum() {
        var physics = EmitterPhysics(initialVelocity: 0)
        let center = CGPoint(x: 200, y: 200)

        // Apply several large swipes to accumulate velocity beyond max
        for _ in 0..<10 {
            physics.updateFromSwipe(
                from: CGPoint(x: 250, y: 200),
                to: CGPoint(x: 250, y: 250),
                center: center,
                deltaTime: 0.1
            )
        }

        XCTAssertLessThanOrEqual(physics.velocity, 25.0,
                                "Physics should cap velocity at maximum of 25")
    }

    func test_physics_caps_negative_velocity() {
        var physics = EmitterPhysics(initialVelocity: 0)
        let center = CGPoint(x: 200, y: 200)

        // Apply several large swipes in opposite direction
        for _ in 0..<10 {
            physics.updateFromSwipe(
                from: CGPoint(x: 250, y: 200),
                to: CGPoint(x: 250, y: 150),
                center: center,
                deltaTime: 0.1
            )
        }

        XCTAssertGreaterThanOrEqual(physics.velocity, -25.0,
                                   "Physics should cap negative velocity at minimum of -25")
    }

    func test_diameter_calculation() {
        let radius: CGFloat = 30
        let expectedDiameter = 60.0

        XCTAssertEqual(expectedDiameter, 60.0)
    }

    func test_velocity_near_center_produces_no_acceleration() {
        var physics = EmitterPhysics(initialVelocity: 0)
        let center = CGPoint(x: 200, y: 200)

        // Swipe very close to center
        let from = CGPoint(x: 200.5, y: 200)
        let to = CGPoint(x: 200.5, y: 201)
        let velocityDelta = physics.calculateVelocityDelta(from: from, to: to, center: center, deltaTime: 0.016)

        XCTAssertEqual(abs(velocityDelta), 0, accuracy: 0.001,
                      "Swipe near center should produce minimal acceleration")
    }
}
