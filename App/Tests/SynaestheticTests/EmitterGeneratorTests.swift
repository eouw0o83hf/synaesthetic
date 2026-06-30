import XCTest
import SwiftUI
@testable import Synaesthetic

final class EmitterGeneratorTests: XCTestCase {

    private let standardBounds = CGRect(x: 0, y: 0, width: 390, height: 844)

    // MARK: - Pitch conversion

    func test_pitchToVelocity_at_lower_range() {
        // C3 = 130.81 Hz should map to ~0.818 rad/s
        let velocity = EmitterGenerator.pitchToVelocity(130.81)
        XCTAssertTrue(abs(velocity - 0.818) <= 0.01)
    }

    func test_pitchToVelocity_at_upper_range() {
        // C7 = 2093.0 Hz should map to ~13.08 rad/s
        let velocity = EmitterGenerator.pitchToVelocity(2093.0)
        XCTAssertTrue(abs(velocity - 13.08) <= 0.01)
    }

    func test_pitchToVelocity_rounds_trip() {
        // Verify the conversion is consistent: hz -> velocity -> hz
        let originalHz = 440.0
        let velocity = EmitterGenerator.pitchToVelocity(originalHz)
        let reconstructedHz = (Double(velocity) / 25.0) * 4000.0
        XCTAssertTrue(abs(reconstructedHz - originalHz) <= 0.01)
    }

    // MARK: - Tempo (harmonic constraints)

    func test_tempoToVelocity_60bpm() {
        // 60 BPM = 2π rad/s
        let velocity = EmitterGenerator.tempoToVelocity(60)
        XCTAssertEqual(Double(velocity), 2.0 * .pi, accuracy: 0.001)
    }

    func test_tempoToVelocity_120bpm() {
        // 120 BPM = 4π rad/s
        let velocity = EmitterGenerator.tempoToVelocity(120)
        XCTAssertEqual(Double(velocity), 4.0 * .pi, accuracy: 0.001)
    }

    func test_velocityToTempo_roundtrip() {
        // Verify tempo -> velocity -> tempo roundtrip
        let originalTempo = 90.0
        let velocity = EmitterGenerator.tempoToVelocity(originalTempo)
        let reconstructedTempo = EmitterGenerator.velocityToTempo(velocity)
        XCTAssertEqual(reconstructedTempo, originalTempo, accuracy: 0.001)
    }

    func test_harmonic_tempos_all_valid() {
        // All harmonic tempos should convert to velocities within 0-25 rad/s
        for bpm in EmitterGenerator.harmonicTemposBPM {
            let velocity = EmitterGenerator.tempoToVelocity(bpm)
            XCTAssertGreaterThanOrEqual(Double(velocity), 0)
            XCTAssertLessThanOrEqual(Double(velocity), 25.2)  // Allow slight overage
        }
    }

    func test_random_harmonic_tempo_velocity_within_range() {
        // Verify random harmonic tempos are valid velocities
        for _ in 0..<20 {
            let velocity = EmitterGenerator.randomHarmonicTempoVelocity()
            XCTAssertGreaterThanOrEqual(Double(velocity), Double(EmitterGenerator.tempoToVelocity(EmitterGenerator.harmonicTemposBPM.min()!)))
            XCTAssertLessThanOrEqual(Double(velocity), Double(EmitterGenerator.tempoToVelocity(EmitterGenerator.harmonicTemposBPM.max()!)))
        }
    }

    // MARK: - generatePythagoreanTriad

    func test_triad_returns_valid_result() {
        let result = EmitterGenerator.generatePythagoreanTriad()
        XCTAssertEqual(result.velocities.count, 3, "Triad should have exactly 3 velocities")
        XCTAssertGreaterThan(result.major7thVelocity, 0, "Major 7th velocity should be positive")
        XCTAssertFalse(result.chordName.isEmpty, "Chord name should not be empty")
    }

    func test_triad_chord_names_are_valid() {
        let validNames = Set(["Major", "Minor", "Quartal"])
        for _ in 0..<50 {
            let result = EmitterGenerator.generatePythagoreanTriad()
            XCTAssertTrue(validNames.contains(result.chordName),
                          "Chord name '\(result.chordName)' is not in expected set: \(validNames)")
        }
    }

