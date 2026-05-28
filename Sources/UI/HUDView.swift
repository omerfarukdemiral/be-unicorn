import SwiftUI

/// Üst gösterge: nakit (kahraman), runway, kullanıcı, MRR, moral, değerleme + tur ilerlemesi.
struct HUDView: View {
    @ObservedObject var model: GameModel
    var theme: Theme

    @State private var pulse = false
    @State private var cashPop: CGFloat = 1
    @State private var showLeaderboard = false

    private var negative: Bool { model.cash < 0 }

    var body: some View {
        VStack(spacing: Space.s3) {
            // 1) Kahraman satırı: nakit solda büyük, değerleme/hisse sağda ikincil grup.
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: Space.s1) {
                    Text(model.currentStage.name.uppercased())
                        .font(.eyebrow)
                        .kerning(1.0)
                        .foregroundStyle(theme.accent)
                    // Lig rozeti + çeyrek ilerlemesi (completed-cycle göstergesi).
                    // Tıkla → canlı leaderboard (rakip kohort + gerçek bahis).
                    LeaguePill(model: model, theme: theme) { showLeaderboard = true }
                    Text(BigNumber.money(model.cash))
                        .font(.displayL)
                        .foregroundStyle(negative ? Palette.danger : theme.text)
                        .contentTransition(.numericText())
                        .scaleEffect(cashPop)
                        .background(
                            // Negatif nakit: hafif kırmızı pulse.
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Palette.danger.opacity(negative && pulse ? 0.14 : 0))
                                .padding(.horizontal, -8).padding(.vertical, -3)
                        )
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text("DEĞERLEME")
                        .font(.caption)
                        .kerning(0.6)
                        .foregroundStyle(theme.subtle)
                    Text(BigNumber.money(model.valuation))
                        .font(.numberM)
                        .foregroundStyle(theme.text)
                        .contentTransition(.numericText())
                    Text("Hisse %\(Int(model.founderEquity * 100))")
                        .font(.numberXS)
                        .foregroundStyle(theme.subtle)
                }
            }

            // 2) 3 pill — surfaceHigh hücreler, tek satır ikon+değer ortalı, etiket altta.
            HStack(spacing: Space.s2) {
                statSF(Icons.Metric.users, BigNumber.format(model.users), "kullanıcı")
                statSF(Icons.Metric.mrr,   BigNumber.money(model.mrr) + "/ay", "MRR")
                statSF(runwaySymbol, runwayText, "runway", tint: runwayTint)
            }

            // 3) İki bar — aynı Inter etiket stili, hizalı sol etiket + monospace değer.
            VStack(spacing: Space.s2) {
                bar(label: "Moral", value: model.morale / 100,
                    fill: moraleColor, valueText: "\(Int(model.morale))",
                    valueColor: moraleColor)
                if let next = model.nextStage {
                    bar(label: next.name, value: model.raiseProgress,
                        fill: theme.accent, valueText: "%\(Int(model.raiseProgress * 100))",
                        valueColor: theme.accent)
                }
            }
        }
        .onAppear { startPulseIfNeeded() }
        .sheet(isPresented: $showLeaderboard) {
            LeaderboardSheet(model: model, theme: theme)
        }
        .onChange(of: negative) { _, _ in startPulseIfNeeded() }
        .onChange(of: model.cash) { old, new in
            // Büyük nakit artışında kısa scale-pop.
            if new - old > 1000 {
                withAnimation(Motion.snappy) { cashPop = 1.08 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    withAnimation(Motion.snappy) { cashPop = 1 }
                }
            }
        }
    }

    private func startPulseIfNeeded() {
        if negative {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulse = true
            }
        } else {
            pulse = false
        }
    }

    /// SF Symbol ile küçük istatistik hücresi (surfaceHigh zemin).
    private func statSF(_ symbol: String, _ value: String, _ label: String, tint: Color? = nil) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: Space.s1) {
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(tint ?? theme.accent)
                Text(value)
                    .font(.numberS)
                    .foregroundStyle(theme.text)
                    .contentTransition(.numericText())
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            Text(label)
                .font(.caption)
                .foregroundStyle(theme.subtle)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.s2)
        .background(theme.surfaceHigh, in: RoundedRectangle(cornerRadius: Radius.s))
    }

    /// Tek satır bar: sabit genişlikte sol etiket + track + sağda hizalı değer.
    private func bar(label: String, value: Double, fill: Color,
                     valueText: String, valueColor: Color) -> some View {
        HStack(spacing: Space.s2) {
            Text(label)
                .font(.labelText)
                .foregroundStyle(theme.subtle)
                .frame(width: 56, alignment: .leading)
                .lineLimit(1)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(theme.surfaceHigh)
                    Capsule().fill(fill)
                        .frame(width: geo.size.width * CGFloat(max(0, min(1, value))))
                }
            }
            .frame(height: 7)
            Text(valueText)
                .font(.numberXS)
                .foregroundStyle(valueColor)
                .frame(width: 40, alignment: .trailing)
                .lineLimit(1)
                .contentTransition(.numericText())
        }
    }

    /// Runway durumuna göre SF Symbol adı.
    private var runwaySymbol: String {
        model.runwayMonths.isInfinite ? Icons.Metric.runwayInf
            : (model.runwayMonths < 2 ? Icons.Metric.runwayWarn : Icons.Metric.runway)
    }
    /// Runway durumuna göre renk tonu.
    private var runwayTint: Color {
        model.runwayMonths.isInfinite ? Palette.success
            : (model.runwayMonths < 2 ? Palette.danger : theme.accent)
    }
    private var runwayText: String {
        let m = model.runwayMonths
        if m.isInfinite { return "karlı" }
        return "\(Int(max(0, m))) ay"
    }

    private var moraleColor: Color {
        model.morale < 30 ? Palette.danger : model.morale < 60 ? Palette.warning : Palette.success
    }
}
