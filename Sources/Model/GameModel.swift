import Foundation
import Combine

/// Tek doğruluk kaynağı: şirket durumu + idle ekonomi + karar/funding/moral mantığı.
@MainActor
final class GameModel: ObservableObject {
    @Published private(set) var state: GameState

    // Geçici UI sinyalleri
    @Published var pendingEvent: DecisionCard? = nil
    @Published var pendingFundingStage: Int? = nil   // tur kutlaması
    @Published var pendingWin: Bool = false
    @Published var pendingBankruptcy: Bool = false
    @Published var pendingOfflineReport: OfflineReport? = nil
    @Published var pendingCycleReview: CycleReview? = nil   // çeyrek kapanış scorecard'ı
    @Published var pendingDailyClose: DailyClose? = nil      // günlük hedef kapanış kutlaması
    @Published var pendingSprintClose: SprintClose? = nil    // haftalık sprint kapanışı (zirve/sonuç)
    @Published var pendingSeasonFinale: SeasonFinale? = nil  // sezon finali kutlaması + kalıcı ödül
    @Published var pendingScenarioResult: ScenarioResult? = nil  // senaryo deadline sonucu (başarı/başarısızlık overlay'i)
    @Published var pendingToast: String? = nil
    @Published var pendingResult: DecisionResult? = nil   // karar sonucu kalıcı kartı (#26) + ders köprüsü
    @Published var inspectedMechanic: String? = nil       // #19: ℹ/metrik/sonuç → ilgili Defter dersi
    @Published var inspectedDept: Int? = nil   // ofiste çalışana tıklanınca açılan kart
    @Published var founderTip: String = NarrativeContent.tips.first ?? ""
    /// HUD üstünde yüzen ±tutar çipi için son ayrık nakit hareketi (kazanç/harcama).
    /// Yalnızca oyuncu eylemleri (hire/buy/raise/decision) tetikler — tick'in sürekli
    /// gelir/burn akışı GÖSTERİLMEZ (gürültü olur). UI `$lastCashDelta`'yı dinler.
    @Published var lastCashDelta: CashDeltaEvent? = nil

    private var timer: Timer?
    private var lastTick = Date()
    private var sinceAutosave: Double = 0
    private var sinceHistory: Double = 0
    private var sinceTip: Double = 0
    private var sinceDecision: Double = 0
    private var nextDecisionAt: Double = Balance.decisionMinInterval
    private var debtMonths: Double = 0

    // Şirket sağlık durum-makinesi: önceki state'i hatırla → geçişleri yakala.
    // (Persist edilmez; tick'te yeniden hesaplanır. Zincir sayacı GameState.crisisChainCount'ta tutulur.)
    private var lastHealth: CompanyHealth = .healthy

