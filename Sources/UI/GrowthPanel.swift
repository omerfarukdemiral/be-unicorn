import SwiftUI

/// Büyüme & Pazarlama ekranı: reklam bütçesi kontrolü + gerçek SaaS edinim metrikleri (CAC/LTV).
struct GrowthPanel: View {
    @ObservedObject var model: GameModel
    var theme: Theme

    var body: some View {
        ScrollView {
            VStack(spacing: Space.s3) {
                header
                growthModeCard
                budgetCard
                metricsGrid
                healthNote
                Spacer(minLength: 20)
            }
            .padding(.horizontal, Space.s4).padding(.top, Space.s3)
        }
    }

    private var header: some View {
        PanelCard(theme: theme) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Büyüme & Pazarlama").font(.titleM)
                    .foregroundStyle(theme.text)
                Text("Reklam bütçesi kullanıcı satın alır; ama ölçek büyüdükçe CAC artar.")
                    .font(.bodyText)
                    .foregroundStyle(theme.subtle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Kalıcı büyüme modu kaldıracı — "hızlı büyü, para yak" (blitzscale) vs "kârlı-yavaş"
    /// (disiplinli). İki yol da Unicorn'a çıkar; seçim Organik/ay + CAC metriklerini canlı oynatır.
    /// İlk yönelim "blitzscale-pressure" karar kartıyla gelir, buradan serbestçe değiştirilebilir.
    private var growthModeCard: some View {
        PanelCard(theme: theme) {
            VStack(alignment: .leading, spacing: Space.s3) {
                HStack(spacing: Space.s1) {
                    Image(systemName: "dial.medium.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(theme.accent)
                    Text("Büyüme Modu")
                        .font(.appText(13, .semibold))
                        .foregroundStyle(theme.subtle)
                    Spacer()
                }
                HStack(spacing: Space.s2) {
                    ForEach(GrowthMode.allCases, id: \.self) { mode in
                        modeButton(mode)
                    }
                }
                Text(model.growthMode.blurb)
                    .font(.appText(11.5, .medium))
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func modeButton(_ mode: GrowthMode) -> some View {
        let selected = model.growthMode == mode
        return Button {
            guard !selected else { return }
            Haptics.selection()
            withAnimation(Motion.smooth) { model.setGrowthMode(mode) }
        } label: {
            HStack(spacing: Space.s1) {
                Image(systemName: mode.icon)
                    .font(.system(size: 13, weight: .bold))
                Text(mode.short)
                    .font(.appText(13, .bold))
            }
            .foregroundStyle(selected ? .white : theme.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Space.s2 + 2)
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                        .fill(theme.accent.opacity(0.92))
                        .overlay(RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                            .stroke(.white.opacity(0.18)))
                } else {
                    RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                        .stroke(theme.hairline)
                }
            }
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("\(mode.title)\(selected ? ", seçili" : "")")
    }

    private var budgetCard: some View {
        PanelCard(theme: theme) {
            VStack(spacing: Space.s3) {
                HStack {
                    HStack(spacing: Space.s1) {
                        Image(systemName: Icons.Metric.adBudget)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(theme.accent)
                        Text("Aylık Reklam Bütçesi")
                            .font(.appText(13, .semibold))
                    }
                    .foregroundStyle(theme.subtle)
                    Spacer()
                    Text(BigNumber.money(model.adSpendPerMonth) + "/ay")
                        .font(.displayM)
                        .foregroundStyle(theme.accent)
                        .contentTransition(.numericText())
                }

                productMaturityNote

                // Ana ikili (− / +) geniş; +×5 / Sıfırla daha küçük ikincil.
                HStack(spacing: Space.s2) {
                    stepButton("−", color: Palette.danger, flex: 1.3) {
                        Haptics.tap(); model.changeAdBudget(by: -model.adBudgetStep)
                    }
                    stepButton("+", color: Palette.success, flex: 1.3) {
                        Haptics.tap(); model.changeAdBudget(by: model.adBudgetStep)
                    }
                    stepButton("+×5", color: theme.accent, flex: 1) {
                        Haptics.tap(); model.changeAdBudget(by: model.adBudgetStep * 5)
                    }
                    stepButton("Sıfırla", color: theme.surfaceHigh, flex: 1) {
                        Haptics.tap(); model.setAdBudget(0)
                    }
                }

                Divider().overlay(theme.hairline)

                HStack {
                    projectedStat("Ücretli kullanıcı/ay", "+\(BigNumber.format(model.paidUserGrowthPerMonth))", Palette.success)
                    projectedStat("CAC (edinme maliyeti)", BigNumber.currency.symbol + String(format: "%.2f", model.currentCAC), theme.accent)
                }
            }
        }
    }

    /// Ürün olgun değilken pazarlamanın boşa gideceğini açıkça anlatan uyarı (sert gelir
    /// kapısı oyuncuya görünür olsun — "neden MRR gelmiyor" şaşkınlığını önler).
    @ViewBuilder private var productMaturityNote: some View {
        let r = model.productReadiness
        if r < 0.6 {
            HStack(alignment: .top, spacing: Space.s2) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11, weight: .bold))
                Text("Ürün henüz olgun değil (%\(Int(r * 100))). Pazarlama büyük ölçüde boşa gider — önce Ofis › Projeler'den ekibi ürüne atayıp özellikleri geliştir.")
                    .font(.appText(11, .medium))
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }
            .foregroundStyle(Palette.warning)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Space.s2)
            .background(Palette.warning.opacity(0.10), in: RoundedRectangle(cornerRadius: Radius.s))
        }
    }

    private func stepButton(_ label: String, color: Color, flex: CGFloat,
                            _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.bodyL)
                .frame(maxWidth: .infinity).frame(height: AppButton.compactHeight)
                .background(color, in: RoundedRectangle(cornerRadius: Radius.s))
                .foregroundStyle(.white)
        }
        .buttonStyle(.pressable)
        .layoutPriority(Double(flex))
        .frame(maxWidth: .infinity)
    }

    private func projectedStat(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.numberL).foregroundStyle(color)
                .contentTransition(.numericText())
            Text(label).font(.appText(10, .medium)).foregroundStyle(theme.subtle)
        }
        .frame(maxWidth: .infinity)
    }

    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            metric("LTV",          BigNumber.money(model.ltv),                                       Icons.Metric.ltv,      .white)
            metric("LTV : CAC",    String(format: "%.1fx", model.ltvCacRatio),                       Icons.Metric.ltvcac,   ratioColor)
            metric("Geri Ödeme",   paybackText,                                                      Icons.Metric.payback,  .white)
            metric("Churn",        String(format: "%%%.1f", model.churnRate * 100),                  Icons.Metric.churn,    .white)
            metric("Organik/ay",   "+\(BigNumber.format(model.organicUserGrowthPerMonth))",           Icons.Metric.organic,  Palette.success)
            metric("Net büyüme/ay", deltaText(model.netUserGrowthPerMonth),                          Icons.Metric.netGrowth, model.netUserGrowthPerMonth >= 0 ? Palette.success : Palette.danger)
        }
    }

    private var ratioColor: Color {
        model.ltvCacRatio >= 3 ? Palette.success : model.ltvCacRatio >= 1 ? Palette.warning : Palette.danger
    }
    private var paybackText: String {
        let m = model.paybackMonths
        return m.isInfinite ? "—" : String(format: "%.1f ay", m)
    }
    private func deltaText(_ v: Double) -> String { (v >= 0 ? "+" : "") + BigNumber.format(v) }

    private func metric(_ label: String, _ value: String, _ symbol: String, _ color: Color) -> some View {
        PanelCard(theme: theme) {
            VStack(alignment: .leading, spacing: Space.s1) {
                HStack(spacing: Space.s1) {
                    Image(systemName: symbol)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(theme.accent)
                    Text(label).font(.labelText)
                        .foregroundStyle(theme.subtle)
                }
                Text(value).font(.numberL)
                    .foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.6)
                    .contentTransition(.numericText())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var healthNote: some View {
        PanelCard(theme: theme) {
            HStack(alignment: .top, spacing: Space.s2) {
                // Sağlık durumu ikonu: yeşil onay veya sarı uyarı
                Image(systemName: model.ltvCacRatio >= 3 ? Icons.Metric.health : Icons.Metric.warning)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(model.ltvCacRatio >= 3 ? Palette.success : Palette.warning)
                Text(healthText).font(.bodyText)
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
        }
    }
    private var healthText: String {
        if model.ltvCacRatio >= 3 { return "Birim ekonomi sağlıklı (LTV:CAC ≥ 3). Reklam harcaman karşılığını veriyor — gaza basabilirsin." }
        if model.ltvCacRatio >= 1 { return "Birim ekonomi kırılgan. CAC'i düşür (pazarlama ekibi/itibar) ya da ARPU'yu artır (Satış/Premium)." }
        return "Reklam harcaman zarar ettiriyor (LTV < CAC). Bütçeyi kıs; önce ürün-pazar uyumu ve gelir."
    }
}
