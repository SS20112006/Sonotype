import AppKit
import Foundation
import os

/// Protocolo de abstração para emissão de feedback auditivo da aplicação.
@MainActor
public protocol FeedbackSoundPlaying: AnyObject, Sendable {
    var isEnabled: Bool { get set }
    func playStartSound()
    func playStopSound()
    func playCancelSound()
}

/// Implementação nativa macOS utilizando sons semânticos do sistema (NSSound).
/// Emite sons sutis ao iniciar, parar e cancelar a gravação, cumprindo os princípios do Apple HIG.
@MainActor
public final class SystemFeedbackSoundPlayer: FeedbackSoundPlaying, Sendable {
    private static let logger = Logger(subsystem: "com.sonotype.app", category: "FeedbackSoundPlayer")

    public var isEnabled: Bool

    public init(isEnabled: Bool = true) {
        self.isEnabled = isEnabled
    }

    /// Som sutil emitido ao iniciar a escuta (Pop).
    public func playStartSound() {
        guard isEnabled else { return }
        playSound(named: "Pop")
    }

    /// Som sutil emitido ao concluir a captura de áudio (Purr).
    public func playStopSound() {
        guard isEnabled else { return }
        playSound(named: "Purr")
    }

    /// Som discreto emitido ao cancelar expressamente a gravação (Basso).
    public func playCancelSound() {
        guard isEnabled else { return }
        playSound(named: "Basso")
    }

    private func playSound(named name: String) {
        if let sound = NSSound(named: NSSound.Name(name)) {
            sound.play()
        } else {
            Self.logger.warning("Som de sistema '\(name, privacy: .public)' não encontrado. Recorrendo a NSSound.beep().")
            NSSound.beep()
        }
    }
}
