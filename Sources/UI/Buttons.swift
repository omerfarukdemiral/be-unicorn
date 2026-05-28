import SwiftUI

/// Tek buton dili — 44pt HIG min yükseklik, radiusM köşe, basılı scale 0.97.
/// Stiller: primary (accent dolu, glow) / secondary (surfaceHigh) / danger.

// MARK: - Basılı durum scale + brightness (tüm butonlar)
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .brightness(configuration.isPressed ? -0.05 : 0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableButtonStyle {
    static var pressable: PressableButtonStyle { PressableButtonStyle() }
}

// MARK: - Etiket sarmalayıcıları (zemin + yükseklik + köşe standardı)

enum AppButton {
    static let height: CGFloat = 44
    static let compactHeight: CGFloat = 40

    /// Birincil CTA — accent dolu (sade derinlik gölgesi).
    static func primary(_ theme: Theme, enabled: Bool = true,
                        glow: Bool = false) -> some ViewModifier {
        ButtonChrome(bg: enabled ? theme.accent : theme.surfaceHigh,
                     fg: enabled ? .white : theme.textQuaternary,
                     glow: enabled && glow ? theme.accent : nil,
                     height: height)
    }

    /// İkincil — surfaceHigh zemin, birincil metin.
    static func secondary(_ theme: Theme, enabled: Bool = true) -> some ViewModifier {
        ButtonChrome(bg: theme.surfaceHigh,
                     fg: enabled ? theme.text : theme.textQuaternary,
                     glow: nil, height: height)
    }

    /// Tehlike — danger dolu.
    static func danger(height: CGFloat = AppButton.height) -> some ViewModifier {
        ButtonChrome(bg: Palette.danger.opacity(0.9), fg: .white, glow: nil, height: height)
    }
}

/// Buton görünüm zarfı — zemin, metin rengi, köşe, yükseklik, opsiyonel glow.
struct ButtonChrome: ViewModifier {
    let bg: Color
    let fg: Color
    let glow: Color?
    let height: CGFloat

    func body(content: Content) -> some View {
        content
            .foregroundStyle(fg)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(bg, in: RoundedRectangle(cornerRadius: Radius.m))
            // Sade derinlik: butonlar hâlâ kabarık hissedilsin, neon hâlesi yok.
            .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
            // Kutlama CTA'ları (Win / Sezon Finali) için explicit glow korunur — soft.
            .shadow(color: glow?.opacity(0.3) ?? .clear, radius: glow != nil ? 10 : 0, y: 4)
    }
}
