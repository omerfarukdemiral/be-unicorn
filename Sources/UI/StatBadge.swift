import SwiftUI

/// Oyun tarzı yüzen rozet / pill — HUD'da nakit, kullanıcı, MRR, runway, moral, değerleme için.
///
/// Tasarım:
/// - Yarı saydam ultraThinMaterial zemin (game-feel "glass"), tint kenarlık, hafif glow.
/// - Sol ikon + sayı (Space Grotesk) + opsiyonel mikro etiket (Inter).
/// - `numericText` content-transition: değer değişince sayı yumuşak akar.
/// - `prominent` modu kahraman rozet: daha büyük tipografi + daha güçlü glow (nakit için).
struct StatBadge: View {
    let symbol: String
    let value: String
    var label: String? = nil
    var tint: Color
    var prominent: Bool = false
    var onTap: (() -> Void)? = nil

    /// İçerik gövdesi (tap'sız sürüm).
    private var content: some View {
        HStack(spacing: prominent ? Space.s2 : 6) {
            // İkon: kahraman rozette tint dolgulu daire içinde (tycoon-coin hissi).
            Group {
                if prominent {
                    ZStack {
                        Circle()
                            .fill(tint.opacity(0.18))
                            .frame(width: 26, height: 26)
                        Image(systemName: symbol)
                            .font(.system(size: 16, weight: .black))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(tint)
                    }
                } else {
                    Image(systemName: symbol)
                        .font(.system(size: 11.5, weight: .bold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(tint)
                }
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(prominent ? .appNumber(20, .heavy) : .appNumber(13, .bold))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let label, prominent {
                    Text(label.uppercased())
                        .font(.appText(8.5, .black))
                        .kerning(0.7)
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, prominent ? Space.s3 : Space.s2 + 2)
        .padding(.vertical, prominent ? Space.s2 : 6)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule().stroke(tint.opacity(prominent ? 0.55 : 0.35),
                             lineWidth: prominent ? 1.2 : 1)
        )
        // Sade derinlik gölgesi (kahraman rozette). Mini rozette gölge yok — flat & temiz.
        .shadow(color: prominent ? .black.opacity(0.25) : .clear,
                radius: prominent ? 4 : 0, y: prominent ? 2 : 0)
    }

    var body: some View {
        if let onTap {
            Button {
                Haptics.tap()
                onTap()
            } label: { content }
            .buttonStyle(.pressable)
        } else {
            content
        }
    }
}
