@preconcurrency import AVFoundation
import Accelerate
import Foundation

/// A reusable real-FFT processor with all working storage allocated up front.
///
/// `process` and spectrum queries do not allocate, which makes them suitable for
/// the AVAudioEngine tap. `magnitudes(from:)` intentionally returns a copy and is
/// provided for diagnostics and tests, not for the realtime path.
nonisolated final class FFTProcessor: @unchecked Sendable {
    let size: Int
    let binCount: Int

    private let log2Size: vDSP_Length
    private let fftSetup: FFTSetup
    private var window: [Float]
    private var monoSamples: [Float]
    private var windowedSamples: [Float]
    private var realParts: [Float]
    private var imaginaryParts: [Float]
    private var spectrum: [Float]

    private(set) var sampleRate: Double = 44_100
    private(set) var analyzedFrameCount = 0
    private(set) var rms: Float = 0
    private(set) var meanSquare: Float = 0
    private(set) var peak: Float = 0

    init(size: Int = 2_048) {
        precondition(size >= 64 && size.nonzeroBitCount == 1, "FFT size must be a power of two")

        self.size = size
        binCount = size / 2
        log2Size = vDSP_Length(log2(Float(size)))

        guard let setup = vDSP_create_fftsetup(log2Size, FFTRadix(kFFTRadix2)) else {
            preconditionFailure("Unable to create vDSP FFT setup")
        }
        fftSetup = setup

        window = Array(repeating: 0, count: size)
        monoSamples = Array(repeating: 0, count: size)
        windowedSamples = Array(repeating: 0, count: size)
        realParts = Array(repeating: 0, count: binCount)
        imaginaryParts = Array(repeating: 0, count: binCount)
        spectrum = Array(repeating: 0, count: binCount)

        window.withUnsafeMutableBufferPointer { pointer in
            guard let baseAddress = pointer.baseAddress else { return }
            vDSP_hann_window(baseAddress, vDSP_Length(size), Int32(vDSP_HANN_NORM))
        }
    }

    deinit {
        vDSP_destroy_fftsetup(fftSetup)
    }

    /// Converts all channels to mono and computes a spectrum without allocating.
    @discardableResult
    func process(_ buffer: AVAudioPCMBuffer) -> Bool {
        guard
            let channelData = buffer.floatChannelData,
            buffer.frameLength > 0
        else {
            clearResults()
            return false
        }

        let frameCount = min(Int(buffer.frameLength), size)
        let channelCount = max(Int(buffer.format.channelCount), 1)

        monoSamples.withUnsafeMutableBufferPointer { destination in
            destination.initialize(repeating: 0)
            guard let destinationBase = destination.baseAddress else { return }

            for channel in 0..<channelCount {
                let source = channelData[channel]
                for frame in 0..<frameCount {
                    destinationBase[frame] += source[frame]
                }
            }

            var divisor = Float(channelCount)
            vDSP_vsdiv(
                destinationBase,
                1,
                &divisor,
                destinationBase,
                1,
                vDSP_Length(frameCount)
            )
        }

        sampleRate = buffer.format.sampleRate
        performFFT(frameCount: frameCount)
        return true
    }

    /// Test and diagnostic entry point for already-mono samples.
    func process(samples: UnsafeBufferPointer<Float>, sampleRate: Double) {
        let frameCount = min(samples.count, size)
        monoSamples.withUnsafeMutableBufferPointer { destination in
            destination.initialize(repeating: 0)
            guard
                let destinationBase = destination.baseAddress,
                let sourceBase = samples.baseAddress,
                frameCount > 0
            else {
                return
            }
            destinationBase.update(from: sourceBase, count: frameCount)
        }

        self.sampleRate = sampleRate
        performFFT(frameCount: frameCount)
    }

    func rootMeanSquareMagnitude(in band: ClosedRange<Float>) -> Float {
        guard analyzedFrameCount > 0 else { return 0 }
        let indices = binRange(for: band)
        guard !indices.isEmpty else { return 0 }

        var sumOfSquares: Float = 0
        for index in indices {
            let magnitude = spectrum[index]
            sumOfSquares += magnitude * magnitude
        }
        return sqrt(sumOfSquares / Float(indices.count))
    }

    func peakMagnitude(in band: ClosedRange<Float>) -> Float {
        guard analyzedFrameCount > 0 else { return 0 }
        var result: Float = 0
        for index in binRange(for: band) {
            result = max(result, spectrum[index])
        }
        return result
    }

    func normalizedSpectralCentroid(maximumFrequency: Float = 12_000) -> Float {
        guard analyzedFrameCount > 0, sampleRate > 0 else { return 0 }
        let upperFrequency = min(maximumFrequency, Float(sampleRate * 0.5))
        let upperBin = min(Int(upperFrequency * Float(size) / Float(sampleRate)), binCount - 1)
        guard upperBin >= 1 else { return 0 }

        var weightedSum: Float = 0
        var magnitudeSum: Float = 0
        let binWidth = Float(sampleRate) / Float(size)

        for index in 1...upperBin {
            let magnitude = spectrum[index]
            weightedSum += Float(index) * binWidth * magnitude
            magnitudeSum += magnitude
        }

        guard magnitudeSum > 0.000_001 else { return 0 }
        return min(max((weightedSum / magnitudeSum) / upperFrequency, 0), 1)
    }

    func dominantFrequency() -> Float {
        guard analyzedFrameCount > 0, binCount > 1 else { return 0 }
        var strongestIndex = 1
        var strongestMagnitude = spectrum[1]

        for index in 2..<binCount where spectrum[index] > strongestMagnitude {
            strongestIndex = index
            strongestMagnitude = spectrum[index]
        }

        guard strongestMagnitude > 0.000_001 else { return 0 }
        return Float(strongestIndex) * Float(sampleRate) / Float(size)
    }

    /// Allocating convenience API for tests and diagnostics.
    func magnitudes(from buffer: AVAudioPCMBuffer) -> [Float] {
        _ = process(buffer)
        return spectrum
    }

    private func performFFT(frameCount: Int) {
        guard frameCount > 0 else {
            clearResults()
            return
        }

        analyzedFrameCount = frameCount

        monoSamples.withUnsafeBufferPointer { samples in
            guard let baseAddress = samples.baseAddress else { return }
            vDSP_rmsqv(baseAddress, 1, &rms, vDSP_Length(frameCount))
            vDSP_measqv(baseAddress, 1, &meanSquare, vDSP_Length(frameCount))
            vDSP_maxmgv(baseAddress, 1, &peak, vDSP_Length(frameCount))
        }

        monoSamples.withUnsafeBufferPointer { samples in
            window.withUnsafeBufferPointer { window in
                windowedSamples.withUnsafeMutableBufferPointer { output in
                    guard
                        let sampleBase = samples.baseAddress,
                        let windowBase = window.baseAddress,
                        let outputBase = output.baseAddress
                    else {
                        return
                    }
                    vDSP_vmul(
                        sampleBase,
                        1,
                        windowBase,
                        1,
                        outputBase,
                        1,
                        vDSP_Length(size)
                    )
                }
            }
        }

        windowedSamples.withUnsafeBytes { bytes in
            realParts.withUnsafeMutableBufferPointer { real in
                imaginaryParts.withUnsafeMutableBufferPointer { imaginary in
                    spectrum.withUnsafeMutableBufferPointer { magnitudes in
                        guard
                            let byteBase = bytes.baseAddress,
                            let realBase = real.baseAddress,
                            let imaginaryBase = imaginary.baseAddress,
                            let magnitudeBase = magnitudes.baseAddress
                        else {
                            return
                        }

                        let complex = byteBase.assumingMemoryBound(to: DSPComplex.self)
                        var splitComplex = DSPSplitComplex(
                            realp: realBase,
                            imagp: imaginaryBase
                        )
                        vDSP_ctoz(
                            complex,
                            2,
                            &splitComplex,
                            1,
                            vDSP_Length(binCount)
                        )
                        vDSP_fft_zrip(
                            fftSetup,
                            &splitComplex,
                            1,
                            log2Size,
                            FFTDirection(FFT_FORWARD)
                        )
                        vDSP_zvabs(
                            &splitComplex,
                            1,
                            magnitudeBase,
                            1,
                            vDSP_Length(binCount)
                        )

                        // 2/N for the one-sided spectrum, plus compensation for the Hann window.
                        var scale = 4 / Float(size)
                        vDSP_vsmul(
                            magnitudeBase,
                            1,
                            &scale,
                            magnitudeBase,
                            1,
                            vDSP_Length(binCount)
                        )
                        magnitudeBase[0] = 0
                    }
                }
            }
        }
    }

    private func binRange(for band: ClosedRange<Float>) -> Range<Int> {
        guard sampleRate > 0 else { return 0..<0 }
        let lower = max(Int(ceil(band.lowerBound * Float(size) / Float(sampleRate))), 1)
        let upperInclusive = min(
            Int(floor(band.upperBound * Float(size) / Float(sampleRate))),
            binCount - 1
        )
        guard upperInclusive >= lower else { return 0..<0 }
        return lower..<(upperInclusive + 1)
    }

    private func clearResults() {
        analyzedFrameCount = 0
        rms = 0
        meanSquare = 0
        peak = 0
        spectrum.withUnsafeMutableBufferPointer { $0.initialize(repeating: 0) }
    }
}
