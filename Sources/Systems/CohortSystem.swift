import Foundation

// MARK: - Rakip Kohort + Canlı Leaderboard (gerçek bahis — Duolingo lig dili)
// Saf fonksiyonlar: çeyrek başında oyuncunun ligine uygun "güç"te 8-10 simüle rakip
// startup üret (isim havuzundan), çeyrek boyunca skorlarını ilerlet, oyuncu + rakipleri
// çeyrek skoruna göre sırala. Terfi/düşüş SIRALAMAYA göre belirlenir (ilk N terfi, son N düşer).
// Mantık burada izole — GameModel sadece çağırır, GameState veriyi saklar.

/// Leaderboard'da gösterilen tek bir sıralama satırı (oyuncu ya da rakip).
struct StandingEntry: Identifiable {
    let id: Int          // -1 = oyuncu; >=0 rakip kohort indeksi
    let name: String
    let score: Double    // çeyrek performans skoru (0-100 ölçeği)
    let isPlayer: Bool
    var rank: Int = 0    // 1'den (sıralama sonrası doldurulur)
}

/// Çeyrek kapanışında oyuncunun ligini sıralamaya göre nasıl değiştireceği.
enum CohortOutcome { case promote, stay, demote }

enum CohortSystem {

    // MARK: Ayarlar
    /// Kohort büyüklüğü (oyuncu DAHİL). 9 → oyuncu + 8 rakip.
    static let size = 9
    /// İlk N sıradaki terfi eder (en üst lig hariç).
    static let promoteTopN = 3
    /// Son N sıradaki düşer (en alt lig hariç).
    static let demoteBottomN = 3

    // MARK: İsim havuzu (startup temalı, kurgusal — emoji yok)
    static let namePool: [String] = [
        "Nimbus", "Vexel", "Quanta", "Pixelly", "Orbital", "Hyperloop",
        "Zenflow", "Bytewise", "Lumina", "Forge AI", "Northpeak", "Cascade",
        "Vantage", "Pulsar", "Echo Labs", "Stratus", "Helix", "Driftwood",
        "Cobalt", "Mosaic", "Tidal", "Apex Stack", "Glimpse", "Verdant",
        "Solstice", "Kindred", "Beacon", "Loopr", "Mintly", "Cascadia",
        "Voltage", "Fathom", "Bramble", "Onyx", "Sablefox", "Meridian",
    ]

    /// Lige uygun "güç" bandı: üst ligler daha rekabetçi (rakip skor ortalaması yüksek).
    /// Bu bantta rastgele bir başlangıç skoru üretilir; çeyrek boyunca ilerler.
    static func powerBand(tier: Int) -> (low: Double, high: Double) {
        // Garaj → Unicorn arası kademeli artan rekabet (taban 30..50 → tepe ~52..72).
        let lo = 30.0 + Double(tier) * 4.0
        let hi = 50.0 + Double(tier) * 4.0
        return (min(85, lo), min(90, hi))
    }

    /// Çeyrek başı için taze kohort üret: rastgele isimler + başlangıç skorları.
    /// Oyuncu HARİÇ `size - 1` rakip döner (isim + başlangıç skoru paralel diziler).
    static func freshCohort(tier: Int) -> (names: [String], scores: [Double]) {
        let band = powerBand(tier: tier)
        let count = size - 1
        let names = Array(namePool.shuffled().prefix(count))
        let scores = (0..<count).map { _ -> Double in
            // Başlangıçta düşük skor (çeyrek yeni başladı); bandın alt diliminden.
            Double.random(in: max(0, band.low - 18) ... max(1, band.low - 4))
        }
        return (names, scores)
    }

    /// Bir tick'te rakip skorlarını ilerlet (oyun temposuyla). Her rakip kendi
    /// hedefine (powerBand içinde) doğru yumuşakça yaklaşır + küçük rastgele dalga.
    /// - progress: çeyrek ilerlemesi 0-1 (rakip skoru çeyrek sonuna doğru olgunlaşır).
    /// - dt: oyun-zamanı saniye (yaklaşım hızı buna ölçeklenir).
    static func advanced(scores: [Double], tier: Int, progress: Double, dt: Double) -> [Double] {
        let band = powerBand(tier: tier)
        let span = band.high - band.low
        return scores.enumerated().map { idx, current in
            // Her rakibin kendi "hedef tavanı" (banttaki sabit konumu, indeksten türetilir).
            let seat = Double((idx * 37) % 100) / 100.0     // 0..1 deterministik konum
            let ceiling = band.low + seat * span
            // Hedef: çeyrek ilerledikçe tavana yaklaşan skor.
            let target = ceiling * (0.55 + 0.45 * min(1, max(0, progress)))
            // Yumuşak yaklaşım + küçük rastgele titreşim (canlı leaderboard hissi).
            let approach = (target - current) * min(1, 0.05 * dt)
            let jitter = Double.random(in: -0.15 ... 0.2) * dt
            return min(100, max(0, current + approach + jitter))
        }
    }

    /// Oyuncu + rakipleri tek listede skora göre sırala (yüksek skor üstte).
    /// `rank` 1'den doldurulur. Beraberlikte oyuncu önde sayılır (lehte yuvarlama).
    static func standings(playerScore: Double, playerName: String,
                          cohortNames: [String], cohortScores: [Double]) -> [StandingEntry] {
        var entries: [StandingEntry] = [
            StandingEntry(id: -1, name: playerName, score: playerScore, isPlayer: true)
        ]
        for (i, name) in cohortNames.enumerated() {
            let sc = i < cohortScores.count ? cohortScores[i] : 0
            entries.append(StandingEntry(id: i, name: name, score: sc, isPlayer: false))
        }
        entries.sort { a, b in
            if abs(a.score - b.score) < 0.0001 { return a.isPlayer && !b.isPlayer }
            return a.score > b.score
        }
        for i in entries.indices { entries[i].rank = i + 1 }
        return entries
    }

    /// Oyuncunun standings içindeki sırası (1'den). Bulunamazsa son sıra.
    static func playerRank(in standings: [StandingEntry]) -> Int {
        standings.first(where: { $0.isPlayer })?.rank ?? standings.count
    }

    /// Sıralamaya göre lig hareketi (gerçek bahis): ilk N terfi, son N düşer.
    /// En üst ligde terfi yok; en alt ligde düşüş yok.
    static func outcome(rank: Int, total: Int, tier: Int, topTier: Int) -> CohortOutcome {
        let isTop = tier >= topTier
        let isBottom = tier <= 0
        if !isTop && rank <= promoteTopN { return .promote }
        if !isBottom && rank > total - demoteBottomN { return .demote }
        return .stay
    }
}
