import Foundation

// MARK: - Gecikmeli / Zincirleme Etki Motoru (#6 — D1)
//
// Bir kararın bazı sonuçları ANINDA değil, AYLAR SONRA görünür: hızlı işe alımın
// uyum sancısı, teknik borcun faizi, indirimle gelen kullanıcının churn'ü.
// Bu "gecikmeli ders" mekaniği oyunun çekirdek felsefesini güçlendirir:
// her karar bir bahistir ve bahsin gerçek bedeli zamanla ortaya çıkar.
//
// KURAL-0: Bu motor SEVK EDİLENE (kartlara `delayed:` bağlanıp tick'te uygulanana)
// kadar pazarlamada "gecikmeli sonuçlar" / "kararların geleceği etkiler" gibi
// bir vaat KULLANILMAZ. Vaadin kodda canlı karşılığı olmalıdır.

/// Bir seçime iliştirilen, GELECEKTE uygulanacak etki paketi (içerik tarafı).
/// `DecisionChoice.delayed` içinde tanımlanır; `delayMonths` kadar OYUN-AYI sonra
/// `effects` uygulanır ve `note` oyuncuya hatırlatma olarak gösterilir.
/// Saf veri — DecisionEffect'i yeniden kullanır (ekonomi sözleşmesi tek noktada).
struct DelayedEffect {
    /// Seçim anından itibaren kaç OYUN-AYI sonra tetiklenecek (kesirli olabilir).
    let delayMonths: Double
    /// Vadesi geldiğinde uygulanacak etkiler (anlık etkilerle aynı DecisionEffect tipi).
    let effects: [DecisionEffect]
    /// Vade dolduğunda oyuncuya gösterilecek hatırlatma metni (geçmiş kararla bağ kurar).
    let note: String

    init(delayMonths: Double, effects: [DecisionEffect], note: String) {
        self.delayMonths = delayMonths
        self.effects = effects
        self.note = note
    }
}

/// Kuyruğa alınmış, zaman-damgalı bekleyen etki (state tarafı — KALICI/Codable).
/// `resolve()` sırasında seçimin her `DelayedEffect`'i için bir tane üretilir;
/// `applyAtMonth` = o anki `state.months + delayMonths`. `tick()` her adımda
/// vadesi gelen (applyAtMonth <= months) kayıtları uygular + kuyruktan çıkarır.
///
/// Codable: DecisionEffect bir enum (Codable değil) olduğundan, etkileri burada
/// AYRIŞTIRILMIŞ ilkel alanlar olarak saklarız (kind + iki sayısal yük). Bu sayede
/// kuyruk kill/relaunch sonrası geri yüklenebilir ve eski save'ler çökmez.
struct PendingEffect: Codable {
    /// Bu etkinin uygulanacağı oyun-ayı (mutlak zaman damgası).
    var applyAtMonth: Double
    /// Vadesi geldiğinde uygulanacak etkiler (Codable temsil — aşağıya bak).
    var effects: [CodableEffect]
    /// Oyuncuya gösterilecek hatırlatma metni.
    var note: String

    init(applyAtMonth: Double, effects: [DecisionEffect], note: String) {
        self.applyAtMonth = applyAtMonth
        self.effects = effects.map(CodableEffect.init)
        self.note = note
    }
}

/// DecisionEffect enum'ının KALICI (Codable) temsili. DecisionEffect'in kendisine
/// DOKUNMADAN (ekonomi sözleşmesi değişmez) yan bir köprü tipi. Her case bir `kind`
/// string'i + iki sayısal yük (`a`, `b`) ile düzleştirilir; `decode` güvenli (bilinmeyen
/// kind / eksik alan → .none, çökme yok → migration-proof).
struct CodableEffect: Codable {
    var kind: String
    var a: Double
    var b: Double

    init(_ e: DecisionEffect) {
        switch e {
        case .cash(let v):              kind = "cash"; a = v; b = 0
        case .cashPercent(let p):       kind = "cashPercent"; a = p; b = 0
        case .users(let v):             kind = "users"; a = v; b = 0
        case .usersPercent(let p):      kind = "usersPercent"; a = p; b = 0
        case .morale(let v):            kind = "morale"; a = v; b = 0
        case .reputation(let v):        kind = "reputation"; a = v; b = 0
        case .moraleTargetBonus(let v): kind = "moraleTargetBonus"; a = v; b = 0
        case .equity(let v):            kind = "equity"; a = v; b = 0
        case .headcount(let dept, let d): kind = "headcount"; a = Double(dept); b = Double(d)
        }
    }

    /// Geri çevrim: DecisionEffect'e dönüştür. Bilinmeyen kind → nil (güvenle atlanır).
    var effect: DecisionEffect? {
        switch kind {
        case "cash":              return .cash(a)
        case "cashPercent":       return .cashPercent(a)
        case "users":             return .users(a)
        case "usersPercent":      return .usersPercent(a)
        case "morale":            return .morale(a)
        case "reputation":        return .reputation(a)
        case "moraleTargetBonus": return .moraleTargetBonus(a)
        case "equity":            return .equity(a)
        case "headcount":         return .headcount(dept: Int(a), delta: Int(b))
        default:                  return nil
        }
    }

    enum CodingKeys: String, CodingKey { case kind, a, b }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        kind = ((try? c.decodeIfPresent(String.self, forKey: .kind)) ?? nil) ?? ""
        a = ((try? c.decodeIfPresent(Double.self, forKey: .a)) ?? nil) ?? 0
        b = ((try? c.decodeIfPresent(Double.self, forKey: .b)) ?? nil) ?? 0
    }
}
