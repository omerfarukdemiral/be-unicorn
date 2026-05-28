import SwiftUI

/// Üst HUD — BitLife / Idle Tycoon tarzı tek BÜYÜK ŞİŞKİN "bubble bar".
///
/// Tasarım:
/// - Tek geniş RoundedRectangle (chunky panel) — kalın stroke + dış drop shadow + üst light highlight.
/// - 3 grup yatayda:
///   • LEFT: dairesel kurucu avatarı (+ kron + lig sıralaması rozeti) + nakit pill + altında net "+$X/ay" pill.
///   • CENTER: moral pill + kullanıcı pill (kritikse kırmızı uyarı noktası).
///   • RIGHT: ⏸/▶/⏩ zaman kontrol pill'i + takvim chip + dişli (ses).
/// - Tüm pill'ler chunky padding, thick stroke, soft shadow, numericText sayı animasyonu.
struct HUDView: View {
    @ObservedObject var model: GameModel
    var theme: Theme
    @Binding var soundEnabled: Bool

    @State private var pulse = false
    @State private var cashPop: CGFloat = 1
    @State private var showLeaderboard = false

    private var negative: Bool { model.cash < 0 }
    private var net: Double { model.netPerMonth }
    private var moraleColor: Color {
        model.morale < 30 ? Palette.danger : model.morale < 60 ? Palette.warning : Palette.success
    }
    private var moraleCritical: Bool { model.morale < 30 }
    private var leagueColor: Color { Color(hex: model.currentLeague.colorHex) }

    var body: some View {
        bubblePanel
            .overlay(
                HStack(alignment: .center, spacing: Space.s2) {
                    leftGroup
                    Spacer(minLength: 4)
                    centerGroup
                    Spacer(minLength: 4)
                    rightGroup
                }
                .padding(.horizontal, Space.s3 - 2)
                .padding(.vertical, Space.s2 - 1)
            )
            .scaleEffect(cashPop)
            .onAppear { startPulseIfNeeded() }
            .onChange(of: negative) { _, _ in startPulseIfNeeded() }
            .onChange(of: model.cash) { old, new in
                if new - old > 1000 {
                    withAnimation(Motion.snappy) { cashPop = 1.04 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                        withAnimation(Motion.snappy) { cashPop = 1 }
                    }
                }
            }
            .sheet(isPresented: $showLeaderboard) {
                LeaderboardSheet(model: model, theme: theme)
            }
    }

    // MARK: - Bubble bar zemini (chunky 3D pop)

