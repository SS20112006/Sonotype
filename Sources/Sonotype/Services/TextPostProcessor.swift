import Foundation

/// Opções de configuração para o pós-processamento do texto ditado.
public struct PostProcessingOptions: Sendable, Equatable {
    /// Ativa ou desativa a filtragem automática de hesitações ("hum", "ãh", "um", etc.).
    public var fillerFilterEnabled: Bool

    /// Ativa ou desativa a conversão de comandos orais em pontuação ("vírgula", "ponto final", etc.).
    public var oralCommandsEnabled: Bool

    /// Ativa ou desativa a capitalização automática no início de frases.
    public var capitalizationEnabled: Bool

    /// Adiciona automaticamente ponto final se o texto terminar sem pontuação terminal.
    public var autoFinalPeriodEnabled: Bool

    public init(
        fillerFilterEnabled: Bool = true,
        oralCommandsEnabled: Bool = true,
        capitalizationEnabled: Bool = true,
        autoFinalPeriodEnabled: Bool = false
    ) {
        self.fillerFilterEnabled = fillerFilterEnabled
        self.oralCommandsEnabled = oralCommandsEnabled
        self.capitalizationEnabled = capitalizationEnabled
        self.autoFinalPeriodEnabled = autoFinalPeriodEnabled
    }

    /// Configuração padrão recomendada de fábrica.
    public static let `default` = PostProcessingOptions()
}

/// Normalizador de termos técnicos em inglês comuns em ambientes de desenvolvimento de software,
/// corrigindo distorções fonéticas ou separações indevidas geradas pelo motor de fala ao misturar inglês com português.
public struct TechnicalTermNormalizer: Sendable {
    public init() {}

    private struct TermRule: Sendable {
        let pattern: String
        let replacement: String
    }

    private static let rules: [TermRule] = [
        // deploy
        TermRule(pattern: #"(?i)\bde\s+play\b"#, replacement: "deploy"),
        TermRule(pattern: #"(?i)\bde\s+ploy\b"#, replacement: "deploy"),
        TermRule(pattern: #"(?i)\bdeplay\b"#, replacement: "deploy"),
        TermRule(pattern: #"(?i)\bdeploied\b"#, replacement: "deployed"),
        TermRule(pattern: #"(?i)\bde\s+ploied\b"#, replacement: "deployed"),
        TermRule(pattern: #"(?i)\bde\s+ployment\b"#, replacement: "deployment"),
        TermRule(pattern: #"(?i)\bdeplayment\b"#, replacement: "deployment"),

        // build
        TermRule(pattern: #"(?i)\bbilde\b"#, replacement: "build"),
        TermRule(pattern: #"(?i)\bbiuld\b"#, replacement: "build"),

        // open
        TermRule(pattern: #"(?i)\bopem\b"#, replacement: "open"),
        TermRule(pattern: #"(?i)\boupen\b"#, replacement: "open"),

        // pull request & PR
        TermRule(pattern: #"(?i)\bpula\s+requeste?\b"#, replacement: "pull request"),
        TermRule(pattern: #"(?i)\bpull\s+requeste\b"#, replacement: "pull request"),
        TermRule(pattern: #"(?i)\bpulo\s+request\b"#, replacement: "pull request"),
        TermRule(pattern: #"(?i)\bpe\s*[- ]\s*erre\b"#, replacement: "PR"),
        TermRule(pattern: #"(?i)\bpe\s*[- ]\s*erres\b"#, replacement: "PRs"),

        // pipeline
        TermRule(pattern: #"(?i)\bpipe\s+line\b"#, replacement: "pipeline"),
        TermRule(pattern: #"(?i)\bpipelaine\b"#, replacement: "pipeline"),

        // architecture / web terms
        TermRule(pattern: #"(?i)\bback\s+end\b"#, replacement: "backend"),
        TermRule(pattern: #"(?i)\bfront\s+end\b"#, replacement: "frontend"),
        TermRule(pattern: #"(?i)\bfull\s+stack\b"#, replacement: "fullstack"),
        TermRule(pattern: #"(?i)\bcode\s+base\b"#, replacement: "codebase"),
        TermRule(pattern: #"(?i)\bend\s+points\b"#, replacement: "endpoints"),
        TermRule(pattern: #"(?i)\bend\s+point\b"#, replacement: "endpoint"),
        TermRule(pattern: #"(?i)\bhot\s+fix\b"#, replacement: "hotfix"),
        TermRule(pattern: #"(?i)\bbug\s+fix\b"#, replacement: "bugfix")
    ]

    public func normalize(_ input: String) -> String {
        var text = input
        for rule in Self.rules {
            guard let regex = try? NSRegularExpression(pattern: rule.pattern, options: []) else { continue }
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            text = regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: rule.replacement)
        }
        return text
    }
}

/// Pipeline integrado de pós-processamento de texto do Sonotype.
/// Coordena a remoção de hesitações, conversão de comandos orais e capitalização correta.
public final class TextPostProcessor: Sendable {
    public let fillerService: FillerWordFilterService
    public let punctuationService: PunctuationService
    public let capitalizationService: CapitalizationService
    public let technicalNormalizer: TechnicalTermNormalizer

    public init(
        fillerService: FillerWordFilterService = FillerWordFilterService(),
        punctuationService: PunctuationService = PunctuationService(),
        capitalizationService: CapitalizationService = CapitalizationService(),
        technicalNormalizer: TechnicalTermNormalizer = TechnicalTermNormalizer()
    ) {
        self.fillerService = fillerService
        self.punctuationService = punctuationService
        self.capitalizationService = capitalizationService
        self.technicalNormalizer = technicalNormalizer
    }

    /// Executa o pipeline completo de transformação do texto cru num texto limpo e natural.
    ///
    /// - Parameters:
    ///   - text: Texto transcrito bruto do motor de fala.
    ///   - language: Idioma detetado ou selecionado para a sessão.
    ///   - options: Opções de ativação dos filtros e formatações.
    /// - Returns: Texto polido pronto para injeção no cursor.
    public func process(
        text: String,
        language: SpeechLanguage = .portuguesePT,
        options: PostProcessingOptions = .default
    ) -> String {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return ""
        }

        var result = text

        // 1. Filtragem de hesitações e muletas linguísticas
        if options.fillerFilterEnabled {
            result = fillerService.filter(text: result, language: language)
        }

        // 2. Normalização de termos técnicos em inglês
        result = technicalNormalizer.normalize(result)

        // 3. Comandos orais e normalização de pontuação
        result = punctuationService.process(
            text: result,
            language: language,
            oralCommandsEnabled: options.oralCommandsEnabled,
            autoFinalPeriod: options.autoFinalPeriodEnabled
        )

        // 4. Capitalização no início do texto e de frases
        if options.capitalizationEnabled {
            result = capitalizationService.capitalize(text: result, locale: language.locale)
        }

        // 5. Limpeza final de espaços redundantes
        return result.trimmingCharacters(in: .whitespaces)
    }
}
