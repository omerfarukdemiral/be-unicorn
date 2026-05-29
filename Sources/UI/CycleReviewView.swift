import SwiftUI

/// Sade hero ışıltı (terfi anı — kontrollü kutlama, neon halo YOK).
private struct CycleCelebrationRing: View {
    let color: Color
    @State private var animate = false
    var body: some View {
        Circle()
            .stroke(color.opacity(0.55), lineWidth: 1.5)
            .frame(width: 96, height: 96)
            .scaleEffect(animate ? 1.5 : 0.7)
            .opacity(animate ? 0 : 0.85)
            .onAppear {
                withAnimation(.easeOut(duration: 1.1)) {
                    animate = true
                }
            }
    }
}

/// Çeyrek kapanış değerlendirmesi (completed-cycle).
/// "Çeyrek N Kapandı" scorecard + lig hareketi (terfi/kaldı/düştü) + "Yeni Çeyrek".
/// Stil: FundingRoundView dilini birebir izler (parıltı halkası, surfaceHigh satırlar).
struct CycleReviewView: View {
    @ObservedObject var model: GameModel
    var theme: Theme
    let review: CycleReview
    @State private var appeared = false

    private var promoted: Bool { review.movement == .promote }
    private var demoted: Bool { review.movement == .demote }
    private var fromLeague: LeagueDef { LeagueSystem.league(review.fromTier) }
    private var toLeague: LeagueDef { LeagueSystem.league(review.toTier) }

