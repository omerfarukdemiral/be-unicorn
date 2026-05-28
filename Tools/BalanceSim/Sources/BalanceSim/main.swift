// SOURCE OF TRUTH:
//   - Sabitler: Sources/Model/Balance.swift
//   - Formüller: Sources/Model/GameModel.swift
//   - Durum:     Sources/Model/GameState.swift
//
// Unicorn — "Garajdan Zirveye" startup idle ekonomi simülatörü.
//
// Bu CLI, GameModel'in idle ekonomi formüllerini BİREBİR kopyalar ve "akıllı
// oyuncu" politikasıyla zaman-bazlı (0.1 sn tick, gerçek tick periyoduyla aynı)
// simüle eder. Karar kartları (DecisionSystem) deterministik olmadığı ve
// çekirdek eğriye varyans kattığı için sim'e DAHİL DEĞİLDİR — temel ekonomi
// eğrisini ölçüyoruz. Moral/itibar dinamiği ise dahildir (üretimi etkiler).
//
// YENİ MODEL (bu sürümle):
//   - Kalemlere ayrılmış OpEx: burn = maaş + opex(kalemli) + reklam.
//   - Pazarlama bütçesi + CAC: büyüme = organik + ücretli(adBudget/CAC).
//     CAC harcama ölçeğiyle artar (doygunluk), pazarlama ekibi/itibar/ürün düşürür.
//   - 8 modül (id 0-7): infraCostReduce (bulut) + rentCostReduce (kira) eklendi.
//
// Akıllı oyuncu politikası:
//   - Her tick, parası yettikçe en iyi "geri-ödeme süreli" aksiyonu alır:
//     işe alım (departman) veya modül yükseltmesi. İşe alımın marjinal NET'i
//     hem maaşı HEM kalemli OpEx artışını (kira+lisans+ekipman+genel) içerir.
//   - Reklam bütçesi kararı: LTV:CAC sağlıklıysa (>~3) ve runway yeterliyse bütçe
//     kademeli artar; kötüyse (oran<2 veya runway tehlikede) kısılır/sıfırlanır.
//   - Runway < minRunway ay ise işe alım/harcama DURUR (nakit korunur).
//   - Değerleme bir sonraki tur hedefini aştığında tur HEMEN toplanır.
//
// Tüm sayılar gerçek `swift run` çıktısındandır.

import Foundation

// =====================================================================
// MARK: - Balance sabitleri (Sources/Model/Balance.swift birebir kopyası)
// =====================================================================

struct DepartmentDef {
    let id: Int
    let name: String
    let role: DeptRole
    let baseHireCost: Double
    let baseSalary: Double
    let baseOutput: Double
}

enum DeptRole { case engineering, product, marketing, sales, ops }

struct ModuleDef {
    let id: Int
    let name: String
    let baseCost: Double
    let costGrowth: Double
    let maxLevel: Int
    let effect: ModuleEffect
    let unlockStage: Int
}

enum ModuleEffect {
    case globalOutput(Double)
    case growthMult(Double)
    case arpuMult(Double)
    case churnReduce(Double)
    case moraleTarget(Double)
    case salaryReduce(Double)
    case infraCostReduce(Double)
    case rentCostReduce(Double)
}

enum CostDriver { case perSeat, perThousandUsers, perStage, flat }

struct CostItemDef {
    let id: Int
    let name: String
    let icon: String
    let driver: CostDriver
    let rate: Double
    let stageScaling: Double
}

struct StageDef {
    let id: Int
    let name: String
    let valuationTarget: Double
    let raiseAmount: Double
    let equityGiven: Double
}

enum Balance {
    static let secondsPerMonth: Double = 60
    static let startCash: Double = 40_000

    static let baseArpu: Double = 3.8
    static let baseChurn: Double = 0.05
    static let viralFactor: Double = 0.045

    static let startMorale: Double = 72
    static let baseMoraleTarget: Double = 60
    static let moraleAdjustRate: Double = 0.08
    static let quitMoraleThreshold: Double = 28
    static let unpaidMoralePenalty: Double = 40

    // MARK: Retention döngü ödülleri (Sources/Model/Balance.swift birebir)
    // Bu kalıcı/yarı-kalıcı bonuslar ekonomiye 3 kanaldan akar:
    //   moral → moraleFactor → üretim ; itibar → büyüme/CAC ; sezon çarpanı → doğrudan üretim.
    static let monthsPerQuarter: Double = 3
    static let promoteMoraleBonus: Double = 8
    static let promoteReputationBonus: Double = 5
    static let quartersPerSeason: Int = 4
    static let seasonOutputBonusPerSeason: Double = 0.02   // +%2 / sezon
    static let seasonOutputBonusCap: Double = 0.15         // toplam +%15 tavan
    static let seasonFinaleMoraleBonus: Double = 10
    static let seasonFinaleReputationBonus: Double = 8
    static let monthsPerSprint: Double = 0.5
    static let sprintWinMoraleBonus: Double = 4
    static let sprintWinReputationBonus: Double = 2
    static let dailyCompleteMoraleBonus: Double = 5
    static let dailyCompleteReputationBonus: Double = 2
    static let streakMoralePerDay: Double = 0.5
    static let streakMoraleCap: Double = 4

    static let revenueMultiple: Double = 7.0
    static let perUserValue: Double = 6.0
    static let unicornValuation: Double = 1_000_000_000

    static let hireCostGrowth = 1.12

    static let offlineCapSeconds: Double = 8 * 3600
    static let offlineEfficiency: Double = 0.5

    static let decisionMinInterval: Double = 22
    static let decisionMaxInterval: Double = 40

    static let departments: [DepartmentDef] = [
        .init(id: 0, name: "Mühendislik",     role: .engineering, baseHireCost: 1_500, baseSalary: 900,   baseOutput: 1.0),
        .init(id: 1, name: "Ürün & Tasarım",  role: .product,     baseHireCost: 2_400, baseSalary: 1_000, baseOutput: 0.9),
        .init(id: 2, name: "Pazarlama",       role: .marketing,   baseHireCost: 3_200, baseSalary: 950,   baseOutput: 4.0),
        .init(id: 3, name: "Satış",           role: .sales,       baseHireCost: 5_000, baseSalary: 1_100, baseOutput: 0.8),
        .init(id: 4, name: "Operasyon",       role: .ops,         baseHireCost: 7_500, baseSalary: 1_050, baseOutput: 1.0),
    ]
    static var departmentCount: Int { departments.count }

    static let modules: [ModuleDef] = [
        .init(id: 0, name: "CI/CD Hattı",          baseCost: 8_000,  costGrowth: 4.0, maxLevel: 5, effect: .globalOutput(0.10),   unlockStage: 0),
        .init(id: 1, name: "Growth Hack",          baseCost: 12_000, costGrowth: 4.5, maxLevel: 5, effect: .growthMult(0.15),     unlockStage: 1),
        .init(id: 2, name: "Premium Paket",        baseCost: 18_000, costGrowth: 5.0, maxLevel: 5, effect: .arpuMult(0.18),       unlockStage: 1),
        .init(id: 3, name: "Müşteri Başarısı",     baseCost: 15_000, costGrowth: 4.5, maxLevel: 5, effect: .churnReduce(0.12),    unlockStage: 2),
        .init(id: 4, name: "Şirket Kültürü",       baseCost: 10_000, costGrowth: 3.5, maxLevel: 5, effect: .moraleTarget(6.0),    unlockStage: 0),
        .init(id: 5, name: "Uzaktan Çalışma",      baseCost: 22_000, costGrowth: 5.0, maxLevel: 4, effect: .salaryReduce(0.06),   unlockStage: 2),
        .init(id: 6, name: "Sunucu Optimizasyonu", baseCost: 14_000, costGrowth: 4.2, maxLevel: 5, effect: .infraCostReduce(0.15), unlockStage: 1),
        .init(id: 7, name: "Hibrit Ofis",          baseCost: 20_000, costGrowth: 4.5, maxLevel: 4, effect: .rentCostReduce(0.12),  unlockStage: 2),
    ]

    static let stages: [StageDef] = [
        .init(id: 0, name: "Garaj",     valuationTarget: 0,             raiseAmount: 0,          equityGiven: 0),
        .init(id: 1, name: "Pre-seed",  valuationTarget: 500_000,       raiseAmount: 150_000,    equityGiven: 0.10),
        .init(id: 2, name: "Seed",      valuationTarget: 3_000_000,     raiseAmount: 800_000,    equityGiven: 0.15),
        .init(id: 3, name: "Series A",  valuationTarget: 15_000_000,    raiseAmount: 4_000_000,  equityGiven: 0.18),
        .init(id: 4, name: "Series B",  valuationTarget: 75_000_000,    raiseAmount: 20_000_000, equityGiven: 0.15),
        .init(id: 5, name: "Series C",  valuationTarget: 300_000_000,   raiseAmount: 150_000_000, equityGiven: 0.12),
        .init(id: 6, name: "Unicorn",   valuationTarget: 1_000_000_000, raiseAmount: 0,          equityGiven: 0),
    ]
    static var stageCount: Int { stages.count }

    static func salaryMultiplier(forStage stage: Int) -> Double {
        pow(1.6, Double(stage))
    }

