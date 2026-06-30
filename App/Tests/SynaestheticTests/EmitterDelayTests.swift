import XCTest
@testable import Synaesthetic

final class EmitterDelayTests: XCTestCase {

    func test_period_zero_means_no_delay() {
        let delay = EmitterDelay(period: 0)
        XCTAssertEqual(delay.period, 0)
    }

    func test_period_stored_correctly() {
        let delay = EmitterDelay(period: 0.4)
        XCTAssertEqual(delay.period, 0.4, accuracy: 0.0001)
    }

    func test_random_period_within_bounds() {
        for _ in 0..<100 {
            let delay = EmitterDelay.random()
            XCTAssertGreaterThanOrEqual(delay.period, 0.1)
            XCTAssertLessThanOrEqual(delay.period, 0.8)
        }
    }

    func test_random_period_never_zero() {
        for _ in 0..<100 {
            let delay = EmitterDelay.random()
            XCTAssertGreaterThan(delay.period, 0)
        }
    }

    func test_random_produces_varied_periods() {
        let periods = (0..<20).map { _ in EmitterDelay.random().period }
        let unique = Set(periods)
        XCTAssertGreaterThan(unique.count, 1)
    }

    func test_period_is_immutable_by_design() {
        let delay = EmitterDelay(period: 0.5)
        // Verify the period cannot be reassigned — type is a let constant.
        // This test documents the contract: period is seeded once and never changes.
        XCTAssertEqual(delay.period, 0.5)
    }

    func test_config_includes_delay() {
        let delay = EmitterDelay(period: 0.3)
        let config = EmitterConfig(
            radius: 100,
            color: .red,
            highlightColor: .orange,
            initialVelocity: 1,
            size: 200,
            position: .zero,
            delay: delay
        )
        XCTAssertEqual(config.delay.period, 0.3, accuracy: 0.0001)
    }

    func test_config_default_delay_period_is_zero() {
        let config = EmitterConfig(
            radius: 100,
            color: .red,
            highlightColor: .orange,
            initialVelocity: 1,
            size: 200,
            position: .zero
        )
        XCTAssertEqual(config.delay.period, 0)
    }

    func test_generator_seeds_random_delay() {
        let screenBounds = CGRect(x: 0, y: 0, width: 390, height: 844)
        var periods: [TimeInterval] = []
        for _ in 0..<10 {
            let config = EmitterGenerator.generateSingleEmitter(
                velocity: EmitterGenerator.tempoToVelocity(120),
                existingEmitters: [],
                screenBounds: screenBounds
            )
            XCTAssertGreaterThanOrEqual(config.delay.period, 0.1)
            XCTAssertLessThanOrEqual(config.delay.period, 0.8)
            periods.append(config.delay.period)
        }
        let unique = Set(periods)
        XCTAssertGreaterThan(unique.count, 1, "delay periods should vary across emitters")
    }
}
