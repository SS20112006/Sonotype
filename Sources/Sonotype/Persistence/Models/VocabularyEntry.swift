import Foundation
import SwiftData

/// Entrada no vocabulário personalizado do utilizador (termos técnicos, nomes próprios, siglas).
@Model
public final class VocabularyEntry {
    @Attribute(.unique) public var id: UUID
    public var word: String
    public var priority: Int
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        word: String,
        priority: Int = 1,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.word = word
        self.priority = priority
        self.createdAt = createdAt
    }
}