    // MARK: Operasyonel gider kalemleri (maaşlar HARİÇ)
    static let costItems: [CostItemDef] = [
        .init(id: 0, name: "Ofis Kirası",              icon: "🏢", driver: .perSeat,          rate: 140, stageScaling: 1.40),
        .init(id: 1, name: "SaaS & Yazılım Lisansları", icon: "🧾", driver: .perSeat,          rate: 50,  stageScaling: 1.12),
        .init(id: 2, name: "Bulut & Sunucu",            icon: "☁️", driver: .perThousandUsers, rate: 10,  stageScaling: 1.05),
        .init(id: 3, name: "Yasal & Muhasebe",          icon: "⚖️", driver: .perStage,         rate: 500, stageScaling: 1.0),
        .init(id: 4, name: "Ekipman & Donanım",         icon: "🖥️", driver: .perSeat,          rate: 32,  stageScaling: 1.18),
        .init(id: 5, name: "Genel & İdari",             icon: "🍽️", driver: .perSeat,          rate: 22,  stageScaling: 1.25),
    ]
    static var costItemCount: Int { costItems.count }

    static func itemMonthlyCost(_ item: CostItemDef, stage: Int, headcount: Int, users: Double) -> Double {
        let stageMult = pow(item.stageScaling, Double(stage))
        let rate = item.rate
        switch item.driver {
        case .perSeat:          return rate * Double(headcount) * stageMult
        case .perThousandUsers: return rate * (users / 1000) * stageMult
        case .perStage:         return rate * Double(stage + 1) * stageMult
        case .flat:             return rate * stageMult
        }
    }

    // MARK: Pazarlama / kullanıcı edinme
    static let baseCAC: Double = 7.0
    static let cacStageScaling: Double = 1.25
    static let marketingAbsorption: Double = 5_000
    static let adBudgetStepBase: Double = 500
}

// =====================================================================
// MARK: - Retention döngü ödülleri modeli (yeni — madde 6)
// =====================================================================
//
// "Tamamlanan döngü" ödülleri ekonomiye ÜÇ kanaldan akar:
//   1) MORAL  → moraleFactor (0.5 + morale/100) → tüm departman çıktısı.
//      Kaynaklar: terfi (+8), sprint zaferi (+4), günlük tamamlama (+5),
//      sezon finali (+10) — anlık moral atışları + streak'in moralTarget'a
//      kalıcı katkısı (gün başına +0.8, tavan +8).
//   2) İTİBAR → organik büyüme (0.5+rep/100), viral (rep/50), qualityFactor
//      (CAC↓). Kaynaklar: terfi (+5), sprint (+2), günlük (+2), sezon (+8).
//   3) SEZON ÇARPANI → deptOutput'a doğrudan çarpan (+%2/sezon, +%20 tavan).
//
// Sim deterministik (karar kartları hariç) ve sprint/günlük/çeyrek olaylarını
// ZAMAN-tabanlı tetikleyebildiği için bu ödülleri GERÇEKÇİ bir "tipik aktif
// retention oyuncusu" temposuyla modelliyoruz:
//   - Sprint her monthsPerSprint'te kapanır; aktif oyuncu çoğunu kazanır (≈%70).
//   - Çeyrek her monthsPerQuarter'da kapanır; oyuncu ortalama orta sıralarda →
//     bazı çeyreklerde terfi (kohort ilk-3). Burada ihtiyatlı: ~her 2 çeyrekte 1 terfi.
//   - Sezon her quartersPerSeason çeyrekte kapanır → kalıcı çarpan +%2 (tavana dek).
//   - Günlük hedef gerçek-takvim gününe bağlı; sim oyun-zamanı koştuğu için günlük
//     tamamlama akışını streak'in moralTarget katkısı + periyodik moral dokunuşu
//     ile yaklaşık modelliyoruz (aktif oyuncu varsayımı: streak tavanda).
// Anahtar RETENTION_REWARDS ile açılıp kapatılır (etki ölçümü için).

var RETENTION_REWARDS_ENABLED: Bool = true

/// Aktif retention oyuncusu davranış varsayımları (sim için kalibrasyon).
enum RetentionAssumptions {
    /// Aktif oyuncu sprintlerin bu oranını kazanır (anlık moral/itibar dokunuşu).
    static let sprintWinRate: Double = 0.70
    /// Oyuncu ortalama kaç çeyrekte 1 terfi alır (kohort ilk-3 sıralaması).
    static let quartersPerPromotion: Double = 2.0
    /// Streak'in (aktif oyuncu) moralTarget katkısı tavanda kabul edilir.
    static let streakMoraleSteadyState: Double = Balance.streakMoraleCap
    /// Oyuncu kesintisiz online değil: anlık moral/itibar dokunuşlarının ortalama
    /// ekonomik etkisi (sürekli online üst-sınır 1.0 yerine gerçekçi ~0.35).
    static let onlineFactor: Double = 0.35
}

// =====================================================================
// MARK: - Sim durumu + GameModel formülleri (birebir)
// =====================================================================

final class Sim {
    var cash = Balance.startCash
    var lifetimeRevenue: Double = 0
    var users: Double = 0
    var reputation: Double = 20
    var morale: Double = Balance.startMorale
    var founderEquity: Double = 1.0

    var adBudgetPerMonth: Double = 0     // oyuncunun ayarladığı aylık reklam bütçesi

    var headcount: [Int]
    var moduleLevels: [Int]

    var stage = 0
    var months: Double = 0
    var founderXP: Double = 0
    var totalHires = 0

    // Retention döngü durumu (madde 6) — kalıcı/yarı-kalıcı ödülleri taşır.
    var seasonsCompleted: Int = 0     // kalıcı sezon çarpanı için
    var reputationFloor: Double = 20  // itibar tabanı; itibar ödülleri tabanı yukarı çeker

    init() {
        headcount = Array(repeating: 0, count: Balance.departmentCount)
        headcount[0] = 1
        moduleLevels = Array(repeating: 0, count: Balance.modules.count)
    }

    /// Kalıcı sezon ödülü çarpanı (1 + birikmiş, tavanlı) — GameModel.seasonMultiplier birebir.
    var seasonMultiplier: Double {
        guard RETENTION_REWARDS_ENABLED else { return 1 }
        let raw = Double(seasonsCompleted) * Balance.seasonOutputBonusPerSeason
        return 1 + min(Balance.seasonOutputBonusCap, raw)
    }

    /// Streak'in (aktif oyuncu) moralTarget'a kalıcı katkısı — yaklaşık tavanda.
    var streakMoraleBonus: Double {
        RETENTION_REWARDS_ENABLED ? RetentionAssumptions.streakMoraleSteadyState : 0
    }

    // MARK: Modül türetilmiş efektleri (GameModel.effects birebir)
    struct Effects {
        var globalOutput = 0.0, growthMult = 0.0, arpuMult = 0.0
        var churnReduce = 0.0, moraleTarget = 0.0, salaryReduce = 0.0
        var infraCostReduce = 0.0, rentCostReduce = 0.0
    }

    var effects: Effects {
        var e = Effects()
        for m in Balance.modules {
            let lvl = Double(moduleLevels[m.id])
            guard lvl > 0 else { continue }
            switch m.effect {
            case .globalOutput(let v):    e.globalOutput += v * lvl
            case .growthMult(let v):      e.growthMult += v * lvl
            case .arpuMult(let v):        e.arpuMult += v * lvl
            case .churnReduce(let v):     e.churnReduce += v * lvl
            case .moraleTarget(let v):    e.moraleTarget += v * lvl
            case .salaryReduce(let v):    e.salaryReduce += v * lvl
            case .infraCostReduce(let v): e.infraCostReduce += v * lvl
            case .rentCostReduce(let v):  e.rentCostReduce += v * lvl
            }
        }
        return e
    }

    var founderBonus: Double { 1 + min(2.0, founderXP * 0.05) }
    var moraleFactor: Double { 0.5 + morale / 100 }

    func deptOutput(_ i: Int) -> Double {
        let d = Balance.departments[i]
        return Double(headcount[i]) * d.baseOutput
            * (1 + effects.globalOutput) * moraleFactor * founderBonus * seasonMultiplier
    }

    var devPower: Double { deptOutput(0) + 0.5 * deptOutput(1) }
    var marketingPower: Double { deptOutput(2) }
    var salesPower: Double { deptOutput(3) }
    var opsPower: Double { deptOutput(4) + 0.5 * deptOutput(1) }

    var userCapacity: Double { max(50, devPower * 1_500) }
    var overload: Double { max(0, users / userCapacity - 1) }

    var churnRate: Double {
        Balance.baseChurn * max(0.2, 1 - effects.churnReduce - opsPower * 0.01) * (1 + overload)
    }

    var arpu: Double {
        Balance.baseArpu * (1 + effects.arpuMult) * (1 + salesPower * 0.05)
    }

    var mrr: Double { users * arpu }

    var totalHeadcount: Int { headcount.reduce(0, +) }

    // MARK: Büyüme — organik + ücretli (gerçek-hayat SaaS edinim modeli)

    var qualityFactor: Double {
        min(2.0, 0.5 + reputation / 100 + min(1.0, devPower / max(1, users / 800)) * 0.4)
    }

    var organicUserGrowthPerMonth: Double {
        marketingPower * 30 * (1 + effects.growthMult) * (0.5 + reputation / 100)
            + users * Balance.viralFactor * (reputation / 50)
    }

    var currentCAC: Double {
        let stageMult = pow(Balance.cacStageScaling, Double(stage))
        let absorb = Balance.marketingAbsorption * (1 + marketingPower * 0.4)
        let saturation = 1 + adBudgetPerMonth / max(1, absorb)
        return Balance.baseCAC * stageMult * saturation / qualityFactor
    }

    var paidUserGrowthPerMonth: Double {
        guard adBudgetPerMonth > 0, currentCAC > 0 else { return 0 }
        return adBudgetPerMonth / currentCAC
    }

    var grossUserGrowthPerMonth: Double { organicUserGrowthPerMonth + paidUserGrowthPerMonth }
    var netUserGrowthPerMonth: Double { grossUserGrowthPerMonth - users * churnRate }

