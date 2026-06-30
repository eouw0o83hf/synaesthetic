import AVFoundation

/// Equal loudness curve (ISO 226) to compensate for human ear sensitivity across frequencies.
/// Boosts bass frequencies so perceived volume is uniform across the spectrum.
struct EmitterEqualLoudness {
    /// ISO 226 equal loudness correction in dB at 40 phons (typical listening level).
    /// Maps frequency (Hz) to gain adjustment (dB).
    /// At 1000 Hz (reference), gain is 0 dB.
    static func gainForFrequency(_ hz: Double) -> Float {
        switch hz {
        case ..<50: return 15.0       // Deep bass
        case ..<100: return 12.0      // Bass
        case ..<200: return 8.0       // Low bass
        case ..<500: return 3.0       // Lower midrange
        case ..<1000: return 0.5      // Lower midrange to ref
        case ..<2000: return 0.0      // Reference point
        case ..<4000: return -0.5     // Upper midrange slight dip
        case ..<8000: return 0.0      // Presence
        case ..<16000: return 2.0     // Upper presence boost
        default: return 3.0            // High treble
        }
    }

    /// Configures AVAudioUnitEQ with ISO 226 equal loudness curve.
    /// Returns configured EQ node ready to be inserted into audio graph.
    static func createEQNode() -> AVAudioUnitEQ {
        let eqNode = AVAudioUnitEQ(numberOfBands: 8)

        // Band 0: 50 Hz (bass) — +15 dB boost
        eqNode.bands[0].frequency = 50
        eqNode.bands[0].gain = 15.0
        eqNode.bands[0].bandwidth = 1.0

        // Band 1: 100 Hz (bass) — +12 dB boost
        eqNode.bands[1].frequency = 100
        eqNode.bands[1].gain = 12.0
        eqNode.bands[1].bandwidth = 1.0

        // Band 2: 200 Hz (low-bass) — +8 dB boost
        eqNode.bands[2].frequency = 200
        eqNode.bands[2].gain = 8.0
        eqNode.bands[2].bandwidth = 1.0

        // Band 3: 500 Hz (lower-mid) — +3 dB boost
        eqNode.bands[3].frequency = 500
        eqNode.bands[3].gain = 3.0
        eqNode.bands[3].bandwidth = 0.8

        // Band 4: 1000 Hz (reference) — 0 dB (no change)
        eqNode.bands[4].frequency = 1000
        eqNode.bands[4].gain = 0.0
        eqNode.bands[4].bandwidth = 0.8

        // Band 5: 4000 Hz (presence) — -0.5 dB slight dip
        eqNode.bands[5].frequency = 4000
        eqNode.bands[5].gain = -0.5
        eqNode.bands[5].bandwidth = 0.8

        // Band 6: 8000 Hz (upper presence) — 0 dB
        eqNode.bands[6].frequency = 8000
        eqNode.bands[6].gain = 0.0
        eqNode.bands[6].bandwidth = 1.0

        // Band 7: 16000 Hz (treble) — +2 dB boost
        eqNode.bands[7].frequency = 16000
        eqNode.bands[7].gain = 2.0
        eqNode.bands[7].bandwidth = 1.0

        return eqNode
    }
}
