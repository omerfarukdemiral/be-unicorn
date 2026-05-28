import Foundation

/// Kaydedilebilir oyun durumu. Saf veri — mantık GameModel'de.
struct GameState: Codable {
    // Para & şirket
    var cash: Double = Balance.startCash
    var lifetimeRevenue: Double = 0
    var users: Double = 0
    var reputation: Double = 20        // 0-100 itibar/hype
    var morale: Double = Balance.startMorale  // 0-100
    var founderEquity: Double = 1.0    // kurucu hisse oranı (1.0 = %100)

    // Ekip (departman jeneratörleri)
    var headcount: [Int]
    var moduleLevels: [Int]

    // Ofis eşyaları (itemId → adet). Eski kayıtta yoksa boş gelir; normalize tohumlar.
    var ownedItems: [Int: Int] = [:]

    // Pazarlama: aylık reklam/kullanıcı-edinme bütçesi (oyuncu ayarlar)
    var adBudgetPerMonth: Double = 0

    // Funding evresi (meta)
    var stage: Int = 0
    var stageReached: Int = 0          // ulaşılan en yüksek evre (kalıcı)

    // Karar olayları
    var seenEventIDs: [String] = []
    var pendingEventID: String? = nil
    var moraleTargetBonus: Double = 0  // kararların/modüllerin kalıcı moral etkisi

    // Zaman & istatistik
    var months: Double = 0             // şirket yaşı (oyun-ayı, kesirli)
    var totalDecisions: Int = 0
    var totalHires: Int = 0
    var bankruptcies: Int = 0
    var founderXP: Double = 0          // NG+ kalıcı çarpan kaynağı

    // MARK: Startup Ligleri + Çeyrek döngüsü (completed-cycle)
    var leagueTier: Int = 0            // 0=Garaj Ligi ... 5=Unicorn Ligi
    var quarterIndex: Int = 0          // tamamlanan çeyrek sayısı (1'den gösterilir)
    var quarterStartMonth: Double = 0  // mevcut çeyreğin başladığı oyun-ayı
    // Çeyrek başı anlık görüntü (delta/skor hesabı için)
    var quarterStartUsers: Double = 0
    var quarterStartValuation: Double = 0
    var quarterStartMRR: Double = 0
    var quarterStartDecisions: Int = 0
    // Çeyrek boyu moral örneklemi (ortalama moral için)
    var quarterMoraleSum: Double = 0
    var quarterMoraleSamples: Double = 0

    // MARK: Günlük Hedef + Streak (geri-dönüş kancası)
    // Gerçek takvim gününe (DailyGoalSystem.dayKey) bağlı küçük tamamlanabilir görev seti.
    var dailyDayKey: Int = 0           // o anki günün anahtarı (0 = hiç ayarlanmadı → ilk açılışta tohumlanır)
    var dailyHires: Int = 0            // bugün yapılan işe alım sayısı
    var dailyDecisions: Int = 0        // bugün verilen karar sayısı
    var dailyUsersStart: Double = 0    // günün başındaki kullanıcı (delta için)
    var dailyCompleted: Bool = false   // bugünkü hedef tamamlandı mı (kapanış bir kez)
    var streak: Int = 0                // ardışık tamamlanan gün sayacı (🔥)
    var bestStreak: Int = 0            // en yüksek streak (kalıcı rekor)
    var dailyGoalsThisQuarter: Int = 0 // bu çeyrekte tamamlanan günlük hedef sayısı (lige besler)

