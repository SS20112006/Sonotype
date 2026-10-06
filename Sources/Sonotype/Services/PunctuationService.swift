import Foundation

/// Serviço de pontuação inteligente e processamento de comandos orais nos idiomas suportados.
/// Converte comandos falados (ex: "vírgula", "ponto final", "nova linha") nos respetivos carateres tipográficos
/// e assegura a correta normalização de espaçamentos em conformidade com as regras gramaticais.
public final class PunctuationService: Sendable {

    /// Comando oral mapeado para o seu símbolo ou carater de controlo correspondente.
    private struct OralCommand: Sendable {
        let pattern: String
        let replacement: String
        let isBlockDelimited: Bool

        init(_ pattern: String, _ replacement: String, isBlockDelimited: Bool = true) {
            self.pattern = pattern
            self.replacement = replacement
            self.isBlockDelimited = isBlockDelimited
        }
    }

    public init() {}

    /// Processa o texto aplicando comandos orais e normalização tipográfica.
    ///
    /// - Parameters:
    ///   - text: Texto original transcrito.
    ///   - language: Idioma correspondente ao texto.
    ///   - oralCommandsEnabled: Define se os comandos orais devem ser convertidos em pontuação.
    ///   - autoFinalPeriod: Define se deve ser inserido ponto final se o texto terminar sem pontuação.
    /// - Returns: Texto devidamente pontuado e formatado.
    public func process(
        text: String,
        language: SpeechLanguage = .portuguesePT,
        oralCommandsEnabled: Bool = true,
        autoFinalPeriod: Bool = false
    ) -> String {
        guard !text.isEmpty else { return "" }

        var result = text

        if oralCommandsEnabled {
            result = applyOralCommands(to: result, language: language)
        }

        result = normalizePunctuationSpacing(result)

        if autoFinalPeriod {
            result = applyFinalPunctuationIfNeeded(result)
        }

        return result
    }

    // MARK: - Comandos Orais por Idioma

    private func applyOralCommands(to input: String, language: SpeechLanguage) -> String {
        var text = input

        let commands = language.isPortuguese
            ? portugueseOralCommands()
            : englishOralCommands()

        for command in commands {
            let pattern = command.isBlockDelimited
                ? "(?i)\\b\(command.pattern)\\b"
                : "(?i)\(command.pattern)"

            text = replaceRegex(pattern: pattern, in: text, with: command.replacement)
        }

        return text
    }

