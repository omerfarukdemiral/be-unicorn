import Foundation

/// Programlı senaryolar: oyun ileride gerçekleşecek olaylar planlar (Demo Day,
/// basın röportajı, müşteri pilotu...). Her senaryo bir **hedef metrik** + **deadline**
/// + **ödül/ceza** taşır; oyuncu hazırlanır → deadline gelince otomatik değerlendirilir.
/// Sprintlerden farkı: senaryolar **anlatısal, ay-mertebesinde, beklenir** olaylardır.

enum ScenarioKind: Int, Codable, CaseIterable {
    case demoDay = 0          // Yatırımcı Demo Day — değerleme hedefi
    case pressInterview = 1   // Basın röportajı — itibar hedefi
    case customerPilot = 2    // Müşteri pilotu — kullanıcı hedefi
    case techCrunchStage = 3  // TechCrunch sahnesi — MRR hedefi
    case hackathonDeadline = 4 // Hackathon teslimi — yayında proje hedefi
    case complianceAudit = 5  // Uyum denetimi — moral hedefi (operasyon)
    case investorMeeting = 6  // Yatırımcı toplantısı — değerleme + itibar
    case clientLaunch = 7     // Müşteri lansmanı — MRR hedefi

    var displayName: String {
        switch self {
        case .demoDay:           return "Yatırımcı Demo Day"
        case .pressInterview:    return "Basın Röportajı"
        case .customerPilot:     return "Müşteri Pilotu"
        case .techCrunchStage:   return "TechCrunch Sahnesi"
        case .hackathonDeadline: return "Hackathon Teslimi"
        case .complianceAudit:   return "Uyum Denetimi"
        case .investorMeeting:   return "Yatırımcı Toplantısı"
        case .clientLaunch:      return "Müşteri Lansmanı"
        }
    }

    var icon: String {
        switch self {
        case .demoDay:           return "trophy.fill"
        case .pressInterview:    return "newspaper.fill"
        case .customerPilot:     return "person.2.badge.gearshape.fill"
        case .techCrunchStage:   return "music.mic"
        case .hackathonDeadline: return "hammer.fill"
        case .complianceAudit:   return "checkmark.shield.fill"
        case .investorMeeting:   return "briefcase.fill"
        case .clientLaunch:      return "rocket.fill"
        }
    }

    /// Kısa anlatı — kart altında 1-satır prompt.
    var blurb: String {
        switch self {
        case .demoDay:           return "Yatırımcılar değerlemenizi inceleyecek."
        case .pressInterview:    return "Gazeteci geliyor; itibarınız test edilecek."
        case .customerPilot:     return "Büyük müşteri pilot kullanıcı sayınızı ölçecek."
        case .techCrunchStage:   return "Sahneye çıkacaksınız; MRR konuşulacak."
        case .hackathonDeadline: return "Demo günü gelecek; yayında ürün şart."
        case .complianceAudit:   return "Denetçi geliyor; ekip morali test edilecek."
        case .investorMeeting:   return "Yatırımcı toplantısı; değerleme + itibar tartılacak."
        case .clientLaunch:      return "Müşteri imzaladı; MRR'nız ölçülecek."
        }
    }

    /// Hangi metrik üzerinde hedef koyacağı (UI ilerleme barı için).
    var metric: ScenarioMetric {
        switch self {
        case .demoDay, .investorMeeting:           return .valuation
        case .pressInterview:                      return .reputation
        case .customerPilot:                       return .users
        case .techCrunchStage, .clientLaunch:      return .mrr
        case .hackathonDeadline:                   return .liveProjects
        case .complianceAudit:                     return .morale
        }
    }
}

/// Senaryo hedef metriği — UI ilerleme barı ve evaluate için.
enum ScenarioMetric {
    case valuation, reputation, users, mrr, liveProjects, morale
}

/// Tek bir senaryo örneği (oyun durumunda saklanır).
/// `deadlineMonth` mutlak oyun-ayı (state.months tabanlı).
/// `goalTargetValue` metriğin türüne göre hedef değer:
///   - valuation/users/mrr → mutlak sayı
///   - reputation/morale → 0-100 puan
///   - liveProjects → adet
struct ScenarioInstance: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var kind: Int                        // ScenarioKind.rawValue
    var startMonth: Double
    var deadlineMonth: Double
    var goalTargetValue: Double
    var settled: Bool = false            // sonuçlandı mı (sonuç overlay tetikçisi)
    var succeeded: Bool? = nil           // settled ise: başardı / başaramadı

    /// Hesaplanan kind (catalog dışı id güvenli: defaults to demoDay).
    var scenarioKind: ScenarioKind { ScenarioKind(rawValue: kind) ?? .demoDay }

    /// Toplam süre (oyun-ayı) — UI countdown için referans.
    var totalDurationMonths: Double { deadlineMonth - startMonth }
}
