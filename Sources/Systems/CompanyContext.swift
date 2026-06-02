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

    // Tepki Veren Rakip (Antagonist): aktif hamleyi yapan rakibin kimliği. competitive
    // kartlarındaki {{rival*}} placeholder'larını doldurur. Kohort boşsa nötr yedek.
    let rivalName: String
    let rivalFounder: String
    let rivalSector: String
    let rivalProject: String

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
        // Aktif rakip = kohortun en yüksek skorlusu (en güçlü tehdit) — yoksa nötr.
        let rival = state.cohortCompetitors.max(by: { $0.score < $1.score })
        self.rivalName = rival?.name ?? "rakip kohort"
        self.rivalFounder = rival?.founderFirstName ?? "bir rakip kurucu"
        self.rivalSector = (rival.flatMap { Balance.sector($0.sector)?.name }) ?? "teknoloji"
        self.rivalProject = rival?.projectName ?? "rakip ürün"
    }

    /// Doğrudan değerlerle (testler için).
    init(companyName: String, founderFirstName: String, founderFullName: String,
         sector: String, primaryProjectName: String,
         rivalName: String = "rakip kohort", rivalFounder: String = "bir rakip kurucu",
         rivalSector: String = "teknoloji", rivalProject: String = "rakip ürün") {
        self.companyName = companyName
        self.founderFirstName = founderFirstName
        self.founderFullName = founderFullName
        self.sector = sector
        self.primaryProjectName = primaryProjectName
        self.rivalName = rivalName
        self.rivalFounder = rivalFounder
        self.rivalSector = rivalSector
        self.rivalProject = rivalProject
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
        // Tepki Veren Rakip placeholder'ları (competitive kartlar).
        r = r.replacingOccurrences(of: "{{rival}}", with: rivalName)
        r = r.replacingOccurrences(of: "{{rivalFounder}}", with: rivalFounder)
        r = r.replacingOccurrences(of: "{{rivalSector}}", with: rivalSector)
        r = r.replacingOccurrences(of: "{{rivalProject}}", with: rivalProject)
        return r
    }
}