    /// Tabela de comandos orais em Português ordenados estrategicamente por especificidade decrescente.
    private func portugueseOralCommands() -> [OralCommand] {
        [
            // Quebras de parágrafo e linha (alta prioridade)
            OralCommand(#"novo\s+par[aá]grafo|par[aá]grafo\s+novo"#, "\n\n"),
            OralCommand(#"nova\s+linha|mudar\s+de\s+linha|linha\s+nova"#, "\n"),

            // Pontuação composta antes de simples
            OralCommand(#"ponto\s+e\s+v[ií]rgula"#, "; "),
            OralCommand(#"ponto\s+de\s+interroga[cç][aã]o"#, "? "),
            OralCommand(#"ponto\s+de\s+exclama[cç][aã]o"#, "! "),
            OralCommand(#"ponto\s+final"#, ". "),
            OralCommand(#"dois\s+pontos"#, ": "),
            OralCommand(#"tr[eê]s\s+pontos|retic[eê]ncias"#, "... "),

            // Pontuação simples (com proteção contra falsos positivos como "ponto de vista", "ponto turístico")
            OralCommand(#"v[ií]rgula"#, ", "),
            OralCommand(#"ponto(?!\s+(?:de|da|do|dos|das|tur[ií]stico|estrat[eé]gico|central|fraco|forte|cardeal|vista|partida|cr[ií]tico))"#, ". "),

            // Aspas (abrir consome espaço posterior, fechar consome espaço anterior)
            OralCommand(#"\b(?:abrir|abre)\s+aspas\s*"#, "\"", isBlockDelimited: false),
            OralCommand(#"\s*(?:fechar|fecha)\s+aspas\b"#, "\"", isBlockDelimited: false),

            // Parênteses (abrir consome espaço posterior, fechar consome espaço anterior)
            OralCommand(#"\b(?:abrir|abre)\s+par[eê]nteses\s*"#, "(", isBlockDelimited: false),
            OralCommand(#"\s*(?:fechar|fecha)\s+par[eê]nteses\b"#, ")", isBlockDelimited: false),

            // Símbolos especiais
            OralCommand(#"travess[aã]o|h[ií]fen"#, " - ")
        ]
    }

    /// Tabela de comandos orais em Inglês ordenados por especificidade decrescente.
    private func englishOralCommands() -> [OralCommand] {
        [
            // Parágrafo e quebra de linha
            OralCommand(#"new\s+paragraph"#, "\n\n"),
            OralCommand(#"new\s+line|line\s+break"#, "\n"),

            // Pontuação composta antes de simples
            OralCommand(#"question\s+mark"#, "? "),
            OralCommand(#"exclamation\s+(?:mark|point)"#, "! "),
            OralCommand(#"full\s+stop"#, ". "),
            OralCommand(#"semicolon"#, "; "),
            OralCommand(#"colon"#, ": "),
            OralCommand(#"three\s+dots|ellipsis"#, "... "),

            // Pontuação simples (com proteção contra expressões nominais como "period of time")
            OralCommand(#"comma"#, ", "),
            OralCommand(#"period(?!\s+of\s+time)"#, ". "),

            // Aspas (abrir consome espaço posterior, fechar consome espaço anterior)
            OralCommand(#"\bopen\s+quotes?\s*|\bopen\s+quotation\s*"#, "\"", isBlockDelimited: false),
            OralCommand(#"\s*close\s+quotes?\b|\s*close\s+quotation\b"#, "\"", isBlockDelimited: false),

            // Parênteses (abrir consome espaço posterior, fechar consome espaço anterior)
            OralCommand(#"\bopen\s+(?:parenthesis|bracket)\s*"#, "(", isBlockDelimited: false),
            OralCommand(#"\s*close\s+(?:parenthesis|bracket)\b"#, ")", isBlockDelimited: false),

            // Símbolos
            OralCommand(#"dash|hyphen"#, " - ")
        ]
    }

    // MARK: - Normalização Tipográfica

    /// Ajusta espaçamento e colisão de pontuações de acordo com regras tipográficas.
    public func normalizePunctuationSpacing(_ input: String) -> String {
        var text = input

        // 1. Elimina espaços que antecedem pontuação de encerramento ou pausa
        text = replaceRegex(pattern: #"[ \t]+([,.:;?!])"#, in: text, with: "$1")

        // 2. Garante um espaço após pontuação se seguida imediatamente por letra ou número (exceto quebras de linha)
        text = replaceRegex(pattern: #"([,.:;?!])([A-Za-z0-9À-ÿ])"#, in: text, with: "$1 $2")

        // 3. Normaliza reticências e pontuações consecutivas acidentais
        text = replaceRegex(pattern: #"\.{4,}"#, in: text, with: "...")
        text = replaceRegex(pattern: #"(?<!\.)\.{2}(?!\.)"#, in: text, with: ".")
        text = replaceRegex(pattern: #",{2,}"#, in: text, with: ",")
        text = replaceRegex(pattern: #"!{2,}"#, in: text, with: "!")
        text = replaceRegex(pattern: #"\?{2,}"#, in: text, with: "?")

        // 4. Aspas e Parênteses: sem espaços no interior
        text = replaceRegex(pattern: #"\"\s+([^"]+?)\s+\""#, in: text, with: "\"$1\"")
        text = replaceRegex(pattern: #"\(\s+"#, in: text, with: "(")
        text = replaceRegex(pattern: #"\s+\)"#, in: text, with: ")")

        // 5. Quebras de linha: limpa espaços no final de linha e início de nova linha
        text = replaceRegex(pattern: #"[ \t]+\n"#, in: text, with: "\n")
        text = replaceRegex(pattern: #"\n[ \t]+"#, in: text, with: "\n")

        // 6. Normaliza múltiplos espaços horizontais mantendo as quebras de linha
        text = replaceRegex(pattern: #"[ \t]{2,}"#, in: text, with: " ")

        return text.trimmingCharacters(in: .whitespaces)
    }

    /// Garante que o texto termina com ponto final caso não possua pontuação terminal.
    private func applyFinalPunctuationIfNeeded(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return text }

        let terminalPunctuation: Set<Character> = [".", "!", "?", ":", ";", "…"]
        if let lastChar = trimmed.last, !terminalPunctuation.contains(lastChar) {
            return text + "."
        }
        return text
    }

    // MARK: - Helper Regex Seguro

    private func replaceRegex(pattern: String, in text: String, with template: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return text
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: template)
    }
}
