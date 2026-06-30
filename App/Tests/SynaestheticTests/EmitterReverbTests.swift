import XCTest
@testable import Synaesthetic

final class EmitterReverbTests: XCTestCase {

    func test_amount_zero_has_no_blur() {
        let reverb = EmitterReverb(amount: 0)
        XCTAssertEqual(reverb.blurRadius, 0)
    }

    func test_amount_one_has_max_blur() {
        let reverb = EmitterReverb(amount: 1)
        XCTAssertEqual(reverb.blurRadius, 30, accuracy: 0.001)
    }

    func test_blur_radius_scales_linearly_with_amount() {
        let reverb = EmitterReverb(amount: 0.5)
        XCTAssertEqual(reverb.blurRadius, 15, accuracy: 0.001)
    }

    func test_amount_zero_has_no_wet_mix() {
        let reverb = EmitterReverb(amount: 0)
        XCTAssertEqual(reverb.wetDryMix, 0, accuracy: 0.001)
    }

    func test_amount_one_has_max_wet_mix() {
        let reverb = EmitterReverb(amount: 1)
        XCTAssertEqual(reverb.wetDryMix, 80, accuracy: 0.001)
    }

    func test_wet_dry_mix_scales_linearly_with_amount() {
        let reverb = EmitterReverb(amount: 0.5)
        XCTAssertEqual(reverb.wetDryMix, 40, accuracy: 0.001)
    }

    func test_random_amount_within_bounds() {
        for _ in 0..<100 {
            let reverb = EmitterReverb.random()
            XCTAssertGreaterThanOrEqual(reverb.amount, 0)
            XCTAssertLessThanOrEqual(reverb.amount, 1)
        }
    }

    func test_blur_radius_never_negative() {
        let reverb = EmitterReverb(amount: 0)
        XCTAssertGreaterThanOrEqual(reverb.blurRadius, 0)
    }

    func test_blur_and_wet_mix_proportional() {
        let reverb = EmitterReverb(amount: 0.25)
        XCTAssertEqual(Double(reverb.blurRadius) / 30.0, Double(reverb.wetDryMix) / 80.0, accuracy: 0.001)
    }
}
