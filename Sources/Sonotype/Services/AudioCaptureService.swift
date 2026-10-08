import Foundation
@preconcurrency import AVFoundation
import os

/// Erros tipados do motor de captação de áudio.
public enum AudioCaptureError: LocalizedError, Sendable {
    case bufferAllocationFailed
    case converterInitializationFailed
    case conversionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .bufferAllocationFailed:
            return "Falha na alocação de buffer PCM de áudio em memória."
        case .converterInitializationFailed:
            return "Falha na inicialização do conversor de formato de áudio."
        case .conversionFailed(let reason):
            return "Falha na conversão de formato de áudio: \(reason)"
        }
    }
}

/// Serviço responsável pela captura de áudio exclusivamente em memória RAM.
/// Gere o AVAudioEngine, conversão para 16kHz mono e cálculo em tempo real da amplitude.
public class AudioCaptureService: @unchecked Sendable {
    private static let logger = Logger(subsystem: "com.sonotype.app", category: "AudioCaptureService")

    private let engine: AVAudioEngine
    private let targetFormat: AVAudioFormat
    private let lock = NSLock()

    private var _isCapturing: Bool = false
    private var converter: AVAudioConverter?

    /// Callback disparado a cada buffer capturado (formato 16kHz mono float32 em RAM).
    public var onBufferCaptured: (@Sendable (AVAudioPCMBuffer) -> Void)?

    /// Callback disparado com a amplitude normalizada (0.0 a 1.0) para alimentar a pílula HUD.
    public var onAmplitudeChanged: (@Sendable (Float) -> Void)?

    /// Callback disparado quando ocorre um erro na captação ou conversão de áudio.
    public var onError: (@Sendable (Error) -> Void)?

    public var isCapturing: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isCapturing
    }

    public init(engine: AVAudioEngine = AVAudioEngine()) {
        self.engine = engine
        // Formato alvo padrão para reconhecimento de fala offline de alta precisão
        self.targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        )!
    }

    deinit {
        stopCapture()
    }

    /// Inicia a captação de áudio do microfone padrão.
    public func startCapture() throws {
        lock.lock()
        defer { lock.unlock() }

        guard !_isCapturing else { return }

        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        // Prepara conversor se o formato de hardware for diferente de 16kHz mono
        if inputFormat != targetFormat {
            self.converter = AVAudioConverter(from: inputFormat, to: targetFormat)
            if self.converter == nil {
                let error = AudioCaptureError.converterInitializationFailed
                Self.logger.error("Falha ao inicializar AVAudioConverter de \(inputFormat) para \(self.targetFormat)")
                onError?(error)
                throw error
            }
        } else {
            self.converter = nil
        }

        // Instala tap de áudio em memória (tamanho de buffer: 1024 frames)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            guard let self = self else { return }
            self.processCapturedBuffer(buffer)
        }

        engine.prepare()
        do {
            try engine.start()
            _isCapturing = true
            Self.logger.info("Captação de áudio iniciada com sucesso")
        } catch {
            Self.logger.error("Falha ao iniciar AVAudioEngine: \(error.localizedDescription, privacy: .public)")
            onError?(error)
            throw error
        }
    }

    /// Pára a captação de áudio e liberta os nós do AVAudioEngine.
    public func stopCapture() {
        lock.lock()
        defer { lock.unlock() }

        guard _isCapturing else { return }

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        _isCapturing = false
        Self.logger.info("Captação de áudio parada")
    }

    /// Processa o buffer capturado em RAM: calcula amplitude e converte para 16kHz mono se necessário.
    public func processCapturedBuffer(_ buffer: AVAudioPCMBuffer) {
        let amplitude = Self.calculateRMS(buffer: buffer)
        
        // Dispara callback de amplitude para o HUD
        if let onAmplitude = onAmplitudeChanged {
            onAmplitude(amplitude)
        }

        // Processa o buffer para o motor de reconhecimento
        if let converter = self.converter {
            if let convertedBuffer = convertBuffer(buffer, using: converter) {
                onBufferCaptured?(convertedBuffer)
            }
            // Se conversão falhar, convertBuffer já registou o erro via logger e onError.
            // Não emitimos buffer corrompido para não quebrar o motor de reconhecimento.
        } else {
            onBufferCaptured?(buffer)
        }
    }

    private final class ConversionState: @unchecked Sendable {
        var hasProvidedData = false
        let buffer: AVAudioPCMBuffer

        init(buffer: AVAudioPCMBuffer) {
            self.buffer = buffer
        }
    }

    /// Converte um buffer de áudio em memória para o formato alvo de 16kHz mono.
    private func convertBuffer(_ inputBuffer: AVAudioPCMBuffer, using converter: AVAudioConverter) -> AVAudioPCMBuffer? {
        let sampleRateRatio = targetFormat.sampleRate / inputBuffer.format.sampleRate
        let outputFrameCapacity = AVAudioFrameCount(Double(inputBuffer.frameLength) * sampleRateRatio + 512)

        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outputFrameCapacity) else {
            Self.logger.error("Falha ao alocar AVAudioPCMBuffer de saída na conversão")
            onError?(AudioCaptureError.bufferAllocationFailed)
            return nil
        }

        var error: NSError?
        let state = ConversionState(buffer: inputBuffer)

        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            if !state.hasProvidedData {
                state.hasProvidedData = true
                outStatus.pointee = .haveData
                return state.buffer
            } else {
                outStatus.pointee = .noDataNow
                return nil
            }
        }

        let status = converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)
        if status == .error || error != nil {
            let desc = error?.localizedDescription ?? "Status code: \(status.rawValue)"
            Self.logger.error("Falha ao converter buffer de áudio via AVAudioConverter: \(desc, privacy: .public)")
            onError?(AudioCaptureError.conversionFailed(desc))
            return nil
        }

        return outputBuffer
    }

    /// Calcula a amplitude RMS (Root Mean Square) do buffer e normaliza entre 0.0 e 1.0.
    public static func calculateRMS(buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return 0.0 }
        let channelCount = Int(buffer.format.channelCount)
        let frameLength = Int(buffer.frameLength)

        guard frameLength > 0, channelCount > 0 else { return 0.0 }

        var totalSum: Float = 0.0
        for channel in 0..<channelCount {
            let data = channelData[channel]
            var channelSum: Float = 0.0
            for i in 0..<frameLength {
                let sample = data[i]
                channelSum += sample * sample
            }
            totalSum += channelSum
        }

        let rms = sqrt(totalSum / Float(frameLength * channelCount))
        // Escala normalizada para sensibilidade ergonómica na UI
        let scaled = min(max(rms * 4.0, 0.0), 1.0)
        return scaled
    }
}
