import Foundation

// MARK: - Departman (jeneratör) tanımı

/// Bir departman: çalışan alınabilen üretim birimi. Her departmanın çıktısı
/// ekonomi zincirinde farklı bir role hizmet eder (DevPower / büyüme / ARPU / churn).
struct DepartmentDef: Identifiable {
    let id: Int
    let name: String
    let icon: String
    let role: DeptRole
    let baseHireCost: Double   // ilk çalışanın işe alım (bir defalık) maliyeti
    let baseSalary: Double     // çalışan başına aylık maaş ($)
    let baseOutput: Double     // çalışan başına rol-çıktısı (birim/sn-eşdeğeri, aylık ölçek)
    let colorHex: String
}

/// Departmanın ekonomideki rolü.
enum DeptRole {
    case engineering   // ürün ilerlemesi / kalite
    case product       // kalite + dönüşüm + churn azaltma
    case marketing     // kullanıcı büyümesi
    case sales         // ARPU (kullanıcı başına gelir)
    case ops           // churn azaltma + ölçek desteği
}

// MARK: - Modül (yükseltme / araştırma) tanımı

struct ModuleDef: Identifiable {
    let id: Int
    let name: String
    let icon: String
    let detail: String
    let baseCost: Double
    let costGrowth: Double
    let maxLevel: Int
    let effect: ModuleEffect
    let unlockStage: Int       // bu evreden itibaren görünür
}

enum ModuleEffect {
    case globalOutput(Double)      // tüm departman çıktısı +x/seviye
    case growthMult(Double)        // kullanıcı büyümesi +x/seviye
    case arpuMult(Double)          // ARPU +x/seviye
    case churnReduce(Double)       // churn -x/seviye (oransal)
    case moraleTarget(Double)      // moral hedefi +x/seviye
    case salaryReduce(Double)      // maaş -x/seviye (oransal verimlilik)
    case infraCostReduce(Double)   // bulut/sunucu gideri -x/seviye (oransal)
    case rentCostReduce(Double)    // ofis kirası gideri -x/seviye (oransal)
}

// MARK: - Operasyonel gider (OpEx) kalemleri

/// Bir gider kaleminin neye göre ölçeklendiği.
enum CostDriver {
    case perSeat            // çalışan başına (kira, lisans, ekipman, genel)
    case perThousandUsers   // 1000 kullanıcı başına (bulut/sunucu)
    case perStage           // funding evresi büyüdükçe (yasal/muhasebe)
    case flat               // sabit taban
}

/// Operasyonel gider kalemi tanımı. Maaşlar HARİÇ tüm "şirket giderleri".
struct CostItemDef: Identifiable {
    let id: Int
    let name: String
    let icon: String
    let driver: CostDriver
    let rate: Double          // sürücü birimi başına aylık $ (evre 0 tabanı)
    let stageScaling: Double  // her evrede ×pow(stageScaling, stage)
    let detail: String
}

// MARK: - Ofis eşyası (kroki + satın alma sistemi)

/// Bir ofis eşyasının kategorisi (mağaza filtresi + kroki renk vurgusu).
enum ItemCategory: String, CaseIterable, Codable {
    case workstation   // masa / koltuk üretim altyapısı
    case social        // moral (oyun/eğlence)
    case kitchen       // moral (yiyecek/içecek)
    case comfort       // moral (dinlenme, churn hissi)
    case plant         // moral + itibar (estetik)
    case luxury        // yüksek moral + itibar (pahalı, ileri evre)
    case infra         // flavor / yardımcı

    var title: String {
        switch self {
        case .workstation: return "Çalışma"
        case .social:      return "Sosyal"
        case .kitchen:     return "Mutfak"
        case .comfort:     return "Konfor"
        case .plant:       return "Yeşil"
        case .luxury:      return "Lüks"
        case .infra:       return "Altyapı"
        }
    }

    /// Kroki/mağaza vurgu rengi (hex).
    var colorHex: String {
        switch self {
        case .workstation: return "5B8DEF"
        case .social:      return "FF9F5A"
        case .kitchen:     return "F5C451"
        case .comfort:     return "C77DFF"
        case .plant:       return "4FD1A1"
        case .luxury:      return "FFD479"
        case .infra:       return "8A93A6"
        }
    }
}

