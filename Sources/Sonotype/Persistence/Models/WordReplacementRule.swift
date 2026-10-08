import Foundation
import SwiftData

/// Regra de substituição rápida de texto por voz (expansão de atalhos falados).
/// Exemplo: trigger "meu email" -> replacement "simao@exemplo.com".
@Model
public final class WordReplacementRule {
    @Attribute(.unique) public var id: UUID
    public var trigger: String
    public var replacement: String
    public var isCaseSensitive: Bool
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        trigger: String,
        replacement: String,
        isCaseSensitive: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.trigger = trigger
        self.replacement = replacement
        self.isCaseSensitive = isCaseSensitive
        self.createdAt = createdAt
    }

    /// Aplica esta regra a um texto dado.
    public func apply(to text: String) -> String {
        guard !trigger.isEmpty else { return text }
        if isCaseSensitive {
            return text.replacingOccurrences(of: trigger, with: replacement)
        } else {
            return text.replacingOccurrences(of: trigger, with: replacement, options: .caseInsensitive)
        }
    }
}