    init() {
        if let saved = SaveManager.load() {
            state = saved
        } else {
            state = GameState()
        }
        BigNumber.currency = state.currency
        applyOfflineProgress()
        seedQuarterSnapshotIfNeeded()
        seedSprintIfNeeded()
        seedCohortIfNeeded()
        refreshDailyGoalIfNeeded()
        scheduleNextDecision()
        // Şirket sağlık durum-makinesi: mevcut metriklerden ilk state'i tohumla
        // (önceki state olarak healthy — sahte geçiş tetiklenmesin).
        lastHealth = HealthSystem.evaluate(model: self, previous: .healthy)
        // Test/QA: --force-decision launch arg'ı (veya FORCE_DECISION env var) ile
        // model init sırasında kartı hemen tetikle (state-tetikli kart dağılımını gözlem için).
        let env = ProcessInfo.processInfo.environment
        if ProcessInfo.processInfo.arguments.contains("--force-decision")
            || env["FORCE_DECISION"] != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                self?.forceDecisionIfAvailable()
            }
        }
        start()
    }

    /// Çeyrek başı snapshot eksikse (yeni oyun / eski kayıt) mevcut metrikleri sabitle.
    private func seedQuarterSnapshotIfNeeded() {
        if state.quarterStartValuation <= 0 {
            captureQuarterStart()
        }
    }

    /// Yeni çeyreğin başlangıç anlık görüntüsünü al (delta/skor hesabı için).
    private func captureQuarterStart() {
        state.quarterStartMonth = state.months
        state.quarterStartUsers = state.users
        state.quarterStartValuation = valuation
        state.quarterStartMRR = mrr
        state.quarterStartDecisions = state.totalDecisions
        state.quarterMoraleSum = 0
        state.quarterMoraleSamples = 0
    }

    // MARK: - Para birimi (görüntü)

    var currency: Currency { state.currency }
    func setCurrency(_ c: Currency) {
        state.currency = c
        BigNumber.currency = c
        save()
    }

    // MARK: - Modül türetilmiş efektleri

    private struct Effects {
        var globalOutput = 0.0, growthMult = 0.0, arpuMult = 0.0
        var churnReduce = 0.0, moraleTarget = 0.0, salaryReduce = 0.0
        var infraCostReduce = 0.0, rentCostReduce = 0.0
    }

    private var effects: Effects {
        var e = Effects()
        for m in Balance.modules {
            let lvl = Double(state.moduleLevels[m.id])
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

    // MARK: - Oyun hızı (zaman hızlandırma)

    /// 1× / 2× / 3× — oyuncunun ayarladığı gerçek-zaman tempo çarpanı.
    @Published var speed: Double = 1
    /// Simülatörü duraklatma (zaman donar; tick economy/karar/moral işlemez).
    @Published var isPaused: Bool = false
    static let speedOptions: [Double] = [1, 2, 3]
    func cycleSpeed() {
        let opts = Self.speedOptions
        let idx = opts.firstIndex(of: speed) ?? 0
        speed = opts[(idx + 1) % opts.count]
        if isPaused { isPaused = false }   // hız değişimi otomatik devam ettirir
    }
    func togglePause() { isPaused.toggle() }

    // MARK: - Erişimciler

    var cash: Double { state.cash }
    var users: Double { state.users }
    var morale: Double { state.morale }
    var reputation: Double { state.reputation }
    var founderEquity: Double { state.founderEquity }
    var months: Double { state.months }
    var headcount: [Int] { state.headcount }
    var totalHeadcount: Int { state.headcount.reduce(0, +) }
    var hasSeenOnboarding: Bool { state.hasSeenOnboarding }

    func count(_ i: Int) -> Int { state.headcount[i] }

    // MARK: - Ekip üyeleri (kimlik katmanı)

    /// Tüm üyeler (kurucu + işe alınanlar). Sıra kalıcı: kurucu ilk, hire sırasıyla devam.
    var members: [TeamMember] { state.members }
    /// Bir departmandaki üyeler (UI roster için).
    func members(in deptIndex: Int) -> [TeamMember] {
        state.members.filter { $0.deptIndex == deptIndex }
    }
    /// Kurucu üyesi (her zaman vardır setup sonrası).
    var founderMember: TeamMember? { state.members.first(where: { $0.isFounder }) }
    /// Bir projeye atanmış üyeler (ProjectsPanel'de "X kişi çalışıyor" rozeti için).
    func teamMembers(forProject projectID: UUID) -> [TeamMember] {
        state.members.filter { $0.assignedProjectID == projectID }
    }
    /// Bir projeye atanmış üye sayısı (hızlı erişim — UI hot path).
    func teamSize(forProject projectID: UUID) -> Int {
        state.members.reduce(0) { $0 + ($1.assignedProjectID == projectID ? 1 : 0) }
    }
    /// Manuel atama: bir üyeyi belirli projeye (ya da nil ile boşa) at.
    func assign(memberID: UUID, toProject projectID: UUID?) {
        guard let idx = state.members.firstIndex(where: { $0.id == memberID }) else { return }
        state.members[idx].assignedProjectID = projectID
        save()
    }

    // MARK: - Ofis alanı & eşyalar (kroki + satın alma)

    var ownedItems: [Int: Int] { state.ownedItems }
    func ownedCount(_ id: Int) -> Int { state.ownedItems[id] ?? 0 }

    /// Toplam ofis alanı (evreye bağlı) m².
    var totalAreaM2: Double { Balance.officeAreaM2(stage: state.stage) }
    /// Sahip olunan eşyaların kapladığı alan m².
    var usedAreaM2: Double {
        state.ownedItems.reduce(0) { acc, kv in
            acc + (Balance.officeItem(kv.key)?.areaM2 ?? 0) * Double(kv.value)
        }
    }
    var freeAreaM2: Double { max(0, totalAreaM2 - usedAreaM2) }

    /// Masalardan gelen koltuk kapasitesi (+ makul taban). İşe alım tavanı budur.
    var seatCapacity: Int {
        let fromItems = state.ownedItems.reduce(0) { acc, kv in
            acc + (Balance.officeItem(kv.key)?.seatCapacity ?? 0) * kv.value
        }
        return Balance.baseSeatCapacity + fromItems
    }
    var seatsUsed: Int { totalHeadcount }
    var seatsFull: Bool { seatsUsed >= seatCapacity }

    /// Eşyaların moral hedefine katkısı (puan).
    private var itemMoraleBonus: Double {
        state.ownedItems.reduce(0) { acc, kv in
            acc + (Balance.officeItem(kv.key)?.moraleBonus ?? 0) * Double(kv.value)
        }
    }
    /// Eşyaların global üretim katkısı (oransal, ör. 0.05 = %5).
    private var itemOutputBonus: Double {
        state.ownedItems.reduce(0) { acc, kv in
            acc + (Balance.officeItem(kv.key)?.outputBonus ?? 0) * Double(kv.value)
        }
    }
    /// Eşyaların itibara kalıcı katkısı (puan — moraleTarget gibi tabana eklenir).
    private var itemReputationBonus: Double {
        state.ownedItems.reduce(0) { acc, kv in
            acc + (Balance.officeItem(kv.key)?.reputationBonus ?? 0) * Double(kv.value)
        }
    }

    func isItemUnlocked(_ id: Int) -> Bool {
        guard let item = Balance.officeItem(id) else { return false }
        return state.stage >= item.unlockStage
    }
    func canBuyItem(_ id: Int) -> Bool {
        guard let item = Balance.officeItem(id) else { return false }
        return state.stage >= item.unlockStage
            && state.cash >= item.cost
            && freeAreaM2 >= item.areaM2
    }

    /// Oyuncu eylemiyle tetiklenen nakit hareketini HUD'a yüzen çip olarak yayar.
    /// 1$'dan küçük gürültüleri yutar. İşaret: pozitif=kazanç, negatif=harcama.
    private func emitCashDelta(_ amount: Double) {
        guard abs(amount) >= 1 else { return }
        lastCashDelta = CashDeltaEvent(amount: amount)
    }

    @discardableResult
    func buyItem(_ id: Int) -> Bool {
        guard canBuyItem(id), let item = Balance.officeItem(id) else { return false }
        state.cash -= item.cost
        emitCashDelta(-item.cost)
        state.ownedItems[id, default: 0] += 1
        // Anlık küçük moral dokunuşu — yeni eşya hevesi (hedef zaten yukarı çeker).
        if item.moraleBonus > 0 { state.morale = min(100, state.morale + 1) }
        Feedback.tap()   // eşya alımı geri bildirimi
        save()
        return true
    }

    // MARK: - Üretim & ekonomi

    private var founderBonus: Double { 1 + min(2.0, state.founderXP * 0.05) }
    private var moraleFactor: Double { 0.5 + state.morale / 100 }   // 0.5 .. 1.5

    /// Kalıcı sezon ödülü çarpanı (1 + birikmiş, tavanlı). Sezon finali ödülü — küçük ama kalıcı.
    var seasonMultiplier: Double { SeasonSystem.totalMultiplier(seasonsCompleted: state.seasonsCompleted) }

    /// i. departmanın rol-çıktısı (moral + modül + founder + kalıcı sezon bonusu dahil).
    func deptOutput(_ i: Int) -> Double {
        let d = Balance.departments[i]
        return Double(state.headcount[i]) * d.baseOutput
            * (1 + effects.globalOutput + itemOutputBonus) * moraleFactor * founderBonus * seasonMultiplier
    }

    var devPower: Double { deptOutput(0) + 0.5 * deptOutput(1) }
    var marketingPower: Double { deptOutput(2) }
    var salesPower: Double { deptOutput(3) }
    var opsPower: Double { deptOutput(4) + 0.5 * deptOutput(1) }

    /// Ürünün taşıyabileceği kullanıcı kapasitesi (dev gücüyle ölçeklenir).
    var userCapacity: Double { max(50, devPower * 1_500) }
    private var overload: Double { max(0, state.users / userCapacity - 1) }

    var churnRate: Double {
        Balance.baseChurn * max(0.2, 1 - effects.churnReduce - opsPower * 0.01) * (1 + overload)
    }

    /// Kullanıcı başına aylık gelir (taban × evre çarpanı × modül + proje katkıları × satış gücü).
    /// Evre çarpanı: SaaS fiyatlandırma gücü/upsell modeller — Series C'de ARPU ~2× taban.
    var arpu: Double {
        Balance.baseArpu
            * Balance.arpuMultiplier(forStage: state.stage)
            * (1 + effects.arpuMult + projectArpuMult)
            * (1 + min(Balance.salesArpuCap, salesPower * Balance.salesArpuPerUnit))
    }

    var mrr: Double { state.users * arpu }

    // MARK: Büyüme — organik + ücretli (gerçek-hayat SaaS edinim modeli)

    /// Ürün/itibar kalitesi: CAC'i düşürür, organik büyümeyi destekler (0.5..~2).
    var qualityFactor: Double {
        min(2.0, 0.5 + state.reputation / 100 + min(1.0, devPower / max(1, state.users / 800)) * 0.4)
    }

    /// Reklamsız, kelime-ağızdan + pazarlama ekibi + viral organik büyüme.
    /// Yayındaki projeler büyümeye oransal katkı verir (portföy etkisi).
    var organicUserGrowthPerMonth: Double {
        marketingPower * 30 * (1 + effects.growthMult + projectGrowthMult) * (0.5 + state.reputation / 100)
            + state.users * Balance.viralFactor * (state.reputation / 50)
    }

    /// O anki müşteri edinme maliyeti ($/kullanıcı). Harcama ölçeğiyle artar (doygunluk),
    /// pazarlama ekibi ve ürün kalitesiyle düşer.
    var currentCAC: Double {
        let stageMult = pow(Balance.cacStageScaling, Double(state.stage))
        let absorb = Balance.marketingAbsorption * (1 + marketingPower * 0.4)
        let saturation = 1 + state.adBudgetPerMonth / max(1, absorb)
        return Balance.baseCAC * stageMult * saturation / qualityFactor
    }

    /// Reklam bütçesinin satın aldığı aylık yeni kullanıcı.
    var paidUserGrowthPerMonth: Double {
        guard state.adBudgetPerMonth > 0, currentCAC > 0 else { return 0 }
        return state.adBudgetPerMonth / currentCAC
    }

    var grossUserGrowthPerMonth: Double { organicUserGrowthPerMonth + paidUserGrowthPerMonth }
    var netUserGrowthPerMonth: Double { grossUserGrowthPerMonth - state.users * churnRate }

    /// Kullanıcı yaşam boyu değeri (aylık gelir / churn).
    // LTV tavanı (audit #17): churn→0'da arpu/churn patlamasını arpu×ltvMonthsCap ile sınırla.
    var ltv: Double { churnRate > 0 ? min(arpu / churnRate, arpu * Balance.ltvMonthsCap) : arpu * Balance.ltvMonthsCap }
    /// LTV / CAC oranı (sağlıklı > 3).
    var ltvCacRatio: Double { currentCAC > 0 ? ltv / currentCAC : 0 }
    /// Geri ödeme süresi (ay): CAC'i kullanıcıdan kaç ayda çıkarırsın.
    var paybackMonths: Double { arpu > 0 ? currentCAC / arpu : .infinity }

    // MARK: Giderler — maaş + kalemlere ayrılmış OpEx + reklam

    private func salary(_ i: Int) -> Double {
        Balance.departments[i].baseSalary
            * Balance.salaryMultiplier(forStage: state.stage)
            * max(0.4, 1 - effects.salaryReduce)
    }

    var payrollPerMonth: Double {
        (0..<Balance.departmentCount).reduce(0) { $0 + Double(state.headcount[$1]) * salary($1) }
    }

    /// Bir OpEx kaleminin (indirimli) aylık tutarı.
    func opexItemCost(_ i: Int) -> Double {
        let item = Balance.costItems[i]
        var c = Balance.itemMonthlyCost(item, stage: state.stage,
                                        headcount: totalHeadcount, users: state.users)
        switch item.driver {
        case .perThousandUsers: c *= max(0.2, 1 - effects.infraCostReduce)   // bulut indirimi
        case .perSeat where item.id == 0: c *= max(0.3, 1 - effects.rentCostReduce) // kira indirimi
        default: break
        }
        return c
    }

    var opexPerMonth: Double {
        (0..<Balance.costItemCount).reduce(0) { $0 + opexItemCost($1) }
    }

    /// Aylık operasyonel sabit gider (UI/eski isim uyumu için).
    var fixedCostPerMonth: Double { opexPerMonth }
    var adSpendPerMonth: Double { state.adBudgetPerMonth }

    var burnPerMonth: Double { payrollPerMonth + opexPerMonth + adSpendPerMonth }
    var revenuePerMonth: Double { mrr }
    var netPerMonth: Double { revenuePerMonth - burnPerMonth }

    /// Tüm gider kalemleri (UI dağılım grafiği için), büyükten küçüğe.
    /// costId: Balance.costItems id ile eşleşir; -1 = maaşlar, -2 = reklam (özel).
    var costBreakdown: [CostLine] {
        var lines = [CostLine(name: "Maaşlar", icon: "person.2.fill", amount: payrollPerMonth, costId: -1)]
        for item in Balance.costItems {
            lines.append(CostLine(name: item.name, icon: item.icon, amount: opexItemCost(item.id), costId: item.id))
        }
        if adSpendPerMonth > 0 {
            lines.append(CostLine(name: "Reklam Harcaması", icon: "megaphone.fill", amount: adSpendPerMonth, costId: -2))
        }
        return lines.sorted { $0.amount > $1.amount }
    }

    // MARK: - Pazarlama bütçesi ayarı

    /// Bütçe ayar adımı — ölçeğe göre büyür.
    var adBudgetStep: Double {
        Balance.adBudgetStepBase * Balance.salaryMultiplier(forStage: state.stage)
    }
    func changeAdBudget(by delta: Double) {
        state.adBudgetPerMonth = max(0, state.adBudgetPerMonth + delta)
        save()
    }
    func setAdBudget(_ value: Double) {
        state.adBudgetPerMonth = max(0, value)
        save()
    }

    /// Kaç ay daha dayanır (negatif net ise). Pozitif net ise sonsuz.
    var runwayMonths: Double {
        netPerMonth >= -0.0001 ? .infinity : state.cash / -netPerMonth
    }

    // MARK: - Şirket Sağlık Durum-Makinesi (krizler state-tetikli + zincirleme)

    /// Şirketin o anki sağlık durumu (HealthSystem'in saf değerlendirmesi).
    /// Önceki state'i hesaba katar (toparlanma sezgisi için).
    var companyHealth: CompanyHealth {
        HealthSystem.evaluate(model: self, previous: lastHealth)
    }

    /// Zincirleme kriz sayacı (kötü gidişat sürerse büyür, healthy'e dönünce sıfırlanır).
    var crisisChainCount: Int { state.crisisChainCount }

    /// Her tick'te çağrılır: health değişimini izle, geçişlerde zincir sayacını güncelle.
    /// - strained → crisis geçişi: zincir +1 (kötüleşme).
    /// - * → healthy geçişi: zincir = 0 (toparlanma tamamlandı).
    /// - crisisChainCount > 2 (uzun zincir): moral uyarısı + toast.
    private func updateHealthState() {
        let current = HealthSystem.evaluate(model: self, previous: lastHealth)
        if current != lastHealth {
            switch (lastHealth, current) {
            case (.strained, .crisis):
                // Zincirleme kötüleşme: sıkıntıdan krize geçtik.
                state.crisisChainCount += 1
                if state.crisisChainCount > 2 {
                    // Uzun zincir: moral uyarısı + oyuncuya bildirim.
                    state.morale = max(0, state.morale - 2)
                    pendingToast = "Şirket sağlığı zincirleme kötüleşiyor — krizden çıkmak için bir karar al."
                    Feedback.warning()
                }
            case (_, .healthy):
                // Toparlanma tamamlandı: zincir sıfırlanır.
                state.crisisChainCount = 0
            default:
                break
            }
            lastHealth = current
        }
    }

    var valuation: Double {
        mrr * 12 * Balance.revenueMultiple
            + state.users * Balance.perUserValue
            + devPower * 15_000
            + state.reputation * 2_000
            + max(0, state.cash) * 0.5
            + Double(liveProjectCount) * Balance.projectValuationEach   // portföy değeri
    }

    // MARK: - İşe alım / çıkarma

    func hireCost(_ i: Int) -> Double {
        Balance.departments[i].baseHireCost
            * pow(Balance.hireCostGrowth, Double(state.headcount[i]))
            * Balance.salaryMultiplier(forStage: state.stage)
    }

    /// İşe alım: nakit yeterli VE boş koltuk var. (Koltuk masalardan gelir — yeni gerçek kısıt.)
    func canHire(_ i: Int) -> Bool { state.cash >= hireCost(i) && totalHeadcount < seatCapacity }

    @discardableResult
    func hire(_ i: Int) -> Bool {
        let c = hireCost(i)
        guard state.cash >= c else { return false }
        state.cash -= c
        emitCashDelta(-c)
        state.headcount[i] += 1
        state.totalHires += 1
        state.dailyHires += 1                          // günlük hedef ilerlemesi
        state.morale = min(100, state.morale + 1.5)   // yeni ekip arkadaşı hevesi

        // Bireysel kimlik katmanı: yeni üye rastgele isimle + skill rulosu;
        // mühendislik/ürün ise en az atanmış geliştirme-aşamasındaki projeye otomatik atanır.
        let name = NarrativeContent.randomFounderName()
        var newMember = TeamMember(firstName: name.first, lastName: name.last,
                                   deptIndex: i, skillLevel: rollSkillLevel(),
                                   joinedMonth: state.months)
        if (i == 0 || i == 1), let proj = projectNeedingHelp() {
            newMember.assignedProjectID = proj.id
        }
        state.members.append(newMember)

        setTip(NarrativeContent.onHire)
        Feedback.tap()   // işe alım geri bildirimi
        checkDailyCompletion()
        save()
        return true
    }

    /// Yeni hire'ın beceri seviyesi rulosu (1-5). Çoğu L1-L2, nadiren L4-L5 — kozmetik.
    /// Ekonomi formüllerini ETKİLEMEZ (skill SADECE UI rozeti içindir).
    private func rollSkillLevel() -> Int {
        let r = Double.random(in: 0..<1)
        if r < 0.55 { return 1 }
        if r < 0.85 { return 2 }
        if r < 0.96 { return 3 }
        if r < 0.995 { return 4 }
        return 5
    }

    /// En az atanmış geliştirme-aşamasındaki proje (otomatik dağılım için).
    /// Tüm projeler ya yayında ya da boşsa nil — yeni üye proje atanmaz.
    private func projectNeedingHelp() -> ProjectState? {
        let inDev = state.projects.filter { !$0.isLive }
        guard !inDev.isEmpty else { return nil }
        return inDev.min(by: { teamSize(forProject: $0.id) < teamSize(forProject: $1.id) })
    }

    @discardableResult
    func fire(_ i: Int) -> Bool {
        guard state.headcount[i] > 0 else { return false }
        // Kurucu KORUNUR: bu departmandaki son hire'lanan kurucu-olmayan üyeyi çıkar.
        // Sadece kurucu varsa fire başarısız (oyuncu kendini çıkaramaz).
        guard let idx = state.members.lastIndex(where: { $0.deptIndex == i && !$0.isFounder }) else {
            return false
        }
        state.members.remove(at: idx)
        state.headcount[i] -= 1
        state.morale = max(0, state.morale - 6)        // işten çıkarma morali bozar
        state.reputation = max(0, state.reputation - 2)
        save()
        return true
    }

    // MARK: - Modüller

    func moduleLevel(_ i: Int) -> Int { state.moduleLevels[i] }
    func isModuleMaxed(_ i: Int) -> Bool { state.moduleLevels[i] >= Balance.modules[i].maxLevel }
    func isModuleUnlocked(_ i: Int) -> Bool { state.stage >= Balance.modules[i].unlockStage }

    func moduleCost(_ i: Int) -> Double {
        let m = Balance.modules[i]
        return m.baseCost * pow(m.costGrowth, Double(state.moduleLevels[i]))
    }

    func canBuyModule(_ i: Int) -> Bool {
        isModuleUnlocked(i) && !isModuleMaxed(i) && state.cash >= moduleCost(i)
    }

    @discardableResult
    func buyModule(_ i: Int) -> Bool {
        guard canBuyModule(i) else { return false }
        let c = moduleCost(i)
        state.cash -= c
        emitCashDelta(-c)
        state.moduleLevels[i] += 1
        save()
        return true
    }

    // MARK: - Funding evreleri

    var currentStage: StageDef { Balance.stages[state.stage] }
    var nextStage: StageDef? {
        state.stage + 1 < Balance.stageCount ? Balance.stages[state.stage + 1] : nil
    }
    var canRaise: Bool {
        guard let next = nextStage else { return false }
        return valuation >= next.valuationTarget
    }

    /// Bir sonraki tura ilerleme (0-1).
    var raiseProgress: Double {
        guard let next = nextStage, next.valuationTarget > 0 else { return 1 }
        return min(1, valuation / next.valuationTarget)
    }

    @discardableResult
    func raiseRound() -> Bool {
        guard canRaise, let next = nextStage else { return false }
        state.cash += next.raiseAmount
        emitCashDelta(next.raiseAmount)
        state.founderEquity *= (1 - next.equityGiven)
        state.stage += 1
        state.stageReached = max(state.stageReached, state.stage)
        state.morale = min(100, state.morale + 10)
        state.reputation = min(100, state.reputation + 15)
        save()
        if state.stage == Balance.stageCount - 1 {
            pendingWin = true
        } else {
            pendingFundingStage = state.stage
        }
        Feedback.celebrate()   // tur toplama / win kutlaması
        return true
    }

    func dismissFunding() { pendingFundingStage = nil }
    func dismissWin() { pendingWin = false }

    // MARK: - Startup Ligleri + Çeyrek değerlendirmesi (completed-cycle)

    var leagueTier: Int { state.leagueTier }
    var currentLeague: LeagueDef { LeagueSystem.league(state.leagueTier) }
    var quarterNumber: Int { state.quarterIndex + 1 }   // 1'den gösterilir

    /// Mevcut çeyreğin ilerlemesi (0-1) — HUD/Yol rozetinde küçük halka.
    var quarterProgress: Double {
        let elapsed = state.months - state.quarterStartMonth
        return min(1, max(0, elapsed / Balance.monthsPerQuarter))
    }

    // MARK: Rakip Kohort + Canlı Leaderboard (gerçek bahis)

    /// Oyuncunun bu ANA kadarki çeyrek performans skoru (canlı leaderboard için).
    /// closeQuarter ile aynı formül; günlük/sprint bonusu dahil, 0-100.
    var liveQuarterScore: Double {
        let avgMorale = state.quarterMoraleSamples > 0
            ? state.quarterMoraleSum / state.quarterMoraleSamples
            : state.morale
        let start = LeagueSystem.Snapshot(users: state.quarterStartUsers,
                                          valuation: state.quarterStartValuation,
                                          mrr: state.quarterStartMRR,
                                          decisions: state.quarterStartDecisions)
        let end = LeagueSystem.Snapshot(users: state.users,
                                        valuation: valuation, mrr: mrr,
                                        decisions: state.totalDecisions)
        let b = LeagueSystem.evaluate(start: start, end: end, avgMorale: avgMorale)
        let dailyBonus = DailyGoalSystem.leagueScoreBonus(
            streak: state.streak, dailyGoalsThisQuarter: state.dailyGoalsThisQuarter)
        let sprintBonus = SprintSystem.leagueScoreBonus(
            sprintsWonThisQuarter: state.sprintsWonThisQuarter)
        return min(100, b.score + dailyBonus + sprintBonus)
    }

    /// Oyuncu ekran adı (leaderboard'da gösterilir) — kuruluşta girilen şirket adı.
    var playerCompanyName: String {
        state.profile.companyName.isEmpty ? "Sen · \(currentStage.name)" : state.profile.companyName
    }

    /// Canlı standings: oyuncu + rakipler, çeyrek skoruna göre sıralı (her tick güncel).
    /// Rakipler artık sektör+kurucu+proje alt-satırıyla zengin (StandingEntry.subtitle).
    var liveStandings: [StandingEntry] {
        CohortSystem.standings(playerScore: liveQuarterScore,
                               playerName: playerCompanyName,
                               competitors: state.cohortCompetitors)
    }

    /// Toplam kohort büyüklüğü (oyuncu dahil).
    var cohortTotal: Int { state.cohortCompetitors.count + 1 }
    /// İlk N terfi eşiği (en üst ligde terfi yok → 0).
    var promoteCutoff: Int {
        state.leagueTier >= LeagueSystem.leagueCount - 1 ? 0 : CohortSystem.promoteTopN
    }
    /// Son N düşüş eşiği (en alt ligde düşüş yok → 0).
    var demoteCutoff: Int {
        state.leagueTier <= 0 ? 0 : CohortSystem.demoteBottomN
    }

    /// Kohort hiç yoksa ya da lig değiştiyse taze kohort tohumla (çeyrek başı dili).
    private func seedCohortIfNeeded() {
        if state.cohortCompetitors.isEmpty || state.cohortTier != state.leagueTier {
            regenerateCohort()
        }
    }

    /// Oyuncunun mevcut ligine uygun güçte taze rakip kohort üret (yeni hafta gibi).
    /// Her rakip: ad + sektör + kurucu ad/soyad + flagship proje + canlı skor.
    private func regenerateCohort() {
        state.cohortCompetitors = CohortSystem.freshCompetitors(tier: state.leagueTier)
        state.cohortTier = state.leagueTier
        // Eski paralel dizileri temizle (kafa karışıklığı + ileride drop edilebilir).
        state.cohortNames.removeAll()
        state.cohortScores.removeAll()
    }

    /// Bir tick'te rakip skorlarını oyun temposuyla ilerlet (canlı leaderboard).
    private func advanceCohort(_ dt: Double) {
        guard !state.cohortCompetitors.isEmpty else { return }
        state.cohortCompetitors = CohortSystem.advancedCompetitors(
            state.cohortCompetitors, tier: state.leagueTier,
            progress: quarterProgress, dt: dt)
    }

    /// Çeyrek dolduysa kapanışı tetikle (overlay açılır, oyun mantığı duraklamaz).
    private func maybeCloseQuarter() {
        // Diğer modal'lar açıkken çeyrek kapanışını beklet (üst üste binmesin).
        guard pendingCycleReview == nil, pendingFundingStage == nil,
              !pendingWin, !pendingBankruptcy else { return }
        guard state.months - state.quarterStartMonth >= Balance.monthsPerQuarter else { return }
        closeQuarter()
    }

    private func closeQuarter() {
        let avgMorale = state.quarterMoraleSamples > 0
            ? state.quarterMoraleSum / state.quarterMoraleSamples
            : state.morale

        let start = LeagueSystem.Snapshot(users: state.quarterStartUsers,
                                          valuation: state.quarterStartValuation,
                                          mrr: state.quarterStartMRR,
                                          decisions: state.quarterStartDecisions)
        let end = LeagueSystem.Snapshot(users: state.users,
                                        valuation: valuation,
                                        mrr: mrr,
                                        decisions: state.totalDecisions)
        var breakdown = LeagueSystem.evaluate(start: start, end: end, avgMorale: avgMorale)

        // Streak + bu çeyrekteki günlük hedef tamamlamaları skora küçük katkı verir
        // (completed-cycle zinciri: günlük döngü → çeyrek döngü). Tavanlı, skor 0-100'de kalır.
        let dailyBonus = DailyGoalSystem.leagueScoreBonus(
            streak: state.streak, dailyGoalsThisQuarter: state.dailyGoalsThisQuarter)
        // Bu çeyrekte kazanılan haftalık sprint'ler de skora küçük katkı verir
        // (completed-cycle zinciri: sprint döngüsü → çeyrek döngü). Tavanlı.
        let sprintBonus = SprintSystem.leagueScoreBonus(
            sprintsWonThisQuarter: state.sprintsWonThisQuarter)
        breakdown.streakBonus = dailyBonus + sprintBonus
        breakdown.score = min(100, breakdown.score + dailyBonus + sprintBonus)

        // Rakip kohortla SIRALAMA — gerçek bahis: oyuncu + rakipler çeyrek skoruna göre
        // sıralanır, terfi/düşüş sıraya göre belirlenir (ilk N terfi, son N düşer).
        let standings = CohortSystem.standings(playerScore: breakdown.score,
                                               playerName: playerCompanyName,
                                               competitors: state.cohortCompetitors)
        let rank = CohortSystem.playerRank(in: standings)
        let outcome = CohortSystem.outcome(rank: rank, total: standings.count,
                                           tier: state.leagueTier,
                                           topTier: LeagueSystem.leagueCount - 1)

        let move: LeagueSystem.Movement
        let fromTier = state.leagueTier
        switch outcome {
        case .promote:
            move = .promote
            state.leagueTier = min(LeagueSystem.leagueCount - 1, state.leagueTier + 1)
            // Küçük prestij ödülü — ekonomiyi bozmaz (nakit enjeksiyonu yok).
            state.morale = min(100, state.morale + Balance.promoteMoraleBonus)
            state.reputation = min(100, state.reputation + Balance.promoteReputationBonus)
            state.seasonPromotions += 1   // sezon finali özeti için terfi sayacı
        case .demote:
            move = .demote
            state.leagueTier = max(0, state.leagueTier - 1)
        case .stay:
            move = .stay
        }

        // Sezon birikimi (finale özeti için): bu çeyreğin skoru + sezonun en yüksek ligi.
        state.seasonScoreSum += breakdown.score
        state.seasonHighestTier = max(state.seasonHighestTier, state.leagueTier)

        pendingCycleReview = CycleReview(quarter: quarterNumber,
                                         breakdown: breakdown,
                                         movement: move,
                                         fromTier: fromTier,
                                         toTier: state.leagueTier,
                                         standings: standings,
                                         playerRank: rank)
        // Çeyrek kapanışı: terfi → kutlama, düşüş → uyarı, sabit → tok kapanış.
        switch outcome {
        case .promote: Feedback.celebrate()
        case .demote:  Feedback.warning()
        case .stay:    Feedback.close()
        }
        save()
    }

    /// "Yeni Çeyrek" — taze çeyrek başlat, snapshot sıfırla. Sezon doluysa finale tetikle.
    func startNextQuarter() {
        state.quarterIndex += 1

        // Sezon birikimi: bu çeyrekte kazanılan sprint + günlük hedefleri sezon toplamına ekle
        // (çeyrek sayaçları aşağıda sıfırlanmadan önce — completed-cycle zinciri: çeyrek → sezon).
        state.seasonSprintsWon += state.sprintsWonThisQuarter
        state.seasonDailyGoals += state.dailyGoalsThisQuarter
        state.quartersThisSeason += 1

        captureQuarterStart()
        state.dailyGoalsThisQuarter = 0   // çeyrek başı: günlük tamamlama sayacı sıfırlanır
        state.sprintsWonThisQuarter = 0   // çeyrek başı: sprint zafer sayacı sıfırlanır
        regenerateCohort()                // çeyrek başı: yeni ligine uygun taze rakip kohort
        pendingCycleReview = nil

        // Sezon doldu mu? (Balance.quartersPerSeason çeyrek kapanışı = 1 sezon)
        // Doluysa görkemli sezon finalini tetikle (overlay, kalıcı ödül "Yeni Sezon"da uygulanır).
        if state.quartersThisSeason >= Balance.quartersPerSeason {
            closeSeason()
        }
        save()
    }

    // MARK: - Sezon Finali + Kalıcı Ödül (uzun-vade tamamlanma)

    var seasonNumber: Int { state.seasonIndex + 1 }       // 1'den gösterilir (mevcut sezon)
    var seasonsCompleted: Int { state.seasonsCompleted }
    /// Bu sezonda kapanan çeyrek ilerlemesi (0-1) — HUD/Yol göstergesi için.
    var seasonProgress: Double {
        min(1, max(0, Double(state.quartersThisSeason) / Double(Balance.quartersPerSeason)))
    }
    /// Şu ana kadar kazanılan en yüksek sezon ünvanı (koleksiyon başlığı).
    var currentSeasonTitle: SeasonTitleDef {
        SeasonSystem.title(forSeason: max(1, state.seasonsCompleted))
    }

    /// Sezon doldu: birikmiş özeti hesapla + görkemli finale overlay'ini tetikle.
    /// Kalıcı ödül burada DEĞİL, "Yeni Sezon" (startNextSeason) ile uygulanır.
    private func closeSeason() {
        let earnedSeason = state.seasonIndex + 1   // bitirilen sezon numarası (1'den)
        let avgScore = state.quartersThisSeason > 0
            ? state.seasonScoreSum / Double(state.quartersThisSeason) : 0
        let summary = SeasonSystem.Summary(quarters: state.quartersThisSeason,
                                           promotions: state.seasonPromotions,
                                           highestTier: state.seasonHighestTier,
                                           sprintsWon: state.seasonSprintsWon,
                                           dailyGoals: state.seasonDailyGoals,
                                           avgScore: avgScore)
        pendingSeasonFinale = SeasonFinale(
            season: earnedSeason,
            summary: summary,
            title: SeasonSystem.title(forSeason: earnedSeason),
            bonusGained: SeasonSystem.bonusForCompleting(season: earnedSeason),
            totalBonusAfter: SeasonSystem.totalMultiplier(seasonsCompleted: earnedSeason) - 1)
        Feedback.celebrate()   // sezon finali — görkemli kutlama
    }

    /// "Yeni Sezon" — KALICI ödülü uygula (çarpan + ünvan koleksiyonu) + sezon sayaçlarını sıfırla.
    func startNextSeason() {
        // Kalıcı ödül: bitirilen sezon sayılır (çarpan + ünvan kalıcıdır, sonraki sezonlara taşınır).
        state.seasonsCompleted += 1
        state.seasonIndex += 1
        // Küçük kutlama dokunuşu (nakit YOK — ekonomi korunur; kalıcı çarpan zaten uygulandı).
        state.morale = min(100, state.morale + Balance.seasonFinaleMoraleBonus)
        state.reputation = min(100, state.reputation + Balance.seasonFinaleReputationBonus)

        // Yeni sezon: birikmiş özet sayaçlarını sıfırla (çarpan/ünvan kalıcı kalır).
        state.quartersThisSeason = 0
        state.seasonPromotions = 0
        state.seasonHighestTier = state.leagueTier
        state.seasonSprintsWon = 0
        state.seasonDailyGoals = 0
        state.seasonScoreSum = 0

        pendingSeasonFinale = nil
        save()
    }

    // MARK: - Günlük Hedef + Streak (geri-dönüş kancası, completed-cycle)

    var streak: Int { state.streak }
    var bestStreak: Int { state.bestStreak }
    var dailyCompleted: Bool { state.dailyCompleted }

    /// Bugünün görev seti (gerçek takvim gününe göre — DailyGoalSystem).
    var dailyTasks: [DailyTask] {
        DailyGoalSystem.tasks(dayKey: state.dailyDayKey, users: state.users, stage: state.stage)
    }

    /// Bir alt görevin o anki ilerlemesi (tamamlanan / hedef).
    func dailyProgress(_ task: DailyTask) -> (done: Int, target: Int) {
        let done: Int
        switch task.kind {
        case .hire:     done = state.dailyHires
        case .decision: done = state.dailyDecisions
        case .users:    done = max(0, Int(state.users - state.dailyUsersStart))
        }
        return (min(done, task.target), task.target)
    }

    func dailyTaskDone(_ task: DailyTask) -> Bool {
        let p = dailyProgress(task)
        return p.done >= p.target
    }

    /// Tamamlanan alt görev sayısı / toplam (kart üst rozeti için).
    var dailyTaskCounts: (done: Int, total: Int) {
        let tasks = dailyTasks
        let done = tasks.filter { dailyTaskDone($0) }.count
        return (done, tasks.count)
    }

    /// Streak'in moral hedefine kalıcı katkısı (puan).
    private var streakMoraleBonus: Double { DailyGoalSystem.streakMoraleBonus(state.streak) }

    /// Gün değiştiyse (gerçek tarih) günlük hedefi yenile + streak'i hesapla.
    /// Eski kayıt / ilk açılış: bugünü tohumla, streak'e dokunma.
    private func refreshDailyGoalIfNeeded() {
        let today = DailyGoalSystem.dayKey()
        // İlk kez (eski kayıt / yeni oyun): bugünü sabitle, snapshot al.
        if state.dailyDayKey == 0 {
            state.dailyDayKey = today
            state.dailyUsersStart = state.users
            state.dailyHires = 0
            state.dailyDecisions = 0
            state.dailyCompleted = false
            return
        }
        guard today != state.dailyDayKey else { return }   // aynı gün — değişme

        // Gün değişti: streak'i dünkü tamamlamaya + gün farkına göre güncelle.
        let gap = today - state.dailyDayKey
        state.streak = DailyGoalSystem.rolledStreak(previousStreak: state.streak,
                                                    dayGap: gap,
                                                    yesterdayCompleted: state.dailyCompleted)
        state.bestStreak = max(state.bestStreak, state.streak)

        // Yeni gün: sayaçları sıfırla, snapshot al.
        state.dailyDayKey = today
        state.dailyUsersStart = state.users
        state.dailyHires = 0
        state.dailyDecisions = 0
        state.dailyCompleted = false
        save()
    }

    /// Bir aksiyon sonrası günlük hedefin tamamlanıp tamamlanmadığını kontrol et;
    /// tamamlandıysa KAPANIŞ anı: streak +1, küçük moral/itibar ödülü, kutlama.
    private func checkDailyCompletion() {
        guard !state.dailyCompleted else { return }
        let tasks = dailyTasks
        guard tasks.allSatisfy({ dailyTaskDone($0) }) else { return }

        state.dailyCompleted = true
        state.streak += 1                                   // bugünü tamamladın → streak ilerler
        state.bestStreak = max(state.bestStreak, state.streak)
        state.dailyGoalsThisQuarter += 1                    // lige besleme sayacı

        // Ödül: küçük moral + itibar (nakit YOK — ekonomi korunur). Streak katkısı moralTarget'tan.
        state.morale = min(100, state.morale + Balance.dailyCompleteMoraleBonus)
        state.reputation = min(100, state.reputation + Balance.dailyCompleteReputationBonus)

        pendingDailyClose = DailyClose(streak: state.streak,
                                       streakMoraleBonus: streakMoraleBonus)
        Feedback.success()   // günlük hedef kapanışı / kutlama
        save()
    }

    func dismissDailyClose() { pendingDailyClose = nil }

    // MARK: - Haftalık Sprint (çeyrek içi kısa, kapanan döngü — completed-cycle)

    var sprintNumber: Int { state.sprintIndex }   // 1'den gösterilir (başlatılınca >=1)
    var sprintsWonThisQuarter: Int { state.sprintsWonThisQuarter }

    /// Aktif sprint hedefi (GameState'te saklı tür+değerden türetilir).
    var sprintGoal: SprintGoal {
        let kind = SprintGoalKind(rawValue: state.sprintGoalKind) ?? .mrr
        return SprintGoal(kind: kind, target: state.sprintGoalTarget)
    }

    /// Aktif sprint'in hedefe göre ilerlemesi (0-1) + gösterim done/target.
    var sprintProgress: (fraction: Double, done: Double, target: Double) {
        SprintSystem.evaluate(goal: sprintGoal,
                              startMRR: state.sprintStartMRR, currentMRR: mrr,
                              startUsers: state.sprintStartUsers, currentUsers: state.users,
                              startDecisions: state.sprintStartDecisions, currentDecisions: state.totalDecisions)
    }

    /// Sprint süresinin geçen oranı (0-1) — kalan süre göstergesi.
    var sprintTimeProgress: Double {
        let elapsed = state.months - state.sprintStartMonth
        return min(1, max(0, elapsed / Balance.monthsPerSprint))
    }

    /// Kalan sprint süresi (gerçek saniye) — kart "kalan süre" şeridi için.
    var sprintSecondsRemaining: Double {
        let remainingMonths = max(0, Balance.monthsPerSprint - (state.months - state.sprintStartMonth))
        let secs = remainingMonths * Balance.secondsPerMonth / max(0.0001, speed)
        return secs
    }

    /// Sprint hedefi şu an karşılanmış mı (kapanmadan da "yolunda" göstergesi).
    var sprintOnTrack: Bool { sprintProgress.fraction >= 1 }

    /// Sprint hiç başlatılmadıysa (yeni oyun / eski kayıt) ilk sprint'i seç.
    private func seedSprintIfNeeded() {
        if state.sprintIndex == 0 || state.sprintGoalTarget <= 0 {
            startNewSprint()
        }
    }

    /// Yeni sprint başlat: ölçeğe göre net + tamamlanabilir hedef seç, snapshot al.
    private func startNewSprint() {
        state.sprintIndex += 1
        state.sprintStartMonth = state.months
        state.sprintStartMRR = mrr
        state.sprintStartUsers = state.users
        state.sprintStartDecisions = state.totalDecisions
        let goal = SprintSystem.goal(sprintIndex: state.sprintIndex - 1,
                                     mrrAtStart: mrr, users: state.users, stage: state.stage)
        state.sprintGoalKind = goal.kind.rawValue
        state.sprintGoalTarget = goal.target
    }

    /// Sprint süresi dolduysa kapanışı tetikle (her zaman SONUÇ — başarılı/başarısız).
    private func maybeCloseSprint() {
        // Diğer kapanış modal'ları açıkken sprint kapanışını beklet (üst üste binmesin).
        guard pendingSprintClose == nil, pendingCycleReview == nil,
              pendingFundingStage == nil, !pendingWin, !pendingBankruptcy else { return }
        guard state.sprintGoalTarget > 0 else { return }
        guard state.months - state.sprintStartMonth >= Balance.monthsPerSprint else { return }
        closeSprint()
    }

    private func closeSprint() {
        let goal = sprintGoal
        let result = sprintProgress
        let success = result.fraction >= 1

        if success {
            state.sprintsWonThisQuarter += 1
            // Başarı ödülü: küçük moral + itibar (nakit YOK — ekonomi korunur).
            state.morale = min(100, state.morale + Balance.sprintWinMoraleBonus)
            state.reputation = min(100, state.reputation + Balance.sprintWinReputationBonus)
        }

        // En KÜÇÜK döngü olarak sprint EN HAFİF dokunuş olmalı: engelleyici modal +
        // elle "Yeni Sprint" tıklaması artık YOK (spam'in kaynağıydı). Sonucu sağ-üst
        // sessiz toast olarak göster ve hemen taze sprint başlat — akış kesilmez.
        // (Daha büyük döngüler — çeyrek/sezon — blocking modal olmaya devam eder.)
        pendingToast = success
            ? "Sprint \(state.sprintIndex) tamam · \(goal.title) — hedefe ulaştın!"
            : "Sprint \(state.sprintIndex) kapandı · hedef tutmadı, yeni sprint başladı."
        if success { Feedback.success() } else { Feedback.select() }
        startNewSprint()   // otomatik ilerle
        save()
    }

    /// "Yeni Sprint" — kapanışı kapat + taze sprint başlat.
    func startNextSprint() {
        pendingSprintClose = nil
        startNewSprint()
        save()
    }

    // MARK: - Programlı senaryolar (anlatısal, geri-sayımlı kaynak yönetimi)

    var scenarios: [ScenarioInstance] { state.scenarios }
    /// Aktif (sonuçlanmamış) senaryolar — UI listesi için.
    var activeScenarios: [ScenarioInstance] { state.scenarios.filter { !$0.settled } }

    /// Bir senaryo için şu anki metrik ilerlemesi (0..1) — UI bar için.
    func progress(for scenario: ScenarioInstance) -> Double {
        ScenarioSystem.progress(for: scenario.scenarioKind,
                                target: scenario.goalTargetValue,
                                snapshot: scenarioSnapshot)
    }
    /// Bir senaryonun şu anki ham metrik değeri (UI etiket için).
    func currentMetricValue(for scenario: ScenarioInstance) -> Double {
        ScenarioSystem.currentValue(for: scenario.scenarioKind, snapshot: scenarioSnapshot)
    }
    /// Bir senaryonun deadline'a kalan oyun-ayı (negatif ise geçmiş).
    func monthsRemaining(for scenario: ScenarioInstance) -> Double {
        scenario.deadlineMonth - state.months
    }
    /// Bir senaryonun deadline'a kalan gerçek saniye (HUD/sn göstergesi için).
    func secondsRemaining(for scenario: ScenarioInstance) -> Double {
        let m = max(0, monthsRemaining(for: scenario))
        return m * Balance.secondsPerMonth / max(0.0001, speed)
    }

    /// Şu anki ekonomik snapshot — ScenarioSystem'in saf değerlendirmesi için DTO.
    private var scenarioSnapshot: ScenarioSystem.Snapshot {
        ScenarioSystem.Snapshot(valuation: valuation,
                                reputation: state.reputation,
                                users: state.users,
                                mrr: mrr,
                                morale: state.morale,
                                liveProjects: liveProjectCount,
                                valuationFloor: Balance.scenarioValuationFloor(stage: state.stage))
    }

    /// Aralık geçti + aktif sayısı tavanda değil + setup tamamlandı → yeni senaryo aç.
    /// Modal/kutlama açıkken bekletir (overlay çakışması olmasın).
    private func maybeSpawnScenario() {
        guard state.profile.setupComplete else { return }
        guard pendingScenarioResult == nil, pendingFundingStage == nil,
              !pendingWin, !pendingBankruptcy else { return }
        guard activeScenarios.count < Balance.maxActiveScenarios else { return }
        let sinceLast = state.months - state.scenarioLastSpawnMonth
        // İlk spawn için lastSpawnMonth=0 ise kuruluştan itibaren aralığa göre.
        guard sinceLast >= Balance.scenarioSpawnIntervalMonths else { return }

        let kind = ScenarioSystem.pickKind(stage: state.stage, active: activeScenarios)
        let target = ScenarioSystem.targetValue(for: kind, snapshot: scenarioSnapshot)
        let instance = ScenarioInstance(
            kind: kind.rawValue,
            startMonth: state.months,
            deadlineMonth: state.months + Balance.scenarioLeadMonths,
            goalTargetValue: target)
        state.scenarios.append(instance)
        state.scenarioLastSpawnMonth = state.months
        pendingToast = "Yeni hedef: \(kind.displayName) — \(Int(Balance.scenarioLeadMonths)) ay sonra."
        save()
    }

    /// Deadline geçen senaryoları değerlendir → ödül/ceza uygula → result overlay tetikle.
    /// Aynı tick'te birden çok senaryo settle olabilir; ilki UI'a düşer, diğerleri sonraki tick'te.
    private func maybeSettleScenarios() {
        guard pendingScenarioResult == nil else { return }
        guard let idx = state.scenarios.firstIndex(where: {
            !$0.settled && state.months >= $0.deadlineMonth
        }) else { return }

        var s = state.scenarios[idx]
        let success = ScenarioSystem.evaluate(s, snapshot: scenarioSnapshot)
        let reward = ScenarioSystem.reward(for: s.scenarioKind, success: success,
                                           snapshot: scenarioSnapshot)
        // Ödül/ceza uygula (nakit emit dahil — HUD'da çip görünür).
        if reward.cash != 0 {
            state.cash += reward.cash
            emitCashDelta(reward.cash)
        }
        if reward.reputation != 0 {
            state.reputation = min(100, max(0, state.reputation + reward.reputation))
        }
        if reward.morale != 0 {
            state.morale = min(100, max(0, state.morale + reward.morale))
        }
        if reward.usersPercent != 0 {
            state.users = max(0, state.users * (1 + reward.usersPercent))
        }
        s.settled = true
        s.succeeded = success
        state.scenarios[idx] = s

        pendingScenarioResult = ScenarioResult(scenario: s, success: success, reward: reward)
        save()
    }

    /// Sonuç overlay'ini kapat + settled senaryoyu listeden temizle (kalıcı saklanmasın).
    func dismissScenarioResult() {
        guard let result = pendingScenarioResult else { return }
        state.scenarios.removeAll { $0.id == result.scenario.id }
        pendingScenarioResult = nil
        save()
    }

    // MARK: - Kararlar (event kartları)

    private func scheduleNextDecision() {
        nextDecisionAt = Double.random(in: Balance.decisionMinInterval...Balance.decisionMaxInterval)
        sinceDecision = 0
    }

    private func maybeTriggerDecision() {
        guard pendingEvent == nil, pendingFundingStage == nil, !pendingWin, !pendingBankruptcy else { return }
        guard sinceDecision >= nextDecisionAt else { return }
        guard let card = DecisionSystem.pick(for: self, state: state) else {
            sinceDecision = 0   // uygun kart yok, biraz sonra tekrar dene
            return
        }
        pendingEvent = card
        Feedback.decision()   // karar kartı geldi
    }

    /// Acil/kriz kartını hemen tetikle (örn. düşük runway).
    func forceDecisionIfAvailable() {
        guard pendingEvent == nil else { return }
        if let card = DecisionSystem.pick(for: self, state: state) {
            pendingEvent = card
            Feedback.decision()   // acil karar kartı geldi
        }
    }

    func resolve(_ choice: DecisionChoice) {
        guard let card = pendingEvent else { return }
        for effect in choice.effects { apply(effect) }
        if card.once || !state.seenEventIDs.contains(card.id) {
            state.seenEventIDs.append(card.id)
        }
        let wasFirstDecision = (state.totalDecisions == 0)   // HZ-1 tebriği için (artıştan ÖNCE)
        state.totalDecisions += 1
        state.dailyDecisions += 1                       // günlük hedef ilerlemesi
        pendingEvent = nil
        scheduleNextDecision()
        // #26: sonuç artık 3.5sn toast'ta UÇMUYOR — kalıcı, kapatılabilir bir kartta
        // gösterilir + "ilgili ders" köprüsü taşır (en zengin eğitici içerik korunur).
        if let line = choice.resultLine {
            // HZ-1: ilk kararda tebriği sonuç kartına ekle (tek yüzey — toast z-order
            // çakışması olmadan, suçlamasız "ilk bahsini koydun" dokunuşu).
            let text = wasFirstDecision ? line + "\n\n" + NarrativeContent.firstDecisionPraise : line
            pendingResult = DecisionResult(text: text,
                                           speaker: card.speaker,
                                           categoryRaw: card.category.rawValue,
                                           mechanic: card.category.lessonMechanic)
        } else if wasFirstDecision {
            pendingToast = NarrativeContent.firstDecisionPraise
        }
        Feedback.tap()   // karar verildi
        clamp()
        checkDailyCompletion()
        save()
    }

    private func apply(_ e: DecisionEffect) {
        switch e {
        case .cash(let v):              state.cash += v; emitCashDelta(v)
        case .cashPercent(let p):
            let delta = state.cash * p
            state.cash += delta
            emitCashDelta(delta)
        case .users(let v):             state.users = max(0, state.users + v)
        case .usersPercent(let p):      state.users = max(0, state.users * (1 + p))
        case .morale(let v):            state.morale += v
        case .reputation(let v):        state.reputation += v
        case .moraleTargetBonus(let v): state.moraleTargetBonus += v
        case .equity(let v):            state.founderEquity = min(1, max(0, state.founderEquity + v))
        case .headcount(let dept, let d):
            let idx = min(max(0, dept), Balance.departmentCount - 1)
            state.headcount[idx] = max(0, state.headcount[idx] + d)
        }
    }

    // MARK: - Moral & istifa

    private var moraleTarget: Double {
        var t = Balance.baseMoraleTarget + effects.moraleTarget + state.moraleTargetBonus + itemMoraleBonus
        t += streakMoraleBonus   // streak büyüdükçe küçük artan moral hedefi (tavanlı)
        if state.cash < 0 { t -= Balance.unpaidMoralePenalty }
        // Aşırı yük: kapasitenin çok üstündeyse ekip yorulur
        t -= overload * 15
        return min(100, max(0, t))
    }

    private func updateMorale(_ dt: Double) {
        let target = moraleTarget
        state.morale += (target - state.morale) * Balance.moraleAdjustRate * dt
        state.morale = min(100, max(0, state.morale))
    }

    private func maybeQuit(_ dt: Double) {
        guard state.morale < Balance.quitMoraleThreshold, totalHeadcount > 1 else { return }
        let severity = (Balance.quitMoraleThreshold - state.morale) / Balance.quitMoraleThreshold
        let probPerSec = severity * 0.03
        if Double.random(in: 0...1) < probPerSec * dt * 60 {
            // rastgele dolu bir departmandan biri ayrılır
            let filled = (0..<Balance.departmentCount).filter { state.headcount[$0] > 0 }
            if let dept = filled.randomElement() {
                state.headcount[dept] -= 1
                state.reputation = max(0, state.reputation - 1)
                pendingToast = "\(Balance.departments[dept].name) ekibinden biri istifa etti."
                Feedback.warning()   // istifa — kritik uyarı
            }
        }
    }

    // MARK: - İflas

    var isBankruptcyImminent: Bool { state.cash < 0 && runwayMonths < 0 }

    private func checkBankruptcy() {
        if debtMonths > 2 || totalHeadcount == 0 {
            triggerBankruptcy()
        }
    }

    private func triggerBankruptcy() {
        guard !pendingBankruptcy else { return }
        pendingBankruptcy = true
        Feedback.failure()   // iflas
        // Founder XP = ulaşılan en yüksek evre + değerlemeden öğrenilen ders
        state.founderXP += Double(state.stageReached) + 1
        state.bankruptcies += 1
        save()
    }

    func restartAfterBankruptcy() {
        let xp = state.founderXP
        let reached = state.stageReached
        let bankruptcies = state.bankruptcies
        let profile = state.profile        // aynı kurucu yeniden kurar (kimlik korunur)
        let firstProject = state.projects.first
        var fresh = GameState()
        fresh.founderXP = xp
        fresh.stageReached = reached
        fresh.bankruptcies = bankruptcies
        fresh.cash = Balance.startCash * (1 + xp * 0.1)   // tecrübe = daha iyi başlangıç
        fresh.hasSeenOnboarding = true
        // Kimliği koru: kuruluşu tekrar istemeyiz; yeni şirket aynı kurucunun yeni denemesidir.
        fresh.profile = profile
        if profile.setupComplete {
            let cat = firstProject?.category ?? 0
            let name = firstProject?.name ?? (profile.companyName.isEmpty ? "MVP" : profile.companyName)
            let proj = ProjectState(name: name, category: cat,
                                    startMonth: 0, devProgress: 1, isLive: true)
            fresh.projects = [proj]
            // Kurucu üyesi: aynı kişi, aynı yeni proje üzerinde — kimlik korunur.
            let founderFirst = profile.founderFirstName.isEmpty ? "Kurucu" : profile.founderFirstName
            fresh.members = [
                TeamMember(firstName: founderFirst, lastName: profile.founderLastName,
                           deptIndex: 0, skillLevel: 5, joinedMonth: 0,
                           isFounder: true, assignedProjectID: proj.id)
            ]
        }
        state = fresh
        debtMonths = 0
        pendingBankruptcy = false
        seedCohortIfNeeded()   // yeni başlangıç ligine taze rakip kohort
        scheduleNextDecision()
        save()
    }

    // MARK: - Döngü

    func start() {
        lastTick = Date()
        timer?.invalidate()
        let t = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func tick() {
        guard !pendingBankruptcy, !pendingWin else { return }
        let now = Date()
        let realDt = now.timeIntervalSince(lastTick)
        lastTick = now
        guard realDt > 0 else { return }
        // Duraklatıldıysa: zaman donar — economy/karar/moral/projeler ilerlemez.
        if isPaused { return }

        // Oyun-zamanı dt = gerçek dt × hız çarpanı (zaman hızlandırma).
        let dt = realDt * speed

        let monthFraction = dt / Balance.secondsPerMonth
        advanceEconomy(monthFraction)
        maybeCelebrateUserMilestone()    // HZ-2: ilk 100/1000 kullanıcı eşik kutlaması (bir kez)
        advanceProjects(monthFraction)   // geliştirilen projeler ilerler, biten yayına girer
        updateMorale(dt)
        maybeQuit(dt)

        // borç takibi
        if state.cash < 0 { debtMonths += monthFraction } else { debtMonths = 0 }
        checkBankruptcy()

        state.months += monthFraction

        // Çeyrek boyu moral örneklemi (ortalama moral skoru için).
        state.quarterMoraleSum += state.morale * monthFraction
        state.quarterMoraleSamples += monthFraction

        advanceCohort(dt)   // canlı leaderboard: rakip skorları oyun temposuyla ilerler
        updateHealthState() // şirket sağlık durum-makinesi: state geçişlerini yakala (zincir izleme)
        maybeCloseQuarter()
        maybeCloseSprint()
        maybeSpawnScenario()    // yeni programlı senaryo aç (aralık geçtiyse)
        maybeSettleScenarios()  // deadline geçen senaryoları değerlendir + ödül/ceza

        // Günlük hedef: kullanıcı hedefi zamanla dolabilir → her tick kontrol.
        // Gerçek gün değişimi de burada yakalanır (ör. uzun açık oturum gece yarısını geçerse).
        refreshDailyGoalIfNeeded()
        checkDailyCompletion()

        sinceDecision += dt
        maybeTriggerDecision()

        sinceAutosave += realDt
        if sinceAutosave >= 8 { sinceAutosave = 0; save() }

        sinceHistory += dt
        if sinceHistory >= 3 { sinceHistory = 0; recordHistory() }

        sinceTip += dt
        if sinceTip >= 12 { sinceTip = 0; setTip(NarrativeContent.tips) }
    }

    private func advanceEconomy(_ monthFraction: Double) {
        let revenue = revenuePerMonth * monthFraction
        let burn = burnPerMonth * monthFraction
        state.cash += revenue - burn
        state.lifetimeRevenue += max(0, revenue)

        let dUsers = netUserGrowthPerMonth * monthFraction
        state.users = max(0, state.users + dUsers)

        // itibar yumuşakça tabana döner (olaylar/turlar yukarı iter)
        // Estetik/lüks eşyalar + yayındaki projeler tabanı kalıcı olarak yukarı çeker.
        let repBaseline = min(100, 20 + itemReputationBonus + projectReputationBonus)
        state.reputation += (repBaseline - state.reputation) * 0.002
        state.reputation = min(100, max(0, state.reputation))
    }

    /// HZ-2: kullanıcı eşiklerini (100, 1000) ilk geçişte BİR KEZ kutla (kalıcı flag).
    /// pendingToast yolu (overlay yarışı yok). Eğitici dokunuş — ölçeklenmeyen işler / churn.
    private func maybeCelebrateUserMilestone() {
        for m in NarrativeContent.userMilestones where state.users >= Double(m)
            && !state.celebratedUserMilestones.contains(m) {
            state.celebratedUserMilestones.append(m)
            if let msg = NarrativeContent.userMilestonePraise(m) {
                pendingToast = msg
                Feedback.success()
            }
        }
    }

    private func recordHistory() {
        state.history.append(HistoryPoint(month: state.months, cash: state.cash,
                                          users: state.users, mrr: mrr, valuation: valuation))
        if state.history.count > 120 { state.history.removeFirst(state.history.count - 120) }
    }

    private func clamp() {
        state.morale = min(100, max(0, state.morale))
        state.reputation = min(100, max(0, state.reputation))
        state.founderEquity = min(1, max(0, state.founderEquity))
        state.users = max(0, state.users)
    }

    private func setTip(_ pool: [String]) {
        if let line = pool.randomElement() { founderTip = line }
    }

    // MARK: - Onboarding

    func completeOnboarding() {
        state.hasSeenOnboarding = true
        save()
    }

    // MARK: - Şirket kuruluşu (CEO + şirket + sektör + ilk proje)

    var companySetupComplete: Bool { state.profile.setupComplete }
    var companyName: String { state.profile.companyName }
    var founderFullName: String { state.profile.founderFullName }
    /// Kurucu ünvanı evreyle yükselir (Hacker → Kurucu → CEO ...).
    var founderTitle: String { currentStage.title }
    var sectorDef: CompanySectorDef { Balance.sector(state.profile.sector) ?? Balance.sectors[0] }

    /// Kuruluşu tamamla: profili kaydet + ilk projeyi (yayında) oluştur.
    /// İlk proje gün-1'den canlıdır (MVP yayında) — şirketin ilk ürünü.
    func completeCompanySetup(firstName: String, lastName: String,
                              company: String, sector: Int,
                              firstProjectName: String, firstProjectCategory: Int) {
        func clean(_ s: String) -> String { s.trimmingCharacters(in: .whitespacesAndNewlines) }
        state.profile.founderFirstName = clean(firstName)
        state.profile.founderLastName = clean(lastName)
        state.profile.companyName = clean(company)
        state.profile.sector = min(max(0, sector), Balance.sectors.count - 1)
        state.profile.setupComplete = true

        let catIndex = min(max(0, firstProjectCategory), Balance.projectCategories.count - 1)
        let projName = clean(firstProjectName).isEmpty ? clean(company) : clean(firstProjectName)
        let firstProject = ProjectState(name: projName, category: catIndex,
                                        startMonth: state.months, devProgress: 1, isLive: true)
        state.projects = [firstProject]

        // Kurucu = ilk üye: GameState init `headcount[0] = 1` ile başlar (kurucu mühendis);
        // setup, anonim üyeyi profilden gelen adla NAMED bir `TeamMember`'a yükseltir
        // ve ilk projeye atar. Skill 5 (kurucu — vizyoner).
        let founderFirst = clean(firstName).isEmpty ? "Kurucu" : clean(firstName)
        let founderMember = TeamMember(firstName: founderFirst,
                                       lastName: clean(lastName),
                                       deptIndex: 0, skillLevel: 5,
                                       joinedMonth: state.months,
                                       isFounder: true,
                                       assignedProjectID: firstProject.id)
        // Diğer üyeler varsa (eski/anonim) onları koru, sadece kurucuyu öne ekle.
        state.members.removeAll { $0.isFounder }
        // Mevcut anonim üyelerden birini kurucuyla DEĞİŞTİR (mühendislik dept'inden).
        if let anonIdx = state.members.firstIndex(where: { $0.deptIndex == 0 }) {
            state.members.remove(at: anonIdx)
        }
        state.members.insert(founderMember, at: 0)
        state.normalize()   // headcount ile yeniden senkronla (her ihtimale karşı)
        // HZ-4: ilk oturum karşılaması — kuruluş biter bitmez sıcak, eğitici bir dokunuş.
        pendingToast = NarrativeContent.firstSessionWelcome
        save()
    }

    // MARK: - Projeler (şirketin ürün portföyü — büyüme mekaniği)

    var projects: [ProjectState] { state.projects }
    var liveProjects: [ProjectState] { state.projects.filter { $0.isLive } }
    var liveProjectCount: Int { liveProjects.count }
    /// Portföy kapasitesi (evreyle büyür) ve doluluk.
    var maxProjects: Int { Balance.maxProjects(stage: state.stage) }
    var canStartNewProject: Bool { state.projects.count < maxProjects }

    /// Yayındaki projelerin organik büyümeye toplam oransal katkısı.
    private var projectGrowthMult: Double {
        liveProjects.reduce(0) { $0 + (Balance.projectCategory($1.category)?.growthBonus ?? 0) }
    }
    /// Yayındaki projelerin ARPU'ya toplam oransal katkısı.
    private var projectArpuMult: Double {
        liveProjects.reduce(0) { $0 + (Balance.projectCategory($1.category)?.arpuBonus ?? 0) }
    }
    /// Yayındaki projelerin itibar tabanına toplam katkısı (puan).
    private var projectReputationBonus: Double {
        liveProjects.reduce(0) { $0 + (Balance.projectCategory($1.category)?.reputationBonus ?? 0) }
    }

    /// Bir kategorinin yeni proje başlatma maliyeti (evreyle ölçeklenir).
    func projectStartCost(_ category: Int) -> Double {
        (Balance.projectCategory(category)?.buildCost ?? 0) * Balance.salaryMultiplier(forStage: state.stage)
    }
    /// Bu kategoride yeni proje başlatılabilir mi (kapasite + nakit).
    func canStartProject(_ category: Int) -> Bool {
        canStartNewProject && state.cash >= projectStartCost(category)
    }

    /// Geliştirme hızı çarpanı: mühendislik gücü referansa göre projeleri hızlandırır.
    private var projectBuildAccel: Double {
        max(0.4, min(2.5, devPower / Balance.projectDevReference))
    }

    /// Geliştirme aşamasındaki projenin kalan süresi (gerçek saniye) — ETA göstergesi.
    func projectETASeconds(_ project: ProjectState) -> Double {
        guard !project.isLive, let cat = Balance.projectCategory(project.category) else { return 0 }
        let remaining = max(0, 1 - project.devProgress)
        let monthsLeft = remaining * max(0.5, cat.buildMonths) / max(0.0001, projectBuildAccel)
        return monthsLeft * Balance.secondsPerMonth / max(0.0001, speed)
    }

    @discardableResult
    func startProject(name: String, category: Int) -> Bool {
        guard canStartProject(category) else { return false }
        let catIndex = min(max(0, category), Balance.projectCategories.count - 1)
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let projName = cleanName.isEmpty ? "Proje \(state.projects.count + 1)" : cleanName
        let cost = projectStartCost(catIndex)
        state.cash -= cost
        emitCashDelta(-cost)
        state.projects.append(ProjectState(name: projName, category: catIndex,
                                           startMonth: state.months, devProgress: 0, isLive: false))
        state.morale = min(100, state.morale + Balance.projectStartMoraleBonus)
        save()
        return true
    }

    /// Geliştirme aşamasındaki projeleri ilerlet; tamamlananları yayına al (kutlama).
    /// `internal` görünürlük — @testable testler deterministik dev → live geçişini tetikleyebilsin.
    func advanceProjects(_ monthFraction: Double) {
        guard state.projects.contains(where: { !$0.isLive }) else { return }
        let accel = projectBuildAccel
        for i in state.projects.indices where !state.projects[i].isLive {
            let cat = Balance.projectCategory(state.projects[i].category)
            let months = max(0.5, cat?.buildMonths ?? 2)
            state.projects[i].devProgress += monthFraction * accel / months
            if state.projects[i].devProgress >= 1 {
                state.projects[i].devProgress = 1
                state.projects[i].isLive = true
                state.morale = min(100, state.morale + Balance.projectLaunchMoraleBonus)
                state.reputation = min(100, state.reputation + Balance.projectLaunchReputationBonus)
                pendingToast = "\(state.projects[i].name) yayında! Büyümeye katkı sağlıyor."
            }
        }
    }

    // MARK: - Tema erişimcileri (Scene & UI okur)

    var stageBgHex: String { currentStage.bgHex }
    var stageAccentHex: String { currentStage.accentHex }
    var stageSurfaceHex: String { currentStage.surfaceHex }
    var officeName: String { currentStage.officeName }
    var stageIndex: Int { state.stage }

    // MARK: - Kayıt & offline

    func save() {
        state.lastSaved = Date()
        SaveManager.save(state)
    }

    func saveOnBackground() { save() }

    func refreshOnForeground() {
        applyOfflineProgress()
        refreshDailyGoalIfNeeded()   // arka planda gün değiştiyse streak/görevleri yenile
        lastTick = Date()
    }

    private func applyOfflineProgress() {
        let elapsed = min(Date().timeIntervalSince(state.lastSaved), Balance.offlineCapSeconds)
        guard elapsed > 60 else { return }
        let monthFraction = elapsed / Balance.secondsPerMonth * Balance.offlineEfficiency
        let revenue = revenuePerMonth * monthFraction
        let burn = burnPerMonth * monthFraction
        let dCash = revenue - burn
        let dUsers = netUserGrowthPerMonth * monthFraction
        state.cash += dCash
        state.users = max(0, state.users + dUsers)
        state.months += monthFraction
        pendingOfflineReport = OfflineReport(seconds: elapsed, cashDelta: dCash,
                                             usersDelta: dUsers)
    }
}

/// HUD üstünde yüzen ±tutar çipi için yayılan ayrık nakit hareketi.
/// `id` her olay için yeni — UI Equatable üzerinden tekrarsız tetikleyebilsin.
/// `amount` işaretli: pozitif=kazanç (yeşil), negatif=harcama (kırmızı).
struct CashDeltaEvent: Identifiable, Equatable {
    let id: UUID = UUID()
    let amount: Double
}

/// Programlı senaryonun deadline'ında üretilen sonuç — overlay payload'u.
/// `success`: oyuncu hedefe ulaştı mı; `reward`: uygulanan etki (UI özet için).
struct ScenarioResult {
    let scenario: ScenarioInstance
    let success: Bool
    let reward: ScenarioSystem.Reward
}

/// "Yokken neler oldu" raporu.
struct OfflineReport {
    let seconds: Double
    let cashDelta: Double
    let usersDelta: Double
}

/// Çeyrek kapanış değerlendirmesi (scorecard + lig hareketi) — overlay okur.
struct CycleReview {
    let quarter: Int
    let breakdown: LeagueSystem.ScoreBreakdown
    let movement: LeagueSystem.Movement
    let fromTier: Int
    let toTier: Int
    // Rakip kohort sıralaması (gerçek bahis): oyuncu + rakipler skora göre sıralı,
    // oyuncunun yeri ve terfi/düşüş eşikleri (ilk N terfi, son N düşer).
    let standings: [StandingEntry]
    let playerRank: Int
}

/// Günlük hedef tamamlanınca gösterilen kapanış/kutlama payload'u — overlay okur.
/// (completed-cycle: günlük döngü kapanışı, çeyrek scorecard'ının küçük kardeşi.)
struct DailyClose {
    let streak: Int               // yeni (artmış) streak değeri
    let streakMoraleBonus: Double // streak'in moral hedefine kalıcı katkısı (puan)
}

/// Haftalık sprint kapanışı (completed-cycle): süre dolunca her zaman SONUÇ.
/// Başarılı → zirve/kutlama + ödül; başarısız → sonucu görürsün (ödül yok).
struct SprintClose {
    let sprint: Int           // kapanan sprint numarası (1'den)
    let goal: SprintGoal      // hedef (tür + değer + metin)
    let success: Bool         // hedef tutturuldu mu
    let doneValue: Double     // ulaşılan değer
    let targetValue: Double   // hedef değer
}

/// Sezon finali (completed-cycle zincirinin en üstü): birkaç çeyrek = 1 sezon.
/// Görkemli kutlama + KALICI ödül (ünvan/rozet koleksiyonu + küçük üretim çarpanı).
struct SeasonFinale {
    let season: Int                    // bitirilen sezon numarası (1'den)
    let summary: SeasonSystem.Summary  // sezon özeti satırları (terfi, en yüksek lig, sprint/günlük, ortalama skor)
    let title: SeasonTitleDef          // bu sezonda kazanılan kalıcı ünvan/rozet
    let bonusGained: Double            // bu sezon kazanılan kalıcı üretim çarpanı katkısı (oransal)
    let totalBonusAfter: Double        // bu sezondan sonra toplam kalıcı çarpan (oransal, ör. 0.08 = +%8)
}

/// Gider dağılımı satırı (UI için).
struct CostLine: Identifiable {
    let name: String
    let icon: String
    let amount: Double
    /// Numerik id: Balance.costItems id ile eşleşir; özel satırlar (-1) kullanır.
    let costId: Int
    var id: String { name }
}
