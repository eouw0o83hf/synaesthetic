import XCTest
import AVFoundation
@testable import Synaesthetic

final class EmitterEqualLoudnessTests: XCTestCase {

    // MARK: - gainForFrequency tests

    func test_gainForFrequency_at_reference_1000hz_is_zero() {
        let gain = EmitterEqualLoudness.gainForFrequency(1000)
        XCTAssertEqual(gain, 0.0, "Reference frequency (1000 Hz) should have 0 dB gain")
    }

    func test_gainForFrequency_bass_boosted() {
        // Low bass frequencies should be boosted
        let gain50Hz = EmitterEqualLoudness.gainForFrequency(50)
        let gain100Hz = EmitterEqualLoudness.gainForFrequency(100)
        let gain200Hz = EmitterEqualLoudness.gainForFrequency(200)

        XCTAssertGreaterThan(gain50Hz, 10.0, "50 Hz should have significant bass boost")
        XCTAssertGreaterThan(gain100Hz, 5.0, "100 Hz should have moderate bass boost")
        XCTAssertGreaterThanOrEqual(gain200Hz, 3.0, "200 Hz should have moderate bass boost")
    }

    func test_gainForFrequency_deep_bass_higher_than_bass() {
        let gainDeepBass = EmitterEqualLoudness.gainForFrequency(30)
        let gainBass = EmitterEqualLoudness.gainForFrequency(100)
        XCTAssertGreaterThanOrEqual(gainDeepBass, gainBass,
                                     "Deep bass (30 Hz) should have gain >= bass (100 Hz)")
    }

    func test_gainForFrequency_treble_slightly_boosted() {
        // Treble should have small positive or zero gain
        let gain8000Hz = EmitterEqualLoudness.gainForFrequency(8000)
        let gain16000Hz = EmitterEqualLoudness.gainForFrequency(16000)

        XCTAssertGreaterThanOrEqual(gain8000Hz, -1.0, "8 kHz should not have severe cut")
        XCTAssertGreaterThanOrEqual(gain16000Hz, 1.0, "16 kHz should be boosted")
    }

    func test_gainForFrequency_presence_dip() {
        // 4 kHz typically has a slight dip in equal loudness
        let gain4000Hz = EmitterEqualLoudness.gainForFrequency(4000)
        XCTAssertLessThan(gain4000Hz, 0.5, "4 kHz should be slightly cut or flat")
    }

    func test_gainForFrequency_monotonic_from_bass_to_midrange() {
        // Gain should increase as frequency rises from 50 Hz to 1000 Hz
        let gain50 = EmitterEqualLoudness.gainForFrequency(50)
        let gain200 = EmitterEqualLoudness.gainForFrequency(200)
        let gain1000 = EmitterEqualLoudness.gainForFrequency(1000)

        XCTAssertGreaterThan(gain50, gain200, "50 Hz boost > 200 Hz boost")
        XCTAssertGreaterThan(gain200, gain1000, "200 Hz boost > 1000 Hz (reference)")
    }

    // MARK: - createEQNode tests

    func test_createEQNode_returns_valid_eq() {
        let eq = EmitterEqualLoudness.createEQNode()
        XCTAssertNotNil(eq, "Should create a valid EQ node")
        // Verify we can access bands
        XCTAssertGreaterThan(eq.bands.count, 0, "EQ should have bands")
    }

    func test_createEQNode_band_frequencies_in_order() {
        let eq = EmitterEqualLoudness.createEQNode()
        let frequencies = eq.bands.map { $0.frequency }

        // Frequencies should be in ascending order
        for i in 1..<frequencies.count {
            XCTAssertGreaterThan(frequencies[i], frequencies[i - 1],
                                "Band frequencies should be in ascending order")
        }
    }

    func test_createEQNode_band0_50hz_bass_boost() {
        let eq = EmitterEqualLoudness.createEQNode()
        XCTAssertEqual(eq.bands[0].frequency, 50.0, accuracy: 0.1)
        XCTAssertEqual(eq.bands[0].gain, 15.0, accuracy: 0.1,
                      "50 Hz band should have +15 dB gain")
    }

    func test_createEQNode_band4_1000hz_reference() {
        let eq = EmitterEqualLoudness.createEQNode()
        XCTAssertEqual(eq.bands[4].frequency, 1000.0, accuracy: 0.1)
        XCTAssertEqual(eq.bands[4].gain, 0.0, accuracy: 0.01,
                      "1000 Hz (reference) should have 0 dB gain")
    }

    func test_createEQNode_band7_16khz_treble_boost() {
        let eq = EmitterEqualLoudness.createEQNode()
        XCTAssertEqual(eq.bands[7].frequency, 16000.0, accuracy: 10.0)
        XCTAssertGreaterThan(eq.bands[7].gain, 0.0,
                            "16 kHz band should have positive gain")
    }

    func test_createEQNode_all_bandwidths_positive() {
        let eq = EmitterEqualLoudness.createEQNode()
        for (index, band) in eq.bands.enumerated() {
            XCTAssertGreaterThan(band.bandwidth, 0.0,
                                "Band \(index) bandwidth should be positive")
            XCTAssertLessThanOrEqual(band.bandwidth, 2.0,
                                    "Band \(index) bandwidth should be reasonable (≤ 2.0)")
        }
    }

    // MARK: - Integration tests

    func test_equal_loudness_applied_to_audio_graph() {
        let eq = EmitterEqualLoudness.createEQNode()

        // The EQ should be usable in an audio engine graph
        let engine = AVAudioEngine()
        engine.attach(eq)

        // Should not throw or fail
        XCTAssertNotNil(engine)
    }

    func test_bass_boost_compensates_frequency_sensitivity() {
        // Verify that bass frequencies get proportionally more boost than reference
        let gain50 = EmitterEqualLoudness.gainForFrequency(50)
        let gain1000 = EmitterEqualLoudness.gainForFrequency(1000)
        let gain16000 = EmitterEqualLoudness.gainForFrequency(16000)

        // Bass should be boosted relative to reference
        XCTAssertGreaterThan(gain50 - gain1000, 5.0,
                            "Bass boost relative to reference should be significant")

        // And should be greater than treble boost
        XCTAssertGreaterThan(gain50 - gain1000, gain16000 - gain1000,
                            "Bass boost should exceed treble boost")
    }
}
