import SwiftUI

/// Empty drop-zone artwork: two pages fanned behind an open folder, with a pointer and sparkles.
/// The glyphs (folder, "Aa", text lines, pointer, sparkles) are SF Symbols (≈ 124×108 pt).
struct DropIllustration: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Back page
            RoundedRectangle(cornerRadius: 5)
                .fill(LinearGradient(colors: [Color(hex: 0xF1F1F4), Color(hex: 0xD9D9DE)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 48, height: 62)
                .shadow(color: .black.opacity(0.16), radius: 3, x: 1, y: 2)
                .rotationEffect(.degrees(14))
                .offset(x: 66, y: 4)

            // Front page: "Aa" over a few lines of text
            RoundedRectangle(cornerRadius: 5)
                .fill(Color(hex: 0xFAFAFB))
                .frame(width: 48, height: 62)
                .overlay(alignment: .top) {
                    VStack(spacing: 5) {
                        Image(systemName: "textformat")
                            .font(.system(size: 15, weight: .heavy))
                            .foregroundStyle(Color(hex: 0x8E8E96))
                        Image(systemName: "text.alignleft")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color(hex: 0xC4C4CA))
                    }
                    .padding(.top, 9)
                }
                .shadow(color: .black.opacity(0.2), radius: 3, x: 1, y: 2)
                .rotationEffect(.degrees(-6))
                .offset(x: 44, y: 10)

            // Open folder; the backing fills the symbol's cut-out so it reads as the folder's inside.
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(hex: 0x6E737D))
                    .frame(width: 64, height: 16)
                    .offset(x: 15, y: 15)
                Image(systemName: "folder.fill")
                    .font(.system(size: 70, weight: .regular))
                    .foregroundStyle(LinearGradient(colors: [Color(hex: 0xC3C7CF), Color(hex: 0x8D929C)],
                                                    startPoint: .topLeading, endPoint: .bottomTrailing))
            }
            .shadow(color: .black.opacity(0.22), radius: 6, y: 3)
            .offset(x: 0, y: 44)

            // Pointer
            Image(systemName: "cursorarrow")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color(hex: 0x1F1F22))
                .shadow(color: .white.opacity(0.9), radius: 0.5)
                .offset(x: 84, y: 30)

            // Sparkles
            Image(systemName: "sparkle")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(hex: 0x8E8E96))
                .offset(x: 4, y: 20)
            Image(systemName: "sparkle")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(hex: 0xA4A4AC))
                .offset(x: 24, y: 26)
            Image(systemName: "sparkle")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white.opacity(0.9))
                .offset(x: 14, y: 70)
        }
        .frame(width: 124, height: 108, alignment: .topLeading)
    }
}