    private var bubblePanel: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        theme.surfaceElevated.opacity(0.98),
                        theme.surface.opacity(0.96)
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .overlay(
                // İç üst highlight — 3D pop (cam üstü ışık).
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.32),
                                .white.opacity(0.04),
                                .black.opacity(0.2)
                            ],
                            startPoint: .top, endPoint: .bottom
                        ),
                        lineWidth: 1.2
                    )
            )
            .overlay(
                // Dış chunky kontur (kartoonsu kalın çerçeve).
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(theme.accent.opacity(0.4), lineWidth: 1.8)
            )
            .shadow(color: .black.opacity(0.45), radius: 12, x: 0, y: 7)
            .frame(height: 78)
    }

    // MARK: - LEFT: avatar + nakit + net

    private var leftGroup: some View {
        HStack(spacing: Space.s2) {
            avatarBadge
            VStack(alignment: .leading, spacing: 3) {
                cashPill
                netPill
            }
        }
    }

    /// Dairesel kurucu avatarı — kron + lig sıralaması rozeti üstte/altta.
    private var avatarBadge: some View {
        Button { Haptics.tap(); showLeaderboard = true } label: {
            ZStack {
                // Dış halka (chunky stroke + glow).
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                leagueColor.opacity(0.95),
                                leagueColor.opacity(0.6)
                            ],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .frame(width: 50, height: 50)
                    .overlay(Circle().stroke(.white.opacity(0.45), lineWidth: 2))
                    .shadow(color: .black.opacity(0.35), radius: 5, y: 2)
                // İç avatar (kurucu glyph).
                Circle()
                    .fill(theme.surfaceElevated)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: Icons.Screen.founder)
                            .font(.system(size: 22, weight: .bold))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.white.opacity(0.92))
                    )
                    .overlay(Circle().stroke(.white.opacity(0.15), lineWidth: 1))

                // Üstte kron rozeti.
                VStack {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(Palette.gold)
                        .offset(y: -3)
                    Spacer()
                }
                .frame(width: 50, height: 50)

                // Sağ-alt: lig tier rozeti (küçük altın badge — 1..6).
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        ZStack {
                            Circle().fill(Palette.gold)
                                .frame(width: 19, height: 19)
                                .overlay(Circle().stroke(.white.opacity(0.7), lineWidth: 1.4))
                                .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                            Text("\(model.leagueTier + 1)")
                                .font(.appNumber(11, .black))
                                .foregroundStyle(.black.opacity(0.82))
                        }
                        .offset(x: 4, y: 4)
                    }
                }
                .frame(width: 50, height: 50)
            }
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("Kurucu, \(model.currentLeague.name)")
    }

    /// Nakit pill — chunky "$" daire + büyük rakam.
    private var cashPill: some View {
        HStack(spacing: 5) {
            ZStack {
                Circle()
                    .fill(negative ? Palette.danger : Palette.success)
                    .frame(width: 22, height: 22)
                    .overlay(Circle().stroke(.white.opacity(0.4), lineWidth: 1.2))
                Image(systemName: negative ? "exclamationmark" : "dollarsign")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(.white)
            }
            Text(BigNumber.money(model.cash))
                .font(.appNumber(15, .heavy))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.leading, 4).padding(.trailing, Space.s2).padding(.vertical, 3)
        .background(Capsule().fill(theme.surfaceHigh))
        .overlay(
            Capsule().stroke(negative ? Palette.danger.opacity(0.55) : .white.opacity(0.18),
                             lineWidth: 1.4)
        )
        // Negatif nakit: yumuşatılmış kırmızı nabız (eskisinden ~40% düşük yoğunluk).
        .shadow(color: negative ? Palette.danger.opacity(pulse ? 0.3 : 0.1) : .black.opacity(0.3),
                radius: negative && pulse ? 11 : 4, y: 2)
    }

    /// Altta küçük net "+$X/ay" pill (pozitifse yeşil, negatifse kırmızı).
    private var netPill: some View {
        let positive = net >= 0
        let color: Color = positive ? Palette.success : Palette.danger
        let sign = positive ? "+" : ""
        return HStack(spacing: 3) {
            Image(systemName: positive ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 9, weight: .black))
                .foregroundStyle(.white)
            Text("\(sign)\(BigNumber.money(net))/ay")
                .font(.appNumber(9.5, .heavy))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, Space.s2).padding(.vertical, 2.5)
        .background(Capsule().fill(color))
        .overlay(Capsule().stroke(.white.opacity(0.45), lineWidth: 1.1))
        .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
    }

    // MARK: - CENTER: moral + kullanıcı

    private var centerGroup: some View {
        VStack(spacing: 4) {
            moralePill
            usersPill
        }
    }

    private var moralePill: some View {
        HStack(spacing: 3) {
            Image(systemName: moraleCritical ? "face.dashed.fill" : "face.smiling.fill")
                .font(.system(size: 13, weight: .black))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(moraleColor)
            Text("\(Int(model.morale))")
                .font(.appNumber(13, .heavy))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .lineLimit(1)
        }
        .padding(.horizontal, Space.s2).padding(.vertical, 3)
        .background(Capsule().fill(theme.surfaceHigh))
        .overlay(Capsule().stroke(moraleColor.opacity(0.5), lineWidth: 1.3))
        .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
        .overlay(alignment: .topTrailing) {
            if moraleCritical {
                Circle().fill(Palette.danger)
                    .frame(width: 8, height: 8)
                    .overlay(Circle().stroke(.white, lineWidth: 1))
                    .offset(x: 2, y: -2)
                    .opacity(pulse ? 1 : 0.5)
            }
        }
    }

    private var usersPill: some View {
        HStack(spacing: 3) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 11, weight: .black))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(theme.accent)
            Text(BigNumber.format(model.users))
                .font(.appNumber(11, .heavy))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .lineLimit(1)
        }
        .padding(.horizontal, Space.s2).padding(.vertical, 2.5)
        .background(Capsule().fill(theme.surfaceHigh))
        .overlay(Capsule().stroke(theme.accent.opacity(0.45), lineWidth: 1.1))
        .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
    }

    // MARK: - RIGHT: zaman + takvim + dişli

    private var rightGroup: some View {
        VStack(alignment: .trailing, spacing: 4) {
            timeControlPill
            HStack(spacing: 3) {
                calendarChip
                gearButton
            }
        }
    }

    /// ⏸ ▶ ⏩ tek pill içinde — aktif duruma göre dolgu.
    private var timeControlPill: some View {
        HStack(spacing: 0) {
            timeButton(
                systemName: model.isPaused ? "play.fill" : "pause.fill",
                active: model.isPaused,
                tint: Palette.warning
            ) { Haptics.selection(); model.togglePause() }
            Capsule().fill(.white.opacity(0.08)).frame(width: 1, height: 14)
            timeButton(
                systemName: "forward.fill",
                label: "\(Int(model.speed))×",
                active: model.speed > 1 && !model.isPaused,
                tint: theme.accent
            ) { Haptics.selection(); model.cycleSpeed() }
        }
        .padding(2)
        .background(Capsule().fill(theme.surfaceHigh))
        .overlay(Capsule().stroke(.white.opacity(0.18), lineWidth: 1.1))
        .shadow(color: .black.opacity(0.3), radius: 3, y: 2)
    }

    private func timeButton(systemName: String, label: String? = nil, active: Bool, tint: Color,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: systemName)
                    .font(.system(size: 10.5, weight: .black))
                    .foregroundStyle(active ? .white : tint.opacity(0.85))
                if let label {
                    Text(label).font(.appNumber(10.5, .heavy))
                        .foregroundStyle(active ? .white : tint.opacity(0.85))
                }
            }
            .padding(.horizontal, Space.s2 - 2).padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(active ? tint : .clear)
            )
        }
        .buttonStyle(.pressable)
    }

    /// Takvim chip — "Ç{N}·S{N}" (mevcut çeyrek ve sezon kompakt).
    private var calendarChip: some View {
        HStack(spacing: 3) {
            Image(systemName: "calendar")
                .font(.system(size: 10, weight: .black))
                .foregroundStyle(Palette.gold)
            Text("Ç\(model.quarterNumber)·S\(model.seasonNumber)")
                .font(.appNumber(10, .heavy))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, Space.s2 - 2).padding(.vertical, 3.5)
        .background(Capsule().fill(theme.surfaceHigh))
        .overlay(Capsule().stroke(Palette.gold.opacity(0.45), lineWidth: 1.1))
        .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
    }

    /// Dişli — ses aç/kapa toggle (sağda kompakt).
    private var gearButton: some View {
        Button {
            soundEnabled = AudioManager.shared.toggle()
            Haptics.selection()
        } label: {
            Image(systemName: soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                .font(.system(size: 11, weight: .black))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(soundEnabled ? theme.accent : Palette.textTertiary)
                .frame(width: 22, height: 22)
                .background(Circle().fill(theme.surfaceHigh))
                .overlay(Circle().stroke(.white.opacity(0.18), lineWidth: 1.1))
                .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(soundEnabled ? "Sesi kapat" : "Sesi aç")
    }

    // MARK: - Pulse (negatif nakit / kritik moral uyarısı)

    private func startPulseIfNeeded() {
        let needsPulse = negative || moraleCritical
        if needsPulse {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulse = true
            }
        } else {
            pulse = false
        }
    }
}