/// Satın alınabilen bir ofis eşyası tanımı. id sırası KALICI (kayıt uyumu).
struct OfficeItemDef: Identifiable {
    let id: Int
    let name: String
    let category: ItemCategory
    let icon: String            // SF Symbol (emoji YOK)
    let cost: Double
    let areaM2: Double          // tükettiği alan
    let seatCapacity: Int       // çalışan koltuğu (masalar)
    let moraleBonus: Double     // moraleTargetBonus'a katkı (puan)
    let outputBonus: Double     // global üretim +% (0.02 = %2)
    let reputationBonus: Double // itibar etkisi (kalıcı puan)
    let unlockStage: Int        // bu evreden itibaren mağazada
}

// MARK: - Funding evresi (meta ilerleme + tema + ofis)

struct StageDef: Identifiable {
    let id: Int
    let name: String           // "Garaj", "Pre-seed", ...
    let title: String          // unvan: "Hacker", "Kurucu", ...
    let valuationTarget: Double // bu evreye geçmek için gereken değerleme
    let raiseAmount: Double      // tur kapanınca gelen nakit
    let equityGiven: Double      // verilen hisse (0.18 = %18)
    let bgHex: String
    let accentHex: String
    let surfaceHex: String       // panel/kart yüzeyi
    let officeName: String       // ofis sahnesi etiketi
}

// MARK: - Tüm sabitler tek kaynakta

enum Balance {
    // Zaman ölçeği: ekonomi "aylık" düşünülür, saniyeye bölünür.
    static let secondsPerMonth: Double = 60      // 1 oyun-ayı = 60 gerçek sn (hızlı tempo)
    static let startCash: Double = 40_000        // erken iflas tamponu (ayar: hook için)

    // Çeyrek döngüsü (completed-cycle çekirdeği): kaç oyun-ayı = 1 çeyrek.
    static let monthsPerQuarter: Double = 3
    // Terfi ödülü: küçük, prestij odaklı moral/itibar dokunuşu (ekonomiyi bozmaz).
    static let promoteMoraleBonus: Double = 8
    static let promoteReputationBonus: Double = 5

    // MARK: Sezon Finali + Kalıcı Ödül (uzun-vade tamamlanma)
    // Kaç çeyrek kapanışı = 1 sezon. Sezon dolunca görkemli finale + kalıcı ödül.
    static let quartersPerSeason: Int = 4
    // Sezon bitirince kazanılan KALICI üretim çarpanı katkısı (oransal, sezon başına).
    // Küçük + tavanlı — founderBonus mantığına benzer, ekonomiyi bozmaz.
    static let seasonOutputBonusPerSeason: Double = 0.02   // +%2 / sezon
    // Math-denge (madde 6): doğrudan üretim çarpanı en doğrudan kaldıraç. Tek Garaj→Unicorn
    // koşusunda ~6 sezon birikir; tavan +%20 yerine +%15 (×1.15) — uzun vadede hâlâ anlamlı
    // prestij ödülü ama eğriyi bozmayan, "hoş ama ezici değil" üst sınır.
    static let seasonOutputBonusCap: Double = 0.15         // toplam +%15 tavan
    // Sezon finali kutlama ödülü: küçük moral + itibar dokunuşu (nakit YOK — ekonomi korunur).
    static let seasonFinaleMoraleBonus: Double = 10
    static let seasonFinaleReputationBonus: Double = 8

    // MARK: Haftalık Sprint (çeyrek içi kısa, kapanan döngü — completed-cycle)
    // Sprint süresi: kaç oyun-ayı = 1 sprint ("hafta"). 0.5 → çeyrekte ~6 sprint.
    static let monthsPerSprint: Double = 0.5
    // Sprint başarı ödülü: küçük moral + itibar dokunuşu (nakit YOK — ekonomi korunur).
    static let sprintWinMoraleBonus: Double = 4
    static let sprintWinReputationBonus: Double = 2
    // Sprint başarısı çeyrek lig skoruna katkı tavanı (küçük — gerçek bahsi bozmaz).
    static let sprintLeagueCap: Double = 5
    static let sprintLeaguePerWin: Double = 1.0

