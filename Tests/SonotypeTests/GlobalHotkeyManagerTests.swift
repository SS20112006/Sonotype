import AppKit
import XCTest
@testable import Sonotype

private final class TestBox<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: T?

    init(_ value: T? = nil) {
        self._value = value
    }

    var value: T? {
        lock.lock()
        defer { lock.unlock() }
        return _value
    }

    func set(_ newValue: T) {
        lock.lock()
        defer { lock.unlock() }
        _value = newValue
    }
}

@MainActor
final class GlobalHotkeyManagerTests: XCTestCase {
    // MARK: - Testes de Estrutura do GlobalHotkey

    func testDefaultHotkeyStructure() {
        let hotkey = GlobalHotkey.defaultToggle
        XCTAssertEqual(hotkey.keyCode, 49) // Espaço
        XCTAssertTrue(hotkey.modifierFlags.contains(.option))
        XCTAssertFalse(hotkey.modifierFlags.contains(.command))
        XCTAssertEqual(hotkey.displayString, "⌥ Espaço")
    }

    func testCustomHotkeyStructure() {
        let custom = GlobalHotkey(keyCode: 36, modifiers: [.command, .shift]) // Cmd + Shift + Return
        XCTAssertEqual(custom.keyCode, 36)
        XCTAssertTrue(custom.modifierFlags.contains(.command))
        XCTAssertTrue(custom.modifierFlags.contains(.shift))
        XCTAssertEqual(custom.displayString, "⇧ ⌘ Return")
    }

    func testEscapeKeyStructure() {
        let esc = GlobalHotkey.escapeKey
        XCTAssertEqual(esc.keyCode, 53)
        XCTAssertEqual(esc.displayString, "Esc")
    }

    func testHotkeyMatching() {
        let hotkey = GlobalHotkey.defaultToggle

        // Coincide exatamente com Option + Espaço
        XCTAssertTrue(hotkey.matches(eventKeyCode: 49, eventModifiers: [.option]))

        // Tecla diferente
        XCTAssertFalse(hotkey.matches(eventKeyCode: 50, eventModifiers: [.option]))

        // Modificadores adicionais ou incorretos
        XCTAssertFalse(hotkey.matches(eventKeyCode: 49, eventModifiers: [.command]))
        XCTAssertFalse(hotkey.matches(eventKeyCode: 49, eventModifiers: [.option, .command]))
    }

    // MARK: - Testes de Ação do SystemGlobalHotkeyManager

    func testHotkeyManagerTriggersActions() {
        let manager = SystemGlobalHotkeyManager()

        let hotkeyCount = TestBox<Int>(0)
        let escapeCount = TestBox<Int>(0)

        manager.onHotkeyPressed {
            hotkeyCount.set((hotkeyCount.value ?? 0) + 1)
        }

        manager.onEscapePressed {
            escapeCount.set((escapeCount.value ?? 0) + 1)
        }

        manager.simulateHotkeyPressed()
        XCTAssertEqual(hotkeyCount.value, 1)
        XCTAssertEqual(escapeCount.value, 0)

        manager.simulateEscapePressed()
        XCTAssertEqual(hotkeyCount.value, 1)
        XCTAssertEqual(escapeCount.value, 1)
    }

    func testHotkeyManagerDisabledSuppressesActions() {
        let manager = SystemGlobalHotkeyManager()

        let hotkeyCount = TestBox<Int>(0)
        let escapeCount = TestBox<Int>(0)

        manager.onHotkeyPressed {
            hotkeyCount.set((hotkeyCount.value ?? 0) + 1)
        }
        manager.onEscapePressed {
            escapeCount.set((escapeCount.value ?? 0) + 1)
        }

        manager.isEnabled = false
        manager.simulateHotkeyPressed()
        manager.simulateEscapePressed()

        XCTAssertEqual(hotkeyCount.value, 0)
        XCTAssertEqual(escapeCount.value, 0)
    }

    func testCustomHotkeyUpdate() {
        let manager = SystemGlobalHotkeyManager()
        let custom = GlobalHotkey(keyCode: 36, modifiers: [.command]) // Cmd + Return
        manager.currentHotkey = custom

        XCTAssertEqual(manager.currentHotkey, custom)
        XCTAssertTrue(manager.currentHotkey.matches(eventKeyCode: 36, eventModifiers: [.command]))
        XCTAssertFalse(manager.currentHotkey.matches(eventKeyCode: 49, eventModifiers: [.option]))
    }
}
