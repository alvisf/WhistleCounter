import Accelerate
import AVFoundation
import Foundation

/// FFT-based whistle detector.
///
/// Pipeline for each incoming audio buffer:
/// 1. Mix-down to mono float samples.
/// 2. Slide a Hann-windowed FFT (size = `fftSize`) over them.
/// 3. Compute power in the whistle band (2–4 kHz) vs. total power.
/// 4. Feed the ratio into a state machine (`WhistleGate`) that
///    requires the ratio to stay above threshold for `minDurationMs`
///    and enforces a `refractoryMs` cooldown between whistles.
///
/// The state machine lives inline rather than in its own file to keep
/// the hot-path logic readable in one place; it's pure (no I/O, no
/// audio types) and is directly unit-tested.
final class DSPWhistleDetector: WhistleDetector {

    // MARK: - Tunables

    /// Power-of-two FFT size. 1024 @ 44.1 kHz ≈ 23 ms per frame, plenty
    /// of frequency resolution for a 2–4 kHz tone.
    private let fftSize = 1024

    /// Whistle band (Hz). A pressure cooker whistle has a strong
    /// fundamental in this range.
    private let bandLowHz: Float = 2000
    private let bandHighHz: Float = 4000

    /// Minimum duration (ms) the band-energy ratio must stay above
    /// threshold to count as a whistle (filters out clicks/pops).
    private let minDurationMs: Double = 300

    /// Minimum gap (ms) between two consecutive whistles (prevents a
    /// single long whistle from being counted multiple times).
    private let refractoryMs: Double = 1500

    // MARK: - Callbacks

    var onWhistleDetected: (() -> Void)?
    var onError: ((String) -> Void)?

    // MARK: - State

    private let engine = AVAudioEngine()
    nonisolated(unsafe) private var fftSetup: vDSP.FFT<DSPSplitComplex>?
    nonisolated(unsafe) private var hannWindow: [Float] = []

    /// Gate that collapses per-frame energy ratios into discrete
    /// whistle events. Mutated only from the audio thread after `start`.
    nonisolated(unsafe) private var gate = WhistleGate(
        thresholdRatio: 0.30,
        minDurationSec: 0.30,
        refractorySec: 1.5
    )

    private var isRunning = false

    // MARK: - Init

    init() {
        let log2n = vDSP_Length(log2(Double(fftSize)))
        self.fftSetup = vDSP.FFT(
            log2n: log2n,
            radix: .radix2,
            ofType: DSPSplitComplex.self
        )
        self.hannWindow = vDSP.window(
            ofType: Float.self,
            usingSequence: .hanningNormalized,
            count: fftSize,
            isHalfWindow: false
        )
    }

    // MARK: - WhistleDetector

    func configure(sensitivity: Double) {
        // sensitivity: 0 = most sensitive (low threshold), 1 = least.
        // Map to threshold ratio in roughly [0.10, 0.60].
        let clamped = min(max(sensitivity, 0), 1)
        let threshold = 0.10 + (0.50 * clamped)
        gate.thresholdRatio = Float(threshold)
    }

    @MainActor
    func start() throws {
        guard !isRunning else { return }

        Task { [weak self] in
            let granted = await AudioSessionManager.requestMicPermission()
            guard let self else { return }
            await MainActor.run {
                if granted {
                    self.startEngine()
                } else {
                    self.onError?("Microphone permission denied. Enable it in Settings.")
                }
            }
        }
    }

    @MainActor
    func stop() {
        guard isRunning else { return }
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        AudioSessionManager.deactivate()
        isRunning = false
    }

    // MARK: - Private

    @MainActor
    private func startEngine() {
        do {
            try AudioSessionManager.configure()

            let input = engine.inputNode
            let format = input.inputFormat(forBus: 0)
            let sampleRate = Float(format.sampleRate)

            input.installTap(
                onBus: 0,
                bufferSize: AVAudioFrameCount(fftSize),
                format: format
            ) { [weak self] buffer, _ in
                self?.process(buffer: buffer, sampleRate: sampleRate)
            }

            engine.prepare()
            try engine.start()
            isRunning = true
        } catch {
            onError?("Failed to start audio engine: \(error.localizedDescription)")
        }
    }

    /// Called on a real-time audio thread. MUST NOT allocate or block.
    nonisolated private func process(
        buffer: AVAudioPCMBuffer,
        sampleRate: Float
    ) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameCount = Int(buffer.frameLength)
        guard frameCount >= fftSize else { return }

        // Take the first `fftSize` frames for analysis. For a tap size
        // of fftSize this is the whole buffer.
        let ratio = bandEnergyRatio(
            samples: channelData,
            sampleRate: sampleRate
        )

