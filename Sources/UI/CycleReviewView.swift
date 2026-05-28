import SwiftUI

/// Genişleyip sönen kutlama parıltı halkası (terfi anı).
private struct CycleCelebrationRing: View {
    let color: Color
    @State private var animate = false
    var body: some View {
        Circle()
            .stroke(color, lineWidth: 3)
            .frame(width: 96, height: 96)
            .scaleEffect(animate ? 2.2 : 0.4)
            .opacity(animate ? 0 : 1)
            .onAppear {
                withAnimation(.easeOut(duration: 1.3).repeatCount(2, autoreverses: false)) {
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
            // İçerik uzun (scorecard + kohort sıralaması + rozetler) → taşmayı önlemek
            // için ScrollView; kart ekrana sığmazsa kaydırılır.
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

                    Button { Haptics.tap(); model.startNextQuarter() } label: {
                        Text("Yeni Çeyrek").font(.bodyL)
                            .modifier(AppButton.primary(theme))
                    }
                    .buttonStyle(.pressable)
                }
                .padding(Space.s5)
                .frame(maxWidth: 360)
                .background(theme.surfaceLow, in: RoundedRectangle(cornerRadius: Radius.overlay))
                .shadow(color: .black.opacity(0.35), radius: 20, y: 8)
                .padding(.horizontal, Space.s5)
                .padding(.vertical, Space.s5)
                .scaleEffect(appeared ? 1 : 0.8).opacity(appeared ? 1 : 0)
            }
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
                    .shadow(color: highlight ? color.opacity(0.5) : .clear, radius: 10)
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
