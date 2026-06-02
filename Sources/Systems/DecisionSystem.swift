import Foundation

// MARK: - Karar kartı veri tipleri

enum DecisionCategory: String {
    case investor, crisis, press, team, product, market, opportunity
    /// Tepki Veren Rakip (Antagonist): kohorttan bir rakip oyuncuya hamle yapar
    /// (fiyat savaşı / yetenek avı / kopya özellik). Birden çok geçerli yanıt taşır.
    case competitive
    var tint: String {
        switch self {
        case .investor:    return "5B8DEF"
        case .crisis:      return "E0574F"
        case .press:       return "FFD166"
        case .team:        return "C77DFF"
        case .product:     return "4FD1A1"
        case .market:      return "FF9F5A"
        case .opportunity: return "2EE6C5"
        case .competitive: return "FF6B6B"
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
    static func pick<R: RandomNumberGenerator>(for model: GameModel, state: GameState,
                                               using rng: inout R) -> DecisionCard? {
        let eligible = DecisionContent.all.filter { isEligible($0, model: model, state: state) }
        let raw: DecisionCard

        // P0-1 CAN-SİMİDİ GUARD: runway kritik eşiğin altında (ölüm-spirali) ise oyuncu ASLA
        // büyüme/fırsat kartı görmemeli. Önce uygun crisis kartlarını süz; varsa SADECE onlardan
        // seç (state'e göre ağırlıklı). Hiç crisis kartı uygun değilse (havuz tükendi) garantili
        // acil-köprü (emergency-bridge) kartını dağıt → krize her zaman UYGUN + çok-yanıtlı bir
        // kart bulunur (tek doğru cevap yok — Tasarım DNA).
        if model.runwayMonths < Balance.crisisLifelineRunwayMonths {
            let crisisCards = eligible.filter { $0.category == .crisis }
            if let picked = weightedPick(from: crisisCards, health: .crisis,
                                         chainCount: state.crisisChainCount, using: &rng) {
                raw = interpolated(picked, with: CompanyContext(state: state))
                return raw
            }
            return interpolated(emergencyBridgeFallback(), with: CompanyContext(state: state))
        }

        // TEPKI VEREN RAKİP: rakip baskısı (rivalAggression) eşiği aştıysa, kohorttan bir rakip
        // oyuncuya hamle yapmıştır → bu turun kartı YÜKSEK OLASILIKLA competitive kategorisinden
        // seçilir (büyüme platosunu kıran ADİL baskı). Tek doğru cevap yok: her competitive kart
        // birden çok geçerli yanıt taşır. Olasılıkla (her tetikte değil) — oyun ritmi tek-renk olmasın.
        if state.rivalAggression >= Balance.rivalCardThreshold {
            let competitiveCards = eligible.filter { $0.category == .competitive }
            // Baskı büyüdükçe competitive kartın bu turda çıkma olasılığı artar (0.5..0.9 bandı).
            let surfaceChance = min(0.9, 0.5 + state.rivalAggression * 0.4)
            if !competitiveCards.isEmpty, Double.random(in: 0..<1, using: &rng) < surfaceChance,
               let picked = competitiveCards.randomElement(using: &rng) {
                return interpolated(picked, with: CompanyContext(state: state))
            }
        }

        // Havuz boşaldıysa (örn. tüm once kartları tükendi, erken evre) DEAD AIR olmasın:
        // jenerik, etkisiz bir "mentor ipucu" kartı dön — oyuncu akışta kalır.
        if eligible.isEmpty {
            raw = mentorTipFallback()
        } else if let picked = weightedPick(from: eligible, health: model.companyHealth,
                                            chainCount: state.crisisChainCount, using: &rng) {
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

    /// P0-1 GARANTİLİ ACİL-KÖPRÜ KARTI: runway kritik (ölüm-spirali) ve uygun başka crisis
    /// kartı kalmadığında dağıtılır. Krize UYGUN + birden çok GEÇERLİ yanıt taşır (tek doğru
    /// cevap yok — Tasarım DNA). Hiçbir seçenek "bedava" değildir: her biri bir takas (hisse /
    /// moral / gelecekteki yük). Köprü kredisinin bedeli GECİKMELİ etkiyle 6 ay sonra patlar
    /// (zincirleme + gecikmeli ders), böylece "kredi al" refleksi gerçek bir bahistir.
    static func emergencyBridgeFallback() -> DecisionCard {
        DecisionCard("emergency-bridge", category: .crisis, speaker: "Mali İşler", icon: "🆘",
            prompt: "{{company}} nakit tükeniyor — runway kritik. Kapanmadan önce bir hamle gerek. Tek doğru yol yok; her seçenek bir bedel ister.",
            choices: [
                .init("Köprü kredisi al", detail: "+nakit şimdi / 6 ay sonra geri ödeme zinciri",
                      effects: [.cash(25_000), .reputation(-2)],
                      result: "Kredi geldi, kasa nefes aldı. (Borç runway uzatır ama yeni bir saat kurar — gelir yetişmezse köprü ikinci krizi getirir.)",
                      delayed: [DelayedEffect(delayMonths: 6,
                                              effects: [.cash(-32_000), .moraleTargetBonus(-1)],
                                              note: "Köprü kredisinin geri ödemesi geldi — gelir yetişmediyse bu ikinci bir kriz başlatır.")]),
                .init("Acil gider kıs: reklamı durdur, kemer sık", detail: "−büyüme / +runway hemen",
                      effects: [.usersPercent(-0.04), .morale(-4), .reputation(1)],
                      result: "Gideri kestin, yangını söndürdün. (Default-alive olmak çoğu zaman büyümeyi değil hayatta kalmayı seçmektir.)"),
                .init("Köprü turu: yatırımcıdan acil sermaye", detail: "+nakit / −%4 hisse (sert koşul)",
                      effects: [.cash(40_000), .equity(-0.04), .morale(2)],
                      result: "Yatırımcı kurtardı ama pahalıya. (Krizde toplanan tur en yüksek dilution'lı turdur — kontrolün bir parçası gitti.)")
            ])
    }

    /// Sağlık durumuna göre kategori ağırlıkları üret + ağırlıklı rastgele seçim.
    static func weightedPick<R: RandomNumberGenerator>(from cards: [DecisionCard],
                             health: CompanyHealth,
                             chainCount: Int,
                             using rng: inout R) -> DecisionCard? {
        let weights = categoryWeights(health: health, chainCount: chainCount)
        let weighted: [(DecisionCard, Double)] = cards.map { card in
            (card, max(0.0001, weights[card.category] ?? 1.0))
        }
        let total = weighted.reduce(0.0) { $0 + $1.1 }
        guard total > 0 else { return cards.randomElement(using: &rng) }
        var roll = Double.random(in: 0..<total, using: &rng)
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
            // competitive düşük (kriz can-simidi guard'ı zaten önceler — rakip baskısı krizi azdırır
            // ama ana mesaj "ayakta kal").
            var w: [DecisionCategory: Double] = [
                .crisis: 8.0, .team: 3.0, .product: 2.5, .market: 1.5,
                .investor: 1.0, .press: 0.5, .opportunity: 0.4, .competitive: 1.0
            ]
            // Uzun zincir → crisis kartlarına neredeyse garanti yönlendir (oyuncu tepki vermeli).
            if chainCount > 2 { w[.crisis] = 14.0 }
            return w
        case .strained:
            // Sarı bölge: önleyici uyarılar — crisis + team + product + biraz market + rakip baskısı.
            return [
                .crisis: 3.5, .team: 3.0, .product: 2.5, .market: 2.0,
                .investor: 1.5, .press: 1.0, .opportunity: 1.0, .competitive: 2.0
            ]
        case .healthy:
            // Yeşil bölge: fırsatlar baskın — AMA hızlı büyüyen oyuncu rakip dikkatini çeker:
            // competitive burada en yüksek (büyüme ivmesi antagonisti uyandırır — orta-oyun platosunu kırar).
            return [
                .crisis: 0.5, .team: 1.5, .product: 1.5, .market: 1.5,
                .investor: 2.5, .press: 2.5, .opportunity: 3.0, .competitive: 3.0
            ]
        case .recovering:
            // Toparlanma: ekip + ürün + fırsat hafifçe baskın; rakip baskısı orta.
            return [
                .crisis: 1.0, .team: 2.5, .product: 2.5, .market: 1.5,
                .investor: 1.5, .press: 1.5, .opportunity: 2.5, .competitive: 1.5
            ]
        }
    }
}
