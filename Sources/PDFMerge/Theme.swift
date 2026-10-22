import SwiftUI
import AppKit

/// Palette sampled from the reference recording (light), with matching dark variants.
enum Theme {
    /// Neutral highlight for selected rows and cards.
    static let selection = dynamic(0xD2D2D6, 0x4A4A4F)
    /// Neutral outline for focus, selection and drop targets.
    static let outline = dynamic(0x8A8A91, 0x8E8E95)

    static let windowBackground = dynamic(0xEBEBEB, 0x1C1C1E)
    static let panel = dynamic(0xE5E5E5, 0x262628)
    static let field = dynamic(0xF2F2F2, 0x323235)
    static let fieldHover = dynamic(0xF7F7F7, 0x3A3A3D)
    static let fieldBorder = dynamic(0xDCDCDC, 0x404044)
    static let divider = dynamic(0xCFCFCF, 0x3A3A3D)
    static let dashed = dynamic(0xBDBDBD, 0x55555A)
    static let menuBackground = dynamic(0xE9E8E9, 0x2E2E31)
    static let menuBorder = dynamic(0xA8A8A8, 0x4A4A4E)
    static let disabledButton = dynamic(0xD7D7D7, 0x343437)
    static let disabledButtonText = dynamic(0x9E9E9E, 0x6A6A6E)
    static let row = dynamic(0xF2F2F2, 0x2F2F32)
    static let rowHover = dynamic(0xF8F8F8, 0x37373A)

    static let text = dynamic(0x1F1F1F, 0xECECEC)
    static let secondaryText = dynamic(0x6B6B6B, 0x9C9CA0)
    static let mutedText = dynamic(0x8A8A8A, 0x7E7E82)
    static let danger = dynamic(0xE5484D, 0xFF6369)

    static let body = Font.system(size: 13)
    static let heading = Font.system(size: 13, weight: .semibold)

    private static func dynamic(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return NSColor(hex: isDark ? dark : light)
        })
    }
}

extension NSColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: alpha)
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(nsColor: NSColor(hex: hex, alpha: opacity))
    }
}
