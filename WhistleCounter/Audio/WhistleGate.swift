import Foundation

/// Pure state machine that converts a stream of per-frame band-energy
/// ratios into discrete whistle events.
///
/// The gate has three responsibilities:
///  1. Fire once when the ratio stays above `fireRatio` for at least
///     `minDurationSec`.
///  2. Keep firing-count at one even if the signal wobbles in
///     amplitude during the whistle (hysteresis via `releaseRatio`).
///  3. Only re-arm for a new whistle after the ratio stays cleanly
///     below `releaseRatio` for at least `minGapSec`.
///
/// The type is a plain value type with no audio dependencies so it
/// can be unit-tested deterministically.
struct WhistleGate {

    // MARK: - Tunables

    /// Energy ratio at or above which the signal is considered "whistle on".
    var fireRatio: Float

    /// How long the signal must stay above `fireRatio` before we fire.
    var minDurationSec: Double

    /// Minimum gap between two CONFIRMED whistles, measured from the
    /// previous fire time. Absorbs amplitude dips that briefly cross
    /// `fireRatio` within a single whistle.
    var minIntervalBetweenFiresSec: Double

    /// How long the signal must stay cleanly below `releaseRatio`
    /// before we consider the current whistle over and arm the gate
    /// for the next one. Must be longer than typical mid-whistle
    /// amplitude dips.
    var minGapSec: Double

    /// Once firing, only amplitude dips *below* this ratio count as
    /// "the whistle is dropping". Expressed as a factor of `fireRatio`.
    static let releaseHysteresisFactor: Float = 0.6

    var releaseRatio: Float {
        fireRatio * Self.releaseHysteresisFactor
    }

    // MARK: - State

    private enum State {
        /// Waiting for the signal to rise above `fireRatio`.
        case idle

        /// Currently above `fireRatio`, accumulating sustain time
        /// toward `minDurationSec`.
        case pending(startedAt: TimeInterval)

        /// We've fired for the current whistle. We'll stay here
        /// until we've been below `releaseRatio` for at least
        /// `minGapSec`, then return to `.idle`.
        case firing(belowSince: TimeInterval?)
    }

    private var state: State = .idle
    private var lastFireTime: TimeInterval = -.infinity

    // MARK: - Init

    init(
        thresholdRatio: Float,
        minDurationSec: Double,
        refractorySec: Double,
        minGapSec: Double = 0.5
    ) {
        self.fireRatio = thresholdRatio
        self.minDurationSec = minDurationSec
        self.minIntervalBetweenFiresSec = refractorySec
        self.minGapSec = minGapSec
    }

    // MARK: - API

    /// Feed one frame's energy ratio in.
    ///
    /// - Returns: `true` exactly once per detected whistle, regardless
    ///   of its duration (1 s or 10 s) and regardless of amplitude
    ///   wobbles within it.
    mutating func process(energyRatio: Float, now: TimeInterval) -> Bool {
        let aboveFire = energyRatio >= fireRatio
        let belowRelease = energyRatio < releaseRatio

        switch state {
        case .idle:
            if aboveFire {
                state = .pending(startedAt: now)
            }

        case .pending(let startedAt):
            if aboveFire {
                return attemptFire(startedAt: startedAt, now: now)
            }
            if belowRelease {
                state = .idle
            }
            // Between releaseRatio and fireRatio: hold current state.

        case .firing(let belowSince):
            updateFiringState(belowSince: belowSince,
                              belowRelease: belowRelease,
                              now: now)
        }

        return false
    }

    // MARK: - State transitions

    private mutating func attemptFire(
        startedAt: TimeInterval,
        now: TimeInterval
    ) -> Bool {
        let sustained = now - startedAt
        let sinceLastFire = now - lastFireTime
        guard sustained >= minDurationSec,
              sinceLastFire >= minIntervalBetweenFiresSec else {
            return false
        }
        lastFireTime = now
        state = .firing(belowSince: nil)
        return true
    }

    private mutating func updateFiringState(
        belowSince: TimeInterval?,
        belowRelease: Bool,
        now: TimeInterval
    ) {
        if belowRelease {
            guard let since = belowSince else {
                state = .firing(belowSince: now)
                return
            }
            if now - since >= minGapSec {
                state = .idle
            }
        } else if belowSince != nil {
            // Signal came back up within the gap window — still the
            // same whistle. Reset the "below since" timer.
            state = .firing(belowSince: nil)
        }
    }
}
