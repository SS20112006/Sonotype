import XCTest
import SwiftUI
@testable import Sonotype

final class BrandViewTests: XCTestCase {
    @MainActor
    func testSonotypeBrandAssetResolvesImage() {
        let image = SonotypeBrandAsset.logoImage
        XCTAssertNotNil(image, "SonotypeBrandAsset deve carregar o logótipo oficial do Sonotype")
        if let image = image {
            XCTAssertGreaterThan(image.size.width, 0)
            XCTAssertGreaterThan(image.size.height, 0)
        }
    }

    @MainActor
    func testSonotypeBrandLogoViewRendersWithParameters() {
        let logoView = SonotypeBrandLogoView(size: 48, cornerRadius: 10, accessibilityDescription: "Logótipo de Teste")
        XCTAssertEqual(logoView.size, 48)
        XCTAssertEqual(logoView.cornerRadius, 10)
        XCTAssertEqual(logoView.accessibilityDescription, "Logótipo de Teste")
    }

    @MainActor
    func testApplyApplicationIconExecutesSafely() {
        SonotypeBrandAsset.applyApplicationIcon()
        // NSApplication icon image deve estar presente ou ser preservado
        XCTAssertNotNil(NSApplication.shared.applicationIconImage)
    }
}
