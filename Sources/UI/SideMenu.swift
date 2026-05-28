import SwiftUI

/// Sağ kenar dikey ikon menüsü — dikey mobil oyunlardaki "side rail" hissi.
///
/// - 7 sekme yukarıdan aşağıya icon-only dizilir.
/// - Seçili sekme: accent dolgu pill + glow halkası + büyük ikon.
/// - Diğerleri: yarı opak hierarchical ikon.
/// - En altta küçük ses toggle (eski tabBar'dan taşındı).
/// - Sticky/floating: ZStack içinde trailing'e yerleşir, safe-area + alt margin'le bekler.
struct SideMenu: View {
    @ObservedObject var model: GameModel
    @Binding var tab: GameTab
    var theme: Theme
    @Binding var soundEnabled: Bool

    private let columnWidth: CGFloat = 58
    private let itemSize: CGFloat = 44

    var body: some View {
        VStack(spacing: 6) {
            // SAĞ-ÜST zaman kontrolü: duraklat/oynat + hız (1×/2×/3×). Global.
            timeControl
            // İnce ayraç (kontrol bloğu ile menü arası).
            Capsule().fill(theme.hairline)
                .frame(width: itemSize - 14, height: 1)
                .padding(.vertical, 4)

            ForEach(GameTab.allCases, id: \.self) { t in
                tabButton(t)
            }
            Spacer(minLength: 8)
            soundToggle
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 7)
        .frame(width: columnWidth)
        .background(
            // Cam panel + ince accent halka (oyun side-rail kültürü).
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(theme.hairline, lineWidth: 1)
                // Sol kenar boyunca ince accent vurgu çizgisi (sci-fi rail hissi).
                HStack {
                    Capsule()
                        .fill(theme.accent.opacity(0.45))
                        .frame(width: 2)
                        .padding(.vertical, 14)
                    Spacer()
                }
            }
            .shadow(color: .black.opacity(0.35), radius: 14, x: -4, y: 6)
            .shadow(color: theme.accent.opacity(0.18), radius: 18, x: -2, y: 0)
        )
    }

    /// Sekme butonu — seçili: accent pill + glow; pasif: hierarchical mat ikon.
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
                    // Aktif: dolgulu pill + glow halkası.
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(theme.accent.opacity(0.92))
                        .shadow(color: theme.accent.opacity(0.55), radius: 10, y: 2)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(.white.opacity(0.25), lineWidth: 1)
                        )
                }
                Image(systemName: t.symbolName)
                    .font(.system(size: selected ? 20 : 18, weight: selected ? .bold : .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(selected ? .white : Palette.textSecondary)
                    .symbolEffect(.bounce, value: selected)
            }
            .frame(width: itemSize, height: itemSize)
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(t.title)
    }

    /// Sağ-üst zaman kontrolü: duraklat/oynat + hız (1×/2×/3×).
    /// Pause aktifken hız pill'i sönükleşir; hız bas → otomatik devam.
    private var timeControl: some View {
        VStack(spacing: 4) {
            // Pause / Play
            Button {
                Haptics.selection()
                model.togglePause()
            } label: {
                Image(systemName: model.isPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(model.isPaused ? .white : theme.accent)
                    .frame(width: itemSize, height: 32)
                    .background(
                        Capsule().fill(model.isPaused ? Palette.warning : theme.surfaceHigh)
                    )
                    .overlay(Capsule().stroke(theme.accent.opacity(model.isPaused ? 0 : 0.45), lineWidth: 1))
                    .shadow(color: model.isPaused ? Palette.warning.opacity(0.45) : .clear, radius: 6, y: 2)
            }
            .buttonStyle(.pressable)
            .accessibilityLabel(model.isPaused ? "Devam et" : "Duraklat")

            // Hız pill (1× / 2× / 3×) — tap to cycle
            Button {
                Haptics.selection()
                model.cycleSpeed()
            } label: {
                let active = model.speed > 1 && !model.isPaused
                HStack(spacing: 2) {
                    Image(systemName: "forward.fill").font(.system(size: 9, weight: .bold))
                    Text("\(Int(model.speed))×").font(.numberXS)
                }
                .foregroundStyle(active ? .white : (model.isPaused ? Palette.textTertiary : theme.accent))
                .frame(width: itemSize, height: 26)
                .background(
                    Capsule().fill(active ? theme.accent : theme.surfaceHigh.opacity(model.isPaused ? 0.5 : 1))
                )
                .overlay(Capsule().stroke(theme.accent.opacity(active ? 0 : (model.isPaused ? 0.2 : 0.45)), lineWidth: 1))
                .shadow(color: active ? theme.accent.opacity(0.35) : .clear, radius: 5, y: 2)
            }
            .buttonStyle(.pressable)
            .accessibilityLabel("Hız \(Int(model.speed)) kat")
        }
    }

    /// Sesi aç/kapa toggle'ı — kolonun en altında küçük ikon.
    private var soundToggle: some View {
        Button {
            soundEnabled = AudioManager.shared.toggle()
            Haptics.selection()
        } label: {
            Image(systemName: soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                .font(.system(size: 14, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(soundEnabled ? theme.accent : Palette.textTertiary)
                .frame(width: itemSize, height: 32)
                .background(
                    Capsule().fill(.white.opacity(0.05))
                )
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(soundEnabled ? "Sesi kapat" : "Sesi aç")
    }
}
