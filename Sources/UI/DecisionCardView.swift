import SwiftUI

/// Karar kartı overlay — kurucu kararı. Tüm meterleri etkiler.
struct DecisionCardView: View {
    @ObservedObject var model: GameModel
    var theme: Theme
    let card: DecisionCard
    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer()
                card_body
                    .padding(.horizontal, Space.s4)
                    .scaleEffect(appeared ? 1 : 0.85)
                    .opacity(appeared ? 1 : 0)
                Spacer()
            }
        }
        .onAppear {
            Haptics.rigid()
            withAnimation(Motion.snappy) { appeared = true }
        }
    }

    /// Kategori tint'i merkezi semantiğe bağla (crisis→danger, opportunity→success, investor→accent...).
    private var tint: Color {
        switch card.category {
        case .crisis:      return Palette.danger
        case .opportunity: return Palette.success
        case .press:       return Palette.warning
        case .investor:    return theme.accent
        default:           return Color(hex: card.category.tint)
        }
    }

    private var card_body: some View {
        VStack(spacing: Space.s4) {
            ZStack {
                Circle().fill(tint.opacity(0.2)).frame(width: 72, height: 72)
                // Karar kategorisi SF Symbol ikonu (emoji yerine)
                Image(systemName: Icons.Decision.symbol(for: card.category.rawValue))
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(tint)
                    .symbolRenderingMode(.hierarchical)
            }
            .padding(.top, Space.s1)

            Text(card.speaker.uppercased())
                .font(.eyebrow)
                .kerning(0.8)
                .foregroundStyle(tint)

            Text(card.prompt)
                .font(.bodyL)
                .foregroundStyle(theme.text)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: Space.s2) {
                ForEach(Array(card.choices.enumerated()), id: \.offset) { idx, choice in
                    // İlk (cesur) seçim hafif tint dolgulu kenarlık, sonrası nötr.
                    let bold = idx == 0
                    Button {
                        Haptics.tap()
                        withAnimation(Motion.quick) { appeared = false }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { model.resolve(choice) }
                    } label: {
                        VStack(spacing: Space.s1) {
                            Text(choice.label)
                                .font(.appText(15, .bold))
                                .foregroundStyle(theme.text)
                            if let d = choice.detail {
                                detailRow(d)
                            }
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, Space.s3)
                        .background(bold ? tint.opacity(0.14) : theme.surfaceHigh,
                                    in: RoundedRectangle(cornerRadius: Radius.m))
                        .overlay(RoundedRectangle(cornerRadius: Radius.m)
                            .stroke(bold ? tint.opacity(0.6) : theme.hairline,
                                    lineWidth: bold ? 1.2 : 1))
                    }
                    .buttonStyle(.pressable)
                }
            }
        }
        .padding(Space.s5)
        .background(theme.surfaceLow, in: RoundedRectangle(cornerRadius: Radius.overlay))
        // Üst kenarda kategori tint'inde ışıltılı şerit.
        .overlay(alignment: .top) {
            RoundedRectangle(cornerRadius: 2)
                .fill(tint)
                .frame(height: 3)
                .padding(.horizontal, Space.s6)
        }
        .overlay(RoundedRectangle(cornerRadius: Radius.overlay).stroke(tint.opacity(0.32), lineWidth: 1))
        .shadow(color: .black.opacity(0.35), radius: 18, y: 6)
    }

    /// Etki ön-izleme satırı: + (yeşil ↑) / − (kırmızı ↓) ikonlu detay.
    private func detailRow(_ detail: String) -> some View {
        HStack(spacing: Space.s1) {
            let positive = detail.contains("+")
            let negative = detail.contains("−") || detail.contains("-") || detail.localizedCaseInsensitiveContains("risk")
            if positive {
                Image(systemName: "arrow.up").font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Palette.success)
            }
            if negative {
                Image(systemName: "arrow.down").font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Palette.danger)
            }
            Text(detail).font(.appText(11, .medium))
                .foregroundStyle(theme.textSecondary)
        }
    }
}
