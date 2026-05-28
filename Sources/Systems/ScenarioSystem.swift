import Foundation

/// Senaryolar için saf fonksiyon paketi: yeni senaryo seç, hedef değer hesapla,
/// ilerleme oranı hesapla, deadline'da başarı/başarısızlık değerlendir, ödül/ceza üret.
/// GameModel sadece çağırır — mantık burada izole, test edilebilir.
enum ScenarioSystem {

    // MARK: - Sayısal ödeme tablosu (Balance ile uyumlu küçük dokunuşlar)

    /// Senaryo başarısı: küçük nakit + itibar/moral dokunuşu (ekonomiyi bozmaz).
    struct Reward {
        var cash: Double = 0
        var reputation: Double = 0
        var morale: Double = 0
        var usersPercent: Double = 0    // mevcut kullanıcının yüzdesi
    }

    // MARK: - Senaryo seçimi

    /// Sıradaki senaryo türünü seç: oyunun mevcut durumuna göre uygun olan(lar)dan rastgele.
    /// Aktif senaryoların tipleriyle ÇAKIŞMAZ (oyuncu aynı türden 2 kopya görmesin).
    /// İlk evrelerde (Garaj/Pre-seed) ağır/kurumsal senaryolar (uyum, yatırımcı) daha az olur.
    static func pickKind(stage: Int, active: [ScenarioInstance]) -> ScenarioKind {
        let activeKinds = Set(active.map { $0.kind })
        let allKinds = ScenarioKind.allCases
            .filter { !activeKinds.contains($0.rawValue) }
            .filter { isUnlockedAtStage($0, stage: stage) }
        return allKinds.randomElement() ?? .demoDay
    }

    /// Bir senaryo türü hangi evreden itibaren spawn edilebilir (gerçekçi kademeli aç).
    static func isUnlockedAtStage(_ kind: ScenarioKind, stage: Int) -> Bool {
        switch kind {
        case .demoDay, .pressInterview, .customerPilot, .hackathonDeadline:
            return true                  // her zaman uygun
        case .techCrunchStage, .clientLaunch:
            return stage >= 1            // Pre-seed+
        case .investorMeeting, .complianceAudit:
            return stage >= 2            // Seed+
        }
    }

    // MARK: - Hedef değer

    /// Senaryo başlangıcı için hedef değer hesapla — mevcut metriği baz alır,
    /// ulaşılabilir ama zorlayıcı bir tavan koyar. Garaj başlangıcında bile mantıklı
    /// (kullanıcı 50 ise hedef 250 mantıksız değil, 5K → 25K agresif).
    static func targetValue(for kind: ScenarioKind, snapshot: Snapshot) -> Double {
        switch kind.metric {
        case .valuation:
            // %30-50 büyüme; minimum tabanı evreye göre.
            return max(snapshot.valuation * 1.4, snapshot.valuationFloor)
        case .reputation:
            // Mevcut itibarın 10-15 puan üstü, max 80 (göreceli ulaşılabilir).
            return min(80, snapshot.reputation + 12)
        case .users:
            // %30-60 büyüme; minimum 100.
            return max(100, snapshot.users * 1.5)
        case .mrr:
            // %40 büyüme; minimum $200.
            return max(200, snapshot.mrr * 1.4)
        case .liveProjects:
            // Mevcut + 1 (tek yeni proje teslimi).
            return Double(snapshot.liveProjects + 1)
        case .morale:
            // 70 — bekledikten sonra moralin orta-üstü olması.
            return 70
        }
    }

    // MARK: - İlerleme + değerlendirme

    /// Şu anki metriğin hedefe oranı (0..1) — UI ilerleme barı için.
    static func progress(for kind: ScenarioKind, target: Double, snapshot: Snapshot) -> Double {
        guard target > 0 else { return 0 }
        let current = currentValue(for: kind, snapshot: snapshot)
        return min(1, max(0, current / target))
    }

    /// Şu anki metrik değeri (UI gösterimi için ham sayı).
    static func currentValue(for kind: ScenarioKind, snapshot: Snapshot) -> Double {
        switch kind.metric {
        case .valuation:    return snapshot.valuation
        case .reputation:   return snapshot.reputation
        case .users:        return snapshot.users
        case .mrr:          return snapshot.mrr
        case .liveProjects: return Double(snapshot.liveProjects)
        case .morale:       return snapshot.morale
        }
    }

    /// Deadline anında başarı testini uygula (current >= target).
    static func evaluate(_ scenario: ScenarioInstance, snapshot: Snapshot) -> Bool {
        currentValue(for: scenario.scenarioKind, snapshot: snapshot) >= scenario.goalTargetValue
    }

    // MARK: - Ödül / ceza

    /// Başarı / başarısızlık karşılığı küçük ekonomik etki (nakit eklemesi tavanlı,
    /// itibar/moral dokunuşları orta — sezon ödülleriyle aynı dilde).
    static func reward(for kind: ScenarioKind, success: Bool, snapshot: Snapshot) -> Reward {
        var r = Reward()
        let cashBase = max(5_000, snapshot.mrr * 6)   // ölçeğe göre küçük enjeksiyon
        switch kind {
        case .demoDay:
            if success { r.cash = cashBase * 2; r.reputation = 5 }
            else { r.reputation = -3 }
        case .pressInterview:
            if success { r.reputation = 10 }
            else { r.reputation = -5 }
        case .customerPilot:
            if success { r.usersPercent = 0.2; r.cash = cashBase * 0.5 }
            else { r.reputation = -3 }
        case .techCrunchStage:
            if success { r.reputation = 12; r.usersPercent = 0.08 }
            else { r.reputation = -4 }
        case .hackathonDeadline:
            if success { r.cash = cashBase; r.reputation = 6 }
            else { r.morale = -8 }
        case .complianceAudit:
            if success { r.morale = 5; r.reputation = 4 }
            else { r.cash = -cashBase * 0.4; r.reputation = -4 }
        case .investorMeeting:
            if success { r.cash = cashBase * 3; r.reputation = 8 }
            else { r.reputation = -6 }
        case .clientLaunch:
            if success { r.cash = cashBase * 1.5; r.reputation = 5 }
            else { r.reputation = -3 }
        }
        return r
    }

    // MARK: - Snapshot (saf fonksiyona giriş)

    /// Sistemin saf kalması için GameModel'in snapshot'unu DTO olarak alır.
    struct Snapshot {
        let valuation: Double
        let reputation: Double
        let users: Double
        let mrr: Double
        let morale: Double
        let liveProjects: Int
        let valuationFloor: Double   // evre tabanlı minimum hedef (mantıksız küçük olmasın)
    }
}