    // MARK: Günlük Hedef + Streak (geri-dönüş kancası)
    // Günlük kullanıcı hedefi tabanı (evre/ölçekle çarpılır — DailyGoalSystem).
    static let dailyUsersBase: Double = 20
    // Günlük hedef tamamlama ödülü: küçük moral + itibar dokunuşu (nakit YOK — ekonomi korunur).
    static let dailyCompleteMoraleBonus: Double = 5
    static let dailyCompleteReputationBonus: Double = 2
    // Streak'in moral hedefine kalıcı katkısı: gün başına puan + tavan (abartma).
    // Math-denge (madde 6): streak en güçlü tek üretim kaldıracıydı (moralFactor üzerinden);
    // ödülü "hoş ama ezici değil" tutmak için tavan 8→5'e, gün/puan 0.8→0.6'ya çekildi.
    static let streakMoralePerDay: Double = 0.5
    static let streakMoraleCap: Double = 4
    // Streak / günlük tamamlamanın çeyrek lig skoruna katkı tavanları (küçük).
    static let streakLeagueCap: Double = 4
    static let dailyLeagueCap: Double = 6

    // Kullanıcı büyüme & gelir
    static let baseArpu: Double = 3.8            // kullanıcı başına aylık $ (taban) — MRR/valuation motorunu güçlendirir
    static let baseChurn: Double = 0.05          // aylık churn oranı (taban)
    static let viralFactor: Double = 0.045       // kullanıcı başına organik büyüme katkısı (geç-oyun ivmesi)

    // Moral
    static let startMorale: Double = 72
    static let baseMoraleTarget: Double = 60
    static let moraleAdjustRate: Double = 0.08   // /sn yaklaşım hızı
    static let quitMoraleThreshold: Double = 28
    static let unpaidMoralePenalty: Double = 40  // maaş ödenemezse hedefe ek baskı

    // Hisse / değerleme
    static let revenueMultiple: Double = 7.0     // değerleme = ARR * multiple bileşeni
    static let perUserValue: Double = 6.0        // kullanıcı başına değerleme bileşeni
    static let unicornValuation: Double = 1_000_000_000

    // Yükseltme maliyet artışı
    static let hireCostGrowth = 1.12             // her ek çalışan %12 pahalı

    // Offline
    static let offlineCapSeconds: Double = 8 * 3600
    static let offlineEfficiency: Double = 0.5

    // Karar olayları
    static let decisionMinInterval: Double = 99999  // sn — ekran görüntüsü için geçici olarak kapatıldı
    static let decisionMaxInterval: Double = 99999

    // MARK: Departmanlar
    static let departments: [DepartmentDef] = [
        .init(id: 0, name: "Mühendislik", icon: "💻", role: .engineering,
              baseHireCost: 1_500, baseSalary: 900, baseOutput: 1.0, colorHex: "5B8DEF"),
        .init(id: 1, name: "Ürün & Tasarım", icon: "🎨", role: .product,
              baseHireCost: 2_400, baseSalary: 1_000, baseOutput: 0.9, colorHex: "C77DFF"),
        .init(id: 2, name: "Pazarlama", icon: "📣", role: .marketing,
              baseHireCost: 3_200, baseSalary: 950, baseOutput: 4.0, colorHex: "FF9F5A"),
        .init(id: 3, name: "Satış", icon: "🤝", role: .sales,
              baseHireCost: 5_000, baseSalary: 1_100, baseOutput: 0.8, colorHex: "4FD1A1"),
        .init(id: 4, name: "Operasyon", icon: "⚙️", role: .ops,
              baseHireCost: 7_500, baseSalary: 1_050, baseOutput: 1.0, colorHex: "E0574F"),
    ]
    static var departmentCount: Int { departments.count }