    /// Hareketin vurgu rengi: terfi=gold, kaldı=accent, düşüş=warning.
    private var moveColor: Color {
        promoted ? Palette.gold : (demoted ? Palette.warning : theme.accent)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            // İçerik uzun (scorecard + kohort + rozetler). Gövde KAYDIRILABİLİR, aksiyon
            // butonu kartın altında SABİT → her zaman görünür (ekrandan taşmaz, tab bar
            // arkasında kalmaz). Kart güvenli alanı doldurur.
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: Space.s4) {
                        hero
                        Text("Çeyrek \(review.quarter) Kapandı")
                            .font(.titleL)
                            .foregroundStyle(theme.accent)
                        Text(headline)
                            .font(.appText(14, .medium))
                            .foregroundStyle(theme.text).multilineTextAlignment(.center)

                        scorecard
                        cohortStandings
                        leagueMovement
                        coachingNote
                    }
                    .padding(Space.s5)
                }
                // Sabit alt aksiyon — kaydırmadan bağımsız, hep erişilebilir.
                Button { Haptics.tap(); model.startNextQuarter() } label: {
                    Text("Yeni Çeyrek").font(.bodyL)
                        .modifier(AppButton.primary(theme))
                }
                .buttonStyle(.pressable)
                .padding(.horizontal, Space.s5)
                .padding(.top, Space.s3).padding(.bottom, Space.s4)
            }
            .frame(maxWidth: 380)
            .background(theme.surfaceLow, in: RoundedRectangle(cornerRadius: Radius.overlay))
            .overlay(RoundedRectangle(cornerRadius: Radius.overlay).stroke(theme.hairline, lineWidth: 1))
            .shadow(color: .black.opacity(0.35), radius: 20, y: 8)
            .padding(.horizontal, Space.s4)
            .padding(.vertical, Space.s4)
            .scaleEffect(appeared ? 1 : 0.8).opacity(appeared ? 1 : 0)
        }
        .onAppear {
            // Terfide kutlama haptiği; aksi halde yumuşak dokunuş.
            if promoted { Haptics.success() } else { Haptics.rigid() }
            withAnimation(Motion.bouncy) { appeared = true }
        }
    }

    // MARK: Hero — skor halkası + (terfide) parıltı.
    private var hero: some View {
        ZStack {
            if appeared && promoted { CycleCelebrationRing(color: Palette.gold) }
            ZStack {
                Circle()
                    .stroke(theme.surfaceHigh, lineWidth: 7)
                    .frame(width: 96, height: 96)
                Circle()
                    .trim(from: 0, to: appeared ? min(1, review.breakdown.score / 100) : 0)
                    .stroke(moveColor, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .frame(width: 96, height: 96)
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(Int(review.breakdown.score.rounded()))")
                        .font(.appNumber(30, .black))
                        .foregroundStyle(theme.text)
                        .contentTransition(.numericText())
                    Text("SKOR").font(.caption).kerning(0.8)
                        .foregroundStyle(theme.subtle)
                }
            }
            .scaleEffect(appeared ? 1 : 0.5)
        }
        .frame(height: 100)
    }

    private var headline: String {
        let total = review.standings.count
        let place = "\(total) startup içinde \(review.playerRank). oldun."
        if promoted { return "Harika çeyrek! \(place) Bir üst lige yükseliyorsun." }
        if demoted { return "Zorlu çeyrek. \(place) Bir alt lige düştün — toparlanma zamanı." }
        return "\(place) Ligini korudun — ama zirve seni bekliyor."
    }

    // MARK: Kohort sıralaması — gerçek bahis: oyuncu + rakipler, terfi/düşüş bölgeleri.
    /// Terfi/düşüş eşikleri ÇEYREK BAŞI lige (fromTier) göre — bu çeyrekte geçerli kurallar.
    private var promoteCutoff: Int {
        review.fromTier >= LeagueSystem.leagueCount - 1 ? 0 : CohortSystem.promoteTopN
    }
    private var demoteCutoff: Int {
        review.fromTier <= 0 ? 0 : CohortSystem.demoteBottomN
    }

    @ViewBuilder private var cohortStandings: some View {
        if !review.standings.isEmpty {
            VStack(alignment: .leading, spacing: Space.s2) {
                Text("KOHORT SIRALAMASI").font(.caption).kerning(0.8)
                    .foregroundStyle(theme.subtle)
                LeaderboardList(model: model, theme: theme,
                                standings: review.standings,
                                promoteCutoff: promoteCutoff,
                                demoteCutoff: demoteCutoff,
                                total: review.standings.count)
            }
            .padding(Space.s4)
            .background(theme.surfaceHigh, in: RoundedRectangle(cornerRadius: Radius.m))
        }
    }

    // MARK: Scorecard satırları — büyüme / gelir / değerleme / karar / moral.
    private var scorecard: some View {
        VStack(spacing: Space.s2) {
            row("Kullanıcı büyümesi", pct(review.breakdown.userGrowthPct),
                icon: Icons.Metric.users, good: review.breakdown.userGrowthPct >= 0)
            row("Değerleme artışı", pct(review.breakdown.valuationGrowthPct),
                icon: Icons.Metric.valuation, good: review.breakdown.valuationGrowthPct >= 0)
            row("MRR artışı", pct(review.breakdown.mrrGrowthPct),
                icon: Icons.Metric.mrr, good: review.breakdown.mrrGrowthPct >= 0)
            row("Alınan karar", "\(review.breakdown.decisionsMade)",
                icon: Icons.Metric.decisions, good: review.breakdown.decisionsMade > 0)
            row("Ortalama moral", "\(Int(review.breakdown.avgMorale.rounded()))",
                icon: Icons.Metric.morale, good: review.breakdown.avgMorale >= 50)
        }
        .padding(Space.s4)
        .background(theme.surfaceHigh, in: RoundedRectangle(cornerRadius: Radius.m))
    }

    private func row(_ label: String, _ value: String, icon: String, good: Bool) -> some View {
        HStack(spacing: Space.s2) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.accent)
                .frame(width: 16)
            Text(label).font(.bodyText).foregroundStyle(theme.subtle)
            Spacer()
            Text(value).font(.numberM)
                .foregroundStyle(good ? Palette.success : Palette.danger)
        }
    }

    // MARK: Lig hareketi — kaynak rozet → hedef rozet + ok.
    private var leagueMovement: some View {
        HStack(spacing: Space.s3) {
            LeagueBadge(league: fromLeague, dim: review.fromTier != review.toTier)
            Image(systemName: arrowSymbol)
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(moveColor)
                .symbolEffect(.bounce, value: appeared)
            LeagueBadge(league: toLeague, dim: false, highlight: review.fromTier != review.toTier)
        }
        .padding(.vertical, Space.s2)
    }

    private var arrowSymbol: String {
        promoted ? "arrow.up.circle.fill"
        : (demoted ? "arrow.down.circle.fill" : "arrow.right.circle.fill")
    }

    // MARK: Koçluk yorumu — kural-tabanlı, suçlayıcı değil, "şunu da deneyebilirsin" tonu.
    /// Skor + delta'lar + lig hareketinden 1-2 cümlelik koçluk notu seçer.
    /// "Tek doğru yol yok" felsefesine sadık — çoğu yorumda alternatif yol ima edilir.
    private var coachingText: String {
        let s = review.breakdown.score
        let users = review.breakdown.userGrowthPct
        let mrr = review.breakdown.mrrGrowthPct
        let morale = review.breakdown.avgMorale
        let decisions = review.breakdown.decisionsMade

        // Lig içinde sıralaman düştü + alt yarıda → rakip baskısı.
        if demoted || (review.standings.count > 0 && review.playerRank > review.standings.count / 2 + 1) {
            return "Kohortun alt yarısındasın; rakiplerin agresif. Hangi mekanikte geride kaldığını düşün — bazen savunma (churn/moral) saldırıdan (büyüme) önce gelir."
        }
        // Skor ≥ 80 + güçlü kullanıcı büyümesi → büyüme sürdürülebilirlik uyarısı.
        if s >= 80 && users >= 25 {
            return "Güçlü çeyrek. Bu hızla devam edersen LTV:CAC sağlığını da takip et — büyüme tek başına sürdürülebilir değil."
        }
        // Yüksek skor ama moral düşük → ekibi tüketme uyarısı.
        if s >= 70 && morale < 50 {
            return "Sayılar iyi ama ekibin yorgun. Bir sonraki çeyrekte moral yatırımı yapmak da meşru bir yol — ürünü kuran insanlar."
        }
        // Orta skor + MRR sabit → büyüme yatırımı önerisi (alternatif yol vurgulu).
        if s >= 50 && s < 80 && abs(mrr) < 10 {
            return "Stabil ama gelir büyümüyor. Belki pazarlamaya, belki ürün derinliğine yatırım zamanı — tek doğru cevap yok, kendi tezini test et."
        }
        // Düşük karar sayısı → daha aktif oyna ipucu.
        if decisions <= 1 && s < 70 {
            return "Bu çeyrekte az karar aldın. Daha aktif bir tempo dene — ya da bilinçli olarak sade kal; ikisi de geçerli bir strateji."
        }
        // Düşük skor + düşük moral → kriz öncesi toparlanma.
        if s < 50 && morale < 50 {
            return "Zor çeyrek. Krize girmeden ekibin moralini önce topla — bir sonraki sprintte küçük bir zafer kovala, momentum kıymetli."
        }
        // Düşük skor ama moral hâlâ ayakta → uzun vade umutlu.
        if s < 50 {
            return "Sayılar düşük ama oyun bitmedi. Bu çeyrekteki en küçük başarını al, üstüne kur — başarısızlık da bir bilgi parçası."
        }
        // Terfi + iyi skor → kutlama + bir sonraki seviye uyarısı.
        if promoted {
            return "Üst lige çıkıyorsun; rakipler daha sert olacak. Aynı oyunu oynamak yerine bir mekaniği daha derinleştirmeyi düşün."
        }
        // Default: stabil, lig korundu.
        return "Ligini korudun. Bir sonraki çeyrekte farklı bir strateji denemek de bir yol — aynı planı sıkılaştırmak da. İkisi de meşru."
    }

    private var coachingNote: some View {
        HStack(alignment: .top, spacing: Space.s2) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(theme.accent)
                .frame(width: 18)
                .padding(.top, 1)
            Text(coachingText)
                .font(.appText(13, .medium))
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Space.s3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surfaceHigh, in: RoundedRectangle(cornerRadius: Radius.m))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.m)
                .stroke(theme.accent.opacity(0.25), lineWidth: 1)
        )
    }

    private func pct(_ v: Double) -> String {
        let sign = v >= 0 ? "+" : ""
        return "\(sign)%\(Int(v.rounded()))"
    }
}