    // MARK: Haftalık Sprint (çeyrek içi kısa, kapanan döngü)
    // Çeyrek içinde tekrarlayan "hafta"/sprint dilimi — net + tamamlanabilir hedef.
    var sprintIndex: Int = 0           // toplam başlatılan sprint sayısı (hedef rotasyonu + 1'den gösterim)
    var sprintStartMonth: Double = 0   // mevcut sprint'in başladığı oyun-ayı
    var sprintGoalKind: Int = 0        // SprintGoalKind.rawValue
    var sprintGoalTarget: Double = 0   // hedef değer (yüzde puanı veya adet)
    // Sprint başı anlık görüntü (ilerleme/sonuç hesabı için)
    var sprintStartMRR: Double = 0
    var sprintStartUsers: Double = 0
    var sprintStartDecisions: Int = 0
    var sprintsWonThisQuarter: Int = 0 // bu çeyrekte başarıyla kapanan sprint sayısı (lige besler)

    // MARK: Sezon Finali + Kalıcı Ödül (uzun-vade tamamlanma)
    // Birkaç çeyrek (Balance.quartersPerSeason) = 1 sezon. Çeyrek kapanışları sayılır;
    // sezon dolunca görkemli finale + KALICI ödül (ünvan/rozet + küçük üretim çarpanı).
    var seasonIndex: Int = 0               // tamamlanan sezon sayısı (1'den gösterilir: seasonIndex+1)
    var quartersThisSeason: Int = 0        // bu sezonda kapanan çeyrek sayısı (quartersPerSeason'da dolar)
    var seasonsCompleted: Int = 0          // bitirilen sezon sayısı (kalıcı ödül kaynağı — çarpan + ünvan)
    // Bu sezon içi birikmiş istatistik (finale özeti için — sezon başında sıfırlanır).
    var seasonPromotions: Int = 0          // bu sezonda kazanılan terfi sayısı
    var seasonHighestTier: Int = 0         // bu sezonda ulaşılan en yüksek lig
    var seasonSprintsWon: Int = 0          // bu sezonda kazanılan toplam sprint
    var seasonDailyGoals: Int = 0          // bu sezonda tamamlanan toplam günlük hedef
    var seasonScoreSum: Double = 0         // bu sezon çeyrek skorlarının toplamı (ortalama için)

    // MARK: Rakip Kohort + Canlı Leaderboard (gerçek bahis)
    // Çeyrek başında ligine uygun taze 8 rakip startup (oyuncu dahil 9'luk kohort).
    // Skorlar çeyrek boyunca oyun temposuyla ilerler; çeyrek kapanışında oyuncu + rakipler
    // sıralanır → SIRALAMAYA göre terfi/düşüş. Boşsa GameModel ilk tick'te taze tohumlar.
    var cohortNames: [String] = []     // rakip startup isimleri (oyuncu HARİÇ)
    var cohortScores: [Double] = []    // rakiplerin o anki çeyrek skoru (isimlerle paralel)
    var cohortTier: Int = -1           // kohortun üretildiği lig (lig değişince yenilenir; -1 = hiç yok)

    // İstatistik grafiği için örnekler (cash, users, valuation, mrr)
    var history: [HistoryPoint] = []

    var lastSaved: Date = Date()
    var hasSeenOnboarding: Bool = false
    var currency: Currency = .usd       // görüntü para birimi (TL/Euro/Dolar)

    init() {
        headcount = Array(repeating: 0, count: Balance.departmentCount)
        headcount[0] = 1   // tek kişilik başlangıç: kurucu = ilk mühendis
        moduleLevels = Array(repeating: 0, count: Balance.modules.count)
        // Garaj başlangıcı: birkaç basit masa tohumla ki ilk çalışan(lar) oturabilsin.
        ownedItems = [0: 2]
    }