    // MARK: Modüller
    static let modules: [ModuleDef] = [
        .init(id: 0, name: "CI/CD Hattı", icon: "🔁",
              detail: "Mühendislik verimi artar.", baseCost: 8_000, costGrowth: 4.0, maxLevel: 5,
              effect: .globalOutput(0.10), unlockStage: 0),
        .init(id: 1, name: "Growth Hack", icon: "🚀",
              detail: "Kullanıcı büyümesi hızlanır.", baseCost: 12_000, costGrowth: 4.5, maxLevel: 5,
              effect: .growthMult(0.15), unlockStage: 1),
        .init(id: 2, name: "Premium Paket", icon: "💎",
              detail: "Kullanıcı başına gelir (ARPU) artar.", baseCost: 18_000, costGrowth: 5.0, maxLevel: 5,
              effect: .arpuMult(0.18), unlockStage: 1),
        .init(id: 3, name: "Müşteri Başarısı", icon: "🎧",
              detail: "Churn (kullanıcı kaybı) azalır.", baseCost: 15_000, costGrowth: 4.5, maxLevel: 5,
              effect: .churnReduce(0.12), unlockStage: 2),
        .init(id: 4, name: "Şirket Kültürü", icon: "🌱",
              detail: "Takım morali yükselir.", baseCost: 10_000, costGrowth: 3.5, maxLevel: 5,
              effect: .moraleTarget(6.0), unlockStage: 0),
        .init(id: 5, name: "Uzaktan Çalışma", icon: "🏠",
              detail: "Maaş maliyetleri düşer.", baseCost: 22_000, costGrowth: 5.0, maxLevel: 4,
              effect: .salaryReduce(0.06), unlockStage: 2),
        .init(id: 6, name: "Sunucu Optimizasyonu", icon: "🗄️",
              detail: "Bulut & sunucu giderleri düşer.", baseCost: 14_000, costGrowth: 4.2, maxLevel: 5,
              effect: .infraCostReduce(0.15), unlockStage: 1),
        .init(id: 7, name: "Hibrit Ofis", icon: "🏢",
              detail: "Ofis kirası giderleri düşer.", baseCost: 20_000, costGrowth: 4.5, maxLevel: 4,
              effect: .rentCostReduce(0.12), unlockStage: 2),
    ]

    // MARK: Funding evreleri
    static let stages: [StageDef] = [
        // Aurora Dark: zemin hep koyu (#0B0E14 ailesi, evreye çok hafif tint),
        // yüzey #161B26 ailesinden, accent rampası evre büyüdükçe güzelleşir.
        .init(id: 0, name: "Garaj", title: "Hacker",
              valuationTarget: 0, raiseAmount: 0, equityGiven: 0,
              bgHex: "0B0E14", accentHex: "22D3EE", surfaceHex: "161B26", officeName: "Garaj"),
        .init(id: 1, name: "Pre-seed", title: "Kurucu",
              valuationTarget: 500_000, raiseAmount: 150_000, equityGiven: 0.10,
              bgHex: "0B0F16", accentHex: "38BDF8", surfaceHex: "151C28", officeName: "Paylaşımlı Ofis"),
        .init(id: 2, name: "Seed", title: "CEO",
              valuationTarget: 3_000_000, raiseAmount: 800_000, equityGiven: 0.15,
              bgHex: "0B1014", accentHex: "4FD1A1", surfaceHex: "151E26", officeName: "İlk Ofis"),
        .init(id: 3, name: "Series A", title: "CEO",
              valuationTarget: 15_000_000, raiseAmount: 4_000_000, equityGiven: 0.18,
              bgHex: "0C0E16", accentHex: "7C5CFF", surfaceHex: "171A2A", officeName: "Açık Plan Kat"),
        .init(id: 4, name: "Series B", title: "CEO",
              valuationTarget: 75_000_000, raiseAmount: 20_000_000, equityGiven: 0.15,
              bgHex: "0E0F14", accentHex: "FFB454", surfaceHex: "1B1B26", officeName: "Şirket Katı"),
        .init(id: 5, name: "Series C", title: "CEO",
              valuationTarget: 300_000_000, raiseAmount: 150_000_000, equityGiven: 0.12,
              bgHex: "0B1013", accentHex: "2EE6C5", surfaceHex: "141F25", officeName: "Plaza"),
        .init(id: 6, name: "Unicorn", title: "Unicorn CEO",
              valuationTarget: 1_000_000_000, raiseAmount: 0, equityGiven: 0,
              bgHex: "0D0C16", accentHex: "FF6FB5", surfaceHex: "1A1828", officeName: "Kampüs"),
    ]
    static var stageCount: Int { stages.count }