        let now = Date().timeIntervalSinceReferenceDate
        let fired = gate.process(energyRatio: ratio, now: now)
        if fired {
            Task { @MainActor [weak self] in
                self?.onWhistleDetected?()
            }
        }
    }

    /// Compute ratio of power in [bandLowHz, bandHighHz] to total
    /// power in the spectrum. Returns 0 on any failure.
    nonisolated private func bandEnergyRatio(
        samples: UnsafePointer<Float>,
        sampleRate: Float
    ) -> Float {
        guard let fftSetup else { return 0 }

        // Apply Hann window to the input.
        var windowed = [Float](repeating: 0, count: fftSize)
        vDSP.multiply(
            UnsafeBufferPointer(start: samples, count: fftSize),
            hannWindow,
            result: &windowed
        )

        // Pack real samples into split-complex form for vDSP FFT.
        let halfN = fftSize / 2
        var realp = [Float](repeating: 0, count: halfN)
        var imagp = [Float](repeating: 0, count: halfN)

        var ratio: Float = 0

        realp.withUnsafeMutableBufferPointer { realBuf in
            imagp.withUnsafeMutableBufferPointer { imagBuf in
                var split = DSPSplitComplex(
                    realp: realBuf.baseAddress!,
                    imagp: imagBuf.baseAddress!
                )
                windowed.withUnsafeBufferPointer { wptr in
                    wptr.baseAddress!.withMemoryRebound(
                        to: DSPComplex.self,
                        capacity: halfN
                    ) { typed in
                        vDSP_ctoz(typed, 2, &split, 1, vDSP_Length(halfN))
                    }
                }

                // Forward FFT in-place.
                fftSetup.forward(input: split, output: &split)

                // Magnitude squared per bin.
                var magSq = [Float](repeating: 0, count: halfN)
                vDSP.squareMagnitudes(split, result: &magSq)

                // Convert bin index → Hz: binHz = sampleRate / fftSize.
                let binHz = sampleRate / Float(fftSize)
                let lowBin = max(1, Int(bandLowHz / binHz))
                let highBin = min(halfN - 1, Int(bandHighHz / binHz))

                let totalPower = magSq.reduce(0, +)
                guard totalPower > 0, highBin > lowBin else {
                    return
                }
                var bandPower: Float = 0
                for i in lowBin...highBin {
                    bandPower += magSq[i]
                }
                ratio = bandPower / totalPower
            }
        }

        return ratio
    }
}

// MARK: - WhistleGate

/// Pure state machine that converts a per-frame band-energy ratio
/// stream into discrete whistle events with duration + refractory
/// guarantees.
///
/// Split out so it can be unit-tested without audio.
struct WhistleGate {
    var thresholdRatio: Float
    var minDurationSec: Double
    var refractorySec: Double

    /// How long the signal must stay BELOW threshold before we treat
    /// the current whistle as "ended". This absorbs brief dropouts
    /// (single-frame noise, buffer edges) that would otherwise split
    /// one whistle into two.
    var minGapSec: Double = 0.2

    private var activeSinceTime: TimeInterval?
    private var belowSinceTime: TimeInterval?
    private var lastFireTime: TimeInterval = -.infinity
    private var hasFiredForCurrentBurst: Bool = false

    init(
        thresholdRatio: Float,
        minDurationSec: Double,
        refractorySec: Double,
        minGapSec: Double = 0.2
    ) {
        self.thresholdRatio = thresholdRatio
        self.minDurationSec = minDurationSec
        self.refractorySec = refractorySec
        self.minGapSec = minGapSec
    }

    /// Feed one frame's energy ratio in. Returns `true` exactly once
    /// per detected whistle.
    ///
    /// A whistle is defined as a contiguous "above threshold" period
    /// — with short dropouts of up to `minGapSec` absorbed as part of
    /// the same whistle. A single burst that lasts 10 seconds still
    /// counts as one whistle.
    mutating func process(energyRatio: Float, now: TimeInterval) -> Bool {
        let aboveThreshold = energyRatio >= thresholdRatio

        if aboveThreshold {
            // Signal is above threshold. Cancel any pending "end of
            // whistle" timer — this keeps the current burst alive
            // through brief dropouts.
            belowSinceTime = nil

            if activeSinceTime == nil {
                activeSinceTime = now
            }
            let sustained = now - (activeSinceTime ?? now)
            let sinceLastFire = now - lastFireTime
            if !hasFiredForCurrentBurst,
               sustained >= minDurationSec,
               sinceLastFire >= refractorySec {
                lastFireTime = now
                hasFiredForCurrentBurst = true
                return true
            }
        } else {
            // Signal is below threshold. Start (or continue) a "maybe
            // whistle ended" timer. We only consider the burst over
            // once we've been below for at least `minGapSec`.
            if belowSinceTime == nil {
                belowSinceTime = now
            }
            let belowFor = now - (belowSinceTime ?? now)
            if belowFor >= minGapSec {
                activeSinceTime = nil
                hasFiredForCurrentBurst = false
            }
        }
        return false
    }
}
