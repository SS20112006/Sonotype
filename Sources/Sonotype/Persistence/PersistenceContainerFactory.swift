import Foundation
import SwiftData
import os

/// Fábrica do ModelContainer para a camada de persistência SwiftData do Sonotype.
/// Configura o schema unificado de modelos e fornece inicialização segura com fallback
/// defensivo em memória caso o armazenamento em disco esteja inacessível ou corrompido.
public enum PersistenceContainerFactory: Sendable {
    private static let logger = Logger(subsystem: "com.sonotype.app", category: "PersistenceContainerFactory")

    /// Schema canónico contendo todos os modelos da aplicação.
    public static func makeSchema() -> Schema {
        Schema([
            TranscriptionRecord.self,
            VocabularyEntry.self,
            WordReplacementRule.self,
            SessionStat.self
        ])
    }

    /// Cria um `ModelContainer` configurado para disco ou memória RAM.
    ///
    /// - Parameter inMemory: Se verdadeiro, armazena apenas em RAM (ideal para testes unitários ultrarrápidos).
    /// - Returns: Instância configurada do `ModelContainer`.
    public static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = makeSchema()
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            if !inMemory {
                // Fallback defensivo para garantir resiliência e integridade sem crash da app
                logger.error("Falha ao inicializar ModelContainer persistente em disco: \(error.localizedDescription, privacy: .public). Recorrendo a contentor em memória RAM.")
                let fallbackConfig = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: true
                )
                return try ModelContainer(for: schema, configurations: [fallbackConfig])
            }
            logger.error("Falha ao inicializar ModelContainer em memória: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }
}