    mutating func normalize() {
        headcount = Self.resized(headcount, to: Balance.departmentCount)
        moduleLevels = Self.resized(moduleLevels, to: Balance.modules.count)
        stage = min(max(0, stage), Balance.stageCount - 1)
        morale = min(100, max(0, morale))
        reputation = min(100, max(0, reputation))
        founderEquity = min(1, max(0, founderEquity))
        if history.count > 120 { history = Array(history.suffix(120)) }

        // Lig/çeyrek alanları — eski kayıtlar için güvenli varsayılan.
        leagueTier = min(max(0, leagueTier), LeagueSystem.leagueCount - 1)
        quarterIndex = max(0, quarterIndex)
        // Çeyrek başı snapshot hiç set edilmediyse (eski kayıt) şimdiki ana sabitle.
        if quarterStartMonth <= 0 { quarterStartMonth = months }
        quarterMoraleSamples = max(0, quarterMoraleSamples)
        quarterMoraleSum = max(0, quarterMoraleSum)

        // Günlük hedef / streak — eski kayıtlar için güvenli varsayılan.
        dailyHires = max(0, dailyHires)
        dailyDecisions = max(0, dailyDecisions)
        dailyUsersStart = max(0, dailyUsersStart)
        streak = max(0, streak)
        bestStreak = max(streak, max(0, bestStreak))
        dailyGoalsThisQuarter = max(0, dailyGoalsThisQuarter)

        // Haftalık sprint — eski kayıtlar için güvenli varsayılan.
        sprintIndex = max(0, sprintIndex)
        sprintsWonThisQuarter = max(0, sprintsWonThisQuarter)
        sprintGoalKind = min(max(0, sprintGoalKind), SprintGoalKind.allCases.count - 1)
        sprintGoalTarget = max(0, sprintGoalTarget)
        sprintStartMRR = max(0, sprintStartMRR)
        sprintStartUsers = max(0, sprintStartUsers)
        sprintStartDecisions = max(0, sprintStartDecisions)
        // Sprint başı snapshot hiç set edilmediyse (eski kayıt) şimdiki ana sabitle;
        // hedef boşsa GameModel ilk tick'te tohumlar (seedSprintIfNeeded).
        if sprintStartMonth <= 0 { sprintStartMonth = months }

        // Sezon — eski kayıt / bozuk veri için güvenli varsayılan (çökmez).
        seasonIndex = max(0, seasonIndex)
        seasonsCompleted = max(0, seasonsCompleted)
        quartersThisSeason = min(max(0, quartersThisSeason), Balance.quartersPerSeason)
        seasonPromotions = max(0, seasonPromotions)
        seasonHighestTier = min(max(0, seasonHighestTier), LeagueSystem.leagueCount - 1)
        seasonSprintsWon = max(0, seasonSprintsWon)
        seasonDailyGoals = max(0, seasonDailyGoals)
        seasonScoreSum = max(0, seasonScoreSum)

        // Rakip kohort — eski kayıt / bozuk veri için güvenli normalize.
        // İsim/skor dizileri eşit uzunlukta olmalı; değilse kısaltıp GameModel taze tohumlar.
        if cohortNames.count != cohortScores.count {
            let n = min(cohortNames.count, cohortScores.count)
            cohortNames = Array(cohortNames.prefix(n))
            cohortScores = Array(cohortScores.prefix(n))
        }
        cohortScores = cohortScores.map { min(100, max(0, $0)) }

        // Ofis eşyaları: geçersiz id / negatif adetleri temizle. Eşya katalog dışıysa at.
        ownedItems = ownedItems.filter { Balance.officeItem($0.key) != nil && $0.value > 0 }
        // Eski kayıt / hiç eşyası olmayan oyuncu: garaj için birkaç basit masa tohumla
        // ki ilk çalışan(lar) oturabilsin (taban koltuk + 2 masa = makul başlangıç).
        if ownedItems.isEmpty { ownedItems = [0: 2] }
    }

    private static func resized(_ array: [Int], to n: Int) -> [Int] {
        if array.count == n { return array }
        var fixed = Array(repeating: 0, count: n)
        for i in 0..<min(n, array.count) { fixed[i] = array[i] }
        return fixed
    }
}

/// İstatistik ekranı için zaman serisi noktası.
struct HistoryPoint: Codable {
    var month: Double
    var cash: Double
    var users: Double
    var mrr: Double
    var valuation: Double
}
