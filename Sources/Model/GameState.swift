import Foundation

/// Kaydedilebilir oyun durumu. Saf veri — mantık GameModel'de.
struct GameState: Codable {
    /// Şema sürümü — gelecekte alan eklenip/değişince migration zinciri için.
    /// Eski kayıtta yoksa varsayılan 1 gelir (decode patlamaz).
    var schemaVersion: Int = 1

    // Para & şirket
    var cash: Double = Balance.startCash
    var lifetimeRevenue: Double = 0
    var users: Double = 0
    var reputation: Double = 20        // 0-100 itibar/hype
    var morale: Double = Balance.startMorale  // 0-100
    var founderEquity: Double = 1.0    // kurucu hisse oranı (1.0 = %100)

    // Şirket kimliği (kuruluşta girilir: CEO + şirket + sektör)
    var profile: CompanyProfile = CompanyProfile()
    // Şirketin ürün portföyü (projelerle büyüme mekaniği)
    var projects: [ProjectState] = []
    // Programlı senaryolar (anlatısal, geri-sayımlı hedefler — kaynak yönetimi hissi).
    var scenarios: [ScenarioInstance] = []
    /// En son senaryo spawn edildiği oyun-ayı (spawn aralığını izlemek için).
    var scenarioLastSpawnMonth: Double = 0

    // Ekip (departman jeneratörleri — sayaç) + bireysel üyeler (kimlik katmanı).
    // `headcount` ekonomi formülleri için tek doğruluk kaynağıdır; `members` üstüne
    // ad/skill/proje atanması ekler. normalize() ikisini her zaman senkron tutar.
    // Varsayılan ataması ŞART: eski/eksik JSON'da bu alanlar yoksa decode patlamasın,
    // normalize() sonradan doğru boyuta getirir. (Varsayılansız bırakmak = tüm save reddi.)
    var headcount: [Int] = Array(repeating: 0, count: Balance.departmentCount)
    var members: [TeamMember] = []
    var moduleLevels: [Int] = Array(repeating: 0, count: Balance.modules.count)

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

    // Şirket sağlık durum-makinesi (HealthSystem) — krizler state'e bağlı tetiklenir.
    // strained→crisis geçişinde artar, healthy'e dönünce 0'a sıfırlanır (zincir izleme).
    var crisisChainCount: Int = 0

    // Zaman & istatistik
    var months: Double = 0             // şirket yaşı (oyun-ayı, kesirli)
    var celebratedUserMilestones: [Int] = []  // HZ-2: kutlanan kullanıcı eşikleri (bir kez)
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
    /// **DEPRECATED**: eski kayıt uyumluluğu için tutuluyor. Yeni kod
    /// `cohortCompetitors`'i kullanır; normalize() boş olduğunda buradan migrate eder.
    var cohortNames: [String] = []     // rakip startup isimleri (oyuncu HARİÇ)
    var cohortScores: [Double] = []    // rakiplerin o anki çeyrek skoru (isimlerle paralel)
    /// Zenginleştirilmiş rakip kohortu: her rakipte sektör + kurucu + proje + skor.
    var cohortCompetitors: [Competitor] = []
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

