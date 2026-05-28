import SwiftUI

/// Sol/sağ yüzen chunky nav kümeleri — sağdaki "rail" yerine her iki yana havada
/// duran şişkin ikon yığınları (Idle Tycoon hissi).
///
/// SOL küme: ana oyun döngüsü — Office · Team · Growth · Projects.
/// SAĞ küme: meta — Modules · Roadmap · Stats.
///
/// Tasarım:
/// - Daire şeklinde chunky ikon-butonlar; seçili: accent dolgu + glow + bounce.
/// - Pasif: hierarchical mat ikon, ince beyaz stroke.
/// - Küme zemini: ultraThinMaterial + thick stroke + drop shadow + ince glow.
struct FloatingNavCluster: View {
    var theme: Theme
    @Binding var tab: GameTab
    let tabs: [GameTab]
    /// Sol veya sağ küme — küçük yön/anchor farkı için.
    let side: Side

    enum Side { case left, right }

    private let itemSize: CGFloat = 46

    var body: some View {
        VStack(spacing: 10) {
            ForEach(tabs, id: \.self) { t in
                tabButton(t)
            }
        }
        .padding(.vertical, Space.s3)
        .padding(.horizontal, 8)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(theme.surfaceElevated.opacity(0.55))
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.32),
                                .white.opacity(0.06),
                                .black.opacity(0.18)
                            ],
                            startPoint: .top, endPoint: .bottom
                        ),
                        lineWidth: 1.2
                    )
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(theme.accent.opacity(0.35), lineWidth: 2)
                    .blendMode(.plusLighter)
                    .opacity(0.55)
            }
            .shadow(color: .black.opacity(0.5),
                    radius: 16,
                    x: side == .left ? 4 : -4,
                    y: 8)
        )
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
                if selected {
                    // Aktif: accent dolu chunky daire + glow.
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [theme.accent, theme.accent.opacity(0.78)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .shadow(color: .black.opacity(0.3), radius: 5, y: 2)
                        .overlay(Circle().stroke(.white.opacity(0.45), lineWidth: 1.5))
                } else {
                    // Pasif: mat daire + ince stroke.
                    Circle()
                        .fill(theme.surfaceHigh.opacity(0.7))
                        .overlay(Circle().stroke(.white.opacity(0.12), lineWidth: 1))
                }

                Image(systemName: t.symbolName)
                    .font(.system(size: selected ? 22 : 19,
                                  weight: selected ? .black : .bold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(selected ? .white : Palette.textSecondary)
                    .symbolEffect(.bounce, value: selected)
            }
            .frame(width: itemSize, height: itemSize)
            .contentShape(Circle())
            .overlay(alignment: .bottom) {
                // Mikro alt etiket — seçili sekme adı (kompakt, görsel hiyerarşi).
                if selected {
                    Text(t.title.uppercased())
                        .font(.appText(8, .black))
                        .kerning(0.6)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(Capsule().fill(theme.accent))
                        .overlay(Capsule().stroke(.white.opacity(0.5), lineWidth: 1))
                        .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                        .offset(y: 10)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(t.title)
    }
}
