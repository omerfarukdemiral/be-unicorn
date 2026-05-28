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

    init(_ label: String, detail: String? = nil, effects: [DecisionEffect], result: String? = nil) {
        self.label = label
        self.detail = detail
        self.effects = effects
        self.resultLine = result
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

    /// Uygun kartlardan birini seç. Kriz kartlarına öncelik ver.
    @MainActor
    static func pick(for model: GameModel, state: GameState) -> DecisionCard? {
        let eligible = DecisionContent.all.filter { isEligible($0, model: model, state: state) }
        guard !eligible.isEmpty else { return nil }
        let crises = eligible.filter { $0.category == .crisis }
        if !crises.isEmpty, Bool.random() { return crises.randomElement() }
        return eligible.randomElement()
    }
}