    // MARK: - Migration-proof decode
    //
    // ÖNEMLİ: Swift'in SENTEZLEDİĞİ Codable init'i, alan varsayılan değerlerini KULLANMAZ —
    // eksik bir anahtar (eski save, sonradan eklenen alan) `keyNotFound` ile decode'u
    // tümüyle patlatır ve TÜM ilerleme reddedilir. Bu yüzden her alanı `decodeIfPresent`
    // + güvenli varsayılan ile çözüyoruz: artık eksik HERHANGİ bir alan save'i bozmaz,
    // normalize()/migrate() devreye girebilir. (Audit #7 + #10'un gerçek/kalıcı çözümü.)
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func g<T: Decodable>(_ k: CodingKeys, _ def: T) -> T {
            ((try? c.decodeIfPresent(T.self, forKey: k)) ?? nil) ?? def
        }
        schemaVersion = g(.schemaVersion, 1)
        cash = g(.cash, Balance.startCash)
        lifetimeRevenue = g(.lifetimeRevenue, 0)
        users = g(.users, 0)
        reputation = g(.reputation, 20)
        morale = g(.morale, Balance.startMorale)
        founderEquity = g(.founderEquity, 1.0)
        profile = g(.profile, CompanyProfile())
        projects = g(.projects, [ProjectState]())
        scenarios = g(.scenarios, [ScenarioInstance]())
        scenarioLastSpawnMonth = g(.scenarioLastSpawnMonth, 0)
        headcount = g(.headcount, Array(repeating: 0, count: Balance.departmentCount))
        members = g(.members, [TeamMember]())
        moduleLevels = g(.moduleLevels, Array(repeating: 0, count: Balance.modules.count))
        ownedItems = g(.ownedItems, [Int: Int]())
        adBudgetPerMonth = g(.adBudgetPerMonth, 0)
        stage = g(.stage, 0)
        stageReached = g(.stageReached, 0)
        seenEventIDs = g(.seenEventIDs, [String]())
        pendingEventID = ((try? c.decodeIfPresent(String.self, forKey: .pendingEventID)) ?? nil)
        moraleTargetBonus = g(.moraleTargetBonus, 0)
        crisisChainCount = g(.crisisChainCount, 0)
        months = g(.months, 0)
        celebratedUserMilestones = g(.celebratedUserMilestones, [Int]())
        totalDecisions = g(.totalDecisions, 0)
        totalHires = g(.totalHires, 0)
        bankruptcies = g(.bankruptcies, 0)
        founderXP = g(.founderXP, 0)
        leagueTier = g(.leagueTier, 0)
        quarterIndex = g(.quarterIndex, 0)
        quarterStartMonth = g(.quarterStartMonth, 0)
        quarterStartUsers = g(.quarterStartUsers, 0)
        quarterStartValuation = g(.quarterStartValuation, 0)
        quarterStartMRR = g(.quarterStartMRR, 0)
        quarterStartDecisions = g(.quarterStartDecisions, 0)
        quarterMoraleSum = g(.quarterMoraleSum, 0)
        quarterMoraleSamples = g(.quarterMoraleSamples, 0)
        dailyDayKey = g(.dailyDayKey, 0)
        dailyHires = g(.dailyHires, 0)
        dailyDecisions = g(.dailyDecisions, 0)
        dailyUsersStart = g(.dailyUsersStart, 0)
        dailyCompleted = g(.dailyCompleted, false)
        streak = g(.streak, 0)
        bestStreak = g(.bestStreak, 0)
        dailyGoalsThisQuarter = g(.dailyGoalsThisQuarter, 0)
        sprintIndex = g(.sprintIndex, 0)
        sprintStartMonth = g(.sprintStartMonth, 0)
        sprintGoalKind = g(.sprintGoalKind, 0)
        sprintGoalTarget = g(.sprintGoalTarget, 0)
        sprintStartMRR = g(.sprintStartMRR, 0)
        sprintStartUsers = g(.sprintStartUsers, 0)
        sprintStartDecisions = g(.sprintStartDecisions, 0)
        sprintsWonThisQuarter = g(.sprintsWonThisQuarter, 0)
        seasonIndex = g(.seasonIndex, 0)
        quartersThisSeason = g(.quartersThisSeason, 0)
        seasonsCompleted = g(.seasonsCompleted, 0)
        seasonPromotions = g(.seasonPromotions, 0)
        seasonHighestTier = g(.seasonHighestTier, 0)
        seasonSprintsWon = g(.seasonSprintsWon, 0)
        seasonDailyGoals = g(.seasonDailyGoals, 0)
        seasonScoreSum = g(.seasonScoreSum, 0)
        cohortNames = g(.cohortNames, [String]())
        cohortScores = g(.cohortScores, [Double]())
        cohortCompetitors = g(.cohortCompetitors, [Competitor]())
        cohortTier = g(.cohortTier, -1)
        history = g(.history, [HistoryPoint]())
        lastSaved = g(.lastSaved, Date())
        hasSeenOnboarding = g(.hasSeenOnboarding, false)
        currency = g(.currency, Currency.usd)
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