    var ltv: Double { churnRate > 0 ? arpu / churnRate : arpu * 100 }
    var ltvCacRatio: Double { currentCAC > 0 ? ltv / currentCAC : 0 }
    var paybackMonths: Double { arpu > 0 ? currentCAC / arpu : .infinity }

    // MARK: Giderler — maaş + kalemlere ayrılmış OpEx + reklam

    func salary(_ i: Int) -> Double {
        Balance.departments[i].baseSalary
            * Balance.salaryMultiplier(forStage: stage)
            * max(0.4, 1 - effects.salaryReduce)
    }

    var payrollPerMonth: Double {
        (0..<Balance.departmentCount).reduce(0) { $0 + Double(headcount[$1]) * salary($1) }
    }

    func opexItemCost(_ i: Int) -> Double {
        let item = Balance.costItems[i]
        var c = Balance.itemMonthlyCost(item, stage: stage, headcount: totalHeadcount, users: users)
        switch item.driver {
        case .perThousandUsers: c *= max(0.2, 1 - effects.infraCostReduce)
        case .perSeat where item.id == 0: c *= max(0.3, 1 - effects.rentCostReduce)
        default: break
        }
        return c
    }

    var opexPerMonth: Double {
        (0..<Balance.costItemCount).reduce(0) { $0 + opexItemCost($1) }
    }

    var adSpendPerMonth: Double { adBudgetPerMonth }
    var burnPerMonth: Double { payrollPerMonth + opexPerMonth + adSpendPerMonth }
    var revenuePerMonth: Double { mrr }
    var netPerMonth: Double { revenuePerMonth - burnPerMonth }

    var runwayMonths: Double {
        netPerMonth >= -0.0001 ? .infinity : cash / -netPerMonth
    }

    var valuation: Double {
        mrr * 12 * Balance.revenueMultiple
            + users * Balance.perUserValue
            + devPower * 15_000
            + reputation * 2_000
            + max(0, cash) * 0.5
    }

    var adBudgetStep: Double {
        Balance.adBudgetStepBase * Balance.salaryMultiplier(forStage: stage)
    }

    // MARK: İşe alım
    func hireCost(_ i: Int) -> Double {
        Balance.departments[i].baseHireCost
            * pow(Balance.hireCostGrowth, Double(headcount[i]))
            * Balance.salaryMultiplier(forStage: stage)
    }

    @discardableResult
    func hire(_ i: Int) -> Bool {
        let c = hireCost(i)
        guard cash >= c else { return false }
        cash -= c
        headcount[i] += 1
        totalHires += 1
        morale = min(100, morale + 1.5)
        return true
    }

    // MARK: Modüller
    func isModuleMaxed(_ i: Int) -> Bool { moduleLevels[i] >= Balance.modules[i].maxLevel }
    func isModuleUnlocked(_ i: Int) -> Bool { stage >= Balance.modules[i].unlockStage }
    func moduleCost(_ i: Int) -> Double {
        let m = Balance.modules[i]
        return m.baseCost * pow(m.costGrowth, Double(moduleLevels[i]))
    }
    func canBuyModule(_ i: Int) -> Bool {
        isModuleUnlocked(i) && !isModuleMaxed(i) && cash >= moduleCost(i)
    }
    @discardableResult
    func buyModule(_ i: Int) -> Bool {
        guard canBuyModule(i) else { return false }
        cash -= moduleCost(i)
        moduleLevels[i] += 1
        return true
    }

    // MARK: Funding
    var nextStage: StageDef? {
        stage + 1 < Balance.stageCount ? Balance.stages[stage + 1] : nil
    }
    var canRaise: Bool {
        guard let next = nextStage else { return false }
        return valuation >= next.valuationTarget
    }
    @discardableResult
    func raiseRound() -> Bool {
        guard canRaise, let next = nextStage else { return false }
        cash += next.raiseAmount
        founderEquity *= (1 - next.equityGiven)
        stage += 1
        morale = min(100, morale + 10)
        reputation = min(100, reputation + 15)
        return true
    }

    // MARK: Moral
    var moraleTarget: Double {
        var t = Balance.baseMoraleTarget + effects.moraleTarget
        t += streakMoraleBonus   // retention: streak'in moralTarget'a kalıcı katkısı (tavanlı)
        if cash < 0 { t -= Balance.unpaidMoralePenalty }
        t -= overload * 15
        return min(100, max(0, t))
    }
    func updateMorale(_ dt: Double) {
        let target = moraleTarget
        morale += (target - morale) * Balance.moraleAdjustRate * dt
        morale = min(100, max(0, morale))
    }

    // MARK: Ekonomi ilerlet (GameModel.advanceEconomy birebir)
    func advanceEconomy(_ monthFraction: Double) {
        let revenue = revenuePerMonth * monthFraction
        let burn = burnPerMonth * monthFraction
        cash += revenue - burn
        lifetimeRevenue += max(0, revenue)

        let dUsers = netUserGrowthPerMonth * monthFraction
        users = max(0, users + dUsers)

        // İtibar yumuşakça tabana döner. Retention ödülleri (terfi/sprint/günlük/sezon)
        // anlık itibar atışı yapar VE tabanı (reputationFloor) yukarı çeker → kalıcı etki.
        reputation += (reputationFloor - reputation) * 0.002
        reputation = min(100, max(0, reputation))
    }
}

// =====================================================================
// MARK: - Akıllı oyuncu politikası
// =====================================================================
//
// Bir aksiyonun "geri-ödeme süresi" = maliyet / (aksiyonun aylık net nakit
// akışına marjinal katkısı). Net akış = MRR - burn (burn = maaş + kalemli OpEx
// + reklam). İşe alım hem geliri artırır hem de maaş YANINDA kalemli OpEx
// (kira+lisans+ekipman+genel) yükü getirir; modüller geliri/verimi artırır ya da
// gider kalemlerini düşürür (genelde tek seferlik maliyet). En kısa geri-ödeme
// süreli aksiyon en iyi yatırım kabul edilir.

struct PlayerAction {
    let kind: Kind
    let index: Int
    let cost: Double
    let deltaNetPerMonth: Double   // marjinal aylık net nakit katkısı
    enum Kind { case hire, module }
    var payback: Double { deltaNetPerMonth > 0 ? cost / deltaNetPerMonth : .infinity }
}

extension Sim {
    /// Bir departmana 1 kişi eklemenin marjinal aylık net etkisi.
    /// netPerMonth = mrr - (payroll + opex + reklam) olduğu için işe alımın
    /// maaş + kalemli OpEx (kira/lisans/ekipman/genel) artışı otomatik dahil olur.
    func marginalNetHire(_ i: Int) -> Double {
        let before = netPerMonth
        headcount[i] += 1
        let after = netPerMonth
        headcount[i] -= 1
        return after - before
    }
    /// Bir modül seviyesinin marjinal aylık net etkisi (tek seferlik maliyet).
    func marginalNetModule(_ i: Int) -> Double {
        let before = netPerMonth
        moduleLevels[i] += 1
        let after = netPerMonth
        moduleLevels[i] -= 1
        return after - before
    }

    func bestActions() -> [PlayerAction] {
        var acts: [PlayerAction] = []
        for i in 0..<Balance.departmentCount {
            acts.append(PlayerAction(kind: .hire, index: i, cost: hireCost(i),
                                     deltaNetPerMonth: marginalNetHire(i)))
        }
        for i in 0..<Balance.modules.count where canBuyModule(i) {
            acts.append(PlayerAction(kind: .module, index: i, cost: moduleCost(i),
                                     deltaNetPerMonth: marginalNetModule(i)))
        }
        return acts
    }
}

// Runway emniyet eşiği (ay). Bunun altında oyuncu harcamayı durdurur.
// Global mutable: "naive" oyuncu testinde 0'a çekilir (tampon yok = iflas riski).
var MIN_RUNWAY: Double = 2.0
// Aksiyonun para harcandıktan SONRA bırakacağı min runway (nakit tamponu).
func runwayAfter(spending cost: Double, _ s: Sim) -> Double {
    let net = s.netPerMonth
    if net >= -0.0001 { return .infinity }
    return (s.cash - cost) / -net
}

// Reklam bütçesi politikası anahtarı: kapalıysa oyuncu hiç reklam harcamaz
// (bütçesiz oyuncu karşılaştırması için).
var AD_BUDGET_ENABLED: Bool = true
// Sağlıklı birim ekonomi eşiği: bu oranın üstünde reklam gaza basılır.
var AD_HEALTHY_LTV_CAC: Double = 3.0
// Reklam bütçesini artırmak için gereken min runway (ay) — disiplinli kaldıraç.
var AD_MIN_RUNWAY: Double = 4.0

// =====================================================================
// MARK: - Oyuncu arketipleri (madde C: 4 strateji politikası)
// =====================================================================
//
// Aynı çekirdek ekonomi (Sim) üzerinde, farklı oyuncu stratejilerini koşturmak
// için politika parametre setleri. Tasarım Prensibi: "her arketip Unicorn'a
// varabilmeli, hiçbiri diğerine kesin baskın olmamalı".
//
//   1) BOOTSTRAP-FRUGAL — yatırım turu REDDET (raise=false), düşük headcount,
//      yüksek itibar+organik büyüme, reklam yok/minimal. Yavaş ama bağımsız.
//   2) VC-ROKET — her tur kapanır kapanmaz topla, agresif hire + reklam,
//      runway koştur. Hızlı ama kırılgan.
//   3) NİŞ UZMAN — az çalışan (mühendislik + ürün + ops odaklı), churn↓,
//      ARPU↑ (Premium modülü erken), reklam orta, organik+itibar.
//   4) PLATFORM GENİŞ — çok çalışan dağıtık (engineering+marketing yüksek),
//      kullanıcı patlat, ARPU düşük, modüller geniş.
//
// Politika parametreleri:

enum Archetype: String, CaseIterable {
    case bootstrap = "Bootstrap-Frugal"
    case vcRocket  = "VC-Roket"
    case niche     = "Niş Uzman"
    case platform  = "Platform Geniş"
}

struct Policy {
    /// Kalan nakitin burn'ün kaç katı altına inmesine izin verilmez (harcama tamponu).
    var minRunway: Double
    /// Bootstrap'ta nakit tampon çarpanı (burn × buffer).
    var bootstrapBufferMult: Double
    /// Reklam bütçesini AÇIK tut.
    var adEnabled: Bool
    /// Reklam için minimum sağlıklı LTV:CAC eşiği.
    var adHealthyLtvCac: Double
    /// Reklam yeniden-yatırım oran tabanı (kârın bu kadarı reklama; 0..1).
    var adReinvestBase: Double
    /// Reklam yeniden-yatırım tavanı (0..1).
    var adReinvestCap: Double
    /// Reklam erken aşamada açılsın mı (stage>=1 yerine stage>=N).
    var adMinStage: Int
    /// Funding turu kapanır kapanmaz al (false = reddet, sadece organik nakitle ilerle).
    var raiseRounds: Bool
    /// Sadece BU evreye kadar tur al (geri kalanını reddet). nil = sınırsız.
    var maxStageToRaise: Int?
    /// Departman önceliği (bootstrap mod ve afford'da bu sırayla tercih).
    /// İlk eleman en yüksek öncelik. Pazarlamaya yetişen-dev mantığı yine devrede.
    var hirePriorityOrder: [Int]
    /// Departman başına headcount tavanı (bütçeleme/yapısal sınır). nil = sınırsız.
    var headcountCap: [Int?]
    /// Modül satın alma önceliği (geçen sırayla).
    var moduleBuyOrder: [Int]
    /// Modül erken erişim kilidi bypass etmez; ama hangileri öncelikle alınır.
    /// Modül başına satın alma tavanı (default: doğal max). nil = doğal.
    var moduleLevelCap: [Int?]
    /// Bootstrap-frugal modunda payback yerine "organik büyüme + itibar" stratejisi tercih edilsin.
    var preferOrganic: Bool
    /// Niş Uzman: ARPU/churn modüllerini ÖNCE yığ.
    var nicheFocus: Bool
    /// Platform Geniş: çalışan sayısını ÇOK tut (rakam üst sınır gevşek + dağıtık hire).
    var platformBreadth: Bool

    static let defaultPolicy = Policy(
        minRunway: 2.0,
        bootstrapBufferMult: 1.5,
        adEnabled: true,
        adHealthyLtvCac: 3.0,
        adReinvestBase: 0.40,
        adReinvestCap: 0.85,
        adMinStage: 1,
        raiseRounds: true,
        maxStageToRaise: nil,
        hirePriorityOrder: [2, 0, 3, 1, 4],
        headcountCap: Array(repeating: nil, count: Balance.departmentCount),
        moduleBuyOrder: [1, 2, 0, 6, 7, 3, 4, 5],
        moduleLevelCap: Array(repeating: nil, count: Balance.modules.count),
        preferOrganic: false,
        nicheFocus: false,
        platformBreadth: false
    )

    static func policy(for arch: Archetype) -> Policy {
        var p = defaultPolicy
        switch arch {
        case .bootstrap:
            // Bağımsız + yavaş. Tur al ama "agresif değil"; reklam minimal; az çalışan.
            // Çekirdek: yüksek itibar + organik büyüme + moral/ARPU modülleri ile
            // birim ekonomiyi kasla. Yavaş ama varır (~%30-50 daha uzun bekleniyor).
            p.minRunway = 2.5
            p.bootstrapBufferMult = 1.8        // sıkı (kasalı oyuncu)
            p.adEnabled = true
            p.adHealthyLtvCac = 4.0            // çok sağlıklı birim ekonomi gerekli
            p.adReinvestBase = 0.20            // hafif kaldıraç (kârı dağıtmaz)
            p.adReinvestCap = 0.40
            p.adMinStage = 2                   // Seed'e kadar reklam YOK (organik+itibar)
            p.raiseRounds = true
            p.maxStageToRaise = nil            // tüm turları al (ama az çalışan + az reklam)
            // Büyüme için pazarlama gerekli ama abartılmasın; modüllerle organik patlat.
            p.hirePriorityOrder = [2, 0, 1, 4, 3]   // pazarlama (büyüme başlasın) sonra dev
            // "Az çalışan" disiplini: mühendislik kapasite için yeterli, pazarlama az
            // (organik+itibara güven), satış+ops orta (ARPU+churn için kritik). Pazarlama
            // SIKI tut → kullanıcı kapasiteyi aşmasın, churn patlamasın.
            p.headcountCap = [42, 22, 12, 22, 24]
            // Modül: moral (üretim), ARPU (premium), churn (ops), verim, sonra büyüme
            p.moduleBuyOrder = [4, 2, 3, 0, 5, 6, 7, 1]
            p.preferOrganic = true
        case .vcRocket:
            // Agresif: her tur kapanır kapanmaz al, reklam erken/yüksek, runway koştur.
            // Buffer 1.3 — agresif ama iflas-uçurumundan biraz uzak. Tur sermayesiyle
            // pazarlama+dev'i çok hızlı şişir; sales/ops geç-oyunda ARPU/churn için.
            p.minRunway = 1.3
            p.bootstrapBufferMult = 1.4
            p.adEnabled = true
            p.adHealthyLtvCac = 2.0          // marjinal birim ekonomide bile gaza bas
            p.adReinvestBase = 0.80
            p.adReinvestCap = 0.95
            p.adMinStage = 1                 // Pre-seed'den itibaren bütçe aç
            p.raiseRounds = true
            p.maxStageToRaise = nil
            p.hirePriorityOrder = [2, 0, 1, 3, 4]   // pazarlama+dev önce, ürün sonra
            p.headcountCap = Array(repeating: nil, count: Balance.departmentCount)
            p.moduleBuyOrder = [1, 2, 0, 3, 6, 7, 4, 5]   // büyüme modülü önce
        case .niche:
            // Az ama derin ekip. Premium fiyatlama (ARPU↑), churn↓, kalite önce.
            // Tur al ama yavaş büyü; pazarlama AZ (premium = az ama derin kullanıcı);
            // satış+ops YÜKSEK (ARPU↑ + churn↓). Az kullanıcıyla yüksek MRR.
            p.minRunway = 2.5
            p.bootstrapBufferMult = 1.6
            p.adEnabled = true
            p.adHealthyLtvCac = 3.5
            p.adReinvestBase = 0.35
            p.adReinvestCap = 0.60
            p.adMinStage = 2             // Seed sonrası reklam aç (ARPU önce kasla)
            p.raiseRounds = true
            p.maxStageToRaise = nil
            // ÖNCE: pazarlama (büyüme başlasın), ürün (kalite), satış (ARPU), ops, dev en son.
            // Satışı önceden alarak ARPU karakteri öne çıkar.
            p.hirePriorityOrder = [2, 1, 3, 4, 0]
            // Pazarlama SIKI (premium = az kullanıcı), satış+ops yüksek (ARPU + churn↓)
            p.headcountCap = [30, 35, 14, 50, 38]
            // Modül: Premium Paket (ARPU) + Müşteri Başarısı (churn) + Kültür (moral)
            p.moduleBuyOrder = [2, 3, 4, 0, 5, 6, 7, 1]
            p.nicheFocus = true
        case .platform:
            // Çok çalışan, geniş büyüme, ARPU düşük ama hacimle telafi. Tüm modüller dolu.
            p.minRunway = 2.0
            p.bootstrapBufferMult = 1.4
            p.adEnabled = true
            p.adHealthyLtvCac = 2.8
            p.adReinvestBase = 0.55
            p.adReinvestCap = 0.80
            p.adMinStage = 1
            p.raiseRounds = true
            p.maxStageToRaise = nil
            // Mühendislik+Pazarlama yüksek; tüm departmanlar dağıtık (sırayla)
            p.hirePriorityOrder = [2, 0, 1, 4, 3]
            p.headcountCap = Array(repeating: nil, count: Balance.departmentCount)
            // Büyüme + verim modülleri önde, ARPU geride (platform = düşük ARPU)
            p.moduleBuyOrder = [1, 0, 6, 7, 4, 3, 2, 5]
            p.platformBreadth = true
        }
        return p
    }
}

/// Aktif politika (mutasyon kolaylığı için global). Her arketip koşusunda set edilir.
var ACTIVE_POLICY: Policy = .defaultPolicy

