import Foundation

/// Serviço responsável pela correção automática de maiúsculas no início de frases,
/// após sinais de pontuação terminal (. ? !) e após quebras de linha (\n).
public final class CapitalizationService: Sendable {

    public init() {}

    /// Capitaliza o início do texto e os inícios de cada frase subsequente.
    ///
    /// - Parameters:
    ///   - text: Texto de entrada com pontuação já normalizada.
    ///   - locale: Locale opcional para regras linguísticas de capitalização Unicode.
    /// - Returns: Texto com as maiúsculas devidamente ajustadas no início de frases.
    public func capitalize(text: String, locale: Locale? = nil) -> String {
        guard !text.isEmpty else { return "" }

        var characters = Array(text)
        var shouldCapitalizeNext = true
        var index = 0

        while index < characters.count {
            let char = characters[index]

            if shouldCapitalizeNext {
                if char.isLetter {
                    let uppercaseChar = String(char).uppercased(with: locale)
                    if let firstUpper = uppercaseChar.first {
                        characters[index] = firstUpper
                    }
                    shouldCapitalizeNext = false
                } else if char.isWhitespace || char == "\"" || char == "'" || char == "“" || char == "”" || char == "(" || char == "-" {
                    // Mantém flag ativa enquanto passa por espaços ou símbolos de abertura
                } else {
                    shouldCapitalizeNext = false
                }
            } else {
                // Deteta gatilhos de nova frase ou início de parênteses:
                if char == "." || char == "?" || char == "!" || char == "(" {
                    // Verifica se não é parte de uma elipse/reticências ainda em processamento
                    if char == "." && index + 1 < characters.count && characters[index + 1] == "." {
                        // É reticência, aguarda o fim dos pontos
                        while index < characters.count && characters[index] == "." {
                            index += 1
                        }
                        shouldCapitalizeNext = true
                        continue
                    }
                    shouldCapitalizeNext = true
                } else if char == "\n" {
                    shouldCapitalizeNext = true
                }
            }

            index += 1
        }

        return String(characters)
    }
}
