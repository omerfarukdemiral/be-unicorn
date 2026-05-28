import SwiftUI

/// Üst gösterge — dikey mobil OYUN tarzı yüzen pill rozetleri.
///
/// Tasarım:
/// - Tam-genişlik HUD bloğu değil; tepede kompakt, yüzen "game badge" şeritleri.
/// - 1. sıra: kahraman nakit rozet (büyük, glow) + tıklanabilir lig rozeti.
/// - 2. sıra: kullanıcı / MRR / runway / moral / değerleme mini-badge'leri (yatay scroll).
/// - Altta ince funding-progress + moral bar şeridi (eski iki bar — game HUD'a uygun ince form).
struct HUDView: View {
    @ObservedObject var model: GameModel
    var theme: Theme

    @State private var pulse = false
    @State private var cashPop: CGFloat = 1
    @State private var showLeaderboard = false

    private var negative: Bool { model.cash < 0 }

    var body: some View {
        VStack(spacing: Space.s2) {
            // 1) Şirket kimliği — küçük eyebrow (oyun "level" şeridi gibi).
            companyEyebrow

            // 2) Kahraman satırı: nakit rozet + lig rozeti yan yana.
            HStack(spacing: Space.s2) {
                cashBadge
                Spacer(minLength: 0)
                LeaguePill(model: model, theme: theme) { showLeaderboard = true }
            }
            .scaleEffect(cashPop)

            // 3) Mini badge şeridi — yatay scroll, gerektiğinde kayar.
            // Sağ kenarda soft fade mask: badge'ler "kesik" değil, kayan bir şerit hissi versin.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    usersBadge
                    mrrBadge
                    runwayBadge
                    moraleBadge
                    valuationBadge
                    equityBadge
                }
                .padding(.horizontal, 2)
                .padding(.trailing, 12)   // son rozet için soluklaşan kenara nefes
            }
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .white, location: 0),
                        .init(color: .white, location: 0.88),
                        .init(color: .white.opacity(0), location: 1)
                    ],
                    startPoint: .leading, endPoint: .trailing
                )
            )

            // 4) Funding + moral şeritleri — ince oyunsu bar (eski iki bar rafine).
            VStack(spacing: 5) {
                miniBar(label: "Moral",
                        value: model.morale / 100,
                        fill: moraleColor,
                        valueText: "\(Int(model.morale))",
                        valueColor: moraleColor)
                if let next = model.nextStage {
                    miniBar(label: next.name,
                            value: model.raiseProgress,
                            fill: theme.accent,
                            valueText: "%\(Int(model.raiseProgress * 100))",
                            valueColor: theme.accent)
                }
            }
            .padding(.top, 2)
        }
        .onAppear { startPulseIfNeeded() }
        .sheet(isPresented: $showLeaderboard) {
            LeaderboardSheet(model: model, theme: theme)
        }
        .onChange(of: negative) { _, _ in startPulseIfNeeded() }
        .onChange(of: model.cash) { old, new in
            // Büyük nakit artışında kısa scale-pop.
            if new - old > 1000 {
                withAnimation(Motion.snappy) { cashPop = 1.05 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    withAnimation(Motion.snappy) { cashPop = 1 }
                }
            }
        }
    }

    // MARK: - Üst kimlik şeridi

    /// Şirket adı + evre — incecik eyebrow şeridi. "Mobil app" tarzı blok yerine oyun başlığı gibi.
    private var companyEyebrow: some View {
        HStack(spacing: 5) {
            Image(systemName: Icons.Tab.office)
                .font(.system(size: 9, weight: .black))
                .foregroundStyle(theme.accent)
            Text(model.companyName.isEmpty ? model.currentStage.name.uppercased()
                                           : model.companyName)
                .font(.eyebrow)
                .kerning(0.6)
                .foregroundStyle(theme.accent)
                .lineLimit(1).truncationMode(.tail)
            if !model.companyName.isEmpty {
                Text("·").font(.eyebrow).foregroundStyle(theme.subtle)
                Text(model.currentStage.name.uppercased())
                    .font(.eyebrow).kerning(1.0)
                    .foregroundStyle(theme.subtle)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Rozet bileşenleri

    /// Kahraman nakit rozet — büyük, glow'lu; negatifte danger renk + pulse halkası.
    /// Tycoon-sim hissi: yuvarlak dolar ikonu + büyük rakam + "NAKİT" mikro etiket.
    private var cashBadge: some View {
        StatBadge(
            symbol: negative ? Icons.Metric.warning : "dollarsign.circle.fill",
            value: BigNumber.money(model.cash),
            label: "nakit",
            tint: negative ? Palette.danger : Palette.success,
            prominent: true
        )
        .background(
            // Negatif nakit: kırmızı pulse halka (mevcut "tehlike" davranışı korunur).
            Capsule()
                .fill(Palette.danger.opacity(negative && pulse ? 0.22 : 0))
                .padding(-3)
                .blur(radius: 4)
        )
    }

    private var usersBadge: some View {
        StatBadge(symbol: Icons.Metric.users,
                  value: BigNumber.format(model.users),
                  tint: theme.accent)
    }
    private var mrrBadge: some View {
        StatBadge(symbol: Icons.Metric.mrr,
                  value: BigNumber.money(model.mrr) + "/ay",
                  tint: Palette.success)
    }
    private var runwayBadge: some View {
        StatBadge(symbol: runwaySymbol, value: runwayText, tint: runwayTint)
    }
    private var moraleBadge: some View {
        StatBadge(symbol: Icons.Metric.morale,
                  value: "\(Int(model.morale))",
                  tint: moraleColor)
    }
    private var valuationBadge: some View {
        StatBadge(symbol: Icons.Metric.valuation,
                  value: BigNumber.money(model.valuation),
                  tint: Palette.gold)
    }
    private var equityBadge: some View {
        StatBadge(symbol: Icons.Metric.reputation,
                  value: "%\(Int(model.founderEquity * 100))",
                  tint: Palette.unicorn)
    }

    // MARK: - Mini bar (game HUD progress)

    /// Tek satır, ince oyun-tarzı progress bar.
    private func miniBar(label: String, value: Double, fill: Color,
                         valueText: String, valueColor: Color) -> some View {
        HStack(spacing: Space.s2) {
            Text(label.uppercased())
                .font(.appText(9, .black))
                .kerning(0.5)
                .foregroundStyle(theme.subtle)
                .frame(width: 64, alignment: .leading)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.07))
                    Capsule()
                        .fill(LinearGradient(colors: [fill.opacity(0.9), fill],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * CGFloat(max(0, min(1, value))))
                        .shadow(color: fill.opacity(0.4), radius: 4, y: 0)
                }
            }
            .frame(height: 5)
            Text(valueText)
                .font(.numberXS)
                .foregroundStyle(valueColor)
                .frame(width: 42, alignment: .trailing)
                .lineLimit(1)
                .contentTransition(.numericText())
        }
    }

    // MARK: - Yardımcılar

    private func startPulseIfNeeded() {
        if negative {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulse = true
            }
        } else {
            pulse = false
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
            : (model.runwayMonths < 2 ? Palette.danger : Palette.warning)
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
