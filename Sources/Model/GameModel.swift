import Foundation
import Combine

/// Tek doğruluk kaynağı: şirket durumu + idle ekonomi + karar/funding/moral mantığı.
@MainActor
final class GameModel: ObservableObject {
    @Published private(set) var state: GameState

    // Geçici UI sinyalleri
    @Published var pendingEvent: DecisionCard? = nil
    @Published var pendingFundingStage: Int? = nil   // tur kutlaması
    /// B6 — Series A yumuşak duvarı sinyali. raiseRound() Series A (stage id 3) turunu
    /// toplamadan ÖNCE bunu true yapar; ContentView entitlement'a göre PaywallView gösterir
    /// ya da confirmSeriesARaise() çağırır. GameModel StoreKit'ten bağımsız kalır.
    @Published var pendingSeriesAGate: Bool = false
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
    // Track C: feed satırından zengin detay-sheet açabilmek için son scorecard payload cache'i.
    var lastCycleReview: CycleReview? = nil
    var lastSeasonFinale: SeasonFinale? = nil
    @Published var inspectedMechanic: String? = nil {     // #19: ℹ/metrik/sonuç → ilgili Defter dersi
        didSet { if let m = inspectedMechanic { unlockLessonByMechanic(m) } } // köprüyle görülen ders Defter'de de açılsın
    }

    /// B1: bu oyunda en çok dokunulan ilk 3 karar mekaniği (frekansa göre azalan;
    /// eşitlikte mechanic adına göre stabil sıralı). FounderScorecardData ile 'en
    /// pahalı 3 ders'e çevrilir. Boşsa Karne 'Henüz yeterli karar' fallback'i gösterir.
    var topTouchedMechanics: [String] {
        state.mechanicTouchCounts
            .sorted { ($0.value, $1.key) > ($1.value, $0.key) }
            .prefix(3)
            .map { $0.key }
    }

    // MARK: - Aktivite Akışı (Track C)
    /// Feed'e yeni girdi ekle (en yeni BAŞTA). 30 üstünü budar, okunmamış sayacı artırır.
    /// pending* modal yayını yerine bunu çağır — retention mutasyonları (sayaç/ödül) AYNEN kalır.
    func pushFeed(_ kind: FeedKind, _ title: String, _ summary: String,
                  positive: Bool = true, mechanic: String? = nil,
                  detail: FeedDetailKind? = nil, reflection: String? = nil) {
        let e = FeedEntry(kind: kind, title: title, summary: summary, atMonth: state.months,
                          positive: positive, mechanic: mechanic, detail: detail,
                          reflection: reflection)
        state.feed.insert(e, at: 0)
        if state.feed.count > 30 { state.feed = Array(state.feed.prefix(30)) }
        state.feedUnread += 1
        objectWillChange.send()
    }

    var feedEntries: [FeedEntry] { state.feed }
    var feedUnread: Int { state.feedUnread }
    var companyMonths: Double { state.months }

    /// Ofis/feed görünür olunca okunmamış sayacını sıfırla (HUD rozeti söner).
    func markFeedRead() {
        guard state.feedUnread > 0 else { return }
        state.feedUnread = 0
        for i in state.feed.indices { state.feed[i].read = true }
        objectWillChange.send()
    }
    @Published var inspectedDept: Int? = nil   // ofiste çalışana tıklanınca açılan kart
    @Published var founderTip: String = NarrativeContent.tips.first ?? ""
    /// HUD üstünde yüzen ±tutar çipi için son ayrık nakit hareketi (kazanç/harcama).
    /// Yalnızca oyuncu eylemleri (hire/buy/raise/decision) tetikler — tick'in sürekli
    /// gelir/burn akışı GÖSTERİLMEZ (gürültü olur). UI `$lastCashDelta`'yı dinler.
    @Published var lastCashDelta: CashDeltaEvent? = nil
    /// "Çünkü" nedensellik çipi: bir eylemin/eşiğin hangi metriği NEDEN etkilediğini
    /// anlık söyler — gizli simülasyonu HİSSE çevirir (Faz 2). UI `$pendingCausalNote`'u dinler.
    @Published var pendingCausalNote: CausalNote? = nil

    // Nedensellik eşik takibi: band kötüleşince/iyileşince bir kez çip yay (her tick değil).
    // 0=kritik, 1=düşük/uyarı, 2=güvenli. İlk tick'te sessizce kalibre edilir (causalPrimed).
    private var lastMoraleBand = 2
    private var lastRunwayBand = 2
    private var causalPrimed = false

    private var timer: Timer?
    private var lastTick = Date()
    private var sinceAutosave: Double = 0
    private var sinceHistory: Double = 0
    private var sinceTip: Double = 0
    private var sinceDecision: Double = 0
    private var sinceDecisionReal: Double = 0   // gerçek-saniye sayacı (hız'dan bağımsız taban)
    private var nextDecisionAt: Double = Balance.decisionMinInterval
    private var debtMonths: Double = 0

    // Şirket sağlık durum-makinesi: önceki state'i hatırla → geçişleri yakala.
    // (Persist edilmez; tick'te yeniden hesaplanır. Zincir sayacı GameState.crisisChainCount'ta tutulur.)
    private var lastHealth: CompanyHealth = .healthy

    // Tepki Veren Rakip: oyuncu büyüme tetikleyicilerini izlemek için son anlık görüntüler
    // (persist edilmez; tick'te güncellenir). Stage jump → baskı sıçraması; MRR surge → baskı.
    private var lastRivalStage: Int = -1
    private var rivalMRRWindow: Double = 0   // MRR tetik penceresi sayacı (oyun-ayı)

    /// Ekonomi-kritik rastgelelik üreticisi — `state.seed`'den tohumlanır
    /// ("aynı tohum → aynı oyun"). Karar seçimi/zamanlaması, senaryo türü ve
    /// rakip kohortu bu akıştan beslenir. Kozmetik rastgelelik (isim/ipucu) seed'siz.
    /// init/restart/reset her zaman `seedRNG()` ile yeniden tohumlar.
    private var rng = SplitMix64RNG(seed: 1)