        // Migrate: eski `cohortNames/cohortScores` varsa ama yeni `cohortCompetitors`
        // boşsa → minimal Competitor'lara dönüştür (sektör/kurucu/proje generic). Bir sonraki
        // çeyrek değişiminde GameModel.regenerateCohort taze + zengin kohort üretir; bu
        // yalnızca "save'i yumuşak geçir" amacıyla.
        if cohortCompetitors.isEmpty && !cohortNames.isEmpty {
            cohortCompetitors = cohortNames.enumerated().map { idx, name in
                Competitor(name: name, sector: 0,
                           founderFirstName: "—", founderLastName: "",
                           projectName: "MVP",
                           score: idx < cohortScores.count ? cohortScores[idx] : 0)
            }
        }
        // Skorları aralık-kilitle (yeni alan için de güvenlik).
        cohortCompetitors = cohortCompetitors.map { c in
            var fixed = c
            fixed.score = min(100, max(0, c.score))
            return fixed
        }

        // Ofis eşyaları: geçersiz id / negatif adetleri temizle. Eşya katalog dışıysa at.
        ownedItems = ownedItems.filter { Balance.officeItem($0.key) != nil && $0.value > 0 }
        // Eski kayıt / hiç eşyası olmayan oyuncu: garaj için birkaç basit masa tohumla
        // ki ilk çalışan(lar) oturabilsin (taban koltuk + 2 masa = makul başlangıç).
        if ownedItems.isEmpty { ownedItems = [0: 2] }

        // Şirket sağlık durum-makinesi — eski kayıt / bozuk veri için güvenli varsayılan.
        crisisChainCount = max(0, crisisChainCount)

        // Şirket profili: sektör katalog dışıysa güvenli tabana çek.
        if Balance.sector(profile.sector) == nil { profile.sector = 0 }
        // Projeler: ilerleme 0-1'e sabitle; geçersiz kategoriyi at; tamamlanmışı canlı say.
        projects = projects.compactMap { p in
            guard Balance.projectCategory(p.category) != nil else { return nil }
            var fixed = p
            fixed.devProgress = min(1, max(0, fixed.devProgress))
            if fixed.devProgress >= 1 { fixed.isLive = true }
            return fixed
        }

        // Senaryolar: geçersiz kind'ı at; settled olmayanların deadline'ı geçmişte ise
        // (eski kayıt / saat manipülasyonu) güvenli şekilde "şimdiden hemen sonra" yapıp
        // GameModel'in normal evaluate'una bırak.
        scenarios = scenarios.compactMap { s in
            guard ScenarioKind(rawValue: s.kind) != nil else { return nil }
            var fixed = s
            fixed.goalTargetValue = max(0, fixed.goalTargetValue)
            return fixed
        }

        // Üye listesi: geçersiz departman indekslerini kırp; var olmayan projeye
        // atanmış üyelerin atamasını temizle; sonra headcount ile senkronla.
        let validProjectIDs = Set(projects.map { $0.id })
        members = members.compactMap { m in
            guard m.deptIndex >= 0 && m.deptIndex < headcount.count else { return nil }
            var fixed = m
            fixed.skillLevel = min(5, max(1, fixed.skillLevel))
            if let pid = fixed.assignedProjectID, !validProjectIDs.contains(pid) {
                fixed.assignedProjectID = nil
            }
            return fixed
        }
        syncMembersToHeadcount()
    }

    /// `headcount` ile `members` arasını eşle: eksik departmanlara generic isimli üye ekle,
    /// fazlalıkları (kurucu hariç en son hire'lardan başlayarak) kaldır. Kurucu üye DAİMA
    /// korunur (oyuncu kimliği). Yeni alan: skill 1 (eski kayıt güvenli — oyun deneyimi bozulmaz).
    mutating func syncMembersToHeadcount() {
        for deptIdx in 0..<headcount.count {
            let currentCount = members.reduce(0) { $0 + ($1.deptIndex == deptIdx ? 1 : 0) }
            let target = headcount[deptIdx]
            if currentCount < target {
                // Eksik: generic isimli üye(ler) ekle.
                for _ in 0..<(target - currentCount) {
                    let n = NarrativeContent.randomFounderName()
                    members.append(TeamMember(firstName: n.first, lastName: n.last,
                                              deptIndex: deptIdx, skillLevel: 1,
                                              joinedMonth: months))
                }
            } else if currentCount > target {
                // Fazla: kurucuyu KORUYARAK en son eklenenden başla.
                var toRemove = currentCount - target
                for i in (0..<members.count).reversed() where toRemove > 0 {
                    if members[i].deptIndex == deptIdx && !members[i].isFounder {
                        members.remove(at: i)
                        toRemove -= 1
                    }
                }
            }
        }
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
