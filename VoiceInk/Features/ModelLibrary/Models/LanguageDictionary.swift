import Foundation

enum TranscriptionLanguageSupport {
    static func languages(for model: any TranscriptionModel, realtimeEnabled: Bool? = nil) -> [String: String] {
        model.supportedLanguages
    }

    static func validLanguageOrFallback(
        _ language: String?, for model: any TranscriptionModel, realtimeEnabled: Bool? = nil
    ) -> String {
        let languages = languages(for: model, realtimeEnabled: realtimeEnabled)

        if let language, languages[language] != nil {
            return language
        }

        if languages["auto"] != nil {
            return "auto"
        }

        let preferredLang = Locale.preferredLanguages.first?.lowercased() ?? "en"
        if preferredLang.starts(with: "pt") {
            if languages["pt-PT"] != nil && preferredLang.contains("pt-pt") { return "pt-PT" }
            if languages["pt-BR"] != nil && (preferredLang.contains("pt-br") || preferredLang.contains("pt_br")) { return "pt-BR" }
            if languages["pt"] != nil { return "pt" }
            if languages["pt-PT"] != nil { return "pt-PT" }
            if languages["pt-BR"] != nil { return "pt-BR" }
        }

        if languages["en-US"] != nil {
            return "en-US"
        }

        if languages["en"] != nil {
            return "en"
        }

        return languages.keys.sorted { lhs, rhs in
            languages[lhs, default: lhs] < languages[rhs, default: rhs]
        }.first ?? "en"
    }
}

enum LanguageDictionary {
    private static let whisperLanguageCodes: Set<String> = [
        "auto",
        "en",
        "pt"
    ]

    static func forProvider(isMultilingual: Bool, provider: ModelProvider = .whisper) -> [String: String] {
        if !isMultilingual {
            return ["en": "English"]
        }

        if let cloudProvider = CloudProviderRegistry.provider(for: provider) {
            guard let codes = cloudProvider.languageCodes else {
                return all
            }
            return forCodes(codes, includesAutoDetect: cloudProvider.includesAutoDetect)
        }

        switch provider {
        case .whisper:
            return languages(matching: whisperLanguageCodes)

        case .nativeApple:
            return appleNative

        case .fluidAudio:
            let codes = ["en", "pt"]
            var filtered = all.filter { codes.contains($0.key) }
            filtered["auto"] = "Auto-detect"
            return filtered

        default:
            return all
        }
    }

    static func forCodes(_ codes: [String], includesAutoDetect: Bool = false) -> [String: String] {
        var filtered = all.filter { codes.contains($0.key) }
        if includesAutoDetect { filtered["auto"] = "Auto-detect" }
        return filtered
    }

    static let nemotronLatin: [String: String] = [
        "auto": "Auto-detect",
        "en-US": "English",
        "pt-BR": "Portuguese (Brazil)",
    ]

    static let nemotronMultilingual: [String: String] = [
        "auto": "Auto-detect",
        "en-US": "English",
        "pt-BR": "Portuguese (Brazil)",
    ]

    static let cohereTranscribe = forCodes([
        "en", "pt",
    ])

    static let senseVoiceSmall = forCodes(
        ["en"],
        includesAutoDetect: true
    )

    private static func languages(matching codes: Set<String>) -> [String: String] {
        all.filter { codes.contains($0.key) }
    }

    // Apple Native Speech languages in BCP-47 format.
    static let appleNative: [String: String] = [
        "en-AU": "English (Australia)",
        "en-CA": "English (Canada)",
        "en-GB": "English (United Kingdom)",
        "en-US": "English (United States)",
        "pt-BR": "Portuguese (Brazil)",
        "pt-PT": "Portuguese (Portugal)",
    ]

    static let all: [String: String] = [
        "auto": "Auto-detect",
        "en": "English",
        "en-AU": "English (Australia)",
        "en-CA": "English (Canada)",
        "en-GB": "English (United Kingdom)",
        "en-US": "English (United States)",
        "pt": "Portuguese",
        "pt-BR": "Portuguese (Brazil)",
        "pt-PT": "Portuguese (Portugal)",
    ]
}