    init() {
        if let saved = SaveManager.load() {
            state = saved
        } else {
            state = GameState()
        }
        // Şimdilik para birimi yalnızca dolar — seçici kapalı (kullanıcı isteği).
        // Eski kayıtlarda ₺/€ seçilmiş olsa bile görüntü dolara sabitlenir.
        state.currency = .usd
        BigNumber.currency = .usd
        seedRNG()   // deterministik RNG'yi state.seed'den tohumla (yoksa üret + kalıcılaştır)
        applyOfflineProgress()
        seedQuarterSnapshotIfNeeded()
        seedSprintIfNeeded()
        seedCohortIfNeeded()
        refreshDailyGoalIfNeeded()
        scheduleNextDecision()
        // Şirket sağlık durum-makinesi: mevcut metriklerden ilk state'i tohumla
        // (önceki state olarak healthy — sahte geçiş tetiklenmesin).
        lastHealth = HealthSystem.evaluate(model: self, previous: .healthy)
        // Tepki Veren Rakip: tetik referanslarını mevcut duruma tohumla (sahte sıçrama tetiklenmesin).
        lastRivalStage = state.stage
        if state.rivalLastMRRSample <= 0 { state.rivalLastMRRSample = mrr }
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
    /// Oyun DURAKLI başlar (kullanıcı isteği): zaman yalnız oyuncu ▶ deyince akar.
    @Published var isPaused: Bool = true
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

    func count(_ i: Int) -> Int {
        guard i >= 0 && i < state.headcount.count else { return 0 }   // #21: latent crash guard
        return state.headcount[i]
    }

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

    /// Nedensellik çipi yay: "şu oldu → şu metrik şöyle etkilendi".
    private func emitCausal(_ icon: String, _ text: String, _ tone: CausalNote.Tone) {
        pendingCausalNote = CausalNote(icon: icon, text: text, tone: tone)
    }

    /// Her tick (advanceEconomy sonrası) çağrılır: moral & runway band'i kötüleşince ya da
    /// güvenliye dönünce BİR KEZ nedensellik çipi yayar. Sürekli sayı akışı değil — eşik anı
    /// dramatize edilir, gizli zincir (moral→üretim/churn, burn→runway) görünür olur.
    private func checkCausalThresholds() {
        let mBand = state.morale < 35 ? 0 : (state.morale < 60 ? 1 : 2)
        let rBand: Int = {
            if netPerMonth >= 0 { return 2 }
            let r = runwayMonths
            return r < 3 ? 0 : (r < 6 ? 1 : 2)
        }()
        if causalPrimed {
            if mBand < lastMoraleBand {
                if mBand == 1 {
                    emitCausal("face.dashed", "Moral düştü → üretim ve gelir yavaşlıyor", .warn)
                } else {
                    emitCausal("exclamationmark.triangle.fill",
                               "Moral kritik → churn artıyor, ekip ayrılabilir", .bad)
                    Feedback.warning()
                }
            } else if mBand > lastMoraleBand && mBand == 2 {
                emitCausal("face.smiling", "Moral toparlandı → üretim hızlandı", .good)
            }
            if rBand < lastRunwayBand {
                if rBand == 1 {
                    emitCausal("hourglass", "Runway 6 ayın altında → gelir artır ya da gideri kıs", .warn)
                    Feedback.warning()
                } else if rBand == 0 {
                    emitCausal("flame.fill", "Runway kritik (<3 ay) → acil nakit gerek", .bad)
                    Feedback.warning()
                }
            }
        }
        lastMoraleBand = mBand
        lastRunwayBand = rBand
        causalPrimed = true
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

    /// Ürün olgunluğu (0..1): yayındaki ürünlerin ortalama geliştirilmişliği. Pazarlamanın
    /// kalıcı gelire dönmesi için ürünün inşa edilmiş olması gerekir (gerçek SaaS / PMF mantığı).
    /// Yayında ürün yoksa 0 → gelir kapısı tam kapalı.
    var productReadiness: Double {
        let live = liveProjects
        guard !live.isEmpty else { return 0 }
        return live.reduce(0) { $0 + min(1, max(0, $1.devProgress)) } / Double(live.count)
    }

    /// Ürün-olgunluğu gelir kapısı (sert): olgunlaşmamış ürün taban ARPU'nun yalnız küçük bir
    /// kısmını kazanır; olgunlukla 1'e çıkar. floor=0.12 → ham ürün ~%12 ARPU.
    private var productArpuGate: Double {
        Balance.productArpuFloor + (1 - Balance.productArpuFloor) * productReadiness
    }
    /// Ürün-olgunluğu churn kapısı: olgunlaşmamış üründe kullanıcılar hızla kaçar (ince ürün
    /// → yüksek churn). penalty=1.6 → ham üründe churn ~2.6×; olgunlukla taban churn'e iner.
    private var productChurnGate: Double {
        1 + Balance.productChurnPenalty * (1 - productReadiness)
    }

    var churnRate: Double {
        Balance.baseChurn * max(0.2, 1 - effects.churnReduce - opsPower * 0.01)
            * (1 + overload) * productChurnGate * rivalChurnMultiplier
    }

    // MARK: Tepki Veren Rakip — ekonomik baskı çarpanları (TAVANLI + GEÇİCİ)
    //
    // rivalAggression (0..1) her tick yumuşakça SOLAR. Tam baskıda bile etki TAVANLI:
    // CAC en fazla ×(1+rivalCacPressureMax), churn en fazla ×(1+rivalChurnPressureMax).
    // Böylece 4 arketip hâlâ Unicorn'a ulaşabilir (denge kısıdı). Çarpan ekonomi sözleşmesini
    // (DecisionEffect/CodableEffect) değiştirmez — doğrudan computed property'ye enjekte edilir.

    /// Fiyat savaşı baskısı: rakip agresifse CAC tırmanır (geçici, tavanlı).
    var rivalCacMultiplier: Double { 1 + state.rivalAggression * Balance.rivalCacPressureMax }
    /// Yetenek avı / kopya özellik baskısı: rakip agresifse churn tırmanır (geçici, tavanlı).
    var rivalChurnMultiplier: Double { 1 + state.rivalAggression * Balance.rivalChurnPressureMax }
    /// Rakip baskısının o anki şiddeti (0..1) — UI/teşhis okuması için.
    var rivalAggression: Double { state.rivalAggression }

    /// Kullanıcı başına aylık gelir (taban × evre çarpanı × modül + proje katkıları × satış gücü
    /// × ürün-olgunluğu kapısı). Evre çarpanı: SaaS fiyatlandırma gücü/upsell modeller.
    var arpu: Double {
        Balance.baseArpu
            * Balance.arpuMultiplier(forStage: state.stage)
            * (1 + effects.arpuMult + projectArpuMult)
            * (1 + min(Balance.salesArpuCap, salesPower * Balance.salesArpuPerUnit))
            * productArpuGate
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
        // Tepki Veren Rakip: fiyat savaşı baskısı CAC'i geçici/tavanlı yukarı çeker.
        return Balance.baseCAC * stageMult * saturation / qualityFactor * rivalCacMultiplier
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
        let before = currentCAC
        state.adBudgetPerMonth = max(0, state.adBudgetPerMonth + delta)
        let after = currentCAC
        // Nedensellik: reklam ↑ → doygunluk → CAC ↑ (azalan verim). Oyuncu bağı CANLI görür.
        if delta != 0, before > 0 {
            let pct = Int((((after - before) / before) * 100).rounded())
            if delta > 0 && pct >= 1 {
                emitCausal("megaphone.fill",
                           "Reklam ↑ → CAC %\(pct) arttı (≈\(BigNumber.money(after))/kullanıcı)", .warn)
            } else if delta < 0 && pct <= -1 {
                emitCausal("megaphone",
                           "Reklam ↓ → CAC %\(abs(pct)) düştü (≈\(BigNumber.money(after))/kullanıcı)", .good)
            }
        }
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
        // Nedensellik: ekip ↑ → aylık gider ↑ → runway kısalır. Bedeli anında görünür kıl.
        let r = runwayMonths
        let rText = r.isFinite ? "\(Int(r.rounded())) ay" : "∞"
        emitCausal("person.fill.badge.plus",
                   "Ekip büyüdü → aylık gider arttı, runway \(rText)",
                   netPerMonth >= 0 ? .good : .warn)
        checkDailyCompletion()
        save()
        return true
    }

    /// Yeni hire'ın beceri seviyesi rulosu (1-5). Çoğu L1-L2, nadiren L4-L5 — kozmetik.
    /// Ekonomi formüllerini ETKİLEMEZ (skill SADECE UI rozeti içindir).
    private func rollSkillLevel() -> Int {
        let r = Double.random(in: 0..<1, using: &rng)
        if r < 0.55 { return 1 }
        if r < 0.85 { return 2 }
        if r < 0.96 { return 3 }
        if r < 0.995 { return 4 }
        return 5
    }

    /// En az atanmış, henüz OLGUNLAŞMAMIŞ (devProgress < 1) proje (otomatik dağılım için).
    /// Yayına girmiş ama hâlâ gelişen ürünler de dahil — yeni mühendis ürünü ilerletmeye
    /// devam etsin. Tüm projeler tam olgunsa nil → yeni üye proje atanmaz.
    private func projectNeedingHelp() -> ProjectState? {
        let buildable = state.projects.filter { $0.devProgress < 1 }
        guard !buildable.isEmpty else { return nil }
        return buildable.min(by: { teamSize(forProject: $0.id) < teamSize(forProject: $1.id) })
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
        // Nedensellik: ekip ↓ → aylık gider ↓ → runway uzar (hire'ın simetriği; moral bedeli var).
        let r = runwayMonths
        let rText = r.isFinite ? "\(Int(r.rounded())) ay" : "∞"
        emitCausal("person.fill.badge.minus",
                   "Ekip küçüldü → aylık gider düştü, runway \(rText)",
                   netPerMonth >= 0 ? .good : .warn)
        Feedback.warning()   // kayıp aksiyonu — işe alımın (tap) simetriği
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
        Feedback.tap()   // modül yükseltme satın alındı (işe alımla aynı dil)
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

    // MARK: - "Sıradaki Adım" direktifi (Faz 3: oyuncuya tek-ses yön)

    /// Direktif şeridinin dokununca yönlendireceği eylem. UI bu enum'ı in-panel aksiyona
    /// (tur topla / günlük / sprint / mağaza) ya da sekme geçişine (büyüme) çevirir.
    enum DirectiveAction: Equatable { case raise, daily, sprint, shop, growth, none }

    /// Tek satırlık öncelikli yön: "şimdi ne yapmalıyım?" sorusunu çözer. Tüm yön verisi
    /// (runway/raise/daily/sprint/users) zaten hesaplı — burada tek önemli sese indirilir.
    struct Directive: Equatable {
        let icon: String
        let text: String
        let tone: CausalNote.Tone
        let action: DirectiveAction
    }

    /// O an oyuncuya gösterilecek en öncelikli direktif (yukarıdan aşağı önem sırası).
    var nextDirective: Directive {
        // 1) Nakit krizi — her şeyin önünde.
        if state.cash < 0 {
            return Directive(icon: "flame.fill",
                             text: "Nakit eksiye düştü — tur topla ya da gideri hemen kıs",
                             tone: .bad, action: canRaise ? .raise : .growth)
        }
        if netPerMonth < 0 && runwayMonths < 6 {
            return Directive(icon: "hourglass",
                             text: "Runway \(Int(runwayMonths.rounded())) ay — gelir artır ya da maliyeti düşür",
                             tone: .warn, action: .growth)
        }
        // 2) Tur toplamaya hazır.
        if canRaise, let next = nextStage {
            return Directive(icon: Icons.Screen.raise,
                             text: "\(next.name) turunu topla — +\(BigNumber.money(next.raiseAmount))",
                             tone: .good, action: .raise)
        }
        // 3) Günlük hedef eksik.
        let d = dailyTaskCounts
        if !dailyCompleted && d.total > 0 {
            return Directive(icon: "target",
                             text: "Günlük görevler: \(d.done)/\(d.total) — tamamla, seriyi sürdür",
                             tone: .warn, action: .daily)
        }
        // 4) Sprint geride.
        if !sprintOnTrack {
            let sp = sprintProgress
            let remaining = max(0, Int((sp.target - sp.done).rounded()))
            return Directive(icon: "bolt.fill",
                             text: "Sprint hedefi: +\(BigNumber.format(Double(remaining))) daha gerek",
                             tone: .warn, action: .sprint)
        }
        // 5) Büyüme: çok az kullanıcı.
        if state.users < 50 {
            return Directive(icon: "person.3.fill",
                             text: "İlk kullanıcıları çek — Büyüme'den reklam bütçesi ayır",
                             tone: .warn, action: .growth)
        }
        // 6) Koltuklar dolu — ekip büyütmek için masa gerek.
        if seatsFull {
            return Directive(icon: "chair.fill",
                             text: "Koltuklar dolu — Mağaza'dan masa al, ekibi büyüt",
                             tone: .warn, action: .shop)
        }
        // 7) Varsayılan: sıradaki evreye ilerleme.
        if let next = nextStage {
            return Directive(icon: "chart.line.uptrend.xyaxis",
                             text: "Sıradaki: \(next.name) — %\(Int(raiseProgress * 100)) yolda",
                             tone: .good, action: .growth)
        }
        return Directive(icon: "trophy.fill",
                         text: "Son evredesin — şirketini büyütmeye devam et",
                         tone: .good, action: .none)
    }

    @discardableResult
    func raiseRound() -> Bool {
        guard canRaise, let next = nextStage else { return false }
        // B6 — Series A (stage id 3) yumuşak duvarı: Seed turuna kadar serbest;
        // Series A toplama Tam Sürüm gerektirir. Mutasyon ContentView onayına ertelenir.
        if next.id == 3 && !pendingSeriesAGate {
            pendingSeriesAGate = true
            return false
        }
        performRaise(next)
        return true
    }

    /// B6 — Series A gate onaylandıktan (entitlement var) sonra ContentView çağırır.
    func confirmSeriesARaise() {
        pendingSeriesAGate = false
        guard canRaise, let next = nextStage, next.id == 3 else { return }
        performRaise(next)
    }

    /// Asıl tur-toplama mutasyonu (gate'ten bağımsız ortak gövde).
    private func performRaise(_ next: StageDef) {
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
    }

    func dismissFunding() { pendingFundingStage = nil }
    /// Paywall'da 'Şimdilik Seed'de devam' — duvarı kapat, hiçbir mutasyon yapma.
    func dismissSeriesAGate() { pendingSeriesAGate = false }
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
        state.cohortCompetitors = CohortSystem.freshCompetitors(tier: state.leagueTier, using: &rng)
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
            progress: quarterProgress, dt: dt, using: &rng)
    }

    // MARK: Tepki Veren Rakip (Eskalasyon / Antagonist) — pasif kohort → canlı tehdit

    /// Her tick çağrılır: rakip baskısını SOLDUR + oyuncu büyüme tetikleyicilerine TEPKI ver.
    /// Sıra önemli: updateHealthState'ten ÖNCE çağrılmalı ki sağlık değerlendirmesi güncel
    /// baskıyı (CAC/churn çarpanlarını) görsün (entegrasyon notu). Etkiler GEÇİCİ ve TAVANLI.
    private func updateRivalAggression(_ monthFraction: Double) {
        guard monthFraction > 0 else { return }
        // 1) Doğal sönüm: baskı her ay üstel olarak solar (kalıcı ceza yok — geçici dalga).
        let decay = pow(1 - Balance.rivalAggressionDecayPerMonth, monthFraction)
        state.rivalAggression *= decay

        // 2) Evre atlama tetikleyicisi: oyuncu yeni tura çıktıysa (büyük görünür başarı) →
        //    kohort dikkatini çeker, bir rakip agresifleşir.
        if lastRivalStage >= 0 && state.stage > lastRivalStage {
            triggerRivalReaction(addAggression: Balance.rivalAggressionStageJump,
                                 reason: .stageJump)
        }
        lastRivalStage = state.stage

        // 3) Hızlı MRR büyümesi tetikleyicisi: bir tetik penceresi boyunca MRR eşiği aşan oranda
        //    büyüdüyse rakip tepki verir. Pencere ~1 oyun-ayı; her pencerede bir kez değerlendir.
        rivalMRRWindow += monthFraction
        if rivalMRRWindow >= 1 {
            rivalMRRWindow = 0
            let base = max(1, state.rivalLastMRRSample)
            let growth = (mrr - base) / base
            if growth >= Balance.rivalMRRGrowthTriggerPct && mrr > 0 {
                triggerRivalReaction(addAggression: Balance.rivalAggressionMRRSurge,
                                     reason: .mrrSurge)
            }
            state.rivalLastMRRSample = mrr
        }

        state.rivalAggression = min(1, max(0, state.rivalAggression))
    }

    /// Rakip tepkisinin sebebi (feed/anlatı için).
    private enum RivalReason { case stageJump, mrrSurge, promote }

    /// Bir rakip hamlesini tetikle: baskıyı artır + AKIŞA bağlamlı bir olay düş (kişiselleştirilmiş).
    /// Ekonomik etki rivalAggression üzerinden CAC/churn'e zaten tavanlı işler; bu yüzeyleme.
    private func triggerRivalReaction(addAggression: Double, reason: RivalReason) {
        let before = state.rivalAggression
        state.rivalAggression = min(1, state.rivalAggression + addAggression)
        // Aynı tick'te tekrar tekrar feed basmamak için: belirgin bir artış olduysa yüzeye çıkar.
        guard state.rivalAggression - before >= 0.1 else { return }

        // Aktif rakibi seç (en güçlü tehdit) — kişiselleştirme için.
        let rival = state.cohortCompetitors.max(by: { $0.score < $1.score })
        let rivalName = rival?.name ?? "Bir rakip"
        let sectorName = (rival.flatMap { Balance.sector($0.sector)?.name }) ?? "teknoloji"
        // Sektör/sebep → hamle türü (fiyat savaşı vs kopya/yetenek avı) anlatısı.
        let move: String
        switch reason {
        case .stageJump:
            move = "yeni turunu duydu ve \(sectorName) pazarında fiyat savaşı başlattı"
        case .mrrSurge:
            move = "hızlı büyümeni fark etti; agresif kullanıcı kapma kampanyasına geçti"
        case .promote:
            move = "seni ligde geçti görünce kopya özellik + yetenek avıyla karşılık veriyor"
        }
        // Şiddet (0..1 → %) + bu baskının CAC/churn'e tavanlı etkisi → opak değil, somut.
        let intensity = Int((state.rivalAggression * 100).rounded())
        let cacUp = Int((state.rivalAggression * Balance.rivalCacPressureMax * 100).rounded())
        let churnUp = Int((state.rivalAggression * Balance.rivalChurnPressureMax * 100).rounded())
        state.rivalMoveLabel = "\(rivalName) (\(sectorName)): \(move) — %\(intensity) baskı"
        pushFeed(.rival, "Rakip Tepki Verdi",
                 "\(rivalName) (\(sectorName)) \(move). Baskı %\(intensity) — CAC ~+%\(cacUp), churn ~+%\(churnUp). Karar kartıyla yanıt verebilirsin.",
                 positive: false, mechanic: "marketing")
        Feedback.warning()
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
            // Tepki Veren Rakip: ligde öne geçtin → rakipler agresifleşir (kohort öne geçeni hedefler).
            triggerRivalReaction(addAggression: Balance.rivalAggressionPromote, reason: .promote)
        case .demote:
            move = .demote
            state.leagueTier = max(0, state.leagueTier - 1)
            // Tepki Veren Rakip: bir lig düştün → rakipler seni daha az tehdit görür, baskı sakinleşir
            // (geri-dönüş kancası — DESIGN: kötü gidişatta nefes alanı).
            state.rivalAggression *= (1 - Balance.rivalAggressionDemoteRelief)
        case .stay:
            move = .stay
        }

        // Sezon birikimi (finale özeti için): bu çeyreğin skoru + sezonun en yüksek ligi.
        state.seasonScoreSum += breakdown.score
        state.seasonHighestTier = max(state.seasonHighestTier, state.leagueTier)

        // Track C: çeyrek kapanışı → AKIŞA (zengin scorecard "detay >"te). Modal YOK.
        // Payload'u cache'le ki feed satırından detay-sheet açılabilsin.
        lastCycleReview = CycleReview(quarter: quarterNumber,
                                      breakdown: breakdown,
                                      movement: move,
                                      fromTier: fromTier,
                                      toTier: state.leagueTier,
                                      standings: standings,
                                      playerRank: rank)
        let moveText = move == .promote ? "Terfi ettin!" : (move == .demote ? "Bir lig düştün." : "Ligini korudun.")
        pushFeed(.quarter, "Çeyrek \(quarterNumber) Kapandı",
                 "Skor \(Int(breakdown.score)) · Sıra \(rank)/\(standings.count) · \(moveText)",
                 positive: move != .demote, detail: .quarter)
        // Çeyrek kapanışı: terfi → kutlama, düşüş → uyarı, sabit → tok kapanış.
        switch outcome {
        case .promote: Feedback.celebrate()
        case .demote:  Feedback.warning()
        case .stay:    Feedback.close()
        }
        save()
        // Modal kalktı → çeyrek OTOMATİK ilerler (eskiden "Yeni Çeyrek" butonu çağırırdı).
        startNextQuarter()
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
        lastSeasonFinale = pendingSeasonFinale   // Track C: feed detayı için cache (modal KALIR + feed özeti)
        let titleName = SeasonSystem.title(forSeason: earnedSeason).name
        let totalBonus = SeasonSystem.totalMultiplier(seasonsCompleted: earnedSeason) - 1
        pushFeed(.season, "Sezon \(earnedSeason) Tamamlandı",
                 "\(titleName) ünvanı kazanıldı · kalıcı +%\(Int(totalBonus * 100)) üretim.",
                 positive: true, detail: .season)
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

        // Track C: günlük kapanış → AKIŞA (modal yok).
        pushFeed(.daily, "Günlük Hedef Tamam · \(state.streak) gün",
                 "Moral +\(Int(Balance.dailyCompleteMoraleBonus)) · İtibar +\(Int(Balance.dailyCompleteReputationBonus)). Yarın da gel, serini büyüt.",
                 positive: true)
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

        // Track C: sprint sonucu → AKIŞA (toast bile yok — feed kalıcı). Otomatik ilerle.
        pushFeed(.sprint, "Sprint \(state.sprintIndex) \(success ? "Tamam" : "Kapandı")",
                 success ? "\(goal.title) — hedefe ulaştın!" : "\(goal.title) — hedef tutmadı, yeni sprint başladı.",
                 positive: success)
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

        let kind = ScenarioSystem.pickKind(stage: state.stage, active: activeScenarios, using: &rng)
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

        // Track C: senaryo sonucu → AKIŞA (modal yok) + settled senaryoyu hemen temizle.
        let rewardHint = reward.cash > 0 ? "+\(BigNumber.money(reward.cash))" :
            (reward.reputation != 0 ? "İtibar \(reward.reputation > 0 ? "+" : "")\(Int(reward.reputation))" : "")
        pushFeed(.scenario, success ? "\(s.scenarioKind.displayName): Hedef Tuttu" : "\(s.scenarioKind.displayName): Kaçtı",
                 success ? "Başardın. \(rewardHint)" : "Bu sefer olmadı — sonraki fırsata.",
                 positive: success)
        if success { Feedback.success() } else { Feedback.warning() }   // 2-3 aylık anlatı olayı sessiz kalmasın
        state.scenarios.removeAll { $0.id == s.id }
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
        nextDecisionAt = Double.random(in: Balance.decisionMinInterval...Balance.decisionMaxInterval, using: &rng)
        sinceDecision = 0
        sinceDecisionReal = 0
    }

