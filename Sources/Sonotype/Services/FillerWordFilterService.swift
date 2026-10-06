import Foundation

/// Serviço de deteção e remoção de palavras e sons de hesitação (filler words).
/// Suporta filtros dedicados para Português (pt-PT / pt-BR) e Inglês (en-US / en-GB).
public final class FillerWordFilterService: Sendable {

    public init() {}

    /// Remove hesitações e muletas linguísticas do texto fornecido com base no idioma.
    ///
    /// - Parameters:
    ///   - text: Texto cru resultante do reconhecimento de fala.
    ///   - language: Idioma correspondente ao texto transcrito.
    /// - Returns: Texto filtrado e normalizado sem as hesitações detetadas.
    public func filter(text: String, language: SpeechLanguage = .portuguesePT) -> String {
        guard !text.isEmpty else { return "" }

        var result = text

        if language.isPortuguese {
            result = removePortugueseFillers(from: result)
        } else if language.isEnglish {
            result = removeEnglishFillers(from: result)
        } else {
            // Se idioma for ambíguo, aplica ambos os filtros básicos
            result = removePortugueseFillers(from: result)
            result = removeEnglishFillers(from: result)
        }

        return cleanupPunctuationAndSpacing(result)
    }

    // MARK: - Filtros Específicos para Português

    private func removePortugueseFillers(from input: String) -> String {
        var text = input

        // 1. Expressões compostas de hesitação
        let compoundPatterns = [
            #"(?i)(?:^|(?<=[\s,]))\s*tipo\s+assim(?=[\s,.:;?!]|$)"#,
            #"(?i)(?:^|(?<=[\s,]))\s*ou\s+seja(?=[\s,.:;?!]|$)"#
        ]

        for pattern in compoundPatterns {
            text = replaceRegex(pattern: pattern, in: text, with: "")
        }

        // 2. Hesitações orais puras em Português:
        // hum, humm, hmm, hm, ãh, hã, ah, ahh, éé, éh, eh, ahn, uhm, er, erm
        // Utiliza delimitadores explícitos de fronteira para compatibilidade Unicode integral (diacríticos)
        let ptPureFillers = #"(?i)(?:^|(?<=[\s,.:;?!]))\s*(?:h+u+m+|h+m+|ãh|hã|a+h+|éé|éh|eh|ahn|uhm|er|erm)(?=[\s,.:;?!]|$)"#
        text = replaceRegex(pattern: ptPureFillers, in: text, with: "")

        // 3. Muleta "tipo" quando usada como filler (entre vírgulas, pausas ou início de oração não seguida de "de/da/do/que")
        // Exemplo: ", tipo," -> "" ou no início "tipo, vamos" -> "vamos"
        let ptTipoFiller = #"(?i)(?:^|(?<=[\s,]))\s*tipo\s*(?=,|$)"#
        text = replaceRegex(pattern: ptTipoFiller, in: text, with: "")

        return text
    }

    // MARK: - Filtros Específicos para Inglês

    private func removeEnglishFillers(from input: String) -> String {
        var text = input

        // 1. Hesitações orais puras em Inglês:
        // um, umm, uh, uhh, er, erm, ah, ahh, uhm
        let enPureFillers = #"(?i)(?:^|(?<=[\s,.:;?!]))\s*(?:u+m+|u+h+|er|erm|a+h+|uhm)(?=[\s,.:;?!]|$)"#
        text = replaceRegex(pattern: enPureFillers, in: text, with: "")

        // 2. Muleta "like" quando isolada por pontuação ou no início com vírgula (evita "I like" ou "like a")
        let enLikeFiller = #"(?i)(?:^|(?<=[\s,]))\s*like\s*(?=,|$)"#
        text = replaceRegex(pattern: enLikeFiller, in: text, with: "")

        return text
    }

    // MARK: - Normalização de Espaçamento e Pontuação Resídua

    /// Limpa pontuação duplicada ou espaços redundantes resultantes da remoção de palavras.
    private func cleanupPunctuationAndSpacing(_ input: String) -> String {
        var text = input

        // Substitui vírgulas duplas ou vírgula antes de ponto
        text = replaceRegex(pattern: #",\s*,"#, in: text, with: ",")
        text = replaceRegex(pattern: #",\s*\."#, in: text, with: ".")
        text = replaceRegex(pattern: #",\s*\?"#, in: text, with: "?")
        text = replaceRegex(pattern: #",\s*!"#, in: text, with: "!")

        // Remove vírgula órfã no início do texto
        text = replaceRegex(pattern: #"^\s*,\s*"#, in: text, with: "")

        // Remove múltiplos espaços mantendo quebras de linha
        text = replaceRegex(pattern: #"[ \t]{2,}"#, in: text, with: " ")

        // Remove espaços antes de pontuação
        text = replaceRegex(pattern: #"\s+([,.:;?!])"#, in: text, with: "$1")

        return text.trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Helper Regex Seguro (ReDoS-Safe)

    private func replaceRegex(pattern: String, in text: String, with template: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return text
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: template)
    }
}
