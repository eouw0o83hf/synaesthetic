import XCTest
import SwiftUI
@testable import Synaesthetic

final class EmitterViewTests: XCTestCase {

    func test_emitter_initializes_with_default_radius() {
        let emitter = Emitter(radius: 30, color: .red, highlightColor: .orange)
        XCTAssertNotNil(emitter)
    }

    func test_emitter_accepts_various_radius_values() {
        let radii: [CGFloat] = [10, 30, 50, 90]

        for radius in radii {
            let emitter = Emitter(radius: radius, color: .red, highlightColor: .orange)
            XCTAssertNotNil(emitter)
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
            XCTAssertNotNil(emitter)
        }
    }

    func test_emitter_initializes_with_custom_velocity() {
        let emitter = Emitter(
            radius: 30,
            color: .red,
            highlightColor: .orange,
            initialVelocity: 5
        )
        XCTAssertNotNil(emitter)
    }

    func test_emitter_initializes_with_binding() {
        let position = Binding.constant(CGPoint(x: 100, y: 100))
        let emitter = Emitter(
            radius: 30,
            color: .red,
            highlightColor: .orange,
            position: position
        )
        XCTAssertNotNil(emitter)
    }
}
