import AppKit
import SwiftUI

/// Fornecedor centralizado de recursos de marca e logótipo oficial do Sonotype.
/// Suporta carregamento a partir do bundle de recursos da aplicação (`Bundle.main`),
/// caminhos locais de desenvolvimento e fallback elegante de sistema.
public enum SonotypeBrandAsset: Sendable {
    /// Carrega a imagem do logótipo principal da aplicação.
    @MainActor
    public static var logoImage: NSImage? {
        // 1. Tentar obter a partir dos recursos do bundle principal
        if let bundleUrl = Bundle.main.url(forResource: "SonotypeLogo", withExtension: "png")
            ?? Bundle.main.url(forResource: "AppIcon", withExtension: "icns")
            ?? Bundle.main.url(forResource: "AppIcon", withExtension: "png"),
           let image = NSImage(contentsOf: bundleUrl) {
            return image
        }

        // 2. Tentar caminhos locais para execuções durante testes e ambiente de desenvolvimento
        let candidatePaths = [
            "Resources/SonotypeLogo.png",
            "Resources/AppIcon.icns",
            "Resources/AppIcon.png",
            "../Resources/SonotypeLogo.png",
            "../../Resources/SonotypeLogo.png"
        ]

        for path in candidatePaths {
            if FileManager.default.fileExists(atPath: path),
               let image = NSImage(contentsOfFile: path) {
                return image
            }
        }

        // 3. Fallback para ícone de sistema da aplicação caso o bundle de recursos não esteja presente
        return NSApplication.shared.applicationIconImage
    }

    /// Aplica o ícone oficial da aplicação ao `NSApplication.shared.applicationIconImage`,
    /// garantindo que a Dock do macOS apresenta o logótipo oficial tanto em execução de desenvolvimento
    /// quanto em versão distribuída.
    @MainActor
    public static func applyApplicationIcon() {
        if let image = logoImage {
            NSApplication.shared.applicationIconImage = image
        }
    }
}

/// Vista SwiftUI que renderiza o logótipo oficial do Sonotype de forma proporcional e com cantos arredondados contínuos.
/// Respeita as diretrizes Apple HIG e WCAG 2.1 AA.
public struct SonotypeBrandLogoView: View {
    public let size: CGFloat
    public let cornerRadius: CGFloat?
    public let accessibilityDescription: String

    public init(
        size: CGFloat = 32,
        cornerRadius: CGFloat? = nil,
        accessibilityDescription: String = "Logótipo Sonotype"
    ) {
        self.size = size
        self.cornerRadius = cornerRadius
        self.accessibilityDescription = accessibilityDescription
    }

    public var body: some View {
        Group {
            if let image = SonotypeBrandAsset.logoImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                // Fallback elegante SF Symbol
                Image(systemName: "waveform.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(Color.accentColor)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius ?? (size * 0.22), style: .continuous))
        .accessibilityLabel(accessibilityDescription)
    }
}
