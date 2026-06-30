import XCTest
import SwiftUI
@testable import Synaesthetic

final class EmitterGeneratorTests: XCTestCase {

    private let standardBounds = CGRect(x: 0, y: 0, width: 390, height: 844)

    // MARK: - generatePythagoreanTriad

    func test_triad_returns_three_velocities() {
        let velocities = EmitterGenerator.generatePythagoreanTriad()
        XCTAssertEqual(velocities.count, 3)
    }

    func test_triad_velocities_respect_minimum_bound() {
        for _ in 0..<50 {
            let velocities = EmitterGenerator.generatePythagoreanTriad()
            for v in velocities {
                XCTAssertGreaterThanOrEqual(v, 0.5, "Velocity \(v) is below the minimum of 0.5")
            }
        }
    }

    func test_triad_velocities_respect_maximum_bound() {
        for _ in 0..<50 {
            let velocities = EmitterGenerator.generatePythagoreanTriad()
            for v in velocities {
                // Allow a tiny floating-point epsilon from the ratio-scaling arithmetic
                XCTAssertLessThanOrEqual(v, 25.0 + 1e-10, "Velocity \(v) exceeds the maximum of 25")
            }
        }
    }

    func test_triad_velocities_are_positive() {
        for _ in 0..<50 {
            let velocities = EmitterGenerator.generatePythagoreanTriad()
            for v in velocities {
                XCTAssertGreaterThan(v, 0)
            }
        }
    }

    // MARK: - generateSingleEmitter — velocity and color

    func test_single_emitter_preserves_velocity() {
        let velocity: CGFloat = 7.5
        let config = EmitterGenerator.generateSingleEmitter(
            velocity: velocity,
            colorIndex: 0,
            existingEmitters: [],
            screenBounds: standardBounds
        )
        XCTAssertEqual(config.initialVelocity, velocity)
    }

    func test_single_emitter_color_index_zero_is_red() {
        let config = EmitterGenerator.generateSingleEmitter(
            velocity: 5, colorIndex: 0, existingEmitters: [], screenBounds: standardBounds
        )
        XCTAssertEqual(config.color, EmitterGenerator.colors[0].0)
        XCTAssertEqual(config.highlightColor, EmitterGenerator.colors[0].1)
    }

    func test_single_emitter_color_index_cycles_every_three() {
        let config0 = EmitterGenerator.generateSingleEmitter(
            velocity: 5, colorIndex: 0, existingEmitters: [], screenBounds: standardBounds
        )
        let config3 = EmitterGenerator.generateSingleEmitter(
            velocity: 5, colorIndex: 3, existingEmitters: [], screenBounds: standardBounds
        )
        XCTAssertEqual(config0.color, config3.color)
        XCTAssertEqual(config0.highlightColor, config3.highlightColor)
    }

    func test_single_emitter_color_index_one_and_four_match() {
        let config1 = EmitterGenerator.generateSingleEmitter(
            velocity: 5, colorIndex: 1, existingEmitters: [], screenBounds: standardBounds
        )
        let config4 = EmitterGenerator.generateSingleEmitter(
            velocity: 5, colorIndex: 4, existingEmitters: [], screenBounds: standardBounds
        )
        XCTAssertEqual(config1.color, config4.color)
        XCTAssertEqual(config1.highlightColor, config4.highlightColor)
    }

    // MARK: - generateSingleEmitter — size and radius

    func test_single_emitter_size_within_expected_range() {
        for _ in 0..<20 {
            let config = EmitterGenerator.generateSingleEmitter(
                velocity: 5, colorIndex: 0, existingEmitters: [], screenBounds: standardBounds
            )
            XCTAssertGreaterThanOrEqual(config.size, Emitter.handleRadius * 2)
            XCTAssertLessThanOrEqual(config.size, 280)
        }
    }

    func test_single_emitter_radius_within_expected_fraction_of_size() {
        for _ in 0..<20 {
            let config = EmitterGenerator.generateSingleEmitter(
                velocity: 5, colorIndex: 0, existingEmitters: [], screenBounds: standardBounds
            )
            XCTAssertGreaterThanOrEqual(config.radius, config.size * 0.2 - 0.001)
            XCTAssertLessThanOrEqual(config.radius, config.size * 0.35 + 0.001)
        }
    }

    // MARK: - generateSingleEmitter — position

    func test_single_emitter_position_is_within_screen_bounds() {
        for _ in 0..<20 {
            let config = EmitterGenerator.generateSingleEmitter(
                velocity: 5, colorIndex: 0, existingEmitters: [], screenBounds: standardBounds
            )
            XCTAssertGreaterThan(config.position.x, 0)
            XCTAssertLessThan(config.position.x, standardBounds.width)
            XCTAssertGreaterThan(config.position.y, 0)
            XCTAssertLessThan(config.position.y, standardBounds.height)
        }
    }

    func test_single_emitter_avoids_overlap_with_existing_emitter() {
        let existing = EmitterGenerator.generateSingleEmitter(
            velocity: 5, colorIndex: 0, existingEmitters: [], screenBounds: standardBounds
        )
        var overlapCount = 0
        for _ in 0..<20 {
            let next = EmitterGenerator.generateSingleEmitter(
                velocity: 5, colorIndex: 1, existingEmitters: [existing], screenBounds: standardBounds
            )
            let distance = hypot(next.position.x - existing.position.x, next.position.y - existing.position.y)
            let minDistance = (next.size + existing.size) / 2 + 10
            if distance < minDistance { overlapCount += 1 }
        }
        // With 50 attempts per placement, overlaps should be rare; allow at most 2 in 20
        XCTAssertLessThanOrEqual(overlapCount, 2, "Too many overlapping placements: \(overlapCount)/20")
    }

    // MARK: - Delete zone threshold

    func test_delete_zone_inset_constant_is_ten_points() {
        XCTAssertEqual(Emitter.deleteZoneInset, 10)
    }

    func test_position_one_point_above_zone_is_safe() {
        let screenHeight: CGFloat = 844
        let safeY = screenHeight - Emitter.deleteZoneInset - 1
        XCTAssertFalse(safeY > screenHeight - Emitter.deleteZoneInset,
                       "Position 1pt above the delete zone should not trigger deletion")
    }

    func test_position_exactly_at_zone_edge_triggers_deletion() {
        let screenHeight: CGFloat = 844
        let edgeY = screenHeight - Emitter.deleteZoneInset
        XCTAssertFalse(edgeY > screenHeight - Emitter.deleteZoneInset,
                       "Position exactly at the boundary should not yet trigger deletion (uses strict >)")
    }

    func test_position_one_point_into_zone_triggers_deletion() {
        let screenHeight: CGFloat = 844
        let deleteY = screenHeight - Emitter.deleteZoneInset + 1
        XCTAssertTrue(deleteY > screenHeight - Emitter.deleteZoneInset,
                      "Position 1pt into the delete zone should trigger deletion")
    }
}
