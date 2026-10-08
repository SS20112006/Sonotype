import SwiftUI
import XCTest
@testable import Sonotype

@MainActor
final class QuickPopoverViewTests: XCTestCase {

    func testQuickPopoverViewInitialization() {
        var didOpenDashboard = false
        var didOpenSettings = false
        var didToggleRecording = false
        var didQuit = false

        let view = QuickPopoverView(
            state: .idle,
            currentLanguage: "PT-PT",
            hotkeyDisplay: "⌥ Espaço",
            onOpenDashboard: { didOpenDashboard = true },
            onOpenSettings: { didOpenSettings = true },
            onToggleRecording: { didToggleRecording = true },
            onQuit: { didQuit = true }
        )

        XCTAssertEqual(view.state, .idle)
        XCTAssertEqual(view.currentLanguage, "PT-PT")
        XCTAssertEqual(view.hotkeyDisplay, "⌥ Espaço")

        view.onOpenDashboard?()
        XCTAssertTrue(didOpenDashboard)

        view.onOpenSettings?()
        XCTAssertTrue(didOpenSettings)

        view.onToggleRecording?()
        XCTAssertTrue(didToggleRecording)

        view.onQuit?()
        XCTAssertTrue(didQuit)
    }

    func testQuickPopoverStates() {
        let idleView = QuickPopoverView(state: .idle)
        XCTAssertEqual(idleView.state, .idle)

        let recordingView = QuickPopoverView(state: .recording)
        XCTAssertEqual(recordingView.state, .recording)

        let processingView = QuickPopoverView(state: .processing)
        XCTAssertEqual(processingView.state, .processing)
    }

    func testQuickPopoverViewBodyEvaluation() {
        let view = QuickPopoverView(state: .recording)
        _ = view.body
        XCTAssertEqual(view.state, .recording)
    }
}