/// Lig rozeti — ikon + isim, lig rengi. Overlay ve HUD/Yol'da paylaşılır.
struct LeagueBadge: View {
    let league: LeagueDef
    var dim: Bool = false
    var highlight: Bool = false

    private var color: Color { Color(hex: league.colorHex) }

    var body: some View {
        VStack(spacing: Space.s1) {
            ZStack {
                Circle()
                    .fill(color.opacity(highlight ? 0.28 : 0.16))
                    .frame(width: 52, height: 52)
                    .overlay(Circle().stroke(color.opacity(highlight ? 0.9 : 0.5),
                                             lineWidth: highlight ? 2 : 1))
                    .shadow(color: highlight ? color.opacity(0.3) : .clear, radius: 7)
                Image(systemName: league.icon)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(color)
            }
            Text(league.name)
                .font(.appText(10, .bold))
                .foregroundStyle(highlight ? Palette.textPrimary : Palette.textTertiary)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .opacity(dim ? 0.45 : 1)
        .frame(width: 88)
    }
}

/// HUD/Yol için kompakt lig rozeti — ikon + lig adı + çeyrek ilerleme halkası.
/// Opsiyonel `onTap` verilirse tıklanabilir (canlı leaderboard sheet'ini açar).
struct LeaguePill: View {
    @ObservedObject var model: GameModel
    var theme: Theme
    var onTap: (() -> Void)? = nil

    private var league: LeagueDef { model.currentLeague }
    private var color: Color { Color(hex: league.colorHex) }

    private var content: some View {
        HStack(spacing: Space.s2) {
            ZStack {
                Circle().stroke(color.opacity(0.25), lineWidth: 3)
                    .frame(width: 26, height: 26)
                Circle()
                    .trim(from: 0, to: model.quarterProgress)
                    .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 26, height: 26)
                    .rotationEffect(.degrees(-90))
                Image(systemName: league.icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(league.name)
                    .font(.appText(11, .bold))
                    .foregroundStyle(theme.text)
                Text("Çeyrek \(model.quarterNumber)")
                    .font(.caption)
                    .foregroundStyle(theme.subtle)
            }
            if onTap != nil {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(theme.subtle)
            }
        }
        .padding(.horizontal, Space.s3).padding(.vertical, Space.s2)
        .background(theme.surfaceHigh, in: Capsule())
        .overlay(Capsule().stroke(color.opacity(0.35), lineWidth: 1))
    }

    var body: some View {
        if let onTap {
            Button { Haptics.tap(); onTap() } label: { content }
                .buttonStyle(.pressable)
        } else {
            content
        }
    }
}
