import Accelerate
import AVFoundation
import Foundation

/// FFT-based whistle detector.
///
/// For each incoming audio buffer the detector:
///   1. Applies a Hann window to `FFTSize` samples.
///   2. Runs a real-to-complex forward FFT using `vDSP`.
///   3. Computes the fraction of spectral power in the whistle band
///      (`BandLowHz`..`BandHighHz`) vs. total power.
///   4. Feeds that ratio into a `WhistleGate` which decides whether
///      the frame represents a new whistle event.
///
/// `WhistleGate` is a separate, pure value type (see `WhistleGate.swift`)
/// so the detection policy can be unit-tested without real audio.
final class DSPWhistleDetector: WhistleDetector {

    // MARK: - Tuning constants

    private enum FFT {
        /// Power-of-two FFT size. 1024 @ 44.1 kHz ≈ 23 ms per frame,
        /// which gives ~43 Hz resolution — plenty for a 2–4 kHz band.
        static let size: Int = 1024
    }

    private enum WhistleBand {
        /// Lower edge of the whistle band in Hz. A pressure-cooker
        /// whistle has a strong fundamental in this range.
        static let lowHz: Float = 2000
        static let highHz: Float = 4000
    }

    private enum GateDefaults {
        static let fireRatio: Float = 0.30
        static let minDurationSec: Double = 0.30
        static let minIntervalBetweenFiresSec: Double = 1.5
    }

    private enum SensitivityMapping {
        /// `sensitivity = 0` → `fireRatio = minFireRatio`  (most sensitive)
        /// `sensitivity = 1` → `fireRatio = maxFireRatio`  (least sensitive)
        static let minFireRatio: Double = 0.10
        static let maxFireRatio: Double = 0.60
    }

    // MARK: - Callbacks

    var onWhistleDetected: (() -> Void)?
    var onError: ((String) -> Void)?

    // MARK: - State

    private(set) var isInterrupted: Bool = false
    private let engine = AVAudioEngine()

    /// FFT scratch owned by the detector. Touched only from the audio
    /// thread after `start`; `nonisolated(unsafe)` documents that
    /// invariant.
    nonisolated(unsafe) private var fftSetup: vDSP.FFT<DSPSplitComplex>?
    nonisolated(unsafe) private var hannWindow: [Float] = []
    nonisolated(unsafe) private var gate = WhistleGate(
        thresholdRatio: GateDefaults.fireRatio,
        minDurationSec: GateDefaults.minDurationSec,
        refractorySec: GateDefaults.minIntervalBetweenFiresSec
    )

    private var isRunning = false

    // MARK: - Init

