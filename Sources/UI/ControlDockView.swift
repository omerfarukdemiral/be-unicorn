import SwiftUI

/// Yatay komut dock'u — alt tab bar'ın HEMEN ÜSTÜNDE yüzen, baş parmağa yakın global
/// kontroller: oynat/duraklat · hız · sezon · defter · ayar.
///
/// Eskiden bu küme HUD'un sağ-üst köşesinde dikey sıkışıktı ve erişimi zordu (kullanıcı
/// geri bildirimi). Buraya yatay, animasyonlu bir dock'a taşındı; HUD üstü sadeleşip nakit
/// kahramanı nefes aldı.
///
/// Tasarım dili HUD ile tutarlı: surfaceLow zemin + hairline + yumuşak gölge. Birincil
/// aksiyon (oynat/duraklat) dolgulu daire — oynarken accent + nefes-alan halo, duraklatınca
/// amber çağrı (zaman-durumu overlay'iyle aynı renk dili).
struct ControlDockView: View {
    @ObservedObject var model: GameModel
    var theme: Theme
    @Binding var settingsOpen: Bool
    @Binding var lessonsOpen: Bool

    @State private var glow = false
    @State private var speedPop: CGFloat = 1

    private var playing: Bool { !model.isPaused }

    var body: some View {
        HStack(spacing: Space.s2) {
            playPauseButton
            speedButton
            Spacer(minLength: Space.s2)
            seasonChip
            Spacer(minLength: Space.s2)
            circleButton(icon: "book.closed.fill", tint: theme.accent, label: "Defter",
                         badgeCount: model.state.newLessonIds.count) {
                Haptics.selection(); lessonsOpen = true
            }
            circleButton(icon: "gearshape.fill", tint: Palette.textSecondary, label: "Ayarlar") {
                Haptics.tap(); settingsOpen = true
            }
        }
        .padding(.horizontal, Space.s3)
        .padding(.vertical, Space.s2)
        // Belirgin "yükseltilmiş" yüzey — kart zemininden (surfaceLow) daha parlak, accent
        // tonlu kenarlık + çift gölge (siyah derinlik + hafif accent ışıltı) ile içerikten
        // net ayrışır. Eskiden surfaceLow'du ve arka kartlarla karışıyordu (kullanıcı geri bildirimi).
        .background(theme.surfaceElevated, in: Capsule())
        .overlay(Capsule().stroke(theme.accent.opacity(0.45), lineWidth: 1.5))
        .shadow(color: .black.opacity(0.4), radius: 14, y: 5)
        .shadow(color: theme.accent.opacity(0.18), radius: 10, y: 0)
        .onAppear { updateGlow() }
        .onChange(of: model.isPaused) { _, _ in updateGlow() }
    }

    // MARK: - Birincil: oynat / duraklat (trafik-ışığı: kırmızı=dur, yeşil=devam ediyor)

    private var playPauseButton: some View {
        let paused = model.isPaused
        // Durum-rengi (kullanıcı isteği): duraklı → kırmızı (dur), oynuyor → yeşil (devam).
        let tint = paused ? Palette.danger : Palette.success
        return Button {
            Haptics.selection(); model.togglePause()
        } label: {
            Image(systemName: paused ? "play.fill" : "pause.fill")
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(Circle().fill(tint))
                .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 1))
                .shadow(color: tint.opacity(playing && glow ? 0.6 : 0.25),
                        radius: playing && glow ? 11 : 5, y: 2)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(paused ? "Devam et" : "Duraklat")
    }

    // MARK: - Hız — forward + N× (aktifken accent; değişimde pop)

    private var speedButton: some View {
        let active = model.speed > 1 && !model.isPaused
        return Button {
            Haptics.selection(); model.cycleSpeed()
            withAnimation(Motion.snappy) { speedPop = 1.15 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                withAnimation(Motion.snappy) { speedPop = 1 }
            }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 11, weight: .bold))
                Text("\(Int(model.speed))×")
                    .font(.appNumber(12, .heavy))
                    .contentTransition(.numericText())
            }
            .foregroundStyle(active ? .white : Palette.textSecondary)
            .padding(.horizontal, Space.s2 + 2).padding(.vertical, 7)
            .background(Capsule().fill(active ? theme.accent.opacity(0.92) : theme.surfaceHigh))
            .overlay(Capsule().stroke(theme.hairline, lineWidth: 1))
            .scaleEffect(speedPop)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("Hız \(Int(model.speed)) kat")
    }

    // MARK: - Sezon bilgi chip'i (Ç·S)

    private var seasonChip: some View {
        HStack(spacing: 4) {
            Image(systemName: "calendar")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Palette.textTertiary)
            Text("Ç\(model.quarterNumber)·S\(model.seasonNumber)")
                .font(.appNumber(12, .bold))
                .foregroundStyle(Palette.textSecondary)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, Space.s2 + 2).padding(.vertical, 7)
        .background(Capsule().fill(theme.surfaceHigh))
        .overlay(Capsule().stroke(theme.hairline, lineWidth: 1))
        .accessibilityLabel("Çeyrek \(model.quarterNumber), sezon \(model.seasonNumber)")
    }

    // MARK: - Yardımcı: dairesel ikon buton (defter · ayar)

    private func circleButton(icon: String, tint: Color, label: String,
                              badgeCount: Int = 0,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(theme.surfaceHigh, in: Circle())
                .overlay(Circle().stroke(theme.hairline, lineWidth: 1))
                // "YENİ ders" rozeti: sağ-üstte sayı çipi; Defter açılınca markLessonsSeen temizler.
                .overlay(alignment: .topTrailing) {
                    if badgeCount > 0 {
                        Text("\(min(badgeCount, 9))")
                            .font(.appNumber(10, .heavy))
                            .foregroundStyle(.white)
                            .frame(minWidth: 16, minHeight: 16)
                            .background(Circle().fill(Palette.danger))
                            .overlay(Circle().stroke(theme.surfaceElevated, lineWidth: 1.5))
                            .offset(x: 5, y: -5)
                    }
                }
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(badgeCount > 0 ? "\(label), \(badgeCount) yeni" : label)
    }

    private func updateGlow() {
        if playing {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                glow = true
            }
        } else {
            withAnimation(.easeInOut(duration: 0.3)) { glow = false }
        }
    }
}