/// Akıllı oyuncunun reklam bütçesi kararı (kârı büyümeye geri yatırma mantığı).
///
/// Reklam, sürdürülebilir bir KÂR FAZLASINDAN finanse edilir: birim ekonomi
/// sağlıklıyken (LTV:CAC yüksek) oyuncu, reklamsız net kârının bir oranını
/// reklama ayırır ve bu "hedef bütçeye" doğru kademeli yaklaşır. Böylece:
///   - Sağlam birim ekonomide gaza basmak büyümeyi GERÇEKTEN hızlandırır.
///   - Erken/zayıf ekonomide (kâr yok, runway kısa) bütçe 0'a çekilir → aşırı
///     erken harcama cezalandırılır.
@discardableResult
func adBudgetStep(_ s: Sim) -> Bool {
    // Arketip-duyarlı: ACTIVE_POLICY'den bütçe parametrelerini al.
    let pol = ACTIVE_POLICY
    let enabled = AD_BUDGET_ENABLED && pol.adEnabled
    guard enabled else {
        if s.adBudgetPerMonth > 0 { s.adBudgetPerMonth = 0; return true }
        return false
    }
    let step = s.adBudgetStep
    let ratio = s.ltvCacRatio
    // Mevcut reklam HARİÇ "çekirdek" net kâr (reklam fazlasını buradan ölçeriz).
    let coreNet = s.netPerMonth + s.adSpendPerMonth
    let runway = s.runwayMonths

    // KRİTİK: nakit/ runway eridi → reklamı hızla kes.
    if s.cash < s.burnPerMonth * 1.5 || (runway.isFinite && runway < 2.0) {
        if s.adBudgetPerMonth > 0 {
            s.adBudgetPerMonth = max(0, s.adBudgetPerMonth - step * 3)
            return true
        }
        return false
    }
    // KÖTÜ birim ekonomi: edinme zarar/başabaş → kıs.
    if ratio < 2.0 {
        if s.adBudgetPerMonth > 0 {
            s.adBudgetPerMonth = max(0, s.adBudgetPerMonth - step)
            return true
        }
        return false
    }
    // Erken evrede reklam gazlamak ölümcül: arketip'in adMinStage'ine kadar bekle.
    guard s.stage >= pol.adMinStage else {
        if s.adBudgetPerMonth > 0 { s.adBudgetPerMonth = 0; return true }
        return false
    }
    // Hedef bütçe: birim ekonomi sağlıklıysa çekirdek kârın bir oranını reklama ayır.
    // Arketipe göre taban/tavan ve eşik farklı (bootstrap düşük, VC-roket yüksek).
    let healthy = pol.adHealthyLtvCac
    guard coreNet > 0, ratio >= healthy else {
        if s.adBudgetPerMonth == 0 && s.cash > s.burnPerMonth * 4 && ratio >= healthy {
            s.adBudgetPerMonth = step
            return true
        }
        return false
    }
    let reinvestFrac = min(pol.adReinvestCap, pol.adReinvestBase + (ratio - healthy) * 0.05)
    let target = coreNet * reinvestFrac
    let diff = target - s.adBudgetPerMonth
    if diff > step * 0.5 {
        s.adBudgetPerMonth += min(step, diff)
        return true
    } else if diff < -step * 0.5 {
        s.adBudgetPerMonth = max(0, s.adBudgetPerMonth - min(step, -diff))
        return true
    }
    return false
}

/// Tek bir akıllı satın alma adımı. Aldıysa true.
@discardableResult
func smartBuyStep(_ s: Sim) -> Bool {
    let pol = ACTIVE_POLICY
    // Tur toplanabiliyorsa önce onu al — ama arketip izin veriyorsa ve maxStage'i aşmıyorsa.
    if s.canRaise && pol.raiseRounds {
        if let cap = pol.maxStageToRaise, s.stage >= cap {
            // Bu evre tavanından sonra tur reddedilir (Bootstrap-Frugal: kurucu hisseyi koru)
        } else {
            s.raiseRound()
            return true
        }
    }

    // Headcount tavanı + modül seviye tavanı filtreleri.
    let actions = s.bestActions().filter { act in
        switch act.kind {
        case .hire:
            if let cap = pol.headcountCap[act.index], s.headcount[act.index] >= cap { return false }
            return true
        case .module:
            if let cap = pol.moduleLevelCap[act.index], s.moduleLevels[act.index] >= cap { return false }
            return true
        }
    }

    let affordable = actions
        .filter { $0.cost <= s.cash && $0.deltaNetPerMonth > 0 }
        .filter { runwayAfter(spending: $0.cost, s) >= MIN_RUNWAY }
        .sorted { $0.payback < $1.payback }

    if let a = affordable.first {
        switch a.kind {
        case .hire:   return s.hire(a.index)
        case .module: return s.buyModule(a.index)
        }
    }
    // Net-pozitif aksiyon yoksa: bootstrap (büyümeyi başlat).
    return bootstrapStep(s)
}

/// Erken evre bootstrap: henüz MRR yokken net-pozitif aksiyon bulunamaz.
/// Akıllı oyuncu büyümeyi başlatmak için: kapasite (dev) + pazarlamayı dengeler.
/// Kullanıcı kapasitesi doluysa dev al; değilse pazarlama al. Para tamponunu korur.
// Naive oyuncu için nakit tamponu çarpanı 0'a çekilir (acemi = tampon tutmaz).
var BOOTSTRAP_BUFFER_MULT: Double = 1.5

@discardableResult
func bootstrapStep(_ s: Sim) -> Bool {
    let pol = ACTIVE_POLICY
    let buffer = BOOTSTRAP_BUFFER_MULT <= 0 ? 0 : max(2_000, s.burnPerMonth * BOOTSTRAP_BUFFER_MULT)

    // Kapasite/kalite dengesi: dev pazarlamaya yetişmek zorunda (her arketipte).
    let devCount = s.headcount[0]
    let mktCount = s.headcount[2]
    let nearCapacity = s.users >= s.userCapacity * 0.75
    let devStarved = devCount * 2 < mktCount + 1
    let order: [Int]
    if nearCapacity || devStarved {
        // Kapasite/kalite önce: dev, ürün, sonra arketipin önceliği
        var cap: [Int] = [0, 1]
        cap.append(contentsOf: pol.hirePriorityOrder.filter { $0 != 0 && $0 != 1 })
        order = cap
    } else {
        order = pol.hirePriorityOrder
    }
    for i in order {
        if let cap = pol.headcountCap[i], s.headcount[i] >= cap { continue }
        let c = s.hireCost(i)
        if s.cash - c >= buffer { return s.hire(i) }
    }
    // Modüller: arketipin sıralamasıyla al.
    for i in pol.moduleBuyOrder where s.canBuyModule(i) {
        if let cap = pol.moduleLevelCap[i], s.moduleLevels[i] >= cap { continue }
        let c = s.moduleCost(i)
        if s.cash - c >= buffer { return s.buyModule(i) }
    }
    return false
}

// =====================================================================
// MARK: - Simülasyon çekirdeği (gerçek tick periyodu: 0.1 sn)
// =====================================================================

final class Runner {
    let s = Sim()
    var elapsed: Double = 0          // gerçek saniye
    let dt: Double = 0.1
    var stageReachTime = [Int: Double]()   // stage id -> ulaşma zamanı (sn)
    var bankrupt = false
    var bankruptTime: Double = -1
    var debtMonths: Double = 0
    var firstUserTime: Double? = nil
    var firstPositiveNetTime: Double? = nil
    var firstThousandUsersTime: Double? = nil
    var firstAdSpendTime: Double? = nil

    // Retention döngü sayaçları (madde 6) — oyun-zamanına bağlı tetiklenir.
    var nextSprintCloseMonth: Double = Balance.monthsPerSprint
    var nextQuarterCloseMonth: Double = Balance.monthsPerQuarter
    var quartersClosed: Int = 0
    var sprintsClosed: Int = 0
    var promotions: Int = 0
    var seasonsClosed: Int = 0

    /// "Tamamlanan döngü" olaylarını oyun-zamanı ilerledikçe tetikle.
    /// Aktif retention oyuncusu varsayımıyla moral/itibar dokunuşları + kalıcı
    /// sezon çarpanı uygulanır. İtibar dokunuşu tabanı da hafifçe yukarı çeker.
    func advanceRetention() {
        guard RETENTION_REWARDS_ENABLED else { return }

        // Sprint kapanışı: aktif oyuncu sprintWinRate oranında kazanır → anlık dokunuş.
        while s.months >= nextSprintCloseMonth {
            let prevWon = Int(Double(sprintsClosed) * RetentionAssumptions.sprintWinRate)
            sprintsClosed += 1
            nextSprintCloseMonth += Balance.monthsPerSprint
            let nowWon = Int(Double(sprintsClosed) * RetentionAssumptions.sprintWinRate)
            if nowWon > prevWon {
                // Sprint zaferi: ANLIK moral/itibar dokunuşu. Bunlar geçicidir (updateMorale
                // ile moralTarget'a, itibar tabana erir). Gerçek oyuncu kesintisiz online
                // olmadığından dokunuşları ONLINE_FACTOR ile ölçekleriz (üst-sınır olmasın).
                s.morale = min(100, s.morale + Balance.sprintWinMoraleBonus * RetentionAssumptions.onlineFactor)
                s.reputation = min(100, s.reputation + Balance.sprintWinReputationBonus * RetentionAssumptions.onlineFactor)
                s.reputationFloor = min(33, s.reputationFloor + 0.05)   // çok küçük kalıcı itibar tabanı
            }
            // Günlük hedefin KALICI moral etkisi streakMoraleBonus (moralTarget'a, zaten dahil).
            // Anlık günlük moral dokunuşu burada YOK (streak ile çift sayım olur). İtibara minik dokunuş.
            s.reputation = min(100, s.reputation + Balance.dailyCompleteReputationBonus * 0.2 * RetentionAssumptions.onlineFactor)
        }

        // Çeyrek kapanışı: periyodik terfi (kohort ilk-3 sıralaması varsayımı).
        while s.months >= nextQuarterCloseMonth {
            quartersClosed += 1
            nextQuarterCloseMonth += Balance.monthsPerQuarter
            // Ortalama her quartersPerPromotion çeyrekte 1 terfi.
            let promoDue = Int(Double(quartersClosed) / RetentionAssumptions.quartersPerPromotion)
            if promoDue > promotions {
                promotions = promoDue
                s.morale = min(100, s.morale + Balance.promoteMoraleBonus * RetentionAssumptions.onlineFactor)
                s.reputation = min(100, s.reputation + Balance.promoteReputationBonus * RetentionAssumptions.onlineFactor)
                s.reputationFloor = min(36, s.reputationFloor + 0.4)   // terfi tabanı küçük çeker
            }
            // Sezon kapanışı: quartersPerSeason çeyrekte bir → KALICI çarpan + büyük dokunuş.
            if quartersClosed % Balance.quartersPerSeason == 0 {
                seasonsClosed += 1
                s.seasonsCompleted += 1   // kalıcı sezon çarpanı (+%2, tavan +%20)
                s.morale = min(100, s.morale + Balance.seasonFinaleMoraleBonus * RetentionAssumptions.onlineFactor)
                s.reputation = min(100, s.reputation + Balance.seasonFinaleReputationBonus * RetentionAssumptions.onlineFactor)
                s.reputationFloor = min(38, s.reputationFloor + 0.8)
            }
        }
    }

