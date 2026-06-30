import CoreGraphics

struct EmitterReverb {
    /// 0.0 = no reverb, 1.0 = maximum reverb.
    let amount: Double

    /// Blur radius in points applied to the outer edge bloom.
    var blurRadius: CGFloat {
        CGFloat(amount * 30.0)
    }

    /// Wet/dry mix for AVAudioUnitReverb (0–80).
    var wetDryMix: Float {
        Float(amount * 80.0)
    }

    static func random() -> EmitterReverb {
        EmitterReverb(amount: Double.random(in: 0...1))
    }
}
