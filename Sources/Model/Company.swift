import Foundation

/// Kuruluşta oyuncunun girdiği kalıcı şirket kimliği (CEO + şirket + sektör).
/// Saf veri — kurgu/lezzet + leaderboard/HUD kimliği. `setupComplete` kuruluş kapısıdır:
/// onboarding tanıtımı bittikten sonra bu `false` ise kuruluş ekranı açılır.
struct CompanyProfile: Codable {
    var founderFirstName: String = ""
    var founderLastName: String = ""
    var companyName: String = ""
    var sector: Int = 0          // Balance.sectors index
    var setupComplete: Bool = false

    /// "Ada Yılmaz" — boşsa boş döner (UI varsayılan gösterir).
    var founderFullName: String {
        let n = "\(founderFirstName) \(founderLastName)".trimmingCharacters(in: .whitespaces)
        return n
    }
}

/// Şirketin yürüttüğü bir proje (ürün). Şirket projeleriyle büyür:
/// yeni proje başlat → mühendislik gücüyle geliştir → yayına al. Canlı proje
/// büyüme/ARPU/itibara katkı verir. Geliştirme aşamasındaki proje henüz katkı vermez.
struct ProjectState: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var category: Int            // Balance.projectCategories index
    var startMonth: Double = 0   // oyun-ayı (başlatıldığı an)
    var devProgress: Double = 0  // 0..1 geliştirme ilerlemesi
    var isLive: Bool = false     // yayında mı (katkı verir)
}

/// Oyuncunun kuruluşta beyan ettiği kurucu EĞİLİMİ (A1/HZ-3). Mekanik etki YOK —
/// yalnızca onboarding felsefe çerçevesi (suçlamasız koçluk). Kural-0: ekonomiye
/// bağlanmadığı için pazarlamada "arketip mekaniği" vaadi VERİLMEZ.
/// Runtime tespit için AYRI bir enum (FounderArchetype) kullanılır — karıştırma.
enum FounderLeaning: Int, Codable, CaseIterable {
    case cautious = 0
    case balanced = 1
    case bold = 2

    var title: String {
        switch self {
        case .cautious: return "Temkinli"
        case .balanced: return "Dengeli"
        case .bold:     return "Cesur"
        }
    }
    var icon: String {
        switch self {
        case .cautious: return "shield.lefthalf.filled"
        case .balanced: return "scalemass.fill"
        case .bold:     return "flame.fill"
        }
    }
    var blurb: String {
        switch self {
        case .cautious: return "Önce hayatta kal. Runway'i korur, bağımsızlığı seçer, yavaş ama sağlam büyürsün."
        case .balanced: return "Fırsatı ve riski tartarsın. Bağlama göre bazen frene, bazen gaza basarsın."
        case .bold:     return "Büyümeye oynarsın. Riski kucaklar, hızlı hamle yapar, sınırları zorlarsın."
        }
    }
    var philosophyDrop: String {
        switch self {
        case .cautious: return "Temkinli kurucular da Unicorn olur — sadece patikaları farklıdır. Hatırla: tek doğru yol yoktur, sadece senin yolun vardır."
        case .balanced: return "Dengeli olmak kararsızlık değil, bağlamı okumaktır. İki seçenek de duruma göre doğru olabilir."
        case .bold:     return "Cesaret iyidir ama runway'i unutturmaz. En hızlı kurucular bile sayacı okur. Tek doğru yol yoktur — riskini bilinçli al."
        }
    }
}