    // OpEx dağılımı örnekleri (evre başına ilk kez kaydedilen snapshot)
    var opexSnapshotByStage = [Int: (payroll: Double, items: [Double], ad: Double, mrr: Double)]()
    // Ücretli vs organik büyüme toplamı (kümülatif kullanıcı, oyun-ayı ağırlıklı)
    var cumulativePaidUsers: Double = 0
    var cumulativeOrganicUsers: Double = 0
    var cumulativeAdSpend: Double = 0
    var peakLtvCac: Double = 0
    var peakAdBudget: Double = 0

    func record() {
        if stageReachTime[s.stage] == nil { stageReachTime[s.stage] = elapsed }
        if firstUserTime == nil && s.users >= 1 { firstUserTime = elapsed }
        if firstThousandUsersTime == nil && s.users >= 1_000 { firstThousandUsersTime = elapsed }
        if firstPositiveNetTime == nil && s.netPerMonth > 0 && s.users > 10 {
            firstPositiveNetTime = elapsed
        }
        if firstAdSpendTime == nil && s.adBudgetPerMonth > 0 { firstAdSpendTime = elapsed }
        if opexSnapshotByStage[s.stage] == nil {
            let items = (0..<Balance.costItemCount).map { s.opexItemCost($0) }
            opexSnapshotByStage[s.stage] = (s.payrollPerMonth, items, s.adSpendPerMonth, s.mrr)
        }
        peakLtvCac = max(peakLtvCac, s.ltvCacRatio)
        peakAdBudget = max(peakAdBudget, s.adBudgetPerMonth)
    }

    func tick() {
        let monthFraction = dt / Balance.secondsPerMonth

        // Büyüme bileşenlerini kümülatif izle (ekonomi ilerlemeden önce).
        cumulativePaidUsers += s.paidUserGrowthPerMonth * monthFraction
        cumulativeOrganicUsers += s.organicUserGrowthPerMonth * monthFraction
        cumulativeAdSpend += s.adSpendPerMonth * monthFraction

        s.advanceEconomy(monthFraction)
        s.updateMorale(dt)

        if s.cash < 0 { debtMonths += monthFraction } else { debtMonths = 0 }
        if debtMonths > 2 || s.totalHeadcount == 0 {
            bankrupt = true
            bankruptTime = elapsed
        }

        s.months += monthFraction

        // Retention "tamamlanan döngü" ödülleri (madde 6): sprint/çeyrek/sezon
        // kapanışları oyun-zamanına bağlı tetiklenir → moral/itibar/sezon çarpanı.
        advanceRetention()

        // Akıllı oyuncu: önce reklam bütçesi kararı, sonra satın almalar.
        // Tick başına en fazla N aksiyon — gerçek oyuncu 0.1 sn'de düzinelerce
        // satın alma yapmaz ve her aksiyon sonrası ekonominin "tepkimesini" görmek
        // için bir sonraki tick'i bekler. N=2 (raise + 1 hire/modül tek frame'de OK).
        adBudgetStep(s)
        let actionsPerTick = 2
        for _ in 0..<actionsPerTick {
            if !smartBuyStep(s) { break }
        }

        elapsed += dt
        record()
    }

    func run(maxSeconds: Double) {
        stageReachTime[0] = 0
        record()
        while elapsed < maxSeconds && !bankrupt {
            tick()
            if s.stage >= Balance.stageCount - 1 { break }   // Unicorn'a ulaştı
        }
    }
}

// =====================================================================
// MARK: - Formatlama
// =====================================================================

func fmt(_ v: Double) -> String {
    let a = abs(v)
    if a >= 1e12 { return String(format: "%.2fT", v / 1e12) }
    if a >= 1e9  { return String(format: "%.2fB", v / 1e9) }
    if a >= 1e6  { return String(format: "%.2fM", v / 1e6) }
    if a >= 1e3  { return String(format: "%.2fK", v / 1e3) }
    return String(format: "%.1f", v)
}

func dollars(_ v: Double) -> String { "$" + fmt(v) }

func mmss(_ sec: Double) -> String {
    if sec.isInfinite || sec.isNaN || sec < 0 { return "—" }
    let s = Int(sec.rounded())
    let h = s / 3600, m = (s % 3600) / 60, ss = s % 60
    if h > 0 { return String(format: "%ds %02dd %02dsn", h, m, ss) }
    return String(format: "%dd %02dsn", m, ss)
}

func mins(_ sec: Double) -> String { String(format: "%.1f dk", sec / 60) }

func gameMonths(_ sec: Double) -> Double { sec / Balance.secondsPerMonth }

func pad(_ s: String, _ n: Int) -> String { s.padding(toLength: n, withPad: " ", startingAt: 0) }

// =====================================================================
// MARK: - Çalıştır & rapor
// =====================================================================

let runner = Runner()
runner.run(maxSeconds: 6 * 3600)   // 6 gerçek saat üst sınır

let st = runner.s

print("==========================================================")
print(" UNICORN — Garajdan Zirveye | Ekonomi Simülasyonu")
print(" akıllı-oyuncu greedy + reklam bütçesi | 0.1 sn tick | 1 oyun-ayı = \(Int(Balance.secondsPerMonth)) sn")
print(" burn = maaş + kalemli OpEx + reklam | büyüme = organik + ücretli(CAC)")
print(" (karar kartları HARİÇ — temel ekonomi eğrisi)")
print("==========================================================\n")

print("(a) Funding turlarına ulaşma süreleri:")
print("  evre        | gerçek süre        | oyun-ayı | ulaşma val.hedefi")
var prevT: Double = 0
for stg in Balance.stages {
    if let t = runner.stageReachTime[stg.id] {
        let interval = t - prevT
        prevT = t
        let intervalStr = stg.id == 0 ? "—" : "(+\(mmss(interval)))"
        print("  \(pad(stg.name, 11)) | \(pad(mmss(t), 14)) \(pad(mins(t), 9)) | "
            + "\(String(format: "%6.1f", gameMonths(t))) | hedef \(dollars(stg.valuationTarget)) \(intervalStr)")
    } else {
        print("  \(pad(stg.name, 11)) | ULAŞILAMADI (hedef \(dollars(stg.valuationTarget)))")
    }
}

let unicornT = runner.stageReachTime[Balance.stageCount - 1]
print("\n  >> Garaj -> Unicorn toplam: ", terminator: "")
if let t = unicornT {
    print("\(mmss(t)) = \(mins(t)) (\(String(format: "%.0f", gameMonths(t))) oyun-ayı)")
} else if runner.bankrupt {
    print("İFLAS @ \(mmss(runner.bankruptTime)) — Unicorn'a ulaşılamadı")
} else {
    print("6 saatte ULAŞILAMADI")
}

print("\n(b) Tur aralıkları hızlanıyor mu / yavaşlıyor mu?")
var intervals: [(String, Double)] = []
var pv: Double = 0
for stg in Balance.stages where stg.id > 0 {
    if let t = runner.stageReachTime[stg.id] {
        intervals.append((stg.name, t - (runner.stageReachTime[stg.id - 1] ?? pv)))
        pv = t
    }
}
for (name, iv) in intervals {
    print("  -> \(pad(name, 11)): +\(mmss(iv))")
}
if intervals.count >= 2 {
    let trend = intervals.last!.1 > intervals.first!.1 ? "YAVAŞLIYOR (her tur daha uzun)" : "HIZLANIYOR"
    print("  trend: \(trend)")
}

print("\n(c) İflas / runway durumu:")
if runner.bankrupt {
    print("  İFLAS oldu @ \(mmss(runner.bankruptTime)) (evre: \(Balance.stages[st.stage].name))")
} else {
    print("  Akıllı oyuncu iflas ETMEDI (runway tamponu \(Int(MIN_RUNWAY)) ay korundu).")
}
print("  Son durum: nakit \(dollars(st.cash)), runway \(st.runwayMonths.isInfinite ? "∞" : String(format: "%.1f ay", st.runwayMonths)), net/ay \(dollars(st.netPerMonth))")

print("\n(d) İlk 5 dakika hook:")
print("  ilk kullanıcı       : \(runner.firstUserTime.map { mmss($0) } ?? "—")")
print("  ilk 1.000 kullanıcı  : \(runner.firstThousandUsersTime.map { mmss($0) } ?? "—")")
print("  ilk pozitif net/ay   : \(runner.firstPositiveNetTime.map { mmss($0) } ?? "—")")
print("  ilk reklam harcaması : \(runner.firstAdSpendTime.map { mmss($0) } ?? "—")")
print("  ilk tur (Pre-seed)   : \(runner.stageReachTime[1].map { mmss($0) } ?? "—")  <-- HEDEF ~3-5 dk")

