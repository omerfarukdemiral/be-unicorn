import SwiftUI

/// Sağ kenarda tek sleek vertical rail — Aurora rafine.
///
/// Tasarım:
/// - İkon-only ~44pt; seçili öğe accent dolu pill + hairlineStrong stroke (neon halo YOK).
/// - Pasif: hierarchical SF Symbol + textSecondary; tek katman surfaceLow zemin + hairline.
/// - En altta ekstra eylemler: Defter (LessonsPanel sheet açar) + ses toggle.
struct SideRail: View {
    var theme: Theme
    @Binding var tab: GameTab
    let tabs: [GameTab]
    /// Defter (Kurucu Bilgeliği) sheet trigger.
    var onLessons: () -> Void
    /// Ses toggle handle.
    @Binding var soundEnabled: Bool

    private let itemSize: CGFloat = 40

    var body: some View {
        VStack(spacing: 4) {
            ForEach(tabs, id: \.self) { t in
                tabButton(t)
            }
            // Mini hairline divider (pasif).
            Rectangle()
                .fill(theme.hairline)
                .frame(width: 22, height: 1)
                .padding(.vertical, 4)
            // Defter (Kurucu Bilgeliği) — sheet açar.
            extraButton(symbol: "text.book.closed.fill",
                        label: "Defter",
                        action: { Haptics.tap(); onLessons() })
            // Ses toggle.
            extraButton(symbol: soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill",
                        label: soundEnabled ? "Sesi kapat" : "Sesi aç",
                        action: {
                            soundEnabled = AudioManager.shared.toggle()
                            Haptics.selection()
                        })
        }
        .padding(.vertical, Space.s2)
        .padding(.horizontal, Space.s1 + 2)
        .background(theme.surfaceLow, in: RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(theme.hairline, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 8, y: 3)
    }

    @ViewBuilder
    private func tabButton(_ t: GameTab) -> some View {
        let selected = tab == t
        Button {
            guard tab != t else { return }
            Feedback.select()
            withAnimation(Motion.smooth) { tab = t }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                    .fill(selected ? theme.accent : Color.clear)
                if selected {
                    RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                        .stroke(theme.hairlineStrong, lineWidth: 1)
                }
                Image(systemName: t.symbolName)
                    .font(.system(size: selected ? 17 : 16,
                                  weight: selected ? .bold : .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(selected ? .white : Palette.textSecondary)
                    .symbolEffect(.bounce, value: selected)
            }
            .frame(width: itemSize, height: itemSize)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(t.title)
    }

    private func extraButton(symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Palette.textSecondary)
                .frame(width: itemSize, height: itemSize - 4)
                .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(label)
    }
}