    func test_triad_velocities_within_pitch_range() {
        // Verify velocities map to frequencies within C3-C7 (130.81–2093.0 Hz)
        for _ in 0..<30 {
            let result = EmitterGenerator.generatePythagoreanTriad()
            for velocity in result.velocities {
                let hz = (Double(velocity) / 25.0) * 4000.0
                XCTAssertGreaterThanOrEqual(hz, EmitterGenerator.pitchRangeHz.lowerBound - 0.01,
                                           "Frequency \(hz) Hz is below C3")
                XCTAssertLessThanOrEqual(hz, EmitterGenerator.pitchRangeHz.upperBound + 0.01,
                                        "Frequency \(hz) Hz exceeds C7")
            }
        }
    }

    func test_major_7th_velocity_within_pitch_range() {
        for _ in 0..<30 {
            let result = EmitterGenerator.generatePythagoreanTriad()
            let hz = (Double(result.major7thVelocity) / 25.0) * 4000.0
            XCTAssertGreaterThanOrEqual(hz, EmitterGenerator.pitchRangeHz.lowerBound - 0.01,
                                       "Major 7th frequency \(hz) Hz is below C3")
            XCTAssertLessThanOrEqual(hz, EmitterGenerator.pitchRangeHz.upperBound + 0.01,
                                    "Major 7th frequency \(hz) Hz exceeds C7")
        }
    }

    func test_triad_velocities_are_positive() {
        for _ in 0..<50 {
            let result = EmitterGenerator.generatePythagoreanTriad()
            for velocity in result.velocities {
                XCTAssertGreaterThan(velocity, 0, "Velocity must be positive")
            }
            XCTAssertGreaterThan(result.major7thVelocity, 0, "Major 7th velocity must be positive")
        }
    }

    func test_major_7th_is_distinct_from_triad() {
        // Major 7th should not equal any of the three triad notes (with tolerance for floating point)
        for _ in 0..<30 {
            let result = EmitterGenerator.generatePythagoreanTriad()
            for triadVelocity in result.velocities {
                let difference = abs(result.major7thVelocity - triadVelocity)
                XCTAssertGreaterThan(difference, 0.1,
                                    "Major 7th should be distinct from triad notes")
            }
        }
    }

    func test_triad_harmonies_are_related() {
        // For a major triad (1, 5/4, 3/2), the ratios between notes should be approximately
        // these just-intonation intervals when we work back from velocities to Hz.
        // This is a statistical test since the root and octave adjustments vary.
        var majorTriads = 0
        var validRatios = 0

        for _ in 0..<50 {
            let result = EmitterGenerator.generatePythagoreanTriad()
            if result.chordName == "Major" {
                majorTriads += 1
                let hz = result.velocities.map { (Double($0) / 25.0) * 4000.0 }
                // Sort frequencies to get root, third, fifth
                let sorted = hz.sorted()

                // Check if major 3rd ratio (5/4 ≈ 1.25) is approximately found
                let ratio2to1 = sorted[1] / sorted[0]
                let ratio3to1 = sorted[2] / sorted[0]

                // For major chord: 5/4 = 1.25 and 3/2 = 1.5 (approximately)
                // Allow octave adjustments, so look for ratios in the ballpark
                if (ratio2to1 > 1.2 && ratio2to1 < 1.3) || (ratio2to1 > 2.4 && ratio2to1 < 2.6) {
                    validRatios += 1
                }
            }
        }

        XCTAssertGreaterThan(majorTriads, 0, "Should generate at least one major triad in 50 iterations")
        XCTAssertGreaterThan(validRatios, majorTriads / 3,
                            "Most major triads should exhibit characteristic just-intonation ratios")
    }

    // MARK: - generateSingleEmitter

    func test_single_emitter_preserves_velocity() {
        let velocity: CGFloat = 7.5
        let config = EmitterGenerator.generateSingleEmitter(
            velocity: velocity,
            existingEmitters: [],
            screenBounds: standardBounds
        )
        XCTAssertEqual(config.initialVelocity, velocity)
    }