    /// Ekranda halihazırda BİR overlay/popup açık mı? Açıksa yeni karar kartı çıkmaz
    /// (üst üste binme = "durmadan popup" hissinin ana kaynağıydı). Oyuncu mevcut
    /// popup'ı kapatıp ofisle oynayabilsin diye karar bekler.
    var anyBlockingOverlay: Bool {
        pendingEvent != nil || pendingResult != nil || pendingScenarioResult != nil
            || pendingCycleReview != nil || pendingSeasonFinale != nil || pendingDailyClose != nil
            || pendingFundingStage != nil || pendingSeriesAGate || pendingWin || pendingBankruptcy
            || inspectedMechanic != nil || inspectedDept != nil || pendingOfflineReport != nil
    }

    private func maybeTriggerDecision() {
        guard !anyBlockingOverlay else { return }                  // başka popup açıkken bekle
        guard sinceDecision >= nextDecisionAt else { return }
        guard sinceDecisionReal >= Balance.decisionMinRealSeconds else { return }  // gerçek-zaman tabanı (kart yağmuru engeli)
        guard let card = DecisionSystem.pick(for: self, state: state, using: &rng) else {
            sinceDecision = 0   // uygun kart yok, biraz sonra tekrar dene
            return
        }
        pendingEvent = card
        Feedback.decision()   // karar kartı geldi
    }

