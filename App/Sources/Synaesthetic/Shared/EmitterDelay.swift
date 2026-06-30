import Foundation

struct EmitterDelay {
    /// Period between the original ping and its echo, in seconds. Zero means no delay.
    let period: TimeInterval

    static func random() -> EmitterDelay {
        EmitterDelay(period: TimeInterval.random(in: 0.1...0.8))
    }
}
