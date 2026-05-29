import SwiftUI

/// Üst HUD — sleek dark premium, Aurora rafine.
///
/// Tasarım dili:
/// - Tek temiz katmanlı surfaceLow zemin (chunky bubble bar YOK, çift gradient + accent halo YOK).
/// - Üst satır SOL: avatar + eyebrow + nakit kahraman + net/ay.
///        SAĞ: kompakt zaman kontrol kapsülü + takvim chip + ses toggle.
/// - Orta satır: ince surfaceHigh stat satırı (users · MRR · runway).
/// - Alt satır: iki ince hairline progress bar (moral · sıradaki tur) — 4pt.
struct HUDView: View {
    @ObservedObject var model: GameModel
    var theme: Theme
    @Binding var soundEnabled: Bool
    @Binding var settingsOpen: Bool
    @Binding var lessonsOpen: Bool

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

    private var runwayText: String {
        if model.netPerMonth >= 0 { return "∞" }
        let m = model.runwayMonths
        if m >= 99 { return "99+" }
        if m >= 12 { return "\(Int(m.rounded()))ay" }
        return String(format: "%.1fay", m)
    }
    private var runwayTint: Color {
        if model.netPerMonth >= 0 { return Palette.success }
        if model.runwayMonths < 3 { return Palette.danger }
        if model.runwayMonths < 6 { return Palette.warning }
        return Palette.textSecondary
    }

