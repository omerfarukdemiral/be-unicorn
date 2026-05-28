import XCTest
@testable import Unicorn

final class UnicornSmokeTests: XCTestCase {
    @MainActor
    func testFreshGameStartsWithCashAndOneEngineer() {
        SaveManager.wipe()
        let model = GameModel()
        XCTAssertEqual(model.cash, Balance.startCash, accuracy: 0.01)
        XCTAssertEqual(model.totalHeadcount, 1)
        XCTAssertGreaterThan(model.valuation, 0)
    }

    func testStageTargetsAscend() {
        let targets = Balance.stages.map { $0.valuationTarget }
        XCTAssertEqual(targets, targets.sorted())
        XCTAssertEqual(Balance.stages.last?.valuationTarget, Balance.unicornValuation)
    }
}

// MARK: - Şirket kuruluşu + projeler (büyüme mekaniği)

/// Şirket kimliği + projeler mekaniğinin sözleşmeleri: kuruluş, başlatma, kapasite,
/// dev → live geçişi, canlı projenin ekonomi etkileri, iflas-sonrası kimlik koruma.
final class CompanyProjectsTests: XCTestCase {

    @MainActor
    private func freshModel() -> GameModel {
        SaveManager.wipe()
        return GameModel()
    }

    // MARK: Kuruluş

    @MainActor
    func testCompleteCompanySetupCreatesProfileAndOneLiveProject() {
        let model = freshModel()
        XCTAssertFalse(model.companySetupComplete)
        XCTAssertTrue(model.projects.isEmpty)

        model.completeCompanySetup(firstName: "Ada", lastName: "Yılmaz",
                                   company: "Nova Labs", sector: 1,
                                   firstProjectName: "Atlas", firstProjectCategory: 0)

        XCTAssertTrue(model.companySetupComplete)
        XCTAssertEqual(model.companyName, "Nova Labs")
        XCTAssertEqual(model.founderFullName, "Ada Yılmaz")
        XCTAssertEqual(model.sectorDef.id, 1)
        XCTAssertEqual(model.projects.count, 1)
        XCTAssertTrue(model.projects.first?.isLive ?? false, "İlk proje yayında başlamalı (MVP day-1)")
        XCTAssertEqual(model.liveProjectCount, 1)
    }

    @MainActor
    func testCompleteSetupTrimsWhitespaceAndFallsBackToCompanyForEmptyProjectName() {
        let model = freshModel()
        model.completeCompanySetup(firstName: "  Ada  ", lastName: "  Yılmaz  ",
                                   company: "  Nova  ", sector: 0,
                                   firstProjectName: "   ", firstProjectCategory: 0)

        XCTAssertEqual(model.companyName, "Nova")
        XCTAssertEqual(model.founderFullName, "Ada Yılmaz")
        XCTAssertEqual(model.projects.first?.name, "Nova",
                       "Boş proje adı şirket adıyla yedeklenmeli")
    }

    @MainActor
    func testPlayerCompanyNameReflectsSetup() {
        let model = freshModel()
        XCTAssertTrue(model.playerCompanyName.contains("Sen"),
                      "Kuruluş öncesi varsayılan etiketi göstermeli")
        model.completeCompanySetup(firstName: "Ada", lastName: "Yılmaz",
                                   company: "Nova Labs", sector: 0,
                                   firstProjectName: "Atlas", firstProjectCategory: 0)
        XCTAssertEqual(model.playerCompanyName, "Nova Labs")
    }

    // MARK: Yeni proje başlatma + kapasite

    @MainActor
    func testStartProjectDeductsCashAndAddsNonLiveProject() {
        let model = freshModel()
        model.completeCompanySetup(firstName: "A", lastName: "B", company: "C",
                                   sector: 0, firstProjectName: "P1", firstProjectCategory: 0)
        let cashBefore = model.cash
        let cost = model.projectStartCost(0)
        let ok = model.startProject(name: "P2", category: 0)
        XCTAssertTrue(ok)
        XCTAssertEqual(model.projects.count, 2)
        XCTAssertEqual(model.liveProjectCount, 1, "Yeni proje geliştirmede başlar, yayında değil")
        XCTAssertEqual(model.cash, cashBefore - cost, accuracy: 0.01)
        XCTAssertEqual(model.projects.last?.devProgress, 0)
        XCTAssertFalse(model.projects.last?.isLive ?? true)
    }

    @MainActor
    func testPortfolioCapacityBlocksNewProjects() {
        let model = freshModel()
        model.completeCompanySetup(firstName: "A", lastName: "B", company: "C",
                                   sector: 0, firstProjectName: "P1", firstProjectCategory: 0)
        // Evre 0 → maxProjects = 2. İlk proje var; bir tane daha eklenebilir.
        XCTAssertEqual(model.maxProjects, 2)
        XCTAssertTrue(model.canStartNewProject)
        _ = model.startProject(name: "P2", category: 0)
        XCTAssertEqual(model.projects.count, 2)
        XCTAssertFalse(model.canStartNewProject, "Kapasite dolduğunda yeni proje engellenmeli")
        let ok = model.startProject(name: "P3", category: 0)
        XCTAssertFalse(ok)
        XCTAssertEqual(model.projects.count, 2)
    }

