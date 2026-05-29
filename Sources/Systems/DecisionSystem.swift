import Foundation

// MARK: - Karar kartı veri tipleri

enum DecisionCategory: String {
    case investor, crisis, press, team, product, market, opportunity
    var tint: String {
        switch self {
        case .investor:    return "5B8DEF"
        case .crisis:      return "E0574F"
        case .press:       return "FFD166"
        case .team:        return "C77DFF"
        case .product:     return "4FD1A1"
        case .market:      return "FF9F5A"
        case .opportunity: return "2EE6C5"
        }
    }
}

/// Kart ne zaman uygun olur.
enum DecisionTrigger {
    case always
    case minStage(Int)
    case minUsers(Double)
    case lowMorale(Double)     // morale < x
    case lowRunwayMonths(Double)
    case minReputation(Double)
}

/// Bir seçimin yarattığı etki.
enum DecisionEffect {
    case cash(Double)
    case cashPercent(Double)
    case users(Double)
    case usersPercent(Double)
    case morale(Double)
    case reputation(Double)
    case moraleTargetBonus(Double)
    case equity(Double)
    case headcount(dept: Int, delta: Int)
}

struct DecisionChoice {
    let label: String
    let detail: String?        // sonucun kısa ipucu (kartta gri yazı)
    let effects: [DecisionEffect]
    let resultLine: String?    // seçimden sonra kısa toast
    let delayed: [DelayedEffect]   // #6 (D1): gelecekte uygulanacak gecikmeli etkiler (varsayılan boş)

    init(_ label: String, detail: String? = nil, effects: [DecisionEffect],
         result: String? = nil, delayed: [DelayedEffect] = []) {
        self.label = label
        self.detail = detail
        self.effects = effects
        self.resultLine = result
        self.delayed = delayed
    }
}

struct DecisionCard: Identifiable {
    let id: String
    let category: DecisionCategory
    let speaker: String
    let icon: String
    let prompt: String
    let choices: [DecisionChoice]
    let once: Bool
    let trigger: DecisionTrigger

    init(_ id: String, category: DecisionCategory, speaker: String, icon: String,
         prompt: String, once: Bool = false, trigger: DecisionTrigger = .always,
         choices: [DecisionChoice]) {
        self.id = id
        self.category = category
        self.speaker = speaker
        self.icon = icon
        self.prompt = prompt
        self.once = once
        self.trigger = trigger
        self.choices = choices
    }
}

// MARK: - Uygunluk & seçim

enum DecisionSystem {
    @MainActor
    static func isEligible(_ card: DecisionCard, model: GameModel, state: GameState) -> Bool {
        if card.once && state.seenEventIDs.contains(card.id) { return false }
        switch card.trigger {
        case .always:                 return true
        case .minStage(let s):        return state.stage >= s
        case .minUsers(let u):        return state.users >= u
        case .lowMorale(let m):       return state.morale < m
        case .lowRunwayMonths(let r): return model.runwayMonths < r
        case .minReputation(let r):   return state.reputation >= r
        }
    }

    /// Uygun kartlardan birini seç. Şirket sağlık durum-makinesi (companyHealth) kartların
    /// ÖNCELİĞİNİ belirler — ekonomi sabitleri/etkileri değişmez, sadece dağılım kayar.
    ///
    /// Önceliklendirme (Tasarım Prensipleri E maddesi):
    /// - `.crisis`: crisis + team + product kartlarına çok yüksek ağırlık (kurtarma odaklı).
    /// - `.strained`: crisis + team + product + uyarıcı kartlar (önleyici).
    /// - `.healthy`: opportunity + press + investor + business-as-usual karışım.
    /// - `.recovering`: team + product + opportunity (toparlanma desteği).
    /// - Uzun zincir (`crisisChainCount > 2`): crisis kartları neredeyse garanti.
    @MainActor
    static func pick(for model: GameModel, state: GameState) -> DecisionCard? {
        let eligible = DecisionContent.all.filter { isEligible($0, model: model, state: state) }
        // Havuz boşaldıysa (örn. tüm once kartları tükendi, erken evre) DEAD AIR olmasın:
        // jenerik, etkisiz bir "mentor ipucu" kartı dön — oyuncu akışta kalır.
        let raw: DecisionCard
        if eligible.isEmpty {
            raw = mentorTipFallback()
        } else if let picked = weightedPick(from: eligible, health: model.companyHealth,
                                            chainCount: state.crisisChainCount) {
            raw = picked
        } else {
            return nil
        }
        // BAĞLAM ENTERPOLASYONU — kart metnindeki {{company}}, {{firstName}}, {{sector}},
        // {{project}}, {{founder}} placeholder'larını oyuncunun şirket bilgileriyle doldur.
        // Yer tutucu içermeyen kartlarda metin değişmez (geriye uyumlu).
        let ctx = CompanyContext(state: state)
        return interpolated(raw, with: ctx)
    }

