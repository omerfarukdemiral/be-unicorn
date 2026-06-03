import SwiftUI

/// Coaching scorecard ("Burada Ne Oldu? · Sonraki Deneme İçin Strateji").
/// İflas anında BankruptcyView'in delege ettiği bilge post-mortem. Tonu suçlayıcı değil,
/// koçluk — "şanssızlık" demek yerine nedenselliği gösterir, çeşitli alternatif rotalar önerir.
///
/// Mantıkta DEĞİŞİKLİK YOK: GameModel SADECE OKUNUR (history + final state). Buradaki tüm
/// teşhis/öneri kuralları görsel/diagnostic katmandadır; oyun davranışını etkilemez.
struct PostMortemView: View {
    @ObservedObject var model: GameModel
    var theme: Theme
    @State private var appeared = false

    // MARK: Kalem rengi — danger tinted ama bilge: kırmızı şok değil amber-uyarı.
    /// Post-mortem ana vurgu rengi (warning amber — koçluk tonu).
    private var penColor: Color { Palette.warning }

    var body: some View {
        ZStack {
            // Sakin koyu zemin — kutlama parıltısı YOK; sade post-mortem mood.
            Color(hex: "12101F").opacity(0.94).ignoresSafeArea()
            // Üstten yumuşak amber sıcaklığı (uyarı tonu).
            RadialGradient(colors: [penColor.opacity(0.14), .clear],
                           center: .top, startRadius: 20, endRadius: 420)
                .ignoresSafeArea()

            // Gövde KAYDIRILABİLİR, "Yeni Deneme" altta SABİT → iflasta kritik buton hep erişilebilir.
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: Space.s4) {
                        header
                        peaksSection
                        causalChainSection
                        miniCharts
                        diagnosticsSection
                        decisionsSection
                        strategySection
                        statsFooter
                    }
                    .padding(Space.s5)
                }
                restartButton
                    .padding(.horizontal, Space.s5)
                    .padding(.top, Space.s3).padding(.bottom, Space.s4)
            }
            .frame(maxWidth: 380)
            .background(theme.surfaceLow, in: RoundedRectangle(cornerRadius: Radius.overlay))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.overlay)
                    .stroke(penColor.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.4), radius: 22, y: 10)
            .padding(.horizontal, Space.s4)
            .padding(.vertical, Space.s4)
            .scaleEffect(appeared ? 1 : 0.88).opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(Motion.snappy) { appeared = true }
        }
    }

    // MARK: - Header — koçluk başlığı, suçlayıcı değil.

    private var header: some View {
        VStack(spacing: Space.s2) {
            // Hero görseli: iniş + ufukta yeniden başlangıç noktası — sakin koçluk tonu.
            HorizonChartHero(accent: penColor, size: 96)
            Text("BURADA NE OLDU?")
                .font(.eyebrow).tracking(1.4)
                .foregroundStyle(penColor)
                .padding(.horizontal, Space.s3).padding(.vertical, Space.s1)
                .background(penColor.opacity(0.13), in: Capsule())
            Text("İflas — bu deneme bitti, ama her başarısızlık bir strateji notudur.")
                .font(.appText(13, .medium))
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            // Hayatta kalma süresi — belirgin: bu denemenin en somut "skoru".
            (Text("\(monthsSurvived) ay").font(.appNumber(22, .heavy)).foregroundStyle(theme.text)
             + Text(" dayandın").font(.appText(14, .semibold)).foregroundStyle(theme.subtle))
                .padding(.top, Space.s1)
        }
        .padding(.bottom, Space.s1)
    }

    /// Bu denemede kaç oyun-ayı hayatta kalındı (en az 1 — sıfır ay garip görünür).
    private var monthsSurvived: Int { max(1, Int(model.state.months)) }

    // MARK: - Zirve metrikleri — "ne battı" değil "ne başardın": kayıp anına karşıtlık.

    private var peaksSection: some View {
        VStack(alignment: .leading, spacing: Space.s2) {
            HStack(spacing: Space.s2) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.gold)
                Text("ZİRVE NOKTALARIN")
                    .font(.caption).kerning(0.8)
                    .foregroundStyle(theme.subtle)
            }
            HStack(spacing: Space.s4) {
                statCell(label: "Zirve Kullanıcı", value: BigNumber.format(model.state.peakUsers),
                         icon: "person.2.fill", tint: theme.accent)
                statCell(label: "Zirve MRR", value: BigNumber.money(model.state.peakMRR),
                         icon: "dollarsign.circle.fill", tint: Palette.gold)
                statCell(label: "Zirve Değerleme", value: BigNumber.money(model.state.peakValuation),
                         icon: "chart.line.uptrend.xyaxis", tint: theme.accent)
            }
            .padding(Space.s3)
            .background(theme.surfaceHigh, in: RoundedRectangle(cornerRadius: Radius.m))
        }
    }

    // MARK: - Zincirleme nedensellik — şirketi öldüren tek cümlelik nedensel zincir.
    /// "Yüksek burn + düşük MRR → runway tükendi" gibi A→B→C akışı. Diagnostic'lerden FARKLI:
    /// burada tek, en baskın ölüm-zinciri görselleştirilir (ok-akışı) — "neden battık" tek bakışta.

    private var causalChainSection: some View {
        VStack(alignment: .leading, spacing: Space.s2) {
            HStack(spacing: Space.s2) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(penColor)
                Text("ŞİRKETİ ÖLDÜREN ZİNCİR")
                    .font(.caption).kerning(0.8)
                    .foregroundStyle(penColor)
            }
            HStack(spacing: Space.s1) {
                ForEach(Array(causalChain.enumerated()), id: \.offset) { idx, node in
                    Text(node)
                        .font(.appText(11, .bold))
                        .foregroundStyle(theme.text)
                        .padding(.horizontal, Space.s2).padding(.vertical, Space.s1)
                        .background(penColor.opacity(0.12), in: Capsule())
                        .fixedSize(horizontal: false, vertical: true)
                    if idx < causalChain.count - 1 {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 9, weight: .black))
                            .foregroundStyle(penColor.opacity(0.7))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Space.s3)
            .background(theme.surfaceHigh, in: RoundedRectangle(cornerRadius: Radius.m))
        }
    }

    /// En baskın 3 düğümlü ölüm-zinciri. Final state'ten en güçlü sinyali seç → kök neden → sonuç.
    /// Her dal NET ve nedensel; tek doğru cevap dayatmaz, ne olduğunu gösterir.
    private var causalChain: [String] {
        let payroll = model.payrollPerMonth
        let burn = payroll + model.opexPerMonth + model.adSpendPerMonth
        let payrollShare = burn > 0 ? payroll / burn : 0
        let mrr = model.mrr
        let churn = model.churnRate
        let ad = model.adSpendPerMonth
        let ratio = model.ltvCacRatio

        // Kök nedeni en güçlü sinyale göre seç (öncelik sırası).
        if ad > 0 && (ratio > 0 && ratio < 2) && (mrr <= 1 || ad / max(1, mrr) >= 0.4) {
            // Olgunlaşmamış ürüne aşırı pazarlama → churn sarmalı.
            return ["Erken aşırı pazarlama", "Pahalı kullanıcı (LTV:CAC<2)", "Nakit eridi"]
        }
        if payrollShare >= 0.55 && burn > max(1, mrr) {
            return ["Şişkin maaş gideri", "Burn > MRR", "Runway tükendi"]
        }
        if churn * 100 >= 7 {
            return ["Yüksek churn", "Kullanıcı tutulamadı", "MRR düşüşe geçti"]
        }
        if model.morale < 35 {
            return ["Moral çöktü", "İstifa zinciri", "Üretim düştü → gelir kurudu"]
        }
        // Genel: en yaygın startup ölümü — burn gelirin önünde kaldı.
        return ["Yüksek burn", "Düşük MRR", "Runway tükendi"]
    }

    // MARK: - Son durumun mini grafikleri.

    private var miniCharts: some View {
        VStack(alignment: .leading, spacing: Space.s2) {
            Text("SON 30-60 GÜN").font(.caption).kerning(0.8)
                .foregroundStyle(theme.subtle)
            HStack(spacing: Space.s2) {
                trendCell(title: "Nakit",
                          icon: Icons.Metric.cash,
                          values: cashSeries,
                          finalText: BigNumber.money(model.cash),
                          color: Palette.danger)
                trendCell(title: "Kullanıcı",
                          icon: Icons.Metric.users,
                          values: usersSeries,
                          finalText: BigNumber.format(model.users),
                          color: Palette.success)
                trendCell(title: "MRR",
                          icon: Icons.Metric.mrr,
                          values: mrrSeries,
                          finalText: BigNumber.money(model.mrr),
                          color: theme.accent)
            }
        }
    }

    /// Tek mini grafik kartı — başlık + spark + final değer + delta rozeti.
    private func trendCell(title: String, icon: String,
                           values: [Double], finalText: String, color: Color) -> some View {
        let delta = trendDelta(values)
        let arrow: String = delta > 0.01 ? "arrow.up.right"
            : (delta < -0.01 ? "arrow.down.right" : "arrow.right")
        let deltaColor: Color = delta > 0.01 ? Palette.success
            : (delta < -0.01 ? Palette.danger : theme.subtle)
        return VStack(alignment: .leading, spacing: Space.s1) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(theme.subtle)
                Text(title)
                    .font(.appText(10, .bold))
                    .foregroundStyle(theme.subtle)
            }
            Sparkline(points: values, color: color)
                .frame(height: 28)
            Text(finalText)
                .font(.appNumber(13, .heavy))
                .foregroundStyle(theme.text)
                .lineLimit(1).minimumScaleFactor(0.7)
            HStack(spacing: 2) {
                Image(systemName: arrow)
                    .font(.system(size: 8, weight: .black))
                Text(deltaText(delta))
                    .font(.appNumber(9, .bold))
            }
            .foregroundStyle(deltaColor)
        }
        .padding(Space.s2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surfaceHigh, in: RoundedRectangle(cornerRadius: Radius.s))
    }

    private func deltaText(_ d: Double) -> String {
        guard d.isFinite else { return "—" }
        let pct = Int((d * 100).rounded())
        return "\(pct >= 0 ? "+" : "")%\(pct)"
    }

    /// İlk → son nokta arası oransal değişim. 0'a yakın başlangıçta güvenli.
    private func trendDelta(_ values: [Double]) -> Double {
        guard let first = values.first, let last = values.last, values.count >= 2 else { return 0 }
        if abs(first) < 1 { return last > first ? 1 : (last < first ? -1 : 0) }
        return (last - first) / abs(first)
    }

    // MARK: Mini-grafik serileri — son ~60 nokta (history zaten 120'de sınırlı).

    private var cashSeries: [Double] { model.state.history.suffix(60).map { $0.cash } }
    private var usersSeries: [Double] { model.state.history.suffix(60).map { $0.users } }
    private var mrrSeries: [Double] { model.state.history.suffix(60).map { $0.mrr } }

    // MARK: - Diagnostic — "Ne Yanlış Gitti", kural-tabanlı 2-4 madde.

    private var diagnosticsSection: some View {
        VStack(alignment: .leading, spacing: Space.s2) {
            HStack(spacing: Space.s2) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(penColor)
                Text("NE YANLIŞ GİTTİ")
                    .font(.caption).kerning(0.8)
                    .foregroundStyle(penColor)
            }
            VStack(alignment: .leading, spacing: Space.s2) {
                ForEach(Array(diagnostics.enumerated()), id: \.offset) { _, line in
                    bulletRow(line, tint: penColor)
                }
            }
            .padding(Space.s3)
            .background(theme.surfaceHigh, in: RoundedRectangle(cornerRadius: Radius.m))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.m)
                    .stroke(penColor.opacity(0.22), lineWidth: 1)
            )
        }
    }

    /// Tek satır madde — uyarı noktası + metin.
    private func bulletRow(_ text: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: Space.s2) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(tint)
                .padding(.top, 2)
            Text(text)
                .font(.appText(12, .medium))
                .foregroundStyle(theme.text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Diagnostic kural motoru.
    /// Final state + history üstünden 2-4 nedensel madde üret. "Şanssızlık" deme — sebep göster.
    private var diagnostics: [String] {
        var lines: [String] = []
        let history = model.state.history
        let users = model.users
        let totalHires = model.state.totalHires
        let months = max(1, model.state.months)
        let payroll = model.payrollPerMonth
        let opex = model.opexPerMonth
        let ad = model.adSpendPerMonth
        let mrr = model.mrr
        let churn = model.churnRate
        let opsHead = model.count(4)
        let productHead = model.count(1)
        let ratio = model.ltvCacRatio

        // Kural 1: Erken aşırı işe alım — burn'i şişirdi.
        // Eşik: yılda 8+ hire (oyun-ayı/12) VE maaş gideri toplam burn'in yarısını geçti.
        let hireRate = Double(totalHires) / max(1, months / 12)
        let burn = payroll + opex + ad
        let payrollShare = burn > 0 ? payroll / burn : 0
        if totalHires >= 4 && hireRate >= 6 && payrollShare >= 0.55 {
            lines.append(String(format:
                "Ay %d'e kadar %d işe alım burn'i şişirdi; maaşlar giderin %%%d'i oldu — runway erken zayıfladı.",
                Int(months), totalHires, Int(payrollShare * 100)))
        }

        // Kural 2: Reklam aşırı harcaması — MRR'a göre büyük + LTV:CAC kötü.
        // Eşik: ad >= 0.4 × MRR (veya MRR sıfırken ad > 0) VE LTV:CAC < 2.
        let adVsMRR = mrr > 1 ? ad / mrr : (ad > 0 ? 2 : 0)
        if ad > 0 && adVsMRR >= 0.4 && (ratio > 0 ? ratio < 2 : true) {
            let pct = mrr > 1 ? Int((ad / mrr * 100).rounded()) : 100
            let ratioText = ratio > 0 ? String(format: "%.1f", ratio) : "—"
            lines.append(
                "Reklam bütçesi MRR'ın %\(pct)'ıydı; LTV:CAC \(ratioText) — kullanıcı edinmek geri dönüşünden pahalıydı.")
        }

        // Kural 3: Churn ihmali — yüksek churn + ops/ürün takımı zayıf.
        // Eşik: churn >= 7% aylık VE (ops <= 1 ya da ürün <= 1) VE kullanıcı > 100.
        let churnPct = churn * 100
        if churnPct >= 7 && (opsHead <= 1 || productHead <= 1) && users > 100 {
            lines.append(String(format:
                "Aylık churn %%%.1f'de kaldı; operasyon (%d) ve ürün (%d) ekibi ince — kullanıcılar gelirken bir o kadar gidiyordu.",
                churnPct, opsHead, productHead))
        }

        // Kural 4: Moral düşüş zinciri — son moral düşük + ekipte istifa zinciri başlamış olabilir.
        // Eşik: morale < 35.
        if model.morale < 35 {
            lines.append(String(format:
                "Moral %d seviyesine indi; istifa zinciri ekibi inceltti ve üretim daha da düştü.",
                Int(model.morale.rounded())))
        }

        // Kural 5: Karar göz ardı / yetersiz tepki — toplam karar oranı düşük.
        // Eşik: ay başına ortalama < 0.3 karar VE en az 6 ay geçmiş.
        let decisionsPerMonth = Double(model.state.totalDecisions) / max(1, months)
        if months >= 6 && decisionsPerMonth < 0.3 {
            lines.append(String(format:
                "Sadece %d karar verildi (%d ayda); kriz kartları erken müdahale şansı veriyordu.",
                model.state.totalDecisions, Int(months)))
        }

        // Kural 6: Nakit serbest düşüş — son 30 örnekte sürekli ve sert düşüş.
        // Eşik: son seri başlangıcı > son nokta × 2 (yani yarı yarıya erimiş).
        let recent = history.suffix(30).map { $0.cash }
        if let first = recent.first, let last = recent.last,
           recent.count >= 10, first > 0, last < first * 0.5 {
            lines.append(String(format:
                "Son dönem nakit %@ → %@ eridi; burn gelirin önündeyken frene basılmadı.",
                BigNumber.money(first), BigNumber.money(last)))
        }

        // Kural 7: Rakip baskısı — Tepki Veren Rakip aktifken CAC/churn tırmandı, gelir yetişemedi.
        // Eşik: iflas anında belirgin rakip baskısı (>= eşik) + zayıf ünit-ekonomi. ADİL: oyuncu
        // bu baskının feed'de açık uyarısını görmüştü; burada nedensel anlatıyı tamamlıyoruz.
        if model.rivalAggression >= Balance.rivalCardThreshold && (ratio > 0 ? ratio < 2.5 : true) {
            let cacUp = Int((model.rivalCacMultiplier - 1) * 100)
            let churnUp = Int((model.rivalChurnMultiplier - 1) * 100)
            lines.append(String(format:
                "Rakip baskısı yüksekti: fiyat savaşı CAC'i ~%%%d, yetenek avı/kopya churn'ü ~%%%d artırdı — bu dalga geçiciydi ama sen büyürken gelir yetişemedi.",
                cacUp, churnUp))
        }

        // Yedek: hiç kural tetiklemediyse genel teşhis ver (boş bırakma).
        if lines.isEmpty {
            lines.append(
                "Gelir gider dengesi tutmadı; ölçek büyüdükçe burn da büyüdü, MRR yetişemedi.")
            lines.append(
                "Ekip kapasitesi ile pazar talebi senkron değildi; ya çok erken ya çok geç tepki verildi.")
        }

        // 4 ile sınırla — fazla madde okuyucuyu boğar.
        return Array(lines.prefix(4))
    }

    // MARK: - En iyi & en kötü kararlar — mechanicTouchCounts üstünden türetilmiş öz-değerlendirme.
    /// Oyuncunun bu denemede en çok / en az dokunduğu karar mekaniği → "neyi iyi/eksik yaptın".
    /// Suçlayıcı değil: en çok kullanılan = güçlü yön, hiç kullanılmayan kritik = fırsat.

    private var decisionsSection: some View {
        VStack(alignment: .leading, spacing: Space.s2) {
            HStack(spacing: Space.s2) {
                Image(systemName: "scale.3d")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.accent)
                Text("KARARLARIN")
                    .font(.caption).kerning(0.8)
                    .foregroundStyle(theme.accent)
            }
            VStack(alignment: .leading, spacing: Space.s2) {
                if let best = bestDecision {
                    decisionRow(icon: "hand.thumbsup.fill", tint: Palette.success,
                                label: "En güçlü tarafın", text: best)
                }
                if let worst = worstDecision {
                    decisionRow(icon: "hand.thumbsdown.fill", tint: penColor,
                                label: "En zayıf tarafın", text: worst)
                }
            }
            .padding(Space.s3)
            .background(theme.surfaceHigh, in: RoundedRectangle(cornerRadius: Radius.m))
        }
    }

    private func decisionRow(icon: String, tint: Color, label: String, text: String) -> some View {
        HStack(alignment: .top, spacing: Space.s2) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(tint)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.appText(10, .bold)).foregroundStyle(tint)
                Text(text)
                    .font(.appText(12, .medium)).foregroundStyle(theme.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// İnsan-okunur mekanik etiketi (lessonMechanic anahtarı → Türkçe alan adı).
    private func mechanicLabel(_ key: String) -> String {
        switch key {
        case "equity":              return "Yatırımcı/hisse"
        case "runway":              return "Kriz/runway yönetimi"
        case "morale":              return "Ekip morali"
        case "hiring":              return "İşe alım"
        case "product-market-fit":  return "Ürün-pazar uyumu"
        case "marketing":           return "Pazarlama"
        case "strategy":            return "Strateji/fırsat"
        default:                    return "Karar"
        }
    }

    /// En çok dokunulan karar mekaniği → güçlü yön. Hiç karar yoksa nil (bölüm boş satır göstermez).
    private var bestDecision: String? {
        guard let top = model.state.mechanicTouchCounts.max(by: { $0.value < $1.value }), top.value > 0
        else { return nil }
        return "\(mechanicLabel(top.key)) kararlarına en çok eğildin (\(top.value)×) — burada ustalaştın."
    }

    /// En çok dokunulanın dışında, hiç/az dokunulan KRİTİK mekanik → en zayıf taraf.
    private var worstDecision: String? {
        let counts = model.state.mechanicTouchCounts
        // Hayatta-kalma için kritik mekanikler — hiç dokunulmamışsa en büyük açık.
        let critical = ["runway", "product-market-fit", "marketing", "equity"]
        if let missing = critical.first(where: { (counts[$0] ?? 0) == 0 }) {
            return "\(mechanicLabel(missing)) tarafına hiç eğilmedin — bu açık pahalıya patladı."
        }
        // Hepsine dokunduysa: en az dokunulanı işaret et.
        guard counts.count >= 2,
              let least = counts.min(by: { $0.value < $1.value }), least.value > 0
        else { return nil }
        return "\(mechanicLabel(least.key)) en az ilgilendiğin alandı (\(least.value)×) — sonraki sefer dengele."
    }

    // MARK: - Sonraki Deneme İçin Strateji — 3 somut öneri, diagnostic'e bağlı seçim.

    private var strategySection: some View {
        VStack(alignment: .leading, spacing: Space.s2) {
            HStack(spacing: Space.s2) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.accent)
                Text("SONRAKİ DENEME İÇİN STRATEJİ")
                    .font(.caption).kerning(0.8)
                    .foregroundStyle(theme.accent)
            }
            VStack(alignment: .leading, spacing: Space.s2) {
                ForEach(Array(strategies.enumerated()), id: \.offset) { _, line in
                    strategyRow(line)
                }
            }
            .padding(Space.s3)
            .background(theme.surfaceHigh, in: RoundedRectangle(cornerRadius: Radius.m))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.m)
                    .stroke(theme.accent.opacity(0.25), lineWidth: 1)
            )
        }
    }

    /// Strateji satırı — sparkle ikonu + "DENE" ipucu.
    private func strategyRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: Space.s2) {
            Image(systemName: "sparkles")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(theme.accent)
                .padding(.top, 2)
            Text(text)
                .font(.appText(12, .medium))
                .foregroundStyle(theme.text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Diagnostic'e bağlı 3 koçluk önerisi — çeşitli alternatif yollar (tek doğru cevap yok).
    /// Her aday öneri bir koşulla bağlı; üst sıradakiler önceliklidir, eksik kalırsa jenerikler dolar.
    private var strategies: [String] {
        var pool: [String] = []
        let history = model.state.history
        let totalHires = model.state.totalHires
        let months = max(1, model.state.months)
        let hireRate = Double(totalHires) / max(1, months / 12)
        let payroll = model.payrollPerMonth
        let burn = payroll + model.opexPerMonth + model.adSpendPerMonth
        let payrollShare = burn > 0 ? payroll / burn : 0
        let ratio = model.ltvCacRatio
        let mrr = model.mrr
        let ad = model.adSpendPerMonth
        let churn = model.churnRate
        let reputation = model.reputation

        // Hire-heavy denemeydi → default-alive disiplini.
        if totalHires >= 4 && (hireRate >= 6 || payrollShare >= 0.55) {
            pool.append(
                "Pre-seed'e kadar masaları doldurmadan büyü: default-alive kal, runway 12 ay altına inmesin.")
        }

        // Reklam aşırılığı → LTV:CAC disiplini.
        if ad > 0 && (mrr <= 1 || ad / max(1, mrr) >= 0.4 || (ratio > 0 && ratio < 2)) {
            pool.append(
                "Reklam bütçesini LTV:CAC ≥ 3 olmadan açma; önce küçük kohortla CAC'i ölç, sonra ölçekle.")
        }

        // Yüksek churn → ürün/ops yatırımı.
        if churn * 100 >= 7 {
            pool.append(
                "Yeni kullanıcı kovalamadan önce churn'ü düşür: ürün/operasyon ekibine ya da Müşteri Başarısı modülüne yatır.")
        }

        // Moral düştüyse → konfor eşyaları + kültür modülü.
        if model.morale < 50 {
            pool.append(
                "Sosyal/konfor eşyalarına önce yatır; moral 60 altına inmeden zincirle önle — şirket kültürü modülü kalıcı taban yükseltir.")
        }

        // Pazarlama ekibi yokken organik kanal — itibar yüksekse altın.
        if model.count(2) <= 1 && reputation >= 30 {
            pool.append(
                "Pazarlama ekibi olmadan organik kanala yatır; itibarın yüksek, kelime-ağızdan büyüme ücretsiz CAC verir.")
        }

        // Nakit erken eridiyse → funding zamanlaması.
        let recent = history.suffix(30).map { $0.cash }
        if let first = recent.first, let last = recent.last, recent.count >= 10, first > 0, last < first * 0.5 {
            pool.append(
                "Funding turunu erken topla: equity ver ama runway kazan — değerlemen düşse de oyunda kalmak öncelik.")
        }

        // Karar oranı düşükse → kararlara kulak ver.
        let decisionsPerMonth = Double(model.state.totalDecisions) / max(1, months)
        if months >= 6 && decisionsPerMonth < 0.3 {
            pool.append(
                "Karar kartlarını erken aç: kriz uyarıları ücretsiz koçluktur, hızlı tepki maliyeti yarıya indirir.")
        }

        // Jenerik dolgular (eğer 3'e doymadıysa) — çeşitli alternatif rotalar.
        let fallback = [
            "Önce niş bir kullanıcı segmentine derinleş; geniş pazara açılmadan PMF'i kanıtla.",
            "Modüllere yatır: CI/CD ve Müşteri Başarısı kalıcı verim getirir, maaştan ucuzdur.",
            "Çeyrek sonu skorunu sezon ödülüne çevir; küçük kalıcı çarpan büyük fark yaratır.",
        ]
        for line in fallback where pool.count < 6 {
            if !pool.contains(line) { pool.append(line) }
        }

        return Array(pool.prefix(3))
    }

    // MARK: - Footer — istatistik satırı + büyük "Yeni Deneme" butonu.

    private var statsFooter: some View {
        HStack(spacing: Space.s4) {
            statCell(label: "Kurucu Tecrübesi",
                     value: "\(Int(model.state.founderXP))",
                     icon: "star.circle.fill", tint: Palette.gold)
            statCell(label: "İflas Sayısı",
                     value: "\(model.state.bankruptcies)",
                     icon: "xmark.octagon.fill", tint: penColor)
            statCell(label: "Toplam Karar",
                     value: "\(model.state.totalDecisions)",
                     icon: Icons.Metric.decisions, tint: theme.accent)
        }
        .padding(Space.s3)
        .background(theme.surfaceHigh, in: RoundedRectangle(cornerRadius: Radius.m))
    }

    private func statCell(label: String, value: String, icon: String, tint: Color) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(tint)
                Text(value)
                    .font(.appNumber(15, .heavy))
                    .foregroundStyle(theme.text)
            }
            Text(label)
                .font(.appText(9, .medium))
                .foregroundStyle(theme.subtle)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Restart — mevcut akışı koru: model.restartAfterBankruptcy().
    private var restartButton: some View {
        VStack(spacing: Space.s2) {
            Button {
                Haptics.tap()
                model.restartAfterBankruptcy()
            } label: {
                HStack(spacing: Space.s2) {
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .font(.system(size: 16, weight: .bold))
                    Text("Yeni Deneme").font(.bodyL)
                }
                .modifier(AppButton.primary(theme))
            }
            .buttonStyle(.pressable)
            // ADİL & ŞEFFAF iz gösterimi: oyuncu boostı VE izi açıkça görür — sürpriz ceza yok.
            Text(scarNote)
                .font(.appText(10, .medium))
                .foregroundStyle(theme.subtle)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, Space.s1)
    }

    /// Sonraki denemenin somut etkisini ŞEFFAF anlat: nakit boostı (tecrübe ödülü) +
    /// itibar izi (modest, zamanla solar). Adil — oyuncu ne kazanıp ne kaybedeceğini görür.
    private var scarNote: String {
        let boost = Int((model.nextAttemptCashBoost * 100).rounded())
        let scar = Int(model.nextAttemptReputationScar.rounded())
        if boost > 0 && scar > 0 {
            return "Tecrübe kalıcı: sonraki şirket +%\(boost) nakitle başlar. İflas izi: başlangıç itibarı −\(scar) (deneyimle solar)."
        } else if boost > 0 {
            return "Tecrübe kalıcı: sonraki şirketin +%\(boost) daha çok nakitle başlar."
        } else if scar > 0 {
            return "İflas izi: başlangıç itibarı −\(scar) puan — modest ve deneyim arttıkça solar."
        }
        return "Tecrübe kalıcı; bir sonraki şirketin daha güçlü başlar."
    }
}
