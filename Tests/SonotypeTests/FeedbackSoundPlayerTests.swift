import XCTest
@testable import Sonotype

@MainActor
final class MockFeedbackSoundPlayer: FeedbackSoundPlaying, Sendable {
    var isEnabled: Bool = true
    var startSoundCount: Int = 0
    var stopSoundCount: Int = 0
    var cancelSoundCount: Int = 0

    func playStartSound() {
        guard isEnabled else { return }
        startSoundCount += 1
    }

    func playStopSound() {
        guard isEnabled else { return }
        stopSoundCount += 1
    }

    func playCancelSound() {
        guard isEnabled else { return }
        cancelSoundCount += 1
    }
}

@MainActor
final class FeedbackSoundPlayerTests: XCTestCase {
    func testMockSoundPlayerInvocations() {
        let player = MockFeedbackSoundPlayer()
        XCTAssertTrue(player.isEnabled)

        player.playStartSound()
        XCTAssertEqual(player.startSoundCount, 1)

        player.playStopSound()
        XCTAssertEqual(player.stopSoundCount, 1)

        player.playCancelSound()
        XCTAssertEqual(player.cancelSoundCount, 1)

        // Desativar som
        player.isEnabled = false
        player.playStartSound()
        player.playStopSound()
        player.playCancelSound()

        XCTAssertEqual(player.startSoundCount, 1, "Não deve reproduzir quando desativado.")
        XCTAssertEqual(player.stopSoundCount, 1, "Não deve reproduzir quando desativado.")
        XCTAssertEqual(player.cancelSoundCount, 1, "Não deve reproduzir quando desativado.")
    }

    func testSystemSoundPlayerInstantiationAndToggle() {
        let systemPlayer = SystemFeedbackSoundPlayer(isEnabled: true)
        XCTAssertTrue(systemPlayer.isEnabled)

        systemPlayer.isEnabled = false
        XCTAssertFalse(systemPlayer.isEnabled)
    }
}