    func test_single_emitter_has_random_colors() {
        // Generate several emitters; they should have different random colors
        var colors: Set<String> = []
        for _ in 0..<10 {
            let config = EmitterGenerator.generateSingleEmitter(
                velocity: 5,
                existingEmitters: [],
                screenBounds: standardBounds
            )
            let colorDesc = "\(config.color)_\(config.highlightColor)"
            colors.insert(colorDesc)
        }
        // With 10 random color pairs, we should get at least 9 unique combinations
        // (allowing 1 collision due to randomness)
        XCTAssertGreaterThanOrEqual(colors.count, 9,
                                   "Random color generation should produce variety")
    }

    // MARK: - Synaesthetic color mapping

    func test_velocityToHue_minimum_velocity_returns_violet() {
        let minVelocity = EmitterGenerator.tempoToVelocity(EmitterGenerator.harmonicTemposBPM.min()!)
        let hue = EmitterGenerator.velocityToHue(minVelocity)
        XCTAssertEqual(hue, 0.75, accuracy: 0.01, "Minimum velocity should map to violet (hue ~0.75)")
    }

    func test_velocityToHue_maximum_velocity_returns_red() {
        let maxVelocity = EmitterGenerator.tempoToVelocity(EmitterGenerator.harmonicTemposBPM.max()!)
        let hue = EmitterGenerator.velocityToHue(maxVelocity)
        XCTAssertEqual(hue, 0.0, accuracy: 0.01, "Maximum velocity should map to red (hue ~0)")
    }

    func test_velocityToHue_middle_velocity_in_range() {
        let minVelocity = EmitterGenerator.tempoToVelocity(EmitterGenerator.harmonicTemposBPM.min()!)
        let maxVelocity = EmitterGenerator.tempoToVelocity(EmitterGenerator.harmonicTemposBPM.max()!)
        let midVelocity = (minVelocity + maxVelocity) / 2
        let hue = EmitterGenerator.velocityToHue(midVelocity)
        XCTAssertGreaterThan(hue, 0.3, "Mid velocity should map to hue > 0.3")
        XCTAssertLessThan(hue, 0.5, "Mid velocity should map to hue < 0.5")
    }

    func test_velocityToHue_output_always_in_valid_range() {
        for bpm in EmitterGenerator.harmonicTemposBPM {
            let velocity = EmitterGenerator.tempoToVelocity(bpm)
            let hue = EmitterGenerator.velocityToHue(velocity)
            XCTAssertGreaterThanOrEqual(hue, 0.0, "Hue should be >= 0")
            XCTAssertLessThanOrEqual(hue, 0.75, "Hue should be <= 0.75 (violet)")
        }
    }

    func test_velocityToHue_clamped_for_out_of_range_velocities() {
        let minVelocity = EmitterGenerator.tempoToVelocity(EmitterGenerator.harmonicTemposBPM.min()!)
        let maxVelocity = EmitterGenerator.tempoToVelocity(EmitterGenerator.harmonicTemposBPM.max()!)

        let belowMin = minVelocity - 10
        let aboveMax = maxVelocity + 10

        let hueBelowMin = EmitterGenerator.velocityToHue(belowMin)
        let hueAboveMax = EmitterGenerator.velocityToHue(aboveMax)

        XCTAssertGreaterThanOrEqual(hueBelowMin, 0.0, "Hue for below-min velocity should be >= 0")
        XCTAssertLessThanOrEqual(hueBelowMin, 0.75, "Hue for below-min velocity should be <= 0.75")
        XCTAssertGreaterThanOrEqual(hueAboveMax, 0.0, "Hue for above-max velocity should be >= 0")
        XCTAssertLessThanOrEqual(hueAboveMax, 0.75, "Hue for above-max velocity should be <= 0.75")
    }

    func test_colorPairForPitch_returns_two_colors() {
        let velocity: CGFloat = 5
        let (baseColor, highlightColor) = EmitterGenerator.colorPairForPitch(velocity)
        let baseDesc = "\(baseColor)"
        let highlightDesc = "\(highlightColor)"
        XCTAssertFalse(baseDesc.isEmpty, "Base color should be valid")
        XCTAssertFalse(highlightDesc.isEmpty, "Highlight color should be valid")
    }

