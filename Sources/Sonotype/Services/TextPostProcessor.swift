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

/// Pipeline integrado de pós-processamento de texto do Sonotype.
/// Coordena a remoção de hesitações, conversão de comandos orais e capitalização correta.
public final class TextPostProcessor: Sendable {
    public let fillerService: FillerWordFilterService
    public let punctuationService: PunctuationService
    public let capitalizationService: CapitalizationService

    public init(
        fillerService: FillerWordFilterService = FillerWordFilterService(),
        punctuationService: PunctuationService = PunctuationService(),
        capitalizationService: CapitalizationService = CapitalizationService()
    ) {
        self.fillerService = fillerService
        self.punctuationService = punctuationService
        self.capitalizationService = capitalizationService
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

        // 2. Comandos orais e normalização de pontuação
        result = punctuationService.process(
            text: result,
            language: language,
            oralCommandsEnabled: options.oralCommandsEnabled,
            autoFinalPeriod: options.autoFinalPeriodEnabled
        )

        // 3. Capitalização no início do texto e de frases
        if options.capitalizationEnabled {
            result = capitalizationService.capitalize(text: result, locale: language.locale)
        }

        // 4. Limpeza final de espaços redundantes
        return result.trimmingCharacters(in: .whitespaces)
    }
}
