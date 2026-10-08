import Foundation
import AppKit

/// Modo de acionamento do atalho de gravação configurado pelo utilizador.
public enum RecordingTriggerMode: String, Sendable, CaseIterable, Codable, Equatable {
    /// Modo de alternância mãos-livres: pressionar para iniciar, pressionar para parar.
    case toggle
    /// Modo Push-to-Talk: manter premido para gravar, soltar para processar e inserir.
    case pushToTalk

    public var displayName: String {
        switch self {
        case .toggle:
            return "Alternância (Mãos Livres)"
        case .pushToTalk:
            return "Manter para Falar (Push-to-Talk)"
        }
    }

    public var hotkeyMode: HotkeyMode {
        switch self {
        case .toggle:
            return .toggle
        case .pushToTalk:
            return .pushToTalk
        }
    }
}

/// Modo de seleção e resolução de idioma de fala no Sonotype.
public enum LanguageSelectionMode: String, Sendable, CaseIterable, Codable, Equatable {
    /// Deteção automática inteligente entre Português e Inglês com base na transcrição.
    case autoDetect
    /// Fixado estritamente em Português (pt-PT).
    case fixedPT
    /// Fixado estritamente em Inglês (en-US).
    case fixedEN

    public var displayName: String {
        switch self {
        case .autoDetect:
            return "Deteção Automática (PT/EN)"
        case .fixedPT:
            return "Português Fixo (pt-PT)"
        case .fixedEN:
            return "Inglês Fixo (en-US)"
        }
    }

    public var badgeTitle: String {
        switch self {
        case .autoDetect:
            return "PT / EN"
        case .fixedPT:
            return "PT"
        case .fixedEN:
            return "EN"
        }
    }

    public var fixedSpeechLanguage: SpeechLanguage? {
        switch self {
        case .autoDetect:
            return nil
        case .fixedPT:
            return .portuguesePT
        case .fixedEN:
            return .englishUS
        }
    }
}

/// Modo de apresentação e retorno visual da pílula flutuante HUD.
public enum HUDFeedbackMode: String, Sendable, CaseIterable, Codable, Equatable {
    /// Apresenta exclusivamente a forma de onda / ponto luminoso com estado.
    case waveformOnly
    /// Apresenta transcrição ao vivo em tempo real na pílula.
    case liveTranscription
    /// Sem pílula intermédia, insere diretamente na posição do cursor ativo.
    case directCursor

    public var displayName: String {
        switch self {
        case .waveformOnly:
            return "Apenas Forma de Onda"
        case .liveTranscription:
            return "Transcrição ao Vivo"
        case .directCursor:
            return "Direto no Cursor"
        }
    }
}

/// Visibilidade granular das métricas analíticas no Dashboard.
public struct DashboardMetricsVisibility: Codable, Equatable, Sendable {
    public var timeSaved: Bool
    public var totalWords: Bool
    public var sessionsCount: Bool
    public var speakingSpeed: Bool
    public var languageBreakdown: Bool

    public init(
        timeSaved: Bool = true,
        totalWords: Bool = true,
        sessionsCount: Bool = true,
        speakingSpeed: Bool = true,
        languageBreakdown: Bool = true
    ) {
        self.timeSaved = timeSaved
        self.totalWords = totalWords
        self.sessionsCount = sessionsCount
        self.speakingSpeed = speakingSpeed
        self.languageBreakdown = languageBreakdown
    }

    public init(
        showTimeSaved: Bool,
        showTotalWords: Bool = true,
        showSessionsCount: Bool = true,
        showSpeakingSpeed: Bool = true,
        showLanguageBreakdown: Bool = true
    ) {
        self.timeSaved = showTimeSaved
        self.totalWords = showTotalWords
        self.sessionsCount = showSessionsCount
        self.speakingSpeed = showSpeakingSpeed
        self.languageBreakdown = showLanguageBreakdown
    }