    /// Çalışan başına maaş, evreyle birlikte artar (kıdemli ekip pahalanır).
    static func salaryMultiplier(forStage stage: Int) -> Double {
        pow(1.6, Double(stage))
    }

    // MARK: Operasyonel gider kalemleri (maaşlar HARİÇ)
    // Sürücülerle ölçeklenir: her çalışan kira+lisans+ekipman+genel gider getirir;
    // her 1000 kullanıcı bulut/sunucu gideri getirir; evre büyüdükçe yasal/muhasebe artar.
    static let costItems: [CostItemDef] = [
        .init(id: 0, name: "Ofis Kirası", icon: "🏢", driver: .perSeat,
              rate: 140, stageScaling: 1.40, detail: "Çalışan başına alan; daha iyi ofis daha pahalı."),
        .init(id: 1, name: "SaaS & Yazılım Lisansları", icon: "🧾", driver: .perSeat,
              rate: 50, stageScaling: 1.12, detail: "Koltuk başına araçlar (kod, tasarım, CRM...)."),
        .init(id: 2, name: "Bulut & Sunucu", icon: "☁️", driver: .perThousandUsers,
              rate: 10, stageScaling: 1.05, detail: "1000 kullanıcı başına altyapı maliyeti."),
        .init(id: 3, name: "Yasal & Muhasebe", icon: "⚖️", driver: .perStage,
              rate: 500, stageScaling: 1.0, detail: "Funding büyüdükçe artan danışmanlık."),
        .init(id: 4, name: "Ekipman & Donanım", icon: "🖥️", driver: .perSeat,
              rate: 32, stageScaling: 1.18, detail: "Çalışan başına laptop, ekran, vb."),
        .init(id: 5, name: "Genel & İdari", icon: "🍽️", driver: .perSeat,
              rate: 22, stageScaling: 1.25, detail: "Faturalar, ikram, ofis sarf malzemeleri."),
    ]
    static var costItemCount: Int { costItems.count }

    /// Bir gider kaleminin aylık tutarı (indirimler GameModel'de uygulanır).
    static func itemMonthlyCost(_ item: CostItemDef, stage: Int, headcount: Int, users: Double) -> Double {
        let stageMult = pow(item.stageScaling, Double(stage))
        switch item.driver {
        case .perSeat:          return item.rate * Double(headcount) * stageMult
        case .perThousandUsers: return item.rate * (users / 1000) * stageMult
        case .perStage:         return item.rate * Double(stage + 1) * stageMult
        case .flat:             return item.rate * stageMult
        }
    }

    // MARK: Ofis alanı & eşya kataloğu

    /// Garaj başlangıcı / eski kayıtlar için makul taban koltuk (kurucu hep oturabilir).
    static let baseSeatCapacity: Int = 2

    /// Evreye bağlı toplam ofis alanı (m²). Funding büyüdükçe daha çok eşya sığar.
    static func officeAreaM2(stage: Int) -> Double {
        let table: [Double] = [30, 80, 200, 500, 1200, 3000, 8000]
        let s = min(max(0, stage), table.count - 1)
        return table[s]
    }