print("\n(e) Departman / modül son durum:")
print("  departman başına çalışan + üretim katkısı:")
for i in 0..<Balance.departmentCount {
    let d = Balance.departments[i]
    print("    \(pad(d.name, 16)): \(String(format: "%3d", st.headcount[i])) kişi | rol-çıktı \(String(format: "%.1f", st.deptOutput(i)))")
}
print("  modül seviyeleri:")
for i in 0..<Balance.modules.count {
    let m = Balance.modules[i]
    let lock = st.isModuleUnlocked(i) ? "" : "  (kilitli, stage \(m.unlockStage))"
    print("    \(pad(m.name, 20)): \(st.moduleLevels[i])/\(m.maxLevel)\(lock)")
}

print("\n  ekonomi snapshot (son):")
print("    kullanıcı   : \(fmt(st.users))")
print("    ARPU        : \(dollars(st.arpu))")
print("    MRR         : \(dollars(st.mrr))/ay")
print("    burn        : \(dollars(st.burnPerMonth))/ay")
print("    devPower    : \(String(format: "%.1f", st.devPower)) (kapasite \(fmt(st.userCapacity)))")
print("    churn       : \(String(format: "%.1f%%", st.churnRate * 100))/ay")
print("    LTV         : \(dollars(st.ltv)) | CAC \(dollars(st.currentCAC)) | LTV:CAC \(String(format: "%.1f", st.ltvCacRatio))")
print("    reklam bütç.: \(dollars(st.adBudgetPerMonth))/ay (zirve \(dollars(runner.peakAdBudget)))")
print("    morale      : \(String(format: "%.0f", st.morale)) | itibar \(String(format: "%.0f", st.reputation)) (taban \(String(format: "%.0f", st.reputationFloor)))")
print("    sezon çarpanı: ×\(String(format: "%.2f", st.seasonMultiplier)) (\(st.seasonsCompleted) sezon → +%\(String(format: "%.0f", (st.seasonMultiplier - 1) * 100)) kalıcı üretim)")
print("    döngüler     : \(runner.sprintsClosed) sprint / \(runner.quartersClosed) çeyrek / \(runner.promotions) terfi / \(runner.seasonsClosed) sezon")
print("    valuation   : \(dollars(st.valuation))")
print("    kurucu hisse: \(String(format: "%.1f%%", st.founderEquity * 100))")
print("    toplam işe alım: \(st.totalHires)")

// =====================================================================
// MARK: (f) OpEx dağılımı — evre evre (maaş vs kira vs bulut...)
// =====================================================================
print("\n(f) OpEx dağılımı (burn'deki pay) — her evreye ilk varışta:")
print("  evre        | maaş%  kira%  lisans% bulut%  yasal%  ekipm% genel% | reklam% | toplam burn  | MRR")
for stg in Balance.stages {
    guard let snap = runner.opexSnapshotByStage[stg.id] else { continue }
    let opexSum = snap.items.reduce(0, +)
    let total = snap.payroll + opexSum + snap.ad
    guard total > 0 else { continue }
    func pct(_ v: Double) -> String { String(format: "%5.1f", v / total * 100) }
    let line = "  \(pad(stg.name, 11)) | "
        + "\(pct(snap.payroll))  "
        + snap.items.map { pct($0) }.joined(separator: " ")
        + " | \(pct(snap.ad)) | \(pad(dollars(total) + "/ay", 12)) | \(dollars(snap.mrr))"
    print(line)
}
print("  (kalemler: kira, SaaS-lisans, bulut, yasal, ekipman, genel)")

// Son durumun ayrıntılı OpEx dökümü
print("\n  Son durum gider dökümü (aylık):")
print("    \(pad("Maaşlar", 22)): \(dollars(st.payrollPerMonth))")
for i in 0..<Balance.costItemCount {
    let item = Balance.costItems[i]
    print("    \(pad(item.icon + " " + item.name, 22)): \(dollars(st.opexItemCost(i)))")
}
print("    \(pad("📣 Reklam Harcaması", 22)): \(dollars(st.adSpendPerMonth))")
print("    \(pad("TOPLAM BURN", 22)): \(dollars(st.burnPerMonth))  (MRR \(dollars(st.mrr)), gelirin %\(String(format: "%.0f", st.burnPerMonth / max(1, st.mrr) * 100))'ı)")

// =====================================================================
// MARK: (g) Reklam bütçesi etkisi — bütçeli vs bütçesiz oyuncu
// =====================================================================
// Reklam kaldıracını İZOLE etmek için her iki taraf da retention KAPALI koşulur
// (aksi halde retention hızlanması reklam farkına karışır).
print("\n(g) Reklam bütçesinin büyümeye etkisi (retention KAPALI — saf reklam kaldıracı):")
RETENTION_REWARDS_ENABLED = false
let adRun = Runner()
adRun.run(maxSeconds: 6 * 3600)
let adUni = adRun.stageReachTime[Balance.stageCount - 1]
print("  bütçeli oyuncu:")
print("    Garaj->Unicorn  : \(adUni.map { mmss($0) } ?? "—")")
print("    zirve LTV:CAC   : \(String(format: "%.1f", adRun.peakLtvCac))")
print("    zirve reklam bütç: \(dollars(adRun.peakAdBudget))/ay")
let totalAcq = adRun.cumulativePaidUsers + adRun.cumulativeOrganicUsers
if totalAcq > 0 {
    let paidPct = adRun.cumulativePaidUsers / totalAcq * 100
    print("    edinilen kull.   : ücretli \(fmt(adRun.cumulativePaidUsers)) (%\(String(format: "%.0f", paidPct))), organik \(fmt(adRun.cumulativeOrganicUsers))")
    print("    toplam reklam harc.: \(dollars(adRun.cumulativeAdSpend))")
}

// Bütçesiz koşu (reklam kapalı): organik-only büyüme.
AD_BUDGET_ENABLED = false
let noAd = Runner()
noAd.run(maxSeconds: 6 * 3600)
print("  bütçesiz oyuncu (reklam KAPALI, sadece organik):")
let noAdUni = noAd.stageReachTime[Balance.stageCount - 1]
if let t = noAdUni {
    print("    Garaj->Unicorn  : \(mmss(t)) = \(mins(t))")
} else if noAd.bankrupt {
    print("    Garaj->Unicorn  : İFLAS @ \(mmss(noAd.bankruptTime))")
} else {
    print("    Garaj->Unicorn  : 6 saatte ULAŞILAMADI")
}
if let u = adUni, let n = noAdUni {
    let speedup = (n - u) / n * 100
    print("    >> reklam bütçesi Unicorn'u %\(String(format: "%.0f", speedup)) HIZLANDIRDI (\(mmss(n)) -> \(mmss(u)))")
} else if adUni != nil && noAdUni == nil {
    print("    >> reklam bütçesi belirleyici: bütçeli Unicorn'a ulaştı, bütçesiz ulaşamadı.")
}
AD_BUDGET_ENABLED = true
RETENTION_REWARDS_ENABLED = true

// =====================================================================
// MARK: (g2) Retention döngü ödüllerinin ekonomiye etkisi (madde 6)
// =====================================================================
// Varsayılan koşu (runner) retention ödülleri AÇIK. Burada ödülleri KAPATIP
// "saf çekirdek ekonomi" eğrisini ölçer, farkı raporlarız: moral→üretim,
// itibar→büyüme/CAC, sezon çarpanı→doğrudan üretim kanallarının net etkisi.
print("\n(g2) Retention döngü ödüllerinin ekonomiye net etkisi:")
RETENTION_REWARDS_ENABLED = false
let noRet = Runner()
noRet.run(maxSeconds: 6 * 3600)
RETENTION_REWARDS_ENABLED = true
let noRetUni = noRet.stageReachTime[Balance.stageCount - 1]
print("  ödüllü oyuncu (varsayılan, AÇIK):")
print("    Garaj->Unicorn  : \(unicornT.map { mmss($0) } ?? "—")  (moral \(String(format: "%.0f", st.morale)), itibar \(String(format: "%.0f", st.reputation)), sezon ×\(String(format: "%.2f", st.seasonMultiplier)))")
print("  ödülsüz oyuncu (retention KAPALI — saf çekirdek ekonomi):")
if let t = noRetUni {
    print("    Garaj->Unicorn  : \(mmss(t)) = \(mins(t))  (moral \(String(format: "%.0f", noRet.s.morale)), itibar \(String(format: "%.0f", noRet.s.reputation)))")
} else if noRet.bankrupt {
    print("    Garaj->Unicorn  : İFLAS @ \(mmss(noRet.bankruptTime))")
} else {
    print("    Garaj->Unicorn  : 6 saatte ULAŞILAMADI")
}
if let u = unicornT, let n = noRetUni {
    let speedup = (n - u) / n * 100
    print("    >> retention ödülleri Unicorn'u %\(String(format: "%.1f", speedup)) hızlandırdı (\(mmss(n)) -> \(mmss(u)))")
    print("    >> kalıcı sezon çarpanı tavanı: +%\(String(format: "%.0f", Balance.seasonOutputBonusCap * 100)) (maks ×\(String(format: "%.2f", 1 + Balance.seasonOutputBonusCap)))")
}