    /// Kartı + tüm seçim satırlarını CompanyContext ile enterpole edilmiş bir kopyasıyla
    /// değiştirir. DecisionCard `let` olduğundan yeni instance üretmek tek yol.
    private static func interpolated(_ card: DecisionCard, with ctx: CompanyContext) -> DecisionCard {
        let newChoices = card.choices.map { c in
            DecisionChoice(ctx.interpolate(c.label),
                           detail: c.detail.map { ctx.interpolate($0) },
                           effects: c.effects,
                           result: c.resultLine.map { ctx.interpolate($0) })
        }
        return DecisionCard(card.id, category: card.category, speaker: card.speaker,
                            icon: card.icon, prompt: ctx.interpolate(card.prompt),
                            once: card.once, trigger: card.trigger, choices: newChoices)
    }

    /// Karar havuzu geçici olarak boşaldığında gösterilen nötr fallback kartı.
    /// Etkisi sıfıra yakın (ekonomiyi bozmaz), ama eğitici bir mentor mesajı taşır —
    /// oyuncu "bekleme/ölü an" yaşamaz. Birkaç varyanttan rastgele biri seçilir.
    static func mentorTipFallback() -> DecisionCard {
        let tips: [(String, String, String)] = [
            ("Şu an sular durgun. Bu nadir an: metriklerine bak, bir sonraki hamleni planla.",
             "Metrikleri incele", "Sakin dönemler stratejik düşünme fırsatıdır — her an kriz olmak zorunda değil."),
            ("Mentorun arıyor: \"Bu hafta öğrendiğin en önemli şey neydi?\" diye soruyor.",
             "Düşün ve devam et", "En iyi kurucular düzenli olarak geriye bakıp ders çıkarır; ivme refleksten değil farkındalıktan gelir."),
            ("Ekip iyi gidiyor, acil bir karar yok. Bir kahve al, ürününü bir kullanıcı gözüyle dene.",
             "Ürünü gözden geçir", "Kendi ürününü kullanmak (dogfooding) en ucuz ve en dürüst geri bildirimdir."),
        ]
        let pick = tips.randomElement() ?? tips[0]
        return DecisionCard("mentor-tip", category: .opportunity, speaker: "Mentor", icon: "🧭",
                            prompt: pick.0,
                            choices: [DecisionChoice(pick.1, detail: nil, effects: [], result: pick.2)])
    }

    /// Sağlık durumuna göre kategori ağırlıkları üret + ağırlıklı rastgele seçim.
    static func weightedPick(from cards: [DecisionCard],
                             health: CompanyHealth,
                             chainCount: Int) -> DecisionCard? {
        let weights = categoryWeights(health: health, chainCount: chainCount)
        let weighted: [(DecisionCard, Double)] = cards.map { card in
            (card, max(0.0001, weights[card.category] ?? 1.0))
        }
        let total = weighted.reduce(0.0) { $0 + $1.1 }
        guard total > 0 else { return cards.randomElement() }
        var roll = Double.random(in: 0..<total)
        for (card, w) in weighted {
            if roll < w { return card }
            roll -= w
        }
        return weighted.last?.0
    }

    /// Şirket sağlığına göre kategori ağırlık tablosu. Daha yüksek değer → daha sık çıkar.
    static func categoryWeights(health: CompanyHealth, chainCount: Int) -> [DecisionCategory: Double] {
        switch health {
        case .crisis:
            // Kırmızı bölge: crisis kartları baskın, team/product kurtarma uygun, opportunity nadir.
            var w: [DecisionCategory: Double] = [
                .crisis: 8.0, .team: 3.0, .product: 2.5, .market: 1.5,
                .investor: 1.0, .press: 0.5, .opportunity: 0.4
            ]
            // Uzun zincir → crisis kartlarına neredeyse garanti yönlendir (oyuncu tepki vermeli).
            if chainCount > 2 { w[.crisis] = 14.0 }
            return w
        case .strained:
            // Sarı bölge: önleyici uyarılar — crisis + team + product + biraz market.
            return [
                .crisis: 3.5, .team: 3.0, .product: 2.5, .market: 2.0,
                .investor: 1.5, .press: 1.0, .opportunity: 1.0
            ]
        case .healthy:
            // Yeşil bölge: fırsatlar + basın + yatırımcı + iş-akışı karışım.
            return [
                .crisis: 0.5, .team: 1.5, .product: 1.5, .market: 1.5,
                .investor: 2.5, .press: 2.5, .opportunity: 3.0
            ]
        case .recovering:
            // Toparlanma: ekip + ürün + fırsat hafifçe baskın; crisis hâlâ olası ama düşük.
            return [
                .crisis: 1.0, .team: 2.5, .product: 2.5, .market: 1.5,
                .investor: 1.5, .press: 1.5, .opportunity: 2.5
            ]
        }
    }
}
