import Foundation
import SwiftData

/// Registo persistente de transcrição de voz.
///
/// PONYTAIL & PRIVACIDADE INVARIANTE:
/// Zero persistência de áudio em disco. Este modelo armazena estritamente o texto transcrito,
/// contagem de palavras, data/hora e metadados de sessão. Não existem URLs de ficheiro,
/// buffers em disco nem dados binários de áudio.
@Model
public final class TranscriptionRecord {
    @Attribute(.unique) public var id: UUID
    public var text: String
    public var createdAt: Date
    public var duration: TimeInterval
    public var wordCount: Int
    public var detectedLanguage: String

    public init(
        id: UUID = UUID(),
        text: String,
        createdAt: Date = Date(),
        duration: TimeInterval = 0.0,
        wordCount: Int? = nil,
        detectedLanguage: String = "pt-PT"
    ) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
        self.duration = duration
        self.wordCount = wordCount ?? Self.calculateWordCount(text)
        self.detectedLanguage = detectedLanguage
    }

    /// Calcula a contagem de palavras ignorando múltiplos espaços e quebras de linha.
    public static func calculateWordCount(_ text: String) -> Int {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }
        let components = trimmed.split { $0.isWhitespace || $0.isNewline }
        return components.count
    }
}