// =====================================================================
// MARK: (h) Naive (acemi) oyuncu — iflas adil bir risk mi?
// =====================================================================
// Acemi: runway umursamaz, tampon tutmaz, reklam bütçesini DİSİPLİNSİZ açar
// (sağlık kontrolü gevşek — erken/aşırı harcamayı cezalandırma testi).
MIN_RUNWAY = 0.0
BOOTSTRAP_BUFFER_MULT = 0.0
AD_HEALTHY_LTV_CAC = 1.2     // acemi düşük eşikle erkenden gaza basar
AD_MIN_RUNWAY = 0.5         // acemi runway korumaz
let naive = Runner()
naive.run(maxSeconds: 6 * 3600)
print("\n(h) NAİVE oyuncu (runway umursamaz, tampon tutmaz, erken reklam gazlar):")
if naive.bankrupt {
    print("  -> İFLAS @ \(mmss(naive.bankruptTime)) (evre: \(Balance.stages[naive.s.stage].name)) — iflas GERÇEK bir risk ✅")
} else if let t = naive.stageReachTime[Balance.stageCount - 1] {
    print("  -> İflas etmeden Unicorn @ \(mmss(t)) (acemi de başarabiliyor)")
} else {
    print("  -> Ne iflas ne Unicorn (6 saat sınırı)")
}
print("  -> naive zirve reklam bütçesi: \(dollars(naive.peakAdBudget))/ay, son nakit: \(dollars(naive.s.cash))")

// Naive testinden çıkışta globalleri varsayılana sıfırla (arketip testleri için temiz başlangıç).
MIN_RUNWAY = 2.0
BOOTSTRAP_BUFFER_MULT = 1.5
AD_HEALTHY_LTV_CAC = 3.0
AD_MIN_RUNWAY = 4.0
AD_BUDGET_ENABLED = true
RETENTION_REWARDS_ENABLED = true

// =====================================================================
// MARK: (i) 4 oyuncu arketipi — Çoklu Yol doğrulaması
// =====================================================================
// Tasarım Prensibi: 4 strateji arketipi de Garaj→Unicorn'a varabilmeli.
// Hiçbiri "açıkça en iyi" olmamalı; farklı dengelerle aynı hedefe ulaşmalılar.
//
//   - Bootstrap-Frugal: Pre-seed dışında tur YOK, az çalışan, düşük reklam → yavaş.
//   - VC-Roket        : Her tur kapanır kapanmaz al, agresif hire+reklam → hızlı.
//   - Niş Uzman       : Az ama derin ekip, Premium/Churn modülleri önde → orta.
//   - Platform Geniş  : Geniş ekip, büyüme + verim modülleri önde, ARPU düşük → orta-hızlı.

struct ArchetypeReport {
    let arch: Archetype
    let bankrupt: Bool
    let bankruptTime: Double
    let unicornTime: Double?      // saniye
    let finalUsers: Double
    let finalMrr: Double
    let finalArpu: Double
    let finalChurn: Double
    let finalReputation: Double
    let finalMorale: Double
    let finalLtvCac: Double
    let totalHires: Int
    let founderEquity: Double
    let peakAdBudget: Double
    let cumulativeAdSpend: Double
    let cumulativePaidUsers: Double
    let cumulativeOrganicUsers: Double
    let stageReachTime: [Int: Double]
    let headcount: [Int]
    let moduleLevels: [Int]
}

func runArchetype(_ arch: Archetype) -> ArchetypeReport {
    ACTIVE_POLICY = Policy.policy(for: arch)
    MIN_RUNWAY = ACTIVE_POLICY.minRunway
    BOOTSTRAP_BUFFER_MULT = ACTIVE_POLICY.bootstrapBufferMult
    AD_HEALTHY_LTV_CAC = ACTIVE_POLICY.adHealthyLtvCac
    AD_BUDGET_ENABLED = ACTIVE_POLICY.adEnabled
    RETENTION_REWARDS_ENABLED = true   // retention herkes için açık (gerçek oyuncu)
    let r = Runner()
    r.run(maxSeconds: 6 * 3600)
    return ArchetypeReport(
        arch: arch,
        bankrupt: r.bankrupt,
        bankruptTime: r.bankruptTime,
        unicornTime: r.stageReachTime[Balance.stageCount - 1],
        finalUsers: r.s.users,
        finalMrr: r.s.mrr,
        finalArpu: r.s.arpu,
        finalChurn: r.s.churnRate,
        finalReputation: r.s.reputation,
        finalMorale: r.s.morale,
        finalLtvCac: r.s.ltvCacRatio,
        totalHires: r.s.totalHires,
        founderEquity: r.s.founderEquity,
        peakAdBudget: r.peakAdBudget,
        cumulativeAdSpend: r.cumulativeAdSpend,
        cumulativePaidUsers: r.cumulativePaidUsers,
        cumulativeOrganicUsers: r.cumulativeOrganicUsers,
        stageReachTime: r.stageReachTime,
        headcount: r.s.headcount,
        moduleLevels: r.s.moduleLevels
    )
}

print("\n==========================================================")
print(" (i) 4 OYUNCU ARKETIPI — Çoklu Yol Doğrulaması")
print("==========================================================")

var reports: [ArchetypeReport] = []
for arch in Archetype.allCases {
    reports.append(runArchetype(arch))
}

print("\n  arketip          | Unicorn | iflas? | son kullanıcı | MRR/ay  | ARPU  | churn | itibar | LTV:CAC | hisse% | toplam işe alım")
for r in reports {
    let uniStr: String
    if r.bankrupt { uniStr = "İFLAS@" + mmss(r.bankruptTime) }
    else if let t = r.unicornTime { uniStr = mmss(t) }
    else { uniStr = "—" }
    let line = "  \(pad(r.arch.rawValue, 16)) | "
        + "\(pad(uniStr, 7)) | "
        + "\(pad(r.bankrupt ? "EVET" : "hayır", 6)) | "
        + "\(pad(fmt(r.finalUsers), 13)) | "
        + "\(pad(dollars(r.finalMrr), 7)) | "
        + "\(pad(dollars(r.finalArpu), 5)) | "
        + "\(pad(String(format: "%.1f%%", r.finalChurn * 100), 5)) | "
        + "\(pad(String(format: "%.0f", r.finalReputation), 6)) | "
        + "\(pad(String(format: "%.1f", r.finalLtvCac), 7)) | "
        + "\(pad(String(format: "%.0f%%", r.founderEquity * 100), 6)) | "
        + "\(r.totalHires)"
    print(line)
}

// Detaylı her arketip profili
for r in reports {
    print("\n--- \(r.arch.rawValue) ---")
    if r.bankrupt {
        print("  İFLAS @ \(mmss(r.bankruptTime)) — Unicorn'a varılamadı.")
        continue
    }
    if let t = r.unicornTime {
        print("  Unicorn: \(mmss(t)) (\(mins(t)), \(String(format: "%.0f", gameMonths(t))) oyun-ayı)")
    } else {
        print("  Unicorn'a 6 saatte ulaşılamadı (max sim süresi).")
    }
    // funding aralıkları
    var prev: Double = 0
    print("  evre süreleri:")
    for stg in Balance.stages where stg.id > 0 {
        if let t = r.stageReachTime[stg.id] {
            let iv = t - prev
            prev = t
            print("    -> \(pad(stg.name, 11)) @ \(pad(mmss(t), 14)) (+\(mmss(iv)))")
        } else {
            print("    -> \(pad(stg.name, 11)) ULAŞILAMADI")
        }
    }
    print("  departman headcount:", terminator: " ")
    for i in 0..<Balance.departmentCount {
        let d = Balance.departments[i]
        print("\(d.name): \(r.headcount[i])", terminator: (i < Balance.departmentCount - 1 ? " | " : ""))
    }
    print("")
    print("  modül seviyeleri  :", terminator: " ")
    for i in 0..<Balance.modules.count {
        let m = Balance.modules[i]
        print("\(m.name): \(r.moduleLevels[i])/\(m.maxLevel)", terminator: (i < Balance.modules.count - 1 ? " | " : ""))
    }
    print("")
    let totalAcq = r.cumulativePaidUsers + r.cumulativeOrganicUsers
    let paidPct = totalAcq > 0 ? r.cumulativePaidUsers / totalAcq * 100 : 0
    print("  edinme dağılımı   : ücretli %\(String(format: "%.0f", paidPct)) / organik %\(String(format: "%.0f", 100 - paidPct)) | toplam reklam harcaması \(dollars(r.cumulativeAdSpend)) | zirve bütçe \(dollars(r.peakAdBudget))/ay")
    print("  birim ekonomi     : ARPU \(dollars(r.finalArpu)) | churn \(String(format: "%.1f%%", r.finalChurn * 100)) | LTV:CAC \(String(format: "%.1f", r.finalLtvCac))")
    print("  insan & moral     : toplam işe alım \(r.totalHires), moral \(String(format: "%.0f", r.finalMorale)), itibar \(String(format: "%.0f", r.finalReputation)), hisse %\(String(format: "%.0f", r.founderEquity * 100))")
}

// Çoklu Yol Doğrulaması özeti
print("\n=== ÇOKLU YOL DOĞRULAMASI ===")
let successful = reports.filter { !$0.bankrupt && $0.unicornTime != nil }
print("  Unicorn'a varan arketip: \(successful.count) / \(reports.count)")
let times = successful.compactMap { $0.unicornTime }
if !times.isEmpty {
    let fastest = times.min()!
    let slowest = times.max()!
    let ratio = slowest / fastest
    print("  En hızlı: \(mmss(fastest)) | En yavaş: \(mmss(slowest)) | yavaş/hızlı oranı: \(String(format: "%.2fx", ratio))")
    print("  Sağlıklı bant (hedef): tüm arketipler Unicorn'a varır, oran <~ 2.0x (hiçbiri ezici değil).")
    if ratio < 2.0 {
        print("  -> DENGE TAMAM ✅ (4 yol meşru ve eşit-değerli)")
    } else {
        print("  -> DENGE ZAYIF (kalibrasyon gerekli — en yavaş yol \(String(format: "%.1fx", ratio)) daha uzun)")
    }
}
if reports.contains(where: { $0.bankrupt }) {
    print("  UYARI: İflas eden arketip(ler) var — politika ya da Balance kalibrasyonu gerekli.")
}
