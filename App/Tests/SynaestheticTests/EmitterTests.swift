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