    init() {
        let log2n = vDSP_Length(log2(Double(FFT.size)))
        self.fftSetup = vDSP.FFT(
            log2n: log2n,
            radix: .radix2,
            ofType: DSPSplitComplex.self
        )
        self.hannWindow = vDSP.window(
            ofType: Float.self,
            usingSequence: .hanningNormalized,
            count: FFT.size,
            isHalfWindow: false
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - WhistleDetector

    func configure(sensitivity: Double) {
        let clamped = min(max(sensitivity, 0), 1)
        let range = SensitivityMapping.maxFireRatio - SensitivityMapping.minFireRatio
        let mapped = SensitivityMapping.minFireRatio + clamped * range
        gate.fireRatio = Float(mapped)
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

    // MARK: - Engine lifecycle

    @MainActor
    private func startEngine() {
        do {
            try AudioSessionManager.configure()
            try installTapAndStartEngine()
            isRunning = true
        } catch {
            onError?("Failed to start audio engine: \(error.localizedDescription)")
        }
    }

    @MainActor
    private func installTapAndStartEngine() throws {
        let input = engine.inputNode
        let format = input.inputFormat(forBus: 0)
        let sampleRate = Float(format.sampleRate)

        input.installTap(
            onBus: 0,
            bufferSize: AVAudioFrameCount(FFT.size),
            format: format
        ) { [weak self] buffer, _ in
            self?.processAudioFrame(buffer: buffer, sampleRate: sampleRate)
        }

        engine.prepare()
        try engine.start()
    }

    // MARK: - Interruption handling

    @objc private func handleInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue)
        else { return }

        Task { @MainActor [weak self] in
            guard let self, self.isRunning else { return }
            switch type {
            case .began:
                self.engine.pause()
                self.isInterrupted = true
            case .ended:
                self.isInterrupted = false
                let shouldResume = (info[AVAudioSessionInterruptionOptionKey] as? UInt)
                    .map { AVAudioSession.InterruptionOptions(rawValue: $0).contains(.shouldResume) }
                    ?? true
                if shouldResume {
                    try? AudioSessionManager.configure()
                    try? self.engine.start()
                }
            @unknown default:
                break
            }
        }
    }

    // MARK: - Audio thread

    /// Called on a real-time audio thread. Must not allocate large
    /// buffers, take locks, or block.
    nonisolated private func processAudioFrame(
        buffer: AVAudioPCMBuffer,
        sampleRate: Float
    ) {
        guard let channelData = buffer.floatChannelData?[0],
              Int(buffer.frameLength) >= FFT.size else {
            return
        }

        let ratio = bandEnergyRatio(samples: channelData, sampleRate: sampleRate)
        let fired = gate.process(
            energyRatio: ratio,
            now: Date().timeIntervalSinceReferenceDate
        )
        guard fired else { return }
        Task { @MainActor [weak self] in
            self?.onWhistleDetected?()
        }
    }

    // MARK: - DSP

    /// Ratio of spectral power in the whistle band to total spectral
    /// power, in the range [0, 1]. Returns 0 if the FFT setup is
    /// missing or the spectrum is silent.
    nonisolated private func bandEnergyRatio(
        samples: UnsafePointer<Float>,
        sampleRate: Float
    ) -> Float {
        guard let fftSetup else { return 0 }

        let windowed = applyHannWindow(to: samples)
        let magnitudesSquared = forwardFFTMagnitudesSquared(
            windowed: windowed,
            fftSetup: fftSetup
        )
        return bandPowerRatio(
            magnitudesSquared: magnitudesSquared,
            sampleRate: sampleRate
        )
    }

    nonisolated private func applyHannWindow(
        to samples: UnsafePointer<Float>
    ) -> [Float] {
        var windowed = [Float](repeating: 0, count: FFT.size)
        vDSP.multiply(
            UnsafeBufferPointer(start: samples, count: FFT.size),
            hannWindow,
            result: &windowed
        )
        return windowed
    }

    nonisolated private func forwardFFTMagnitudesSquared(
        windowed: [Float],
        fftSetup: vDSP.FFT<DSPSplitComplex>
    ) -> [Float] {
        let halfN = FFT.size / 2
        var realParts = [Float](repeating: 0, count: halfN)
        var imagParts = [Float](repeating: 0, count: halfN)
        var magnitudesSquared = [Float](repeating: 0, count: halfN)

        realParts.withUnsafeMutableBufferPointer { realBuf in
            imagParts.withUnsafeMutableBufferPointer { imagBuf in
                var split = DSPSplitComplex(
                    realp: realBuf.baseAddress!,
                    imagp: imagBuf.baseAddress!
                )

                // Pack interleaved real samples into split-complex form.
                windowed.withUnsafeBufferPointer { buffer in
                    buffer.baseAddress!.withMemoryRebound(
                        to: DSPComplex.self,
                        capacity: halfN
                    ) { complexView in
                        vDSP_ctoz(complexView, 2, &split, 1, vDSP_Length(halfN))
                    }
                }

                fftSetup.forward(input: split, output: &split)
                vDSP.squareMagnitudes(split, result: &magnitudesSquared)
            }
        }

        return magnitudesSquared
    }

    nonisolated private func bandPowerRatio(
        magnitudesSquared: [Float],
        sampleRate: Float
    ) -> Float {
        let binCount = magnitudesSquared.count
        let hzPerBin = sampleRate / Float(FFT.size)
        let lowBin = max(1, Int(WhistleBand.lowHz / hzPerBin))
        let highBin = min(binCount - 1, Int(WhistleBand.highHz / hzPerBin))
        let totalPower = magnitudesSquared.reduce(0, +)

        guard totalPower > 0, highBin > lowBin else { return 0 }

        var bandPower: Float = 0
        for bin in lowBin...highBin {
            bandPower += magnitudesSquared[bin]
        }
        return bandPower / totalPower
    }
}
