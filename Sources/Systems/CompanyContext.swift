import Foundation

/// Karar metinleri + anlatı satırları için bağlam: oyuncunun şirketinden çekilen
/// ad/sektör/proje değerleri. DecisionContent'teki `{{...}}` placeholder'larını
/// `interpolate(_:)` ile doldurur. Profil/proje yoksa makul nötr yedeklerle döner.
///
/// Tasarım: SAF değer + saf fonksiyon — UI/Model bağımsız, test edilebilir.
struct CompanyContext: Equatable {
    let companyName: String
    let founderFirstName: String
    let founderFullName: String
    let sector: String              // CompanySectorDef.name
    let primaryProjectName: String  // ilk yayında proje (yoksa ilk proje, yoksa fallback)

    /// State'ten makul varsayılanlarla üret.
    init(state: GameState) {
        let p = state.profile
        self.companyName = p.companyName.isEmpty ? "şirketin" : p.companyName
        self.founderFirstName = p.founderFirstName.isEmpty ? "Kurucu" : p.founderFirstName
        self.founderFullName = p.founderFullName.isEmpty ? "Kurucu" : p.founderFullName
        self.sector = Balance.sector(p.sector)?.name ?? "teknoloji"
        // İlk yayındaki proje > ilk proje > generic "ürününüz"
        let proj = state.projects.first(where: { $0.isLive }) ?? state.projects.first
        self.primaryProjectName = proj?.name ?? "ürününüz"
    }

    /// Doğrudan değerlerle (testler için).
    init(companyName: String, founderFirstName: String, founderFullName: String,
         sector: String, primaryProjectName: String) {
        self.companyName = companyName
        self.founderFirstName = founderFirstName
        self.founderFullName = founderFullName
        self.sector = sector
        self.primaryProjectName = primaryProjectName
    }

    /// Şablonu doldur. Placeholder yoksa metin değişmez (geriye uyumlu).
    /// Tanımlı placeholder'lar:
    /// - `{{company}}`   — şirket adı (örn. "Nova Labs")
    /// - `{{firstName}}` — kurucunun ilk adı (örn. "Ada")
    /// - `{{founder}}`   — kurucunun tam adı (örn. "Ada Yılmaz")
    /// - `{{sector}}`    — sektör adı (örn. "Fintech")
    /// - `{{project}}`   — ana proje adı (örn. "Atlas")
    func interpolate(_ template: String) -> String {
        var r = template
        r = r.replacingOccurrences(of: "{{company}}", with: companyName)
        r = r.replacingOccurrences(of: "{{firstName}}", with: founderFirstName)
        r = r.replacingOccurrences(of: "{{founder}}", with: founderFullName)
        r = r.replacingOccurrences(of: "{{sector}}", with: sector)
        r = r.replacingOccurrences(of: "{{project}}", with: primaryProjectName)
        return r
    }
}