    /// Acil/kriz kartını hemen tetikle (örn. düşük runway).
    func forceDecisionIfAvailable() {
        guard pendingEvent == nil else { return }
        if let card = DecisionSystem.pick(for: self, state: state, using: &rng) {
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

        // #6 (D1): seçimin gecikmeli etkilerini zaman-damgalı kuyruğa al.
        // applyAtMonth = şu anki oyun-ayı + delayMonths; tick() vadesi gelince uygular.
        for d in choice.delayed {
            state.pendingEffects.append(PendingEffect(applyAtMonth: state.months + d.delayMonths,
                                                      effects: d.effects, note: d.note))
        }
        let wasFirstDecision = (state.totalDecisions == 0)   // HZ-1 tebriği için (artıştan ÖNCE)
        state.totalDecisions += 1
        // B1: dokunulan karar mekaniğini say (Kurucu Karnesi 'en pahalı 3 ders' için).
        // Mentor-tip jenerik/etkisiz fallback kartı — sayma (gerçek karar değil).
        if card.id != "mentor-tip" {
            let m = card.category.lessonMechanic
            state.mechanicTouchCounts[m, default: 0] += 1
        }
        state.dailyDecisions += 1                       // günlük hedef ilerlemesi
        pendingEvent = nil
        scheduleNextDecision()
        // #26: sonuç artık 3.5sn toast'ta UÇMUYOR — kalıcı, kapatılabilir bir kartta
        // gösterilir + "ilgili ders" köprüsü taşır (en zengin eğitici içerik korunur).
        // Track C: karar sonucu artık MODAL değil → AKIŞA düşer (ders köprüsü mechanic ile korunur).
        if let line = choice.resultLine {
            // #8: suçlamasız yansıma — bu seçim neyi önceliklendirdi, alternatif neyi.
            // Detay-sheet'te "Yansıma" bloğu olarak görünür (yargı yok, koçluk).
            let reflection = DecisionSystem.reflection(chosen: choice, among: card.choices)
            pushFeed(.decision, "Kararın Sonucu", line,
                     positive: true, mechanic: card.category.lessonMechanic,
                     reflection: reflection)
        }
        if wasFirstDecision {
            pendingToast = NarrativeContent.firstDecisionPraise   // ilk-karar tebriği kısa toast (tek sefer)
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

    // MARK: İflas izi — post-mortem'in ADİL/ŞEFFAF gösterimi için önizleme (salt okunur).
    /// Sonraki denemenin başlangıç nakdi boost oranı (tavanlı). Örn 0.4 = +%40.
    var nextAttemptCashBoost: Double {
        min(Balance.bankruptcyXPCashBonusCap, state.founderXP * Balance.bankruptcyXPCashBonusPerXP)
    }
    /// Sonraki denemede başlangıç itibarından düşülecek iz puanı (modest, tecrübeyle solar).
    /// Not: triggerBankruptcy SONRASI çağrılır → bankruptcies + founderXP zaten güncel.
    var nextAttemptReputationScar: Double {
        let raw = min(Balance.bankruptcyReputationScarCap,
                      Double(state.bankruptcies) * Balance.bankruptcyReputationScarPerCount)
        let fade = max(0, 1 - state.founderXP * Balance.bankruptcyScarFadePerXP)
        return raw * fade
    }

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

    // MARK: - Deterministik RNG (Faz 0)

    /// `state.seed`'den RNG'yi tohumla. Tohum 0 ise (yeni oyun / eski kayıt) gerçek bir
    /// tohum üretip state'e yazar ve kalıcılaştırır → "aynı tohum → aynı oyun" garantisi.
    private func seedRNG() {
        if state.seed == 0 {
            // 0 "atanmadı" işaretidir; gerçek, sıfırdan-farklı bir tohum üret.
            var s: UInt64 = 0
            while s == 0 { s = UInt64.random(in: UInt64.min ... UInt64.max) }
            state.seed = s
            save()
        }
        rng = SplitMix64RNG(seed: state.seed)
    }

    /// Test/replay dikişi: tohumu açıkça ayarla ve RNG akışını sıfırla.
    /// (Aynı tohumla iki oyun aynı ekonomi-kritik diziyi üretir.)
    func reseed(_ seed: UInt64) {
        state.seed = seed
        rng = SplitMix64RNG(seed: seed == 0 ? 1 : seed)
    }

    // MARK: - Faz 4: Zirve metrik takibi (post-mortem "ne başardın")

    /// Bu denemenin zirvelerini monotonik max ile güncelle. İflasta post-mortem,
    /// final değil ZİRVE değerleri gösterir → kayıp anına gurur/karşıtlık katar.
    private func updatePeaks() {
        if state.users > state.peakUsers { state.peakUsers = state.users }
        let m = mrr;       if m > state.peakMRR { state.peakMRR = m }
        let v = valuation; if v > state.peakValuation { state.peakValuation = v }
        if state.reputation > state.peakReputation { state.peakReputation = state.reputation }
    }

    // MARK: - Faz 5: Hata-tetikli ders açılımı ("önce hata, sonra ders")

    /// Her tick: oyuncu ilgili HATAYI yaşadıysa ilgili Defter dersini O AN açar.
    /// Eşikler ekonomi formüllerini DEĞİŞTİRMEZ (yalnızca öğretici katman). Idempotent:
    /// `!contains` guard'ı her dersi bir kez açar → pause/save/reload güvenli.
    /// Her dersin bir açılış yolu vardır (LessonsContent.unlockHint ile birebir) —
    /// yoksa kilitli kart kalıcı gizli kalırdı.
    private func evaluateLessonTriggers() {
        // Runway / nakit
        unlockLessonIf("default-alive",   runwayMonths < 3 && netPerMonth < 0)
        unlockLessonIf("runway-half-truth", runwayMonths < 6)
        unlockLessonIf("burn-is-velocity", burnPerMonth > revenuePerMonth * 2 && burnPerMonth > 0)
        // Büyüme / birim ekonomisi
        unlockLessonIf("ltv-cac-3x",       ltvCacRatio > 0 && ltvCacRatio < 3 && netPerMonth < 0)
        unlockLessonIf("churn-silent-killer", churnRate > Balance.lessonHighChurn)
        unlockLessonIf("organic-vs-paid",  state.adBudgetPerMonth > 0 && state.adBudgetPerMonth > burnPerMonth * 0.5)
        unlockLessonIf("premature-scaling", state.users < 200 && state.members.count >= 5)
        // Ürün / fiyat
        unlockLessonIf("pmf-feel",         state.users >= 100)
        unlockLessonIf("do-things-that-dont-scale", state.months > 1.5 && state.users < 50)
        unlockLessonIf("feature-vs-product", state.projects.count >= 2)
        unlockLessonIf("focus-says-no",    state.projects.count >= 3)
        unlockLessonIf("pricing-captures-value", state.users > 200 && mrr < 1000)
        // Ekip / moral
        unlockLessonIf("hire-slow-fire-fast", state.members.count >= 2)
        unlockLessonIf("ten-x-myth",       state.members.count >= 6)
        unlockLessonIf("morale-compounds", state.morale < 35)
        unlockLessonIf("ride-the-trough",  state.months > 6 && state.morale < 50 && netUserGrowthPerMonth < 5)
        // Hisse / strateji / psikoloji
        unlockLessonIf("equity-not-valuation",   state.founderEquity < 0.7)
        unlockLessonIf("safe-deferred-dilution", state.founderEquity < 0.5)
        unlockLessonIf("no-single-path",   state.stage >= 2)
        unlockLessonIf("failure-is-data",  state.bankruptcies >= 1)
    }

    private func unlockLessonIf(_ id: String, _ condition: Bool) {
        guard condition, !state.unlockedLessons.contains(id) else { return }
        unlockLesson(id)
    }

    /// Dersi aç: koleksiyona ekle, "YENİ" işaretle. `notify` true ise akışa bildir + haptik
    /// (hata-tetikli açılım). Köprüyle (karar sonucu/scorecard'dan ders görüntüleme) açılırken
    /// notify=false → sessizce koleksiyona eklenir (oyuncu zaten dersi okuyor).
    private func unlockLesson(_ id: String, notify: Bool = true) {
        guard !state.unlockedLessons.contains(id) else { return }
        state.unlockedLessons.append(id)
        if !state.newLessonIds.contains(id) { state.newLessonIds.append(id) }
        if notify, let lesson = LessonsContent.lesson(id: id) {
            pushFeed(.lesson, "Yeni Ders: \(lesson.title)",
                     "Yaşadığın durumun arkasındaki ilke Defter'de açıldı.",
                     positive: true, mechanic: lesson.mechanic)
            Feedback.success()
        }
        save()
    }

    /// Köprüyle görüntülenen dersi (mechanic eşleşmesi) sessizce koleksiyona ekle —
    /// böylece Defter'de kilitli "???" olarak kalmaz (tutarlılık).
    private func unlockLessonByMechanic(_ mechanic: String) {
        guard let lesson = LessonsContent.lesson(for: mechanic) else { return }
        unlockLesson(lesson.id, notify: false)
    }

    /// Kurucu Defteri açıldığında "YENİ" rozetlerini temizle (görüldü olarak işaretle).
    func markLessonsSeen() {
        guard !state.newLessonIds.isEmpty else { return }
        state.newLessonIds.removeAll()
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
        // Tecrübe = daha iyi başlangıç nakdi — ama TAVAN'lı (erken-oyun koruması + denge).
        let cashBoost = min(Balance.bankruptcyXPCashBonusCap, xp * Balance.bankruptcyXPCashBonusPerXP)
        fresh.cash = Balance.startCash * (1 + cashBoost)
        // İflas izi (scar): başlangıç itibarına MODEST, ZAMANLA SOLAN düşüş. Adil — açıkça gösterilir.
        // İz = (iflas sayısı × puan, tavanlı) × (1 - tecrübe-solması). Öğrenen kurucu daha az "yanık" başlar.
        let rawScar = min(Balance.bankruptcyReputationScarCap,
                          Double(bankruptcies) * Balance.bankruptcyReputationScarPerCount)
        let fade = max(0, 1 - xp * Balance.bankruptcyScarFadePerXP)
        fresh.reputation = max(0, fresh.reputation - rawScar * fade)
        fresh.hasSeenOnboarding = true
        // Kimliği koru: kuruluşu tekrar istemeyiz; yeni şirket aynı kurucunun yeni denemesidir.
        fresh.profile = profile
        if profile.setupComplete {
            let cat = firstProject?.category ?? 0
            let name = firstProject?.name ?? (profile.companyName.isEmpty ? "MVP" : profile.companyName)
            let proj = ProjectState(name: name, category: cat,
                                    startMonth: 0,
                                    devProgress: Balance.projectMVPThreshold, isLive: true)
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
        seedRNG()              // yeni deneme = yeni tohum (kohort üretiminden ÖNCE tohumla)
        debtMonths = 0
        pendingBankruptcy = false
        lastRivalStage = fresh.stage   // Tepki Veren Rakip: yeni denemede sahte stage-jump tetiklenmesin
        rivalMRRWindow = 0
        seedCohortIfNeeded()   // yeni başlangıç ligine taze rakip kohort
        scheduleNextDecision()
        save()
    }

    /// Ayarlardan "Baştan Başla": tüm ilerlemeyi sıfırla ve şirket+proje KURULUŞ ekranına dön.
    /// Onboarding tanıtımı atlanır (hasSeenOnboarding korunur); setupComplete=false →
    /// CompanySetupOverlay açılır (kullanıcı yeni şirket adı + proje + eğilim girer).
    func resetToSetup() {
        var fresh = GameState()
        fresh.hasSeenOnboarding = true
        fresh.profile.setupComplete = false   // → CompanySetupOverlay
        state = fresh
        seedRNG()              // baştan başla = yeni tohum
        debtMonths = 0
        lastRivalStage = fresh.stage   // Tepki Veren Rakip: yeni kuruluşta sahte tetik olmasın
        rivalMRRWindow = 0
        // Tüm bekleyen overlay'leri temizle (eski oyundan sarkmasın).
        pendingBankruptcy = false; pendingWin = false; pendingEvent = nil; pendingResult = nil
        pendingFundingStage = nil; pendingCycleReview = nil; pendingSeasonFinale = nil
        pendingScenarioResult = nil; pendingDailyClose = nil; pendingSeriesAGate = false
        inspectedMechanic = nil; inspectedDept = nil; pendingOfflineReport = nil; pendingToast = nil
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
        step(realDt: realDt)
    }

    /// Tek simülasyon adımı — `tick()`'in saf gövdesi (Timer/Date'ten bağımsız).
    /// `tick()` gerçek-zaman dt'sini hesaplayıp bunu çağırır; testler/headless mod
    /// sabit dt ile çağırır → deterministik ilerleme (seedli RNG ile birlikte).
    private func step(realDt: Double) {
        // Oyun-zamanı dt = gerçek dt × hız çarpanı (zaman hızlandırma).
        let dt = realDt * speed

        let monthFraction = dt / Balance.secondsPerMonth
        advanceEconomy(monthFraction)
        updatePeaks()                    // Faz 4: bu denemenin zirve metriklerini izle (post-mortem)
        maybeCelebrateUserMilestone()    // HZ-2: ilk 100/1000 kullanıcı eşik kutlaması (bir kez)
        maybeDetectArchetype()           // C3: runtime arketibi gerçek duruma göre güncelle (yapışkan)
        advanceProjects(monthFraction)   // geliştirilen projeler ilerler, biten yayına girer
        resolvePendingEffects()          // #6 (D1): vadesi gelen gecikmeli etkileri uygula + hatırlat
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
        updateRivalAggression(monthFraction) // Tepki Veren Rakip: baskıyı soldur + büyüme tetiklerine yanıt ver (health'ten ÖNCE)
        updateHealthState() // şirket sağlık durum-makinesi: state geçişlerini yakala (zincir izleme)
        checkCausalThresholds() // Faz 2: moral/runway eşik geçişinde "çünkü" çipi yay
        evaluateLessonTriggers() // Faz 5: ilgili hata yaşandıysa Defter dersini O AN aç
        maybeCloseQuarter()
        maybeCloseSprint()
        maybeSpawnScenario()    // yeni programlı senaryo aç (aralık geçtiyse)
        maybeSettleScenarios()  // deadline geçen senaryoları değerlendir + ödül/ceza

        // Günlük hedef: kullanıcı hedefi zamanla dolabilir → her tick kontrol.
        // Gerçek gün değişimi de burada yakalanır (ör. uzun açık oturum gece yarısını geçerse).
        refreshDailyGoalIfNeeded()
        checkDailyCompletion()

        sinceDecision += dt
        sinceDecisionReal += realDt
        maybeTriggerDecision()

        sinceAutosave += realDt
        if sinceAutosave >= 8 { sinceAutosave = 0; save() }

        sinceHistory += dt
        if sinceHistory >= 3 { sinceHistory = 0; recordHistory() }

        sinceTip += dt
        if sinceTip >= 12 { sinceTip = 0; setTip(NarrativeContent.tips) }
    }

    /// Test/headless: simülasyonu `months` oyun-ayı boyunca deterministik olarak ilerlet
    /// (Timer'sız, sabit alt-adımlarla). Her ay sınırında metrik anlık görüntüsü döner.
    /// Aynı tohum + aynı kurulum → eleman-eleman aynı dizi (Faz 0 kabul kriteri).
    @discardableResult
    func advanceMonthsHeadless(_ months: Int, stepsPerMonth: Int = 10) -> [MetricSnapshot] {
        let prevSpeed = speed
        speed = 1
        lastTick = Date()
        let realDtPerStep = Balance.secondsPerMonth / Double(max(1, stepsPerMonth))
        var out: [MetricSnapshot] = []
        out.reserveCapacity(months)
        for _ in 0..<max(0, months) {
            for _ in 0..<max(1, stepsPerMonth) { step(realDt: realDtPerStep) }
            out.append(MetricSnapshot(month: state.months, cash: state.cash, users: state.users,
                                      morale: state.morale, mrr: mrr, valuation: valuation,
                                      reputation: state.reputation))
        }
        speed = prevSpeed
        return out
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

    /// #6 (D1): Vadesi gelen (applyAtMonth <= months) gecikmeli etkileri uygula,
    /// not'u oyuncuya göster, kuyruktan çıkar. Aynı tick'te birden çok vade dolarsa
    /// hepsi uygulanır; en sonuncusunun notu pendingResult/pendingToast'a yazılır
    /// (overlay yarışı yok — mevcut tek-yüzey deseni). Karar kartı açıksa toast'a düşer.
    private func resolvePendingEffects() {
        guard !state.pendingEffects.isEmpty else { return }
        let due = state.pendingEffects.filter { $0.applyAtMonth <= state.months }
        guard !due.isEmpty else { return }
        state.pendingEffects.removeAll { $0.applyAtMonth <= state.months }
        var lastNote: String? = nil
        for pe in due {
            for ce in pe.effects { if let eff = ce.effect { apply(eff) } }
            if !pe.note.isEmpty { lastNote = pe.note }
        }
        clamp()
        if let note = lastNote {
            // Track C: gecikmeli karar sonucu → AKIŞA (modal/toast çakışması yok).
            pushFeed(.delayed, "Geçmiş Kararın", note, positive: true)
            Feedback.warning()
        }
    }

    /// HZ-2: kullanıcı eşiklerini (100, 1000) ilk geçişte BİR KEZ kutla (kalıcı flag).
    /// pendingToast yolu (overlay yarışı yok). Eğitici dokunuş — ölçeklenmeyen işler / churn.
    private func maybeCelebrateUserMilestone() {
        for m in NarrativeContent.userMilestones where state.users >= Double(m)
            && !state.celebratedUserMilestones.contains(m) {
            state.celebratedUserMilestones.append(m)
            if let msg = NarrativeContent.userMilestonePraise(m) {
                pushFeed(.milestone, "\(BigNumber.format(Double(m))) kullanıcı!", msg, positive: true)
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

    /// Faz 3: kuruluş bitti ama "ilk hedef" splash'ı henüz gösterilmedi → bir kez göster.
    var shouldShowFirstGoalSplash: Bool { companySetupComplete && !state.hasSeenFirstGoalSplash }
    func completeFirstGoalSplash() { state.hasSeenFirstGoalSplash = true; save() }

    var companyName: String { state.profile.companyName }
    var founderFullName: String { state.profile.founderFullName }
    /// Kurucu ünvanı evreyle yükselir (Hacker → Kurucu → CEO ...).
    var founderTitle: String { currentStage.title }

    /// A1: oyuncunun beyan ettiği kurucu eğilimi (mekanik etki yok — salt felsefe/UI).
    var founderLeaning: FounderLeaning { FounderLeaning(rawValue: state.founderLeaning) ?? .balanced }

    // MARK: - C3 Runtime arketip tespiti
    //
    // Oyunun GERÇEK durumundan TÜRETİLİR (oyuncu seçmez). Niche eşiği C4 LTV/ARPU
    // tavanından SONRA kalibre edilmiştir: satış-gücü kaynaklı ARPU katkısı tavanın
    // (Balance.salesArpuCap) yarısını geçtiğinde + kullanıcı tabanı darsa = niş premium.
    // Erken oyunda yeterli sinyal yoksa .unknown döner (suçlamasız: 'henüz şekilleniyor').
    var currentArchetype: FounderArchetype {
        // Yeterli sinyal yok → henüz şekilleniyor (erken oyun).
        guard state.stageReached >= 2 || state.users >= 200 else { return .unknown }
        // Satış gücünün ARPU'ya katkısı (C4 tavanına göre orantılı: 0..1).
        let salesArpuShare = min(Balance.salesArpuCap, salesPower * Balance.salesArpuPerUnit) / Balance.salesArpuCap
        // Öncelik sırası: ilk tutan dal (suçlamasız — hiçbiri 'doğru' değil).
        if state.founderEquity >= 0.55 && state.adBudgetPerMonth <= 0 {
            return .bootstrap                                    // hisseyi koru + reklamsız
        }
        if state.founderEquity < 0.45 && state.stageReached >= 3 {
            return .vcRocket                                     // dilution → hız
        }
        if salesArpuShare >= 0.5 && state.users < 5_000 {
            return .niche                                        // dar taban + güçlü fiyat
        }
        if state.users >= 20_000 {
            return .platform                                     // geniş taban + ağ etkisi
        }
        return FounderArchetype(rawValue: state.detectedArchetype) ?? .unknown  // son kararlı arketibi koru
    }

    /// C3: tespit edilen arketibi state'e yazar (yapışkan). Tick'te çağrılır; ucuz.
    /// .unknown'a geri düşürmez (bir kez şekillenince UI titreşmesin) — yalnızca
    /// somut bir arketip tespit edildiğinde günceller.
    private func maybeDetectArchetype() {
        let detected = currentArchetype
        if detected != .unknown, detected.rawValue != state.detectedArchetype {
            state.detectedArchetype = detected.rawValue
        }
    }
    var sectorDef: CompanySectorDef { Balance.sector(state.profile.sector) ?? Balance.sectors[0] }

    /// Kuruluşu tamamla: profili kaydet + ilk projeyi (yayında) oluştur.
    /// İlk proje gün-1'den canlıdır (MVP yayında) — şirketin ilk ürünü.
    func completeCompanySetup(firstName: String, lastName: String,
                              company: String, sector: Int,
                              firstProjectName: String, firstProjectCategory: Int,
                              leaning: FounderLeaning = .balanced) {
        func clean(_ s: String) -> String { s.trimmingCharacters(in: .whitespacesAndNewlines) }
        state.profile.founderFirstName = clean(firstName)
        state.profile.founderLastName = clean(lastName)
        state.profile.companyName = clean(company)
        state.profile.sector = min(max(0, sector), Balance.sectors.count - 1)
        state.profile.setupComplete = true
        state.founderLeaning = leaning.rawValue   // A1: kurucu eğilimini kaydet (mekanik etki yok)

        let catIndex = min(max(0, firstProjectCategory), Balance.projectCategories.count - 1)
        let projName = clean(firstProjectName).isEmpty ? clean(company) : clean(firstProjectName)
        // İlk ürün "yayında ama henüz ince MVP" doğar (devProgress = MVP eşiği): kazanç cılız
        // başlar, oyuncu ekibi ürüne atayıp geliştirdikçe olgunlaşır ve geliri büyür.
        let firstProject = ProjectState(name: projName, category: catIndex,
                                        startMonth: state.months,
                                        devProgress: Balance.projectMVPThreshold, isLive: true)
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
        // Oyun DURAKLI başlar: oyuncu ▶ (kontrol dock) deyince zaman akar. Kuruluştan sonra
        // sakin bir "hazırlan" anı; oyuncu önce ekibi/ürünü görür, sonra başlatır.
        isPaused = true
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

    /// Bir üyenin departmanındaki kişi-başı çıktısı (atanan-ekiple proje inşa gücü için).
    private func perHeadOutput(_ dept: Int) -> Double {
        let hc = state.headcount[dept]
        guard hc > 0 else { return 0 }
        return deptOutput(dept) / Double(hc)
    }

    /// Bir projeye ATANAN ekibin ürün-inşa gücü. Yalnız atanan üyeler sayılır; ürünü asıl
    /// Mühendislik (d0) inşa eder, Ürün&Tasarım (d1) yarı katkı, diğer roller küçük katkı.
    /// Kimse atanmazsa 0 → ürün ilerlemez (ekip yönetimi zorunlu — gerçek-hayat mantığı).
    func projectBuildPower(_ project: ProjectState) -> Double {
        let assigned = state.members.filter { $0.assignedProjectID == project.id }
        guard !assigned.isEmpty else { return 0 }
        return assigned.reduce(0) { acc, m in
            let w: Double
            switch m.deptIndex {
            case 0:  w = 1.0    // Mühendislik
            case 1:  w = 0.5    // Ürün & Tasarım
            default: w = 0.15   // pazarlama/satış/ops ürünü doğrudan inşa etmez
            }
            return acc + perHeadOutput(m.deptIndex) * w
        }
    }

    /// Geliştirme hızı çarpanı: ATANAN ekibin gücü referansa göre projeyi hızlandırır.
    /// 0 olabilir (atama yoksa) → durur. Tavan 3× (kalabalık ekip aşırı hızlanmasın).
    func projectBuildAccel(_ project: ProjectState) -> Double {
        min(3.0, projectBuildPower(project) / Balance.projectDevReference)
    }

    /// Henüz olgunlaşmamış projenin MVP (yayın) eşiğine kalan süresi (gerçek saniye) — ETA.
    /// Atanan ekip yoksa süresiz (.infinity) → UI "ekip ata" yönlendirir.
    func projectETASeconds(_ project: ProjectState) -> Double {
        guard !project.isLive, let cat = Balance.projectCategory(project.category) else { return 0 }
        let accel = projectBuildAccel(project)
        guard accel > 0 else { return .infinity }
        let remaining = max(0, Balance.projectMVPThreshold - project.devProgress)
        let monthsLeft = remaining * max(0.5, cat.buildMonths) / accel
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

    /// Projeleri ATANAN ekiple ilerlet. Olgunluk (devProgress) MVP eşiğinde yayına geçirir
    /// ama YAYINDAN SONRA da 1'e dek gelişmeye devam eder (ürün olgunlaştıkça gelir büyür).
    /// `internal` görünürlük — @testable testler deterministik geçişi tetikleyebilsin.
    func advanceProjects(_ monthFraction: Double) {
        guard state.projects.contains(where: { $0.devProgress < 1 }) else { return }
        let mvp = Balance.projectMVPThreshold
        for i in state.projects.indices where state.projects[i].devProgress < 1 {
            let accel = projectBuildAccel(state.projects[i])
            guard accel > 0 else { continue }   // atanan ekip yoksa ürün ilerlemez
            let cat = Balance.projectCategory(state.projects[i].category)
            let months = max(0.5, cat?.buildMonths ?? 2)
            state.projects[i].devProgress = min(1, state.projects[i].devProgress + monthFraction * accel / months)
            // MVP eşiğini İLK kez geçince yayına gir (bir kerelik kutlama + moral/itibar).
            if !state.projects[i].isLive && state.projects[i].devProgress >= mvp {
                state.projects[i].isLive = true
                state.morale = min(100, state.morale + Balance.projectLaunchMoraleBonus)
                state.reputation = min(100, state.reputation + Balance.projectLaunchReputationBonus)
                pendingToast = "\(state.projects[i].name) yayında! Geliştirdikçe geliri büyür."
                // Nedensellik: ürün olgunlaştı → gizli büyüme/ARPU katkısını görünür kıl.
                let g = Int((cat?.growthBonus ?? 0) * 100)
                let a = Int((cat?.arpuBonus ?? 0) * 100)
                emitCausal("chart.line.uptrend.xyaxis",
                           "\(state.projects[i].name) yayında → organik büyüme +%\(g) · ARPU +%\(a)",
                           .good)
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

    func saveOnBackground() {
        save()
        // D2 (#5): arka plana alınırken nazik hatırlatmaları planla (baskısız).
        // streak-risk yalnız korunacak bir seri varsa planlanır; ayrıca ~24sa dönüş daveti.
        // İzin yoksa no-op (status kontrollü).
        NotificationManager.scheduleReminders(streak: state.streak, dailyCompleted: state.dailyCompleted,
                                              runwayMonths: runwayMonths)
    }

    func refreshOnForeground() {
        // D2 (#5): oyuncu geri döndü — bekleyen tüm planlı bildirimleri iptal et
        // (içerideyken bildirim göndermek anlamsız + rahatsız edici).
        NotificationManager.cancelAll()
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
        updatePeaks()   // Faz 4: çevrimdışı büyüme de zirveye yansısın
        // Track C: "yokken neler oldu" → AKIŞA (engellemeyen özet).
        let h = Int(elapsed) / 3600, m = (Int(elapsed) % 3600) / 60
        let timeText = h > 0 ? "\(h)sa \(m)dk" : "\(m)dk"
        pushFeed(.offline, "Yokken Neler Oldu",
                 "\(timeText) yoktun. Nakit \(dCash >= 0 ? "+" : "")\(BigNumber.money(dCash)) · Kullanıcı +\(BigNumber.format(max(0, dUsers))).",
                 positive: dCash >= 0)
        // Anlamlı yoklukta belirgin "tekrar hoş geldin" modalı (UI zaten kurulu: OfflineReportView).
        if elapsed >= Balance.offlineReportMinSeconds {
            pendingOfflineReport = OfflineReport(seconds: elapsed, cashDelta: dCash, usersDelta: dUsers)
        }
    }
}

/// HUD üstünde yüzen ±tutar çipi için yayılan ayrık nakit hareketi.
/// `id` her olay için yeni — UI Equatable üzerinden tekrarsız tetikleyebilsin.
/// `amount` işaretli: pozitif=kazanç (yeşil), negatif=harcama (kırmızı).
struct CashDeltaEvent: Identifiable, Equatable {
    let id: UUID = UUID()
    let amount: Double
}

/// "Çünkü" nedensellik çipi payload'u — HUD altında kısa süre beliren tek satırlık
/// neden-sonuç bildirimi. Faz 2'nin matematiğini oyuncuya HİSSETTİREN katman.
struct CausalNote: Identifiable, Equatable {
    enum Tone { case good, warn, bad }
    let id: UUID = UUID()
    let icon: String
    let text: String
    let tone: Tone
}

/// Headless/test ilerlemesinin ay-sınırı metrik anlık görüntüsü. Determinizm
/// testleri iki oyunun dizilerini eleman-eleman karşılaştırır (Faz 0 kabul kriteri).
struct MetricSnapshot: Equatable {
    let month: Double
    let cash: Double
    let users: Double
    let morale: Double
    let mrr: Double
    let valuation: Double
    let reputation: Double
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
