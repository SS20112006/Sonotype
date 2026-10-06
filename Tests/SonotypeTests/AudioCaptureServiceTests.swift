import XCTest
@preconcurrency import AVFoundation
@testable import Sonotype

private final class TestBox<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: T?

    var value: T? {
        lock.lock()
        defer { lock.unlock() }
        return _value
    }

    func set(_ newValue: T) {
        lock.lock()
        defer { lock.unlock() }
        _value = newValue
    }
}

final class AudioCaptureServiceTests: XCTestCase {
    private var format: AVAudioFormat!

    override func setUp() {
        super.setUp()
        format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false)!
    }

    private func createSilentBuffer(frameCount: AVAudioFrameCount = 1024) -> AVAudioPCMBuffer {
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let channelData = buffer.floatChannelData![0]
        for i in 0..<Int(frameCount) {
            channelData[i] = 0.0
        }
        return buffer
    }

    private func createToneBuffer(frequency: Float = 440.0, frameCount: AVAudioFrameCount = 1024) -> AVAudioPCMBuffer {
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let channelData = buffer.floatChannelData![0]
        for i in 0..<Int(frameCount) {
            let t = Float(i) / Float(format.sampleRate)
            channelData[i] = sin(2.0 * .pi * frequency * t) * 0.5
        }
        return buffer
    }

    func testSilentBufferRMSIsZero() {
        let buffer = createSilentBuffer()
        let rms = AudioCaptureService.calculateRMS(buffer: buffer)
        XCTAssertEqual(rms, 0.0, accuracy: 0.0001, "Buffer de silêncio deve ter amplitude RMS igual a zero.")
    }

    func testActiveToneBufferRMSIsGreaterThanZero() {
        let buffer = createToneBuffer()
        let rms = AudioCaptureService.calculateRMS(buffer: buffer)
        XCTAssertGreaterThan(rms, 0.1, "Sinal sonoro ativo deve produzir amplitude superior a 0.1.")
        XCTAssertLessThanOrEqual(rms, 1.0, "Amplitude normalizada nunca deve exceder 1.0.")
    }

    func testProcessCapturedBufferTriggersCallbacksInMemory() {
        let service = AudioCaptureService()
        let buffer = createToneBuffer()

        let amplitudeBox = TestBox<Float>()
        let bufferBox = TestBox<AVAudioPCMBuffer>()

        service.onAmplitudeChanged = { amp in
            amplitudeBox.set(amp)
        }
        service.onBufferCaptured = { buf in
            bufferBox.set(buf)
        }

        service.processCapturedBuffer(buffer)

        XCTAssertNotNil(amplitudeBox.value, "O callback de amplitude deve ser acionado.")
        XCTAssertGreaterThan(amplitudeBox.value ?? 0, 0.0)
        XCTAssertNotNil(bufferBox.value, "O buffer capturado em RAM deve ser emitido.")
        XCTAssertEqual(bufferBox.value?.frameLength, buffer.frameLength)
    }

    func testZeroDiskWritesDuringAudioProcessing() {
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory

        let initialContents = (try? fileManager.contentsOfDirectory(atPath: tempDir.path)) ?? []

        let service = AudioCaptureService()
        for _ in 0..<20 {
            let buf = createToneBuffer()
            service.processCapturedBuffer(buf)
        }

        let finalContents = (try? fileManager.contentsOfDirectory(atPath: tempDir.path)) ?? []
        let audioExtensions = ["wav", "caf", "m4a", "pcm", "mp3", "aac", "raw"]
        let newAudioFiles = finalContents
            .filter { !initialContents.contains($0) }
            .filter { filename in
                audioExtensions.contains { ext in filename.lowercased().hasSuffix(ext) }
            }

        XCTAssertTrue(newAudioFiles.isEmpty, "Nenhum ficheiro de áudio pode ser escrito no disco durante a captação.")
    }
}
