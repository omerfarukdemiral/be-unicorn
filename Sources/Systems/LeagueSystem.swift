import Foundation

// MARK: - Startup Ligleri + Çeyrek Değerlendirmesi (completed-cycle çekirdeği)
// Saf fonksiyonlar: lig tanımları, çeyrek skoru, terfi/düşüş mantığı.
// Mantık burada izole — GameModel sadece çağırır, GameState veriyi saklar.

/// Bir startup ligi (Duolingo Bronz→Elmas eşleniği, startup teması).
struct LeagueDef: Identifiable {
    let id: Int
    let name: String        // "Garaj Ligi", "Tohum Ligi", ...
    let icon: String        // SF Symbol
    let colorHex: String    // rozet/tema rengi (Palette uyumlu hex)
    /// Bu ligde KALMAK/terfi için gereken çeyrek skoru (0-100 ölçeği).
    let promoteThreshold: Double
    /// Bu skorun ALTINDA düşersin (en alt lig için 0 — düşüş yok).
    let demoteThreshold: Double
}

enum LeagueSystem {

    // MARK: Lig tanımları (Garaj → Unicorn)
    static let leagues: [LeagueDef] = [
        .init(id: 0, name: "Garaj Ligi",   icon: "shippingbox.fill",       colorHex: "9A7B5A",
              promoteThreshold: 55, demoteThreshold: 0),
        .init(id: 1, name: "Tohum Ligi",   icon: "leaf.fill",              colorHex: "4FD1A1",
              promoteThreshold: 58, demoteThreshold: 32),
        .init(id: 2, name: "Melek Ligi",   icon: "sparkles",              colorHex: "5B8DEF",
              promoteThreshold: 60, demoteThreshold: 35),
        .init(id: 3, name: "Seri Ligi",    icon: "chart.line.uptrend.xyaxis", colorHex: "C77DFF",
              promoteThreshold: 62, demoteThreshold: 38),
        .init(id: 4, name: "Elmas Ligi",   icon: "diamond.fill",           colorHex: "2EE6C5",
              promoteThreshold: 65, demoteThreshold: 40),
        .init(id: 5, name: "Unicorn Ligi", icon: "crown.fill",             colorHex: "FF6FB5",
              promoteThreshold: 100, demoteThreshold: 42),  // en üst: terfi yok, sadece koru
    ]
    static var leagueCount: Int { leagues.count }

    static func league(_ tier: Int) -> LeagueDef {
        leagues[min(max(0, tier), leagueCount - 1)]
    }

    // MARK: Çeyrek başı anlık görüntü (delta hesabı için)
    struct Snapshot {
        var users: Double
        var valuation: Double
        var mrr: Double
        var decisions: Int
    }

    // MARK: Skor bileşenleri (UI scorecard satırları için)
    struct ScoreBreakdown {
        var userGrowthPct: Double   // çeyrek boyu kullanıcı büyümesi %
        var valuationGrowthPct: Double
        var mrrGrowthPct: Double
        var decisionsMade: Int
        var avgMorale: Double
        /// Bileşenlerden türetilen tek performans skoru (0-100).
        var score: Double
        /// Günlük hedef/streak'ten gelen küçük skor katkısı (completed-cycle besleme).
        var streakBonus: Double = 0
    }

    /// Çeyrek performans skorunu hesapla. Bileşenler 0-100'e normalize edilip
    /// ağırlıklı toplanır — büyüme ağır basar ama moral/karar da besler.
    static func evaluate(start: Snapshot, end: Snapshot, avgMorale: Double) -> ScoreBreakdown {
        let userGrowth = pctGrowth(start.users, end.users)
        let valGrowth  = pctGrowth(start.valuation, end.valuation)
        let mrrGrowth  = pctGrowth(start.mrr, end.mrr)
        let decisions  = max(0, end.decisions - start.decisions)

        // Her bileşeni 0-100 puana çevir (hedefe göre normalize).
        // Çeyrek başına ~%40 kullanıcı, ~%50 değerleme büyümesi "tam puan" sayılır.
        let growthScore = clamp100(userGrowth / 40 * 100)        // hedef +%40 kullanıcı
        let valScore    = clamp100(valGrowth / 50 * 100)         // hedef +%50 değerleme
        let mrrScore    = clamp100(mrrGrowth / 45 * 100)         // hedef +%45 MRR
        let decScore    = clamp100(Double(decisions) / 4 * 100)  // hedef ~4 karar/çeyrek
        let moraleScore = clamp100(avgMorale)                    // moral zaten 0-100

        // Ağırlıklar: büyüme + değerleme baskın, gelir/karar/moral destek.
        let score = growthScore * 0.30
                  + valScore    * 0.30
                  + mrrScore    * 0.18
                  + decScore    * 0.10
                  + moraleScore * 0.12

        return ScoreBreakdown(userGrowthPct: userGrowth,
                              valuationGrowthPct: valGrowth,
                              mrrGrowthPct: mrrGrowth,
                              decisionsMade: decisions,
                              avgMorale: avgMorale,
                              score: clamp100(score))
    }

    // MARK: Lig hareketi sonucu
    enum Movement { case promote, stay, demote }

    /// Çeyrek skoruna + küçük rastgele rakip aralığına göre lig hareketi.
    /// `competitorBar`: o çeyrek rakip kohortunun "ortalama performansı" (eşiğe küçük gürültü).
    static func movement(score: Double, tier: Int, competitorBar: Double) -> Movement {
        let def = league(tier)
        let topTier = (tier >= leagueCount - 1)
        // Terfi: hem sabit eşiği aş hem de rakip bar'ı geç (gerçek bahis hissi).
        if !topTier && score >= def.promoteThreshold && score >= competitorBar {
            return .promote
        }
        // Düşüş: en alt lig hariç, eşiğin belirgin altına düşersen.
        if tier > 0 && score < def.demoteThreshold {
            return .demote
        }
        return .stay
    }

    /// Çeyrek için rakip kohort barı: eşik ± küçük rastgele aralık (adil ama belirsiz).
    static func competitorBar(tier: Int) -> Double {
        let def = league(tier)
        return def.promoteThreshold + Double.random(in: -6 ... 4)
    }

    // MARK: Yardımcılar
    private static func pctGrowth(_ from: Double, _ to: Double) -> Double {
        guard from > 0.0001 else { return to > 0 ? 100 : 0 }
        return (to - from) / from * 100
    }
    private static func clamp100(_ v: Double) -> Double { min(100, max(0, v)) }
}
