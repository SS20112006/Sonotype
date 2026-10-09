import Foundation
import SwiftData

/// Registo agregado de estatísticas diárias de utilização do Sonotype.
/// Permite alimentar os cartões de produtividade (palavras hoje, divisão PT/EN, tempo poupado estimado).
@Model
public final class SessionStat {
    @Attribute(.unique) public var id: UUID
    public var dayKey: String
    public var date: Date
    public var totalTranscriptions: Int
    public var totalWords: Int
    public var totalDurationSeconds: TimeInterval
    public var portugueseWords: Int
    public var englishWords: Int

    public init(
        id: UUID = UUID(),
        date: Date = Date(),
        dayKey: String? = nil,
        totalTranscriptions: Int = 0,
        totalWords: Int = 0,
        totalDurationSeconds: TimeInterval = 0.0,
        portugueseWords: Int = 0,
        englishWords: Int = 0
    ) {
        self.id = id
        self.date = date
        self.dayKey = dayKey ?? Self.makeDayKey(from: date)
        self.totalTranscriptions = totalTranscriptions
        self.totalWords = totalWords
        self.totalDurationSeconds = totalDurationSeconds
        self.portugueseWords = portugueseWords
        self.englishWords = englishWords
    }

    /// Gera uma chave de dia normalizada no formato "YYYY-MM-DD" para agregações diárias consistentes.
    public static func makeDayKey(from date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 2026
        let month = components.month ?? 1
        let day = components.day ?? 1
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    /// Estima o tempo poupado em minutos considerando a taxa média de digitação humana (~45 ppm).
    public var estimatedTimeSavedMinutes: Double {
        let typingMinutes = Double(totalWords) / 45.0
        let speakingMinutes = totalDurationSeconds / 60.0
        return max(0.0, typingMinutes - speakingMinutes)
    }
}