    /// Eşya kataloğu. id sırası KALICI (ownedItems id-tabanlı). ~40 eşya, kategorili.
    static let officeItems: [OfficeItemDef] = [
        // --- workstation (koltuk + üretim) ---
        .init(id: 0,  name: "Basit Masa",       category: .workstation, icon: "tablecells",                 cost: 600,     areaM2: 4,  seatCapacity: 1, moraleBonus: 0,   outputBonus: 0.0,  reputationBonus: 0, unlockStage: 0),
        .init(id: 1,  name: "Ergonomik Masa",   category: .workstation, icon: "tablecells.fill",            cost: 1_800,   areaM2: 5,  seatCapacity: 1, moraleBonus: 2,   outputBonus: 0.02, reputationBonus: 0, unlockStage: 0),
        .init(id: 2,  name: "Ayakta Masa",      category: .workstation, icon: "rectangle.portrait",         cost: 2_600,   areaM2: 5,  seatCapacity: 1, moraleBonus: 3,   outputBonus: 0.02, reputationBonus: 0, unlockStage: 1),
        .init(id: 3,  name: "Toplantı Masası",  category: .workstation, icon: "person.3.fill",              cost: 4_500,   areaM2: 12, seatCapacity: 0, moraleBonus: 1,   outputBonus: 0.04, reputationBonus: 2, unlockStage: 1),
        .init(id: 4,  name: "Beyaz Tahta",      category: .workstation, icon: "rectangle.on.rectangle",     cost: 900,     areaM2: 2,  seatCapacity: 0, moraleBonus: 0,   outputBonus: 0.02, reputationBonus: 0, unlockStage: 0),
        .init(id: 5,  name: "Kitaplık / Dolap", category: .workstation, icon: "books.vertical.fill",        cost: 1_400,   areaM2: 3,  seatCapacity: 0, moraleBonus: 1,   outputBonus: 0.01, reputationBonus: 0, unlockStage: 0),
        .init(id: 6,  name: "Ekstra Monitör",   category: .workstation, icon: "display.2",                  cost: 1_100,   areaM2: 1,  seatCapacity: 0, moraleBonus: 1,   outputBonus: 0.03, reputationBonus: 0, unlockStage: 0),

        // --- social (moral) ---
        .init(id: 7,  name: "Masa Tenisi",      category: .social,      icon: "figure.table.tennis",        cost: 3_000,   areaM2: 8,  seatCapacity: 0, moraleBonus: 5,   outputBonus: 0.0,  reputationBonus: 1, unlockStage: 1),
        .init(id: 8,  name: "Langırt",          category: .social,      icon: "figure.soccer",              cost: 3_500,   areaM2: 6,  seatCapacity: 0, moraleBonus: 5,   outputBonus: 0.0,  reputationBonus: 1, unlockStage: 1),
        .init(id: 9,  name: "Bilardo Masası",   category: .social,      icon: "circle.grid.3x3.fill",       cost: 6_000,   areaM2: 10, seatCapacity: 0, moraleBonus: 6,   outputBonus: 0.0,  reputationBonus: 1, unlockStage: 2),
        .init(id: 10, name: "Dart Tahtası",     category: .social,      icon: "target",                     cost: 800,     areaM2: 2,  seatCapacity: 0, moraleBonus: 3,   outputBonus: 0.0,  reputationBonus: 0, unlockStage: 0),
        .init(id: 11, name: "Oyun Konsolu + TV",category: .social,      icon: "gamecontroller.fill",        cost: 4_200,   areaM2: 5,  seatCapacity: 0, moraleBonus: 6,   outputBonus: 0.0,  reputationBonus: 1, unlockStage: 1),
        .init(id: 12, name: "Atari Kabini",     category: .social,      icon: "arcade.stick.console.fill",  cost: 5_500,   areaM2: 4,  seatCapacity: 0, moraleBonus: 6,   outputBonus: 0.0,  reputationBonus: 2, unlockStage: 2),
        .init(id: 13, name: "Bordoyun Köşesi",  category: .social,      icon: "dice.fill",                  cost: 1_600,   areaM2: 4,  seatCapacity: 0, moraleBonus: 4,   outputBonus: 0.0,  reputationBonus: 0, unlockStage: 1),

        // --- kitchen (moral) ---
        .init(id: 14, name: "Kahve Makinesi",   category: .kitchen,     icon: "cup.and.saucer.fill",        cost: 1_200,   areaM2: 2,  seatCapacity: 0, moraleBonus: 4,   outputBonus: 0.0,  reputationBonus: 0, unlockStage: 0),
        .init(id: 15, name: "Espresso İstasyonu",category: .kitchen,    icon: "mug.fill",                   cost: 4_800,   areaM2: 3,  seatCapacity: 0, moraleBonus: 6,   outputBonus: 0.0,  reputationBonus: 1, unlockStage: 2),
        .init(id: 16, name: "Mini Mutfak",      category: .kitchen,     icon: "refrigerator.fill",          cost: 5_000,   areaM2: 10, seatCapacity: 0, moraleBonus: 5,   outputBonus: 0.0,  reputationBonus: 1, unlockStage: 1),
        .init(id: 17, name: "Buzdolabı",        category: .kitchen,     icon: "refrigerator",               cost: 1_800,   areaM2: 2,  seatCapacity: 0, moraleBonus: 3,   outputBonus: 0.0,  reputationBonus: 0, unlockStage: 0),
        .init(id: 18, name: "Atıştırmalık Bar", category: .kitchen,     icon: "takeoutbag.and.cup.and.straw.fill", cost: 2_400, areaM2: 3, seatCapacity: 0, moraleBonus: 5, outputBonus: 0.0, reputationBonus: 0, unlockStage: 1),
        .init(id: 19, name: "Su Sebili",        category: .kitchen,     icon: "drop.fill",                  cost: 700,     areaM2: 1,  seatCapacity: 0, moraleBonus: 2,   outputBonus: 0.0,  reputationBonus: 0, unlockStage: 0),

        // --- comfort (moral, churn↓ hissi) ---
        .init(id: 20, name: "Dinlenme Kanepesi",category: .comfort,     icon: "sofa.fill",                  cost: 2_800,   areaM2: 6,  seatCapacity: 0, moraleBonus: 5,   outputBonus: 0.0,  reputationBonus: 0, unlockStage: 1),
        .init(id: 21, name: "Puf Köşesi",       category: .comfort,     icon: "circle.circle.fill",         cost: 1_000,   areaM2: 4,  seatCapacity: 0, moraleBonus: 3,   outputBonus: 0.0,  reputationBonus: 0, unlockStage: 0),
        .init(id: 22, name: "Hamak",            category: .comfort,     icon: "bed.double.fill",            cost: 1_500,   areaM2: 5,  seatCapacity: 0, moraleBonus: 4,   outputBonus: 0.0,  reputationBonus: 1, unlockStage: 1),
        .init(id: 23, name: "Uyku Kapsülü",     category: .comfort,     icon: "moon.zzz.fill",              cost: 9_000,   areaM2: 4,  seatCapacity: 0, moraleBonus: 8,   outputBonus: 0.02, reputationBonus: 2, unlockStage: 3),
        .init(id: 24, name: "Kütüphane Köşesi", category: .comfort,     icon: "book.fill",                  cost: 3_200,   areaM2: 8,  seatCapacity: 0, moraleBonus: 5,   outputBonus: 0.02, reputationBonus: 1, unlockStage: 2),
        .init(id: 25, name: "Ergonomik Lounge", category: .comfort,     icon: "chair.lounge.fill",          cost: 6_500,   areaM2: 7,  seatCapacity: 0, moraleBonus: 7,   outputBonus: 0.0,  reputationBonus: 2, unlockStage: 2),

        // --- plant (moral + estetik/itibar) ---
        .init(id: 26, name: "Saksı Bitki",      category: .plant,       icon: "leaf.fill",                  cost: 400,     areaM2: 1,  seatCapacity: 0, moraleBonus: 2,   outputBonus: 0.0,  reputationBonus: 1, unlockStage: 0),
        .init(id: 27, name: "Büyük Bitki",      category: .plant,       icon: "tree.fill",                  cost: 1_200,   areaM2: 3,  seatCapacity: 0, moraleBonus: 3,   outputBonus: 0.0,  reputationBonus: 2, unlockStage: 1),
        .init(id: 28, name: "Dikey Bahçe",      category: .plant,       icon: "camera.macro",               cost: 5_500,   areaM2: 4,  seatCapacity: 0, moraleBonus: 4,   outputBonus: 0.0,  reputationBonus: 4, unlockStage: 2),
        .init(id: 29, name: "Akvaryum",         category: .plant,       icon: "fish.fill",                  cost: 7_000,   areaM2: 5,  seatCapacity: 0, moraleBonus: 5,   outputBonus: 0.0,  reputationBonus: 4, unlockStage: 3),
        .init(id: 30, name: "Bonsai",           category: .plant,       icon: "leaf.circle.fill",           cost: 2_000,   areaM2: 1,  seatCapacity: 0, moraleBonus: 2,   outputBonus: 0.0,  reputationBonus: 3, unlockStage: 2),

        // --- luxury (yüksek moral + itibar, pahalı, ileri evre) ---
        .init(id: 31, name: "Şömine",           category: .luxury,      icon: "flame.fill",                 cost: 12_000,  areaM2: 6,  seatCapacity: 0, moraleBonus: 8,   outputBonus: 0.0,  reputationBonus: 4, unlockStage: 3),
        .init(id: 32, name: "Jakuzi",           category: .luxury,      icon: "bathtub.fill",               cost: 25_000,  areaM2: 12, seatCapacity: 0, moraleBonus: 10,  outputBonus: 0.0,  reputationBonus: 5, unlockStage: 4),
        .init(id: 33, name: "Golf Simülatörü",  category: .luxury,      icon: "figure.golf",                cost: 30_000,  areaM2: 15, seatCapacity: 0, moraleBonus: 10,  outputBonus: 0.0,  reputationBonus: 6, unlockStage: 4),
        .init(id: 34, name: "İçki Barı",        category: .luxury,      icon: "wineglass.fill",             cost: 18_000,  areaM2: 10, seatCapacity: 0, moraleBonus: 9,   outputBonus: 0.0,  reputationBonus: 5, unlockStage: 3),
        .init(id: 35, name: "Mini Sinema",      category: .luxury,      icon: "tv.fill",                    cost: 40_000,  areaM2: 25, seatCapacity: 0, moraleBonus: 12,  outputBonus: 0.0,  reputationBonus: 6, unlockStage: 4),
        .init(id: 36, name: "Masaj Koltuğu",    category: .luxury,      icon: "figure.seated.side.right",   cost: 9_000,   areaM2: 4,  seatCapacity: 0, moraleBonus: 7,   outputBonus: 0.02, reputationBonus: 3, unlockStage: 3),
        .init(id: 37, name: "Sanat Koleksiyonu",category: .luxury,      icon: "paintpalette.fill",          cost: 50_000,  areaM2: 8,  seatCapacity: 0, moraleBonus: 6,   outputBonus: 0.0,  reputationBonus: 10, unlockStage: 5),
        .init(id: 38, name: "Çatı Terası",      category: .luxury,      icon: "sun.max.fill",               cost: 35_000,  areaM2: 40, seatCapacity: 0, moraleBonus: 11,  outputBonus: 0.0,  reputationBonus: 7, unlockStage: 4),

        // --- infra (flavor / utility) ---
        .init(id: 39, name: "Sunucu Rafı",      category: .infra,       icon: "server.rack",                cost: 6_000,   areaM2: 4,  seatCapacity: 0, moraleBonus: 0,   outputBonus: 0.04, reputationBonus: 0, unlockStage: 2),
        .init(id: 40, name: "Telefon Kabini",   category: .infra,       icon: "phone.fill",                 cost: 2_200,   areaM2: 2,  seatCapacity: 0, moraleBonus: 1,   outputBonus: 0.02, reputationBonus: 0, unlockStage: 1),
        .init(id: 41, name: "Resepsiyon Bankosu",category: .infra,      icon: "person.crop.rectangle.fill", cost: 4_000,   areaM2: 6,  seatCapacity: 0, moraleBonus: 0,   outputBonus: 0.0,  reputationBonus: 3, unlockStage: 2),
        .init(id: 42, name: "Konferans Ekranı", category: .infra,       icon: "videoprojector.fill",        cost: 5_000,   areaM2: 2,  seatCapacity: 0, moraleBonus: 0,   outputBonus: 0.03, reputationBonus: 1, unlockStage: 2),
    ]
    static func officeItem(_ id: Int) -> OfficeItemDef? { officeItems.first { $0.id == id } }

    // MARK: Pazarlama / kullanıcı edinme (gerçek-hayat SaaS metrikleri)
    static let baseCAC: Double = 7.0          // taban müşteri edinme maliyeti ($/kullanıcı, evre 0)
    static let cacStageScaling: Double = 1.25 // CAC evreyle artar (kanallar doyar, rekabet artar)
    static let marketingAbsorption: Double = 5_000 // 1 birim pazarlama-gücü bu kadar reklam harcamasını verimli yutar
    static let adBudgetStepBase: Double = 500 // bütçe ayar adımı tabanı (evreyle ölçeklenir)
}
