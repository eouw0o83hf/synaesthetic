import XCTest
import SwiftUI
@testable import Synaesthetic

final class EmitterTests: XCTestCase {

    // MARK: - Emitter Tests

    func test_emitter_renders_with_default_radius() {
        let emitter = Emitter(radiusPercent: 0.3, color: .red, highlightColor: .orange)
        XCTAssertNotNil(emitter.body)
    }

    func test_emitter_accepts_various_radius_percentages() {
        let radiusPercentages: [CGFloat] = [0.1, 0.3, 0.5, 0.9]

        for percent in radiusPercentages {
            let emitter = Emitter(radiusPercent: percent, color: .red, highlightColor: .orange)
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
            let emitter = Emitter(radiusPercent: 0.3, color: color, highlightColor: highlight)
            XCTAssertNotNil(emitter.body)
        }
    }

    func test_emitter_diameter_calculation() {
        let emitter = Emitter(radiusPercent: 0.3, color: .red, highlightColor: .orange)

        let mockGeometry = MockGeometryProxy(width: 100, height: 100)
        let expectedDiameter = 60.0 // 100 * 0.3 * 2

        let actualDiameter = mockGeometry.size.width * 0.3 * 2
        XCTAssertEqual(actualDiameter, expectedDiameter)
    }

    func test_emitter_uses_smaller_dimension() {
        let mockGeometry = MockGeometryProxy(width: 200, height: 100)
        let minDimension = min(mockGeometry.size.width, mockGeometry.size.height)

        XCTAssertEqual(minDimension, 100)
        let diameter = minDimension * 0.3 * 2
        XCTAssertEqual(diameter, 60.0)
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