    var body: some View {
        VStack(spacing: Space.s2 + 2) {
            topRow
            statsRow
            barsRow
        }
        .padding(.horizontal, Space.s4)
        .padding(.vertical, Space.s3)
        .background(theme.surfaceLow, in: RoundedRectangle(cornerRadius: Radius.overlay))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.overlay)
                .stroke(theme.hairline, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 8, y: 3)
        .scaleEffect(cashPop)
        .onAppear { startPulseIfNeeded() }
        .onChange(of: negative) { _, _ in startPulseIfNeeded() }
        .onChange(of: moraleCritical) { _, _ in startPulseIfNeeded() }
        .onChange(of: model.cash) { old, new in
            if new - old > 1000 {
                withAnimation(Motion.snappy) { cashPop = 1.03 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    withAnimation(Motion.snappy) { cashPop = 1 }
                }
            }
        }
        .sheet(isPresented: $showLeaderboard) {
            LeaderboardSheet(model: model, theme: theme)
        }
    }

    // MARK: - Üst satır: SOL (avatar + cash) · SAĞ (kontrol)

    private var topRow: some View {
        HStack(alignment: .center, spacing: Space.s3) {
            leftGroup
                .layoutPriority(1)
            Spacer(minLength: Space.s2)
            rightGroup
                .fixedSize(horizontal: true, vertical: false)
        }
    }

    private var leftGroup: some View {
        HStack(spacing: Space.s2 + 2) {
            avatarBadge
            VStack(alignment: .leading, spacing: 1) {
                eyebrowRow
                Text(BigNumber.money(model.cash))
                    .font(.displayL)
                    .foregroundStyle(negative ? Palette.danger : Palette.textPrimary)
                    .contentTransition(.numericText())
                    .lineLimit(1).minimumScaleFactor(0.6)
                    .opacity(negative && pulse ? 0.7 : 1)
                netLine
            }
        }
    }

    /// Eyebrow satırı — kurucu ilk adı (gold) + evre (accent), tek satır.
    private var eyebrowRow: some View {
        HStack(spacing: 4) {
            if let founder = model.founderMember, !founder.firstName.isEmpty {
                Text(founder.firstName.uppercased())
                    .foregroundStyle(Palette.gold)
                Text("·").foregroundStyle(theme.subtle)
            }
            Text(model.currentStage.name.uppercased())
                .foregroundStyle(theme.accent)
        }
        .font(.eyebrow).kerning(0.8)
        .lineLimit(1)
        .fixedSize(horizontal: false, vertical: false)
    }

    /// Küçük dairesel avatar — 30pt, sade 1pt hairline halka, tap → leaderboard.
    private var avatarBadge: some View {
        Button { Haptics.tap(); showLeaderboard = true } label: {
            ZStack {
                Circle()
                    .fill(theme.surfaceHigh)
                    .frame(width: 32, height: 32)
                    .overlay(Circle().stroke(theme.hairline, lineWidth: 1))
                Image(systemName: Icons.Screen.founder)
                    .font(.system(size: 17, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Palette.textPrimary)
                // Sağ-alt: lig tier rozeti — küçük accent dolgulu daire.
                Circle()
                    .fill(leagueColor)
                    .frame(width: 13, height: 13)
                    .overlay(
                        Text("\(model.leagueTier + 1)")
                            .font(.appNumber(8, .heavy))
                            .foregroundStyle(.black.opacity(0.85))
                    )
                    .overlay(Circle().stroke(theme.surfaceLow, lineWidth: 1.2))
                    .offset(x: 11, y: 11)
            }
            .frame(width: 32, height: 32)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("Kurucu, \(model.currentLeague.name)")
    }

    /// Net/ay — küçük renkli etiket.
    private var netLine: some View {
        let positive = net >= 0
        let color: Color = positive ? Palette.success : Palette.danger
        let sign = positive ? "+" : ""
        return HStack(spacing: 3) {
            Image(systemName: positive ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 8.5, weight: .bold))
            Text("\(sign)\(BigNumber.money(net))/ay")
                .font(.appNumber(10.5, .bold))
                .contentTransition(.numericText())
        }
        .foregroundStyle(color)
        .lineLimit(1)
    }

    // MARK: - Orta satır: ince stat row (users · MRR · runway)

    private var statsRow: some View {
        HStack(spacing: 0) {
            statCell(label: "Kullanıcı", value: BigNumber.format(model.users), tint: Palette.textPrimary)
            divider
            statCell(label: "MRR", value: BigNumber.money(model.mrr), tint: Palette.textPrimary)
            divider
            statCell(label: "Runway", value: runwayText, tint: runwayTint)
        }
        .padding(.horizontal, Space.s2)
        .padding(.vertical, Space.s2 - 2)
        .background(theme.surfaceHigh, in: RoundedRectangle(cornerRadius: Radius.s))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.s)
                .stroke(theme.hairline, lineWidth: 1)
        )
    }

    private func statCell(label: String, value: String, tint: Color) -> some View {
        VStack(spacing: 0) {
            Text(value)
                .font(.numberL)
                .foregroundStyle(tint)
                .contentTransition(.numericText())
                .lineLimit(1).minimumScaleFactor(0.55)
            Text(label)
                .font(.appText(9.5, .medium))
                .kerning(0.4)
                .foregroundStyle(Palette.textTertiary)
                .lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle()
            .fill(theme.hairline)
            .frame(width: 1, height: 22)
    }

    // MARK: - SAĞ: zaman kontrol + takvim + ses (alt alta)

    private var rightGroup: some View {
        VStack(alignment: .trailing, spacing: Space.s1 + 2) {
            timeControlPill
            // Sabit kontrol satırı: takvim (günler) · Defter · ayarlar — yüzen ikon YOK.
            HStack(spacing: 5) {
                calendarChip
                bookButton
                gearButton
            }
        }
    }

    /// Defter (dersler) — takvim ile ayar arasında SABİT buton (eskiden yüzen chip'ti).
    private var bookButton: some View {
        Button { Haptics.selection(); lessonsOpen = true } label: {
            Image(systemName: "book.closed.fill")
                .font(.system(size: 10.5, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(theme.accent)
                .frame(width: 24, height: 24)
                .background(theme.surfaceHigh, in: Circle())
                .overlay(Circle().stroke(theme.hairline, lineWidth: 1))
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("Defter")
    }

    private var timeControlPill: some View {
        HStack(spacing: 0) {
            timeButton(
                systemName: model.isPaused ? "play.fill" : "pause.fill",
                active: model.isPaused,
                tint: Palette.warning
            ) { Haptics.selection(); model.togglePause() }
            Rectangle()
                .fill(theme.hairline)
                .frame(width: 1, height: 14)
            timeButton(
                systemName: "forward.fill",
                label: "\(Int(model.speed))×",
                active: model.speed > 1 && !model.isPaused,
                tint: theme.accent
            ) { Haptics.selection(); model.cycleSpeed() }
        }
        .padding(2)
        .background(theme.surfaceHigh, in: Capsule())
        .overlay(Capsule().stroke(theme.hairline, lineWidth: 1))
    }

    private func timeButton(systemName: String, label: String? = nil, active: Bool, tint: Color,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: systemName)
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(active ? .white : Palette.textSecondary)
                if let label {
                    Text(label).font(.appNumber(10.5, .heavy))
                        .foregroundStyle(active ? .white : Palette.textSecondary)
                }
            }
            .padding(.horizontal, Space.s2).padding(.vertical, 5)
            .background(
                Capsule().fill(active ? tint.opacity(0.92) : .clear)
            )
        }
        .buttonStyle(.pressable)
    }

    private var calendarChip: some View {
        HStack(spacing: 3) {
            Image(systemName: "calendar")
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(Palette.textTertiary)
            Text("Ç\(model.quarterNumber)·S\(model.seasonNumber)")
                .font(.appNumber(10, .bold))
                .foregroundStyle(Palette.textSecondary)
        }
        .padding(.horizontal, Space.s2).padding(.vertical, 4)
        .background(theme.surfaceHigh, in: Capsule())
        .overlay(Capsule().stroke(theme.hairline, lineWidth: 1))
    }

    private var gearButton: some View {
        Button {
            Haptics.tap(); settingsOpen = true
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 10.5, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Palette.textSecondary)
                .frame(width: 24, height: 24)
                .background(theme.surfaceHigh, in: Circle())
                .overlay(Circle().stroke(theme.hairline, lineWidth: 1))
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("Ayarlar")
    }

    // MARK: - ALT: iki ince progress bar (moral · sıradaki tur)

    private var barsRow: some View {
        HStack(spacing: Space.s4) {
            progressLine(label: "Moral", value: "\(Int(model.morale))",
                         fraction: max(0, min(1, model.morale / 100)),
                         tint: moraleColor, critical: moraleCritical)
            progressLine(label: nextRoundLabel, value: "\(Int(model.raiseProgress * 100))%",
                         fraction: model.raiseProgress,
                         tint: theme.accent, critical: false)
        }
    }

    private var nextRoundLabel: String {
        if let next = model.nextStage { return next.name }
        return "Final"
    }

    private func progressLine(label: String, value: String, fraction: Double,
                              tint: Color, critical: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: Space.s2) {
                Text(label)
                    .font(.labelText)
                    .foregroundStyle(Palette.textTertiary)
                    .lineLimit(1)
                Spacer(minLength: 2)
                Text(value)
                    .font(.numberS)
                    .foregroundStyle(critical ? Palette.danger : Palette.textSecondary)
                    .contentTransition(.numericText())
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(theme.hairline)
                    Capsule()
                        .fill(tint)
                        .frame(width: max(2, geo.size.width * fraction))
                }
            }
            .frame(height: 4)
        }
    }

    // MARK: - Pulse (negatif nakit / kritik moral)
    private func startPulseIfNeeded() {
        let needsPulse = negative || moraleCritical
        if needsPulse {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                pulse = true
            }
        } else {
            pulse = false
        }
    }
}
