import Foundation

/// Ekran-içi aktivite akışı girdisi (Track C). Modal yerine feed'de kalıcı birikir.
/// Saf veri — sunum ActivityFeedView'de. Migration-proof: tüm alanlar decodeIfPresent.
struct FeedEntry: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var kindRaw: Int                // FeedKind.rawValue (ileride yeni tür eklenince kırılmaz)
    var title: String               // kısa başlık ("Çeyrek 3 Kapandı")
    var summary: String             // tek-iki satır özet
    var atMonth: Double             // state.months — relatif zaman için
    var positive: Bool = true       // tint yönü (success vs warning); nötr için kind belirler
    var mechanic: String? = nil     // #19 ders köprüsü (varsa "detay >" derse gider)
    var detailKindRaw: Int? = nil   // zengin detay-sheet payload anahtarı (çeyrek/sezon); nil = köprü yok
    var read: Bool = false          // HUD okunmamış rozeti için

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func g<T: Decodable>(_ k: CodingKeys, _ d: T) -> T {
            ((try? c.decodeIfPresent(T.self, forKey: k)) ?? nil) ?? d
        }
        id = g(.id, UUID())
        kindRaw = g(.kindRaw, 0)
        title = g(.title, "")
        summary = g(.summary, "")
        atMonth = g(.atMonth, 0)
        positive = g(.positive, true)
        mechanic = (try? c.decodeIfPresent(String.self, forKey: .mechanic)) ?? nil
        detailKindRaw = (try? c.decodeIfPresent(Int.self, forKey: .detailKindRaw)) ?? nil
        read = g(.read, false)
    }
    init(kind: FeedKind, title: String, summary: String, atMonth: Double,
         positive: Bool = true, mechanic: String? = nil, detail: FeedDetailKind? = nil) {
        self.kindRaw = kind.rawValue; self.title = title; self.summary = summary
        self.atMonth = atMonth; self.positive = positive; self.mechanic = mechanic
        self.detailKindRaw = detail?.rawValue
    }
    var kind: FeedKind { FeedKind(rawValue: kindRaw) ?? .info }
}

/// Feed girdisinin görsel kimliği (ikon + nötr tint). rawValue Codable-stabil.
enum FeedKind: Int, Codable {
    case info = 0, quarter, sprint, daily, scenario, decision, delayed, milestone, season, offline, funding, rival, lesson
    var icon: String {
        switch self {
        case .info:      return "sparkles"
        case .quarter:   return "flag.checkered"
        case .sprint:    return "bolt.fill"
        case .daily:     return "target"
        case .scenario:  return "scope"
        case .decision:  return "checkmark.circle.fill"
        case .delayed:   return "clock.arrow.circlepath"
        case .milestone: return "rosette"
        case .season:    return "crown.fill"
        case .offline:   return "moon.zzz.fill"
        case .funding:   return "dollarsign.circle.fill"
        case .rival:     return "bolt.shield.fill"
        case .lesson:    return "book.fill"
        }
    }
    /// Detay-sheet tür rozeti için okunur etiket.
    var label: String {
        switch self {
        case .info:      return "Bilgi"
        case .quarter:   return "Çeyrek"
        case .sprint:    return "Sprint"
        case .daily:     return "Günlük"
        case .scenario:  return "Senaryo"
        case .decision:  return "Karar"
        case .delayed:   return "Gecikmeli"
        case .milestone: return "Kilometre Taşı"
        case .season:    return "Sezon"
        case .offline:   return "Çevrimdışı"
        case .funding:   return "Yatırım"
        case .rival:     return "Rakip"
        case .lesson:    return "Ders"
        }
    }
}

/// Feed satırından açılabilen zengin detay-sheet türü (çeyrek scorecard, sezon özeti…).
/// rawValue Codable-stabil tutulur ki feed kalıcı kayıttan açılabilsin.
enum FeedDetailKind: Int { case quarter = 1, season = 2 }
