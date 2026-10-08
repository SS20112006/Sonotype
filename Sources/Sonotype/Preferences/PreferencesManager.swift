import Foundation
import Combine
import os

/// Gestor central reativo de preferências da aplicação Sonotype no macOS.
/// Responsável pela persistência atómica em UserDefaults e notificação em tempo real
/// de alterações aos serviços em execução sem necessidade de reiniciar a aplicação.
@MainActor
public final class PreferencesManager: ObservableObject, Sendable {
    private static let logger = Logger(subsystem: "com.sonotype.app", category: "PreferencesManager")

    /// Chave padrão de armazenamento em UserDefaults.
    public static let storageKey = "com.sonotype.app.preferences"

    /// Instância partilhada opcional (Singleton) para conveniência da aplicação.
    public static let shared = PreferencesManager()

    /// Contentor UserDefaults injetado (permite isolamento completo em suites de teste).
    public let userDefaults: UserDefaults

    // MARK: - Callbacks de Notificação em Tempo Real

    public var onDockModeChanged: (@MainActor @Sendable (DockVisibilityMode) -> Void)?
    public var onSilenceTimeoutChanged: (@MainActor @Sendable (TimeInterval?) -> Void)?
    public var onSoundFeedbackChanged: (@MainActor @Sendable (Bool) -> Void)?
    public var onHotkeyChanged: (@MainActor @Sendable (GlobalHotkey) -> Void)?
    public var onLanguageModeChanged: (@MainActor @Sendable (LanguageSelectionMode) -> Void)?
    public var onTriggerModeChanged: (@MainActor @Sendable (RecordingTriggerMode) -> Void)?
    public var onHUDFeedbackModeChanged: (@MainActor @Sendable (HUDFeedbackMode) -> Void)?
    public var onOnboardingStatusChanged: (@MainActor @Sendable (Bool) -> Void)?

    // MARK: - Estado Reativo

    @Published public var preferences: AppPreferences {
        didSet {
            savePreferences()
            notifyChanges(oldValue: oldValue, newValue: preferences)
        }
    }

    // MARK: - Inicialização

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults

        if let data = userDefaults.data(forKey: Self.storageKey) {
            do {
                self.preferences = try JSONDecoder().decode(AppPreferences.self, from: data)
            } catch {
                Self.logger.error("Falha ao descodificar preferências persistidas de UserDefaults: \(error.localizedDescription, privacy: .public)")
                self.preferences = AppPreferences()
            }
        } else {
            self.preferences = AppPreferences()
        }
    }

    /// Redefine todas as preferências para os valores padrão de fábrica.
    public func resetToDefaults() {
        preferences = AppPreferences()
    }

    /// Serializa e persiste o estado atual das preferências no UserDefaults.
    public func savePreferences() {
        do {
            let data = try JSONEncoder().encode(preferences)
            userDefaults.set(data, forKey: Self.storageKey)
        } catch {
            Self.logger.error("Falha ao codificar preferências para UserDefaults: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Acesso de Conveniência (Get/Set Direto)

    public var launchAtLogin: Bool {
        get { preferences.launchAtLogin }
        set { preferences.launchAtLogin = newValue }
    }

    public var dockVisibilityMode: DockVisibilityMode {
        get { preferences.dockVisibilityMode }
        set { preferences.dockVisibilityMode = newValue }
    }

    public var triggerMode: RecordingTriggerMode {
        get { preferences.triggerMode }
        set { preferences.triggerMode = newValue }
    }

    public var globalHotkey: GlobalHotkey {
        get { preferences.globalHotkey }
        set { preferences.globalHotkey = newValue }
    }

    public var silenceTimeoutSeconds: Double? {
        get { preferences.silenceTimeoutSeconds }
        set { preferences.silenceTimeoutSeconds = newValue }
    }

    public var soundFeedbackEnabled: Bool {
        get { preferences.soundFeedbackEnabled }
        set { preferences.soundFeedbackEnabled = newValue }
    }

    public var languageSelectionMode: LanguageSelectionMode {
        get { preferences.languageSelectionMode }
        set { preferences.languageSelectionMode = newValue }
    }

    public var hudFeedbackMode: HUDFeedbackMode {
        get { preferences.hudFeedbackMode }
        set { preferences.hudFeedbackMode = newValue }
    }

    public var oralCommandsEnabled: Bool {
        get { preferences.oralCommandsEnabled }
        set { preferences.oralCommandsEnabled = newValue }
    }

    public var fillerFilterEnabled: Bool {
        get { preferences.fillerFilterEnabled }
        set { preferences.fillerFilterEnabled = newValue }
    }

    public var autoCapitalizationEnabled: Bool {
        get { preferences.autoCapitalizationEnabled }
        set { preferences.autoCapitalizationEnabled = newValue }
    }

    public var autoFinalPeriodEnabled: Bool {
        get { preferences.autoFinalPeriodEnabled }
        set { preferences.autoFinalPeriodEnabled = newValue }
    }

    public var clipboardSafetyMode: ClipboardSafetyMode {
        get { preferences.clipboardSafetyMode }
        set { preferences.clipboardSafetyMode = newValue }
    }

    public var textInjectionStrategy: TextInjectionStrategy {
        get { preferences.textInjectionStrategy }
        set { preferences.textInjectionStrategy = newValue }
    }

    public var metricsVisibility: DashboardMetricsVisibility {
        get { preferences.metricsVisibility }
        set { preferences.metricsVisibility = newValue }
    }

    public var hasCompletedOnboarding: Bool {
        get { preferences.hasCompletedOnboarding }
        set { preferences.hasCompletedOnboarding = newValue }
    }

    // MARK: - Emissão de Eventos de Alteração

    private func notifyChanges(oldValue: AppPreferences, newValue: AppPreferences) {
        if oldValue.dockVisibilityMode != newValue.dockVisibilityMode {
            onDockModeChanged?(newValue.dockVisibilityMode)
        }
        if oldValue.silenceTimeoutSeconds != newValue.silenceTimeoutSeconds {
            onSilenceTimeoutChanged?(newValue.silenceTimeoutSeconds)
        }
        if oldValue.soundFeedbackEnabled != newValue.soundFeedbackEnabled {
            onSoundFeedbackChanged?(newValue.soundFeedbackEnabled)
        }
        if oldValue.globalHotkey != newValue.globalHotkey {
            onHotkeyChanged?(newValue.globalHotkey)
        }
        if oldValue.languageSelectionMode != newValue.languageSelectionMode {
            onLanguageModeChanged?(newValue.languageSelectionMode)
        }
        if oldValue.triggerMode != newValue.triggerMode {
            onTriggerModeChanged?(newValue.triggerMode)
        }
        if oldValue.hudFeedbackMode != newValue.hudFeedbackMode {
            onHUDFeedbackModeChanged?(newValue.hudFeedbackMode)
        }
        if oldValue.hasCompletedOnboarding != newValue.hasCompletedOnboarding {
            onOnboardingStatusChanged?(newValue.hasCompletedOnboarding)
        }
    }
}
