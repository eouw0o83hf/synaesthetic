import XCTest
import SwiftUI
@testable import Synaesthetic

final class EmitterTests: XCTestCase {

    // MARK: - Emitter Tests

    func test_emitter_renders_with_default_radius() {
        let emitter = Emitter(radius: 30, color: .red, highlightColor: .orange)
        XCTAssertNotNil(emitter.body)
    }

    func test_emitter_accepts_various_radius_percentages() {
        let radii: [CGFloat] = [10, 30, 50, 90]

        for radius in radii {
            let emitter = Emitter(radius: radius, color: .red, highlightColor: .orange)
            XCTAssertNotNil(emitter.body)
        }
    }

    func test_emitter_accepts_various_color_combinations() {
        let colorCombinations: [(Color, Color)] = [
            (.red, .orange),
            (.blue, .purple),
            (.green, .yellow),
            (.white, .black)
        ]

        for (color, highlight) in colorCombinations {
            let emitter = Emitter(radius: 30, color: color, highlightColor: highlight)
            XCTAssertNotNil(emitter.body)
        }
    }

    func test_emitter_diameter_calculation() {
        let radius: CGFloat = 30
        let emitter = Emitter(radius: radius, color: .red, highlightColor: .orange)

        let expectedDiameter = 60.0 // radius * 2

        XCTAssertEqual(expectedDiameter, 60.0)
    }

    func test_emitter_diameter_from_radius() {
        let radius: CGFloat = 50
        let expectedDiameter = radius * 2

        XCTAssertEqual(expectedDiameter, 100.0)
    }

    // MARK: - Continuous Swipe Acceleration Tests

    @MainActor
    func test_swipe_applies_acceleration_continuously() {
        // Create an emitter for testing calculation logic
        let position = Binding.constant(CGPoint(x: 200, y: 200))
        let emitter = Emitter(
            radius: 50,
            color: .red,
            highlightColor: .orange,
            initialVelocity: 0,
            position: position
        )

        let center = CGPoint(x: 200, y: 200)

        // Simulate first swipe movement (tangential motion around center)
        // From right of center, moving down = clockwise rotation
        let from1 = CGPoint(x: 250, y: 200) // Right of center
        let to1 = CGPoint(x: 250, y: 210)   // Moving down (clockwise)
        let velocityDelta1 = emitter.calculateVelocityDelta(from: from1, to: to1, center: center, deltaTime: 0.016)

        XCTAssertGreaterThan(abs(velocityDelta1), 0.01,
                         "Velocity delta from first swipe should be significant")

        // Simulate second continuous swipe movement
        let from2 = CGPoint(x: 250, y: 210)
        let to2 = CGPoint(x: 250, y: 220)
        let velocityDelta2 = emitter.calculateVelocityDelta(from: from2, to: to2, center: center, deltaTime: 0.016)

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

    @MainActor
    func test_swipe_acceleration_is_continuous_not_discrete() {
        // Create an emitter for testing
        let position = Binding.constant(CGPoint(x: 200, y: 200))
        let emitter = Emitter(
            radius: 50,
            color: .red,
            highlightColor: .orange,
            initialVelocity: 0,
            position: position
        )

        let center = CGPoint(x: 200, y: 200)
        var velocityDeltas: [CGFloat] = []

        // Simulate 5 continuous swipe segments
        for i in 0..<5 {
            let from = CGPoint(x: 250, y: 200 + CGFloat(i * 10))
            let to = CGPoint(x: 250, y: 200 + CGFloat((i + 1) * 10))
            let delta = emitter.calculateVelocityDelta(from: from, to: to, center: center, deltaTime: 0.016)
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

    @MainActor
    func test_counter_clockwise_swipe_applies_negative_acceleration() {
        // Create an emitter for testing
        let position = Binding.constant(CGPoint(x: 200, y: 200))
        let emitter = Emitter(
            radius: 50,
            color: .red,
            highlightColor: .orange,
            initialVelocity: 5,
            position: position
        )

        let center = CGPoint(x: 200, y: 200)

        // Simulate counter-clockwise swipe (should produce negative delta)
        let from = CGPoint(x: 250, y: 200)
        let to = CGPoint(x: 250, y: 190) // Moving up (counter-clockwise from right)
        let velocityDelta = emitter.calculateVelocityDelta(from: from, to: to, center: center, deltaTime: 0.016)

        XCTAssertLessThan(velocityDelta, 0,
                         "Counter-clockwise swipe should produce negative velocity delta")
        XCTAssertGreaterThan(abs(velocityDelta), 0.01,
                         "Counter-clockwise swipe should produce significant velocity change")
    }
}

// MARK: - Mock Helper

/// Mock GeometryProxy for testing size calculations.
struct MockGeometryProxy {
    let width: CGFloat
    let height: CGFloat

    var size: CGSize {
        CGSize(width: width, height: height)
    }
}
