import SwiftUI

/// İstatistik ekranı: temel metrikler + basit nakit/kullanıcı grafiği.
struct StatsPanel: View {
    @ObservedObject var model: GameModel
    var theme: Theme

    var body: some View {
        ScrollView {
            VStack(spacing: Space.s3) {
                PanelCard(theme: theme) {
                    VStack(alignment: .leading, spacing: Space.s3) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("İstatistik").font(.titleM)
                                .foregroundStyle(theme.text)
                            Text("Şirket yaşı: \(Int(model.months)) ay · \(model.currentStage.title)")
                                .font(.appNumber(12, .medium))
                                .foregroundStyle(theme.subtle)
                        }
                        currencyPicker
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                grid

                costBreakdownCard

                PanelCard(theme: theme) {
                    VStack(alignment: .leading, spacing: Space.s2) {
                        Text("Değerleme Eğrisi").font(.appText(13, .bold))
                            .foregroundStyle(theme.text)
                        Sparkline(points: model.state.history.map { $0.valuation }, color: theme.accent)
                            .frame(height: 90)
                        Text("Kullanıcı").font(.appText(13, .bold))
                            .foregroundStyle(theme.text)
                        Sparkline(points: model.state.history.map { $0.users }, color: Palette.success)
                            .frame(height: 60)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                Spacer(minLength: 20)
            }
            .padding(.horizontal, Space.s4)
            .padding(.top, Space.s3)
        }
    }

    private var grid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            metric("MRR",          BigNumber.money(model.mrr),                                   Icons.Metric.mrr)
            metric("Aylık Gider",  BigNumber.money(model.burnPerMonth),                          Icons.Metric.burn)
            metric("Net / Ay",     BigNumber.money(model.netPerMonth),                           model.netPerMonth >= 0 ? "checkmark.circle.fill" : "xmark.circle.fill")
            metric("ARPU",         BigNumber.currency.symbol + String(format: "%.2f", model.arpu), Icons.Metric.arpu)
            metric("Churn",        String(format: "%%%.1f", model.churnRate * 100),              Icons.Metric.churn)
            metric("İtibar",       "\(Int(model.reputation))",                                   Icons.Metric.reputation)
            metric("Toplam Karar", "\(model.state.totalDecisions)",                              Icons.Metric.decisions)
            metric("Kapasite",     BigNumber.format(model.userCapacity),                         Icons.Metric.capacity)
        }
    }

    private var currencyPicker: some View {
        HStack(spacing: Space.s2) {
            Text("Para Birimi").font(.labelText)
                .foregroundStyle(theme.subtle)
            Spacer()
            ForEach(Currency.allCases, id: \.self) { c in
                Button { Haptics.tap(); model.setCurrency(c) } label: {
                    Text("\(c.symbol) \(c.label)")
                        .font(.appText(12, .bold))
                        .padding(.horizontal, Space.s3).frame(height: 32)
                        .background(model.currency == c ? theme.accent : theme.surfaceHigh,
                                    in: RoundedRectangle(cornerRadius: Radius.s))
                        .foregroundStyle(model.currency == c ? .white : Palette.textTertiary)
                }
                .buttonStyle(.pressable)
            }
        }
    }

    @State private var barsFilled = false

    private var costBreakdownCard: some View {
        PanelCard(theme: theme) {
            VStack(alignment: .leading, spacing: Space.s3) {
                HStack {
                    Text("Gider Dağılımı").font(.appText(13, .bold))
                        .foregroundStyle(theme.text)
                    Spacer()
                    Text("\(BigNumber.money(model.burnPerMonth))/ay")
                        .font(.numberM)
                        .foregroundStyle(Palette.danger)
                }
                let lines = model.costBreakdown.filter { $0.amount > 0 }
                let total = max(model.burnPerMonth, 1)
                let maxAmount = lines.map(\.amount).max() ?? 1
                ForEach(Array(lines.enumerated()), id: \.element.id) { idx, line in
                    let isLargest = line.amount >= maxAmount
                    VStack(spacing: Space.s1) {
                        HStack(spacing: Space.s2) {
                            // Gider kalemi ikonu: costId bazlı SF Symbol (-1=maaş, -2=reklam, 0-5=opex)
                            Image(systemName: costSymbol(for: line))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(isLargest ? theme.accent : theme.accent.opacity(0.55))
                                .frame(width: 14)
                            Text(line.name)
                                .font(.labelText)
                                .foregroundStyle(theme.textSecondary)
                            Spacer()
                            // Sağda monospace hizalı tutar.
                            Text(BigNumber.money(line.amount))
                                .font(.numberS)
                                .foregroundStyle(theme.subtle)
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(theme.surfaceHigh)
                                // En büyük kalem dolu accent, diğerleri .4.
                                Capsule().fill(theme.accent.opacity(isLargest ? 1 : 0.4))
                                    .frame(width: geo.size.width
                                           * CGFloat(line.amount / total)
                                           * (barsFilled ? 1 : 0))
                            }
                        }
                        .frame(height: 8)
                        .animation(.easeOut(duration: 0.5).delay(Double(idx) * 0.06), value: barsFilled)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear { barsFilled = true }
    }

    /// Gider kalemi için SF Symbol adını döndürür.
    private func costSymbol(for line: CostLine) -> String {
        switch line.costId {
        case -1: return Icons.Metric.users      // maaşlar
        case -2: return Icons.Metric.adBudget   // reklam
        default: return Icons.Cost.symbol(for: line.costId)
        }
    }

    private func metric(_ label: String, _ value: String, _ symbol: String) -> some View {
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
                    .foregroundStyle(theme.text).lineLimit(1).minimumScaleFactor(0.6)
                    .contentTransition(.numericText())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Basit çizgi grafik (min-max normalize).
struct Sparkline: View {
    let points: [Double]
    let color: Color
    var body: some View {
        GeometryReader { geo in
            let pts = points.suffix(60)
            if pts.count >= 2 {
                let lo = pts.min() ?? 0
                let hi = pts.max() ?? 1
                let range = max(hi - lo, 1)
                let arr = Array(pts)
                Path { p in
                    for (i, v) in arr.enumerated() {
                        let x = geo.size.width * CGFloat(i) / CGFloat(arr.count - 1)
                        let y = geo.size.height * (1 - CGFloat((v - lo) / range))
                        if i == 0 { p.move(to: CGPoint(x: x, y: y)) }
                        else { p.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            } else {
                Text("Veri toplanıyor…")
                    .font(.appText(11, .regular))
                    .foregroundStyle(.white.opacity(0.3))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
