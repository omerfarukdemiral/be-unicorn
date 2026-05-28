import Foundation

// MARK: - Sezon Finali + Kalıcı Ödül (uzun-vade tamamlanma, completed-cycle zincirinin en üstü)
// Saf fonksiyonlar: birkaç çeyrek = 1 sezon. Sezon dolunca görkemli finale + KALICI ödül
// (ünvan/rozet koleksiyonu + küçük kalıcı üretim çarpanı — founderBonus mantığına benzer, ufak).
// Mantık burada izole — GameModel sadece çağırır, GameState veriyi saklar.

/// Bir sezonun kazanılan ünvanı/rozeti. Sezon sayısıyla yükselen koleksiyon.
/// id == sezon sırası (1'den). icon = SF Symbol, colorHex = Palette uyumlu rozet rengi.
struct SeasonTitleDef: Identifiable {
    let id: Int
    let name: String        // ünvan ("Seri Kurucu", "Vizyoner", ...)
    let icon: String        // SF Symbol (emoji YOK)
    let colorHex: String    // rozet/tema rengi (gold/unicorn paleti hex)
}

enum SeasonSystem {

    // MARK: Ünvan koleksiyonu (sezon sırasıyla yükselir; sonu döngüsel "+roman" eki)
    static let titles: [SeasonTitleDef] = [
        .init(id: 1, name: "Yükselen Kurucu", icon: "sparkles",            colorHex: "FFD479"),
        .init(id: 2, name: "Seri Kurucu",     icon: "rosette",             colorHex: "FFC24B"),
        .init(id: 3, name: "Vizyoner",        icon: "eye.trianglebadge.exclamationmark", colorHex: "C77DFF"),
        .init(id: 4, name: "Sektör Devi",     icon: "shield.lefthalf.filled", colorHex: "5B8DEF"),
        .init(id: 5, name: "Efsane Kurucu",   icon: "flame.fill",          colorHex: "FF9F5A"),
        .init(id: 6, name: "Unicorn Lordu",   icon: "crown.fill",          colorHex: "FF6FB5"),
    ]

    /// Verilen sezon sayısı için ünvan (1'den). Listeden taşarsa son ünvan + roman eki döner.
    static func title(forSeason season: Int) -> SeasonTitleDef {
        guard season >= 1 else { return titles[0] }
        if season <= titles.count {
            return titles[season - 1]
        }
        // Koleksiyon doldu: en üst ünvan + tekrar sayısı (II, III, ...) — sonsuz koleksiyon.
        let last = titles[titles.count - 1]
        let extra = season - titles.count + 1   // 2, 3, ...
        return SeasonTitleDef(id: season, name: "\(last.name) \(roman(extra))",
                              icon: last.icon, colorHex: last.colorHex)
    }

    /// Bir sezonu bitirince kazanılan KALICI üretim çarpanı katkısı (oransal).
    /// Küçük + tavanlı — ekonomiyi bozmaz (founderBonus mantığına benzer, ufak).
    static func bonusForCompleting(season: Int) -> Double {
        Balance.seasonOutputBonusPerSeason
    }

    /// Toplam kalıcı sezon çarpanı (1 + birikmiş bonus), tavanlı.
    static func totalMultiplier(seasonsCompleted: Int) -> Double {
        let raw = Double(seasonsCompleted) * Balance.seasonOutputBonusPerSeason
        return 1 + min(Balance.seasonOutputBonusCap, raw)
    }

    // MARK: Sezon özeti (finale scorecard satırları için)
    /// Bir sezon kapanışında gösterilen birikmiş istatistik (çeyrek kapanışlarından toplanır).
    struct Summary {
        var quarters: Int          // bu sezonda kapanan çeyrek sayısı
        var promotions: Int        // bu sezonda kazanılan terfi sayısı
        var highestTier: Int       // bu sezonda ulaşılan en yüksek lig
        var sprintsWon: Int        // bu sezonda kazanılan toplam sprint
        var dailyGoals: Int        // bu sezonda tamamlanan toplam günlük hedef
        var avgScore: Double       // bu sezonda ortalama çeyrek skoru (0-100)
    }

    // MARK: Yardımcı — basit roma rakamı (koleksiyon taşması için)
    private static func roman(_ n: Int) -> String {
        let table: [(Int, String)] = [(10, "X"), (9, "IX"), (5, "V"), (4, "IV"), (1, "I")]
        var v = max(1, n), out = ""
        for (val, sym) in table {
            while v >= val { out += sym; v -= val }
        }
        return out
    }
}
