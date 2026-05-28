import SwiftUI

/// Ana ofis ekranı — sleek Aurora.
///
/// Düzen:
/// - (üstte) Eğer canRaise ise: yatay sade "Tur Topla" success-tint pill (sade, glow yok).
/// - Kroki (FloorPlanView) hero — dikey ~60% yer kaplar (içerideki canvas yüksekliğini büyüttük).
/// - Alt action strip: Sprint mini-card · Günlük mini-card · Mağaza primary CTA.
///   Halka/glow chip YOK — sade pill kartlar şeridi.
struct OfficePanel: View {
    @ObservedObject var model: GameModel
    var theme: Theme
    @State private var showShop = false
    @State private var expanded: GoalsStrip.Detail? = nil

    var body: some View {
        VStack(spacing: Space.s3) {
            if model.canRaise, let next = model.nextStage {
                raiseStrip(next)
            }

            // Hero: kroki sahnesi (büyük).
            FloorPlanView(model: model, theme: theme)
                .frame(maxHeight: .infinity)

            // Alt action strip — Sprint · Günlük · Mağaza
            actionStrip
        }
        .padding(.vertical, Space.s2)
        .sheet(isPresented: $showShop) {
            ItemShopView(model: model, theme: theme)
        }
        .sheet(item: $expanded) { which in
            GoalDetailSheet(model: model, theme: theme, detail: which)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Raise strip (canRaise ise, HUD altında sade)

    private func raiseStrip(_ next: StageDef) -> some View {
        Button { Haptics.medium(); model.raiseRound() } label: {
            HStack(spacing: Space.s2) {
                Image(systemName: Icons.Screen.raise)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                Text("\(next.name) Topla")
                    .font(.bodyL)
                    .foregroundStyle(.white)
                Spacer(minLength: 0)
                Text("+\(BigNumber.money(next.raiseAmount))")
                    .font(.numberM)
                    .foregroundStyle(.white.opacity(0.92))
            }
            .padding(.horizontal, Space.s3).padding(.vertical, Space.s2 + 2)
            .background(Palette.success, in: RoundedRectangle(cornerRadius: Radius.m))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.m)
                    .stroke(.white.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.18), radius: 6, y: 2)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("\(next.name) turunu topla")
    }

    // MARK: - Alt action strip (Sprint+Daily yan yana, altında full Mağaza CTA)

    private var actionStrip: some View {
        VStack(spacing: Space.s2) {
            HStack(spacing: Space.s2) {
                sprintMini
                dailyMini
            }
            shopButton
        }
    }

    private var sprintMini: some View {
        let p = model.sprintProgress.fraction
        let onTrack = model.sprintOnTrack
        return miniCard(
            icon: "bolt.fill",
            title: "Sprint",
            badge: model.sprintsWonThisQuarter > 0
                ? "\(model.sprintsWonThisQuarter)" : "—",
            fraction: p,
            fill: onTrack ? Palette.success : theme.accent,
            highlighted: onTrack
        ) { Haptics.tap(); expanded = .sprint }
    }

    private var dailyMini: some View {
        let c = model.dailyTaskCounts
        let frac = c.total > 0 ? Double(c.done) / Double(c.total) : 0
        let allDone = model.dailyCompleted
        return miniCard(
            icon: "target",
            title: "Günlük",
            badge: model.streak > 0 ? "🔥\(model.streak)" : "\(c.done)/\(c.total)",
            fraction: allDone ? 1 : frac,
            fill: allDone ? Palette.success : theme.accent,
            highlighted: allDone
        ) { Haptics.tap(); expanded = .daily }
    }

    /// Sade mini kart: ikon + ad + sağda küçük badge + altında ince accent fill bar.
    private func miniCard(icon: String, title: String, badge: String,
                          fraction: Double, fill: Color, highlighted: Bool,
                          action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: Space.s1 + 2) {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(fill)
                    Text(title)
                        .font(.appText(12, .heavy))
                        .foregroundStyle(theme.text)
                    Spacer(minLength: 0)
                    Text(badge)
                        .font(.numberS)
                        .foregroundStyle(Palette.textSecondary)
                        .lineLimit(1).minimumScaleFactor(0.6)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(theme.hairline)
                        Capsule()
                            .fill(fill)
                            .frame(width: max(3, geo.size.width * min(1, max(0, fraction))))
                    }
                }
                .frame(height: 4)
            }
            .padding(.horizontal, Space.s3).padding(.vertical, Space.s2 + 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surfaceLow, in: RoundedRectangle(cornerRadius: Radius.m))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.m)
                    .stroke(highlighted ? theme.hairlineStrong : theme.hairline,
                            lineWidth: highlighted ? 1.4 : 1)
            )
        }
        .buttonStyle(.pressable)
    }

    /// Mağaza CTA — primary AppButton stilinde tam kart, sağda m² sade chip.
    private var shopButton: some View {
        Button { Haptics.tap(); showShop = true } label: {
            HStack(spacing: Space.s2) {
                Image(systemName: "cart.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                Text("Mağaza")
                    .font(.bodyL)
                    .foregroundStyle(.white)
                Spacer(minLength: 0)
                Text("\(Int(model.freeAreaM2))m²")
                    .font(.numberS)
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, Space.s1 + 2).padding(.vertical, 2)
                    .background(.white.opacity(0.16), in: Capsule())
            }
            .padding(.horizontal, Space.s3).padding(.vertical, Space.s2 + 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.accent, in: RoundedRectangle(cornerRadius: Radius.m))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.m)
                    .stroke(.white.opacity(0.14), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.18), radius: 6, y: 2)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("Mağaza")
    }
}
