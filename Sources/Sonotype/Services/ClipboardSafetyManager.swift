import AppKit
import Foundation
import os

/// Modo de salvaguarda do clipboard durante a injeção de texto no cursor.
public enum ClipboardSafetyMode: String, Sendable, CaseIterable {
    /// Modo A (Padrão): Cola no cursor e preserva uma cópia do texto transcrito no Clipboard (Cmd+V).
    /// Garante que o utilizador nunca perde o texto mesmo se a janela ativa mudar.
    case pasteAndKeep

    /// Modo B: Preserva o conteúdo anterior do clipboard, restaurando-o após a injeção do texto.
    case preservePrevious
}

/// Representação snapshot imutável e Sendable de um item do pasteboard.
public struct PasteboardItemSnapshot: Sendable, Equatable {
    public let dataByType: [String: Data]

    public init(dataByType: [String: Data]) {
        self.dataByType = dataByType
    }
}

/// Instantâneo imutável e Sendable do estado completo do pasteboard.
public struct PasteboardSnapshot: Sendable, Equatable {
    public let items: [PasteboardItemSnapshot]
    public let changeCount: Int

    public init(items: [PasteboardItemSnapshot], changeCount: Int) {
        self.items = items
        self.changeCount = changeCount
    }
}

/// Gestor responsável pela salvaguarda, escrita e restauração segura do conteúdo do Clipboard.
/// Suporta o Modo A (manter texto transcrito) e o Modo B (restauração fiel do conteúdo anterior).
@MainActor
public final class ClipboardSafetyManager: Sendable {
    private static let logger = Logger(subsystem: "com.sonotype.app", category: "ClipboardSafetyManager")

    public let pasteboard: NSPasteboard

    /// Inicializa o gestor com um pasteboard específico (padrão: `NSPasteboard.general`).
    /// Permite injeção de pasteboard com nome único para isolamento de testes unitários.
    public init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    /// Captura um instantâneo imutável do estado atual do pasteboard (todos os itens e tipos).
    public func captureSnapshot() -> PasteboardSnapshot {
        guard let items = pasteboard.pasteboardItems, !items.isEmpty else {
            return PasteboardSnapshot(items: [], changeCount: pasteboard.changeCount)
        }

        var snapshotItems: [PasteboardItemSnapshot] = []
        for item in items {
            var dataDict: [String: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    dataDict[type.rawValue] = data
                }
            }
            if !dataDict.isEmpty {
                snapshotItems.append(PasteboardItemSnapshot(dataByType: dataDict))
            }
        }

        return PasteboardSnapshot(items: snapshotItems, changeCount: pasteboard.changeCount)
    }

    /// Restaura o estado anterior do pasteboard a partir de um snapshot.
    public func restore(snapshot: PasteboardSnapshot) {
        pasteboard.clearContents()
        guard !snapshot.items.isEmpty else { return }

        var newItems: [NSPasteboardItem] = []
        for itemSnapshot in snapshot.items {
            let pbItem = NSPasteboardItem()
            for (typeRaw, data) in itemSnapshot.dataByType {
                pbItem.setData(data, forType: NSPasteboard.PasteboardType(typeRaw))
            }
            newItems.append(pbItem)
        }

        pasteboard.writeObjects(newItems)
        Self.logger.debug("Clipboard restaurado a partir de snapshot com \(snapshot.items.count) item(s)")
    }

    /// Define o texto no pasteboard como string simples (UTF-8).
    @discardableResult
    public func setText(_ text: String) -> Bool {
        pasteboard.clearContents()
        return pasteboard.setString(text, forType: .string)
    }

    /// Retorna a representação em texto simples atualmente no pasteboard.
    public func currentString() -> String? {
        pasteboard.string(forType: .string)
    }

    /// Executa uma ação com o texto fornecido no clipboard e, caso o modo seja `.preservePrevious`,
    /// restaura o conteúdo anterior após um intervalo assíncrono para permitir o consumo do paste.
    public func withPreservedClipboard(
        text: String,
        mode: ClipboardSafetyMode,
        restoreDelayNanoseconds: UInt64 = 75_000_000,
        action: () async throws -> Void
    ) async rethrows {
        let snapshot = (mode == .preservePrevious) ? captureSnapshot() : nil
        setText(text)

        defer {
            if let snapshot {
                restore(snapshot: snapshot)
            }
        }

        try await action()

        if snapshot != nil && restoreDelayNanoseconds > 0 {
            do {
                try await Task.sleep(nanoseconds: restoreDelayNanoseconds)
            } catch {
                Self.logger.warning("Atraso de restauração interrompido em withPreservedClipboard: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
