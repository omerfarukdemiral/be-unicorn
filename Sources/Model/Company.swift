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