    public var showTimeSaved: Bool {
        get { timeSaved }
        set { timeSaved = newValue }
    }

    public var showTotalWords: Bool {
        get { totalWords }
        set { totalWords = newValue }
    }

    public var showSessionsCount: Bool {
        get { sessionsCount }
        set { sessionsCount = newValue }
    }

    public var showSpeakingSpeed: Bool {
        get { speakingSpeed }
        set { speakingSpeed = newValue }
    }

    public var showLanguageBreakdown: Bool {
        get { languageBreakdown }
        set { languageBreakdown = newValue }
    }

    public static let `default` = DashboardMetricsVisibility()
}

/// Conjunto consolidado de preferências da aplicação Sonotype.
public struct AppPreferences: Codable, Equatable, Sendable {
    public var launchAtLogin: Bool
    public var dockVisibilityMode: DockVisibilityMode
    public var triggerMode: RecordingTriggerMode
    public var globalHotkey: GlobalHotkey
    public var silenceTimeoutSeconds: Double?
    public var soundFeedbackEnabled: Bool
    public var languageSelectionMode: LanguageSelectionMode
    public var hudFeedbackMode: HUDFeedbackMode
    public var oralCommandsEnabled: Bool
    public var fillerFilterEnabled: Bool
    public var autoCapitalizationEnabled: Bool
    public var autoFinalPeriodEnabled: Bool
    public var clipboardSafetyMode: ClipboardSafetyMode
    public var textInjectionStrategy: TextInjectionStrategy
    public var metricsVisibility: DashboardMetricsVisibility

    public init(
        launchAtLogin: Bool = false,
        dockVisibilityMode: DockVisibilityMode = .dynamic,
        triggerMode: RecordingTriggerMode = .toggle,
        globalHotkey: GlobalHotkey = .defaultToggle,
        silenceTimeoutSeconds: Double? = 45.0,
        soundFeedbackEnabled: Bool = true,
        languageSelectionMode: LanguageSelectionMode = .autoDetect,
        hudFeedbackMode: HUDFeedbackMode = .waveformOnly,
        oralCommandsEnabled: Bool = true,
        fillerFilterEnabled: Bool = true,
        autoCapitalizationEnabled: Bool = true,
        autoFinalPeriodEnabled: Bool = false,
        clipboardSafetyMode: ClipboardSafetyMode = .pasteAndKeep,
        textInjectionStrategy: TextInjectionStrategy = .accessibilityWithFallback,
        metricsVisibility: DashboardMetricsVisibility = DashboardMetricsVisibility()
    ) {
        self.launchAtLogin = launchAtLogin
        self.dockVisibilityMode = dockVisibilityMode
        self.triggerMode = triggerMode
        self.globalHotkey = globalHotkey
        self.silenceTimeoutSeconds = silenceTimeoutSeconds
        self.soundFeedbackEnabled = soundFeedbackEnabled
        self.languageSelectionMode = languageSelectionMode
        self.hudFeedbackMode = hudFeedbackMode
        self.oralCommandsEnabled = oralCommandsEnabled
        self.fillerFilterEnabled = fillerFilterEnabled
        self.autoCapitalizationEnabled = autoCapitalizationEnabled
        self.autoFinalPeriodEnabled = autoFinalPeriodEnabled
        self.clipboardSafetyMode = clipboardSafetyMode
        self.textInjectionStrategy = textInjectionStrategy
        self.metricsVisibility = metricsVisibility
    }

    public static let `default` = AppPreferences()

    /// Gera o conjunto de opções de pós-processamento alinhado com as preferências atuais.
    public var postProcessingOptions: PostProcessingOptions {
        PostProcessingOptions(
            fillerFilterEnabled: fillerFilterEnabled,
            oralCommandsEnabled: oralCommandsEnabled,
            capitalizationEnabled: autoCapitalizationEnabled,
            autoFinalPeriodEnabled: autoFinalPeriodEnabled
        )
    }
}