    // MARK: Geliştirme → yayına alma

    @MainActor
    func testAdvanceProjectsBringsDevProjectLive() {
        let model = freshModel()
        model.completeCompanySetup(firstName: "A", lastName: "B", company: "C",
                                   sector: 0, firstProjectName: "P1", firstProjectCategory: 0)
        _ = model.startProject(name: "P2", category: 0)   // Mobil Uygulama, buildMonths 1.5
        XCTAssertEqual(model.liveProjectCount, 1)
        XCTAssertFalse(model.projects.last?.isLive ?? true)

        // Cömertçe büyük bir monthFraction → devProgress kesinlikle 1'i aşar.
        model.advanceProjects(20)

        XCTAssertEqual(model.liveProjectCount, 2, "İkinci proje yayına geçmeli")
        XCTAssertTrue(model.projects.last?.isLive ?? false)
        XCTAssertEqual(model.projects.last?.devProgress, 1.0)
    }

    @MainActor
    func testAdvanceProjectsPartialKeepsBelowLive() {
        let model = freshModel()
        model.completeCompanySetup(firstName: "A", lastName: "B", company: "C",
                                   sector: 0, firstProjectName: "P1", firstProjectCategory: 0)
        _ = model.startProject(name: "P2", category: 0)

        // Çok küçük monthFraction → ilerlemeli ama yayına ALMAMALI.
        model.advanceProjects(0.05)
        let p = model.projects.last!
        XCTAssertGreaterThan(p.devProgress, 0)
        XCTAssertLessThan(p.devProgress, 1.0)
        XCTAssertFalse(p.isLive)
        XCTAssertEqual(model.liveProjectCount, 1)
    }

    // MARK: Canlı projenin ekonomi etkileri

    @MainActor
    func testHigherArpuBonusCategoryYieldsHigherArpu() {
        // İki taze model: biri düşük arpuBonus (Oyun = 0.03), diğeri yüksek (AI = 0.09).
        let baseline = freshModel()
        baseline.completeCompanySetup(firstName: "A", lastName: "B", company: "Base",
                                      sector: 0, firstProjectName: "P", firstProjectCategory: 4)

        let boosted = freshModel()
        boosted.completeCompanySetup(firstName: "A", lastName: "B", company: "Boost",
                                     sector: 0, firstProjectName: "P", firstProjectCategory: 2)

        XCTAssertGreaterThan(boosted.arpu, baseline.arpu,
                             "Daha yüksek arpuBonus → daha yüksek ARPU")
    }

    @MainActor
    func testValuationIncreasesWithLiveProjectCount() {
        let model = freshModel()
        model.completeCompanySetup(firstName: "A", lastName: "B", company: "C",
                                   sector: 0, firstProjectName: "P1", firstProjectCategory: 0)
        let valOne = model.valuation
        _ = model.startProject(name: "P2", category: 0)
        model.advanceProjects(20)   // P2 yayına gir
        XCTAssertEqual(model.liveProjectCount, 2)
        let valTwo = model.valuation
        XCTAssertGreaterThanOrEqual(valTwo - valOne, Balance.projectValuationEach * 0.9,
                                    "İkinci canlı proje değerlemeye ~projectValuationEach katmalı")
    }

    // MARK: İflas sonrası kimlik koruma

    @MainActor
    func testRestartAfterBankruptcyKeepsCompanyIdentity() {
        let model = freshModel()
        model.completeCompanySetup(firstName: "Ada", lastName: "Yılmaz",
                                   company: "Nova Labs", sector: 3,
                                   firstProjectName: "Atlas", firstProjectCategory: 2)
        XCTAssertEqual(model.projects.count, 1)

        model.restartAfterBankruptcy()

        XCTAssertTrue(model.companySetupComplete, "Profil korunmalı; kuruluş tekrar istenmemeli")
        XCTAssertEqual(model.companyName, "Nova Labs")
        XCTAssertEqual(model.founderFullName, "Ada Yılmaz")
        XCTAssertEqual(model.sectorDef.id, 3)
        XCTAssertEqual(model.projects.count, 1)
        XCTAssertTrue(model.projects.first?.isLive ?? false,
                      "İflas sonrası yeniden başlayan şirket bir canlı projeyle başlamalı")
        XCTAssertEqual(model.projects.first?.name, "Atlas")
        XCTAssertEqual(model.projects.first?.category, 2)
    }
}