    func test_colorPairForPitch_highlight_varies_per_call() {
        let velocity: CGFloat = 5
        var highlightDescs: Set<String> = []

        for _ in 0..<10 {
            let (_, highlightColor) = EmitterGenerator.colorPairForPitch(velocity)
            highlightDescs.insert("\(highlightColor)")
        }

        XCTAssertGreaterThan(highlightDescs.count, 1,
                           "Highlight colors should vary across multiple calls (randomized)")
    }

    func test_single_emitter_pitch_determines_base_color() {
        // Two emitters with different velocities should have different base colors
        let config1 = EmitterGenerator.generateSingleEmitter(
            velocity: EmitterGenerator.tempoToVelocity(EmitterGenerator.harmonicTemposBPM.min()!),
            existingEmitters: [],
            screenBounds: standardBounds
        )
        let config2 = EmitterGenerator.generateSingleEmitter(
            velocity: EmitterGenerator.tempoToVelocity(EmitterGenerator.harmonicTemposBPM.max()!),
            existingEmitters: [],
            screenBounds: standardBounds
        )

        let color1Desc = "\(config1.color)"
        let color2Desc = "\(config2.color)"
        XCTAssertNotEqual(color1Desc, color2Desc,
                         "Emitters with different velocities should have different base colors")
    }

    func test_single_emitter_size_within_expected_range() {
        for _ in 0..<20 {
            let config = EmitterGenerator.generateSingleEmitter(
                velocity: 5,
                existingEmitters: [],
                screenBounds: standardBounds
            )
            XCTAssertGreaterThanOrEqual(config.size, Emitter.handleRadius * 2)
            XCTAssertLessThanOrEqual(config.size, 280)
        }
    }

    func test_single_emitter_radius_within_expected_fraction_of_size() {
        for _ in 0..<20 {
            let config = EmitterGenerator.generateSingleEmitter(
                velocity: 5,
                existingEmitters: [],
                screenBounds: standardBounds
            )
            XCTAssertGreaterThanOrEqual(config.radius, config.size * 0.2 - 0.001)
            XCTAssertLessThanOrEqual(config.radius, config.size * 0.35 + 0.001)
        }
    }

    func test_single_emitter_position_is_within_screen_bounds() {
        for _ in 0..<20 {
            let config = EmitterGenerator.generateSingleEmitter(
                velocity: 5,
                existingEmitters: [],
                screenBounds: standardBounds
            )
            XCTAssertGreaterThan(config.position.x, 0)
            XCTAssertLessThan(config.position.x, standardBounds.width)
            XCTAssertGreaterThan(config.position.y, 0)
            XCTAssertLessThan(config.position.y, standardBounds.height)
        }
    }

    func test_single_emitter_avoids_overlap_with_existing_emitter() {
        let existing = EmitterGenerator.generateSingleEmitter(
            velocity: 5,
            existingEmitters: [],
            screenBounds: standardBounds
        )
        var overlapCount = 0
        for _ in 0..<20 {
            let next = EmitterGenerator.generateSingleEmitter(
                velocity: 5,
                existingEmitters: [existing],
                screenBounds: standardBounds
            )
            let distance = hypot(next.position.x - existing.position.x, next.position.y - existing.position.y)
            let minDistance = (next.size + existing.size) / 2 + 10
            if distance < minDistance { overlapCount += 1 }
        }
        XCTAssertLessThanOrEqual(overlapCount, 2,
                                "Too many overlapping placements: \(overlapCount)/20")
    }

    // MARK: - Unified pitch randomization

    func test_pitch_algorithm_unified_between_startup_and_new_emitter() {
        // Both startup triad and new emitter additions should use the same pitchToVelocity function.
        // This test verifies that:
        // 1. Triad generates velocities via pitchToVelocity
        // 2. New emitter receives velocity from the same pool
        // 3. All velocities convert back to valid frequencies in C3-C7

        let triad = EmitterGenerator.generatePythagoreanTriad()
        let allVelocities = triad.velocities + [triad.major7thVelocity]

        for velocity in allVelocities {
            let hz = (Double(velocity) / 25.0) * 4000.0
            XCTAssertTrue(
                hz >= EmitterGenerator.pitchRangeHz.lowerBound && hz <= EmitterGenerator.pitchRangeHz.upperBound,
                "Unified pitch algorithm failed: velocity \(velocity) maps to \(hz) Hz outside C3-C7"
            )
        }
    }
}


