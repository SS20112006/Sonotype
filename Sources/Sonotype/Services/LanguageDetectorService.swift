import Foundation
import NaturalLanguage

/// Idiomas suportados pelo Sonotype (exclusivamente Português e Inglês).
public enum SpeechLanguage: String, CaseIterable, Sendable {
    case portuguesePT = "pt-PT"
    case portugueseBR = "pt-BR"
    case englishUS = "en-US"
    case englishGB = "en-GB"

    public var isPortuguese: Bool {
        self == .portuguesePT || self == .portugueseBR
    }

    public var isEnglish: Bool {
        self == .englishUS || self == .englishGB
    }

    public var locale: Locale {
        Locale(identifier: rawValue)
    }

    public var displayName: String {
        switch self {
        case .portuguesePT: return "Português (Portugal)"
        case .portugueseBR: return "Português (Brasil)"
        case .englishUS: return "Inglês (EUA)"
        case .englishGB: return "Inglês (Reino Unido)"
        }
    }
}

/// Serviço de deteção inteligente de idioma entre Português e Inglês.
public final class LanguageDetectorService: Sendable {
    public let defaultLanguage: SpeechLanguage

    public init(defaultLanguage: SpeechLanguage = .portuguesePT) {
        self.defaultLanguage = defaultLanguage
    }

    /// Deteta o idioma dominante entre Português e Inglês a partir de uma hipótese de texto.
    public func detectLanguage(from text: String) -> SpeechLanguage {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return defaultLanguage
        }

        let recognizer = NLLanguageRecognizer()
        recognizer.processString(trimmed)

        let hypotheses = recognizer.languageHypotheses(withMaximum: 3)
        let ptConfidence = hypotheses[.portuguese] ?? 0.0
        let enConfidence = hypotheses[.english] ?? 0.0

        if ptConfidence > enConfidence && ptConfidence >= 0.15 {
            return defaultLanguage.isPortuguese ? defaultLanguage : .portuguesePT
        } else if enConfidence > ptConfidence && enConfidence >= 0.15 {
            return defaultLanguage.isEnglish ? defaultLanguage : .enUSDefault
        }

        if let dominant = recognizer.dominantLanguage {
            if dominant == .portuguese {
                return defaultLanguage.isPortuguese ? defaultLanguage : .portuguesePT
            } else if dominant == .english {
                return defaultLanguage.isEnglish ? defaultLanguage : .englishUS
            }
        }

        return defaultLanguage
    }

    /// Retorna as pontuações de confiança para Português e Inglês.
    public func confidenceScores(for text: String) -> (portuguese: Double, english: Double) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return (0.0, 0.0) }

        let recognizer = NLLanguageRecognizer()
        recognizer.processString(trimmed)

        let hypotheses = recognizer.languageHypotheses(withMaximum: 4)
        let pt = hypotheses[.portuguese] ?? 0.0
        let en = hypotheses[.english] ?? 0.0
        return (portuguese: pt, english: en)
    }
}

private extension SpeechLanguage {
    static var enUSDefault: SpeechLanguage {
        .englishUS
    }
}
