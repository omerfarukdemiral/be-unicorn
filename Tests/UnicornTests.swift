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

// MARK: - TeamMember + kimlik katmanı (hire/fire/founder/atama)

/// Çalışanların bireysel kimliği + headcount ile senkronu + kurucu korunumu + iflas-sonrası kimlik.
final class TeamMemberTests: XCTestCase {

    @MainActor
    private func freshModel() -> GameModel {
        SaveManager.wipe()
        return GameModel()
    }

    @MainActor
    func testSetupCreatesNamedFounderAsFirstMember() {
        let model = freshModel()
        model.completeCompanySetup(firstName: "Ada", lastName: "Yılmaz",
                                   company: "Nova", sector: 0,
                                   firstProjectName: "Atlas", firstProjectCategory: 0)
        XCTAssertEqual(model.members.count, 1, "Kurulduktan sonra yalnızca kurucu olmalı")
        let founder = model.founderMember
        XCTAssertNotNil(founder)
        XCTAssertEqual(founder?.firstName, "Ada")
        XCTAssertEqual(founder?.lastName, "Yılmaz")
        XCTAssertEqual(founder?.deptIndex, 0, "Kurucu mühendislik departmanında başlamalı")
        XCTAssertTrue(founder?.isFounder ?? false)
        XCTAssertEqual(founder?.assignedProjectID, model.projects.first?.id,
                       "Kurucu ilk projeye atanmış olmalı")
    }

    @MainActor
    func testHireAddsNamedMemberAndKeepsHeadcountInSync() {
        let model = freshModel()
        model.completeCompanySetup(firstName: "Ada", lastName: "Y", company: "N",
                                   sector: 0, firstProjectName: "P", firstProjectCategory: 0)
        XCTAssertEqual(model.totalHeadcount, 1)
        XCTAssertEqual(model.members.count, 1)

        let ok = model.hire(0)   // mühendis al
        XCTAssertTrue(ok)
        XCTAssertEqual(model.totalHeadcount, 2)
        XCTAssertEqual(model.members.count, 2)
        let newMember = model.members.last!
        XCTAssertFalse(newMember.isFounder)
        XCTAssertEqual(newMember.deptIndex, 0)
        XCTAssertFalse(newMember.firstName.isEmpty, "Yeni hire isimli olmalı (anonim sayı değil)")
    }

    @MainActor
    func testFirePreservesFounder() {
        let model = freshModel()
        model.completeCompanySetup(firstName: "Ada", lastName: "Y", company: "N",
                                   sector: 0, firstProjectName: "P", firstProjectCategory: 0)
        // Yalnızca kurucu var. Fire başarısız OLMALI (kurucu çıkarılamaz).
        let result = model.fire(0)
        XCTAssertFalse(result, "Kurucu hariç fire'lanabilir üye yoksa fire başarısız olmalı")
        XCTAssertEqual(model.totalHeadcount, 1)
        XCTAssertNotNil(model.founderMember)
    }

    @MainActor
    func testFireRemovesLastHireNotFounder() {
        let model = freshModel()
        model.completeCompanySetup(firstName: "Ada", lastName: "Y", company: "N",
                                   sector: 0, firstProjectName: "P", firstProjectCategory: 0)
        _ = model.hire(0)   // ikinci mühendis
        XCTAssertEqual(model.members.count, 2)
        let secondHireID = model.members.last!.id
        let founderID = model.founderMember!.id

        let result = model.fire(0)
        XCTAssertTrue(result)
        XCTAssertEqual(model.totalHeadcount, 1)
        XCTAssertEqual(model.members.count, 1)
        XCTAssertNotNil(model.members.first(where: { $0.id == founderID }), "Kurucu korunmalı")
        XCTAssertNil(model.members.first(where: { $0.id == secondHireID }), "Son hire kaldırıldı")
    }

    @MainActor
    func testHireAutoAssignsEngineerToDevProject() {
        let model = freshModel()
        model.completeCompanySetup(firstName: "Ada", lastName: "Y", company: "N",
                                   sector: 0, firstProjectName: "MVP", firstProjectCategory: 0)
        // Yeni geliştirme aşamasında bir proje ekle.
        _ = model.startProject(name: "Beta", category: 0)
        let devProject = model.projects.last!
        XCTAssertFalse(devProject.isLive)

        // Mühendis al → otomatik olarak dev project'e atanmalı.
        _ = model.hire(0)
        let newMember = model.members.last!
        XCTAssertEqual(newMember.assignedProjectID, devProject.id,
                       "Yeni mühendis geliştirme-aşamasındaki projeye atanmalı")
        XCTAssertEqual(model.teamSize(forProject: devProject.id), 1)
    }

    @MainActor
    func testHireMarketingDoesNotAssignToProject() {
        let model = freshModel()
        model.completeCompanySetup(firstName: "Ada", lastName: "Y", company: "N",
                                   sector: 0, firstProjectName: "MVP", firstProjectCategory: 0)
        _ = model.startProject(name: "Beta", category: 0)
        // Pazarlama al (id=2): proje atanmamalı.
        _ = model.hire(2)
        let marketer = model.members.last!
        XCTAssertEqual(marketer.deptIndex, 2)
        XCTAssertNil(marketer.assignedProjectID,
                     "Pazarlama üyesi proje-bağımsız (atama olmamalı)")
    }

    @MainActor
    func testNormalizeSyncsMembersToHeadcount() {
        var state = GameState()
        state.headcount[0] = 3   // 3 mühendis istiyoruz ama members boş
        state.normalize()
        XCTAssertEqual(state.members.filter { $0.deptIndex == 0 }.count, 3,
                       "Eksik üye sayısı isimli generic'lerle dolmalı")
        XCTAssertEqual(state.headcount[0], 3)
    }

    @MainActor
    func testRestartAfterBankruptcyKeepsFounderIdentity() {
        let model = freshModel()
        model.completeCompanySetup(firstName: "Ada", lastName: "Yılmaz",
                                   company: "Nova", sector: 0,
                                   firstProjectName: "Atlas", firstProjectCategory: 0)
        _ = model.hire(0); _ = model.hire(2)
        XCTAssertEqual(model.members.count, 3)

        model.restartAfterBankruptcy()

        XCTAssertEqual(model.members.count, 1, "Yeniden başlangıçta sadece kurucu döner")
        XCTAssertEqual(model.founderMember?.firstName, "Ada")
        XCTAssertEqual(model.founderMember?.lastName, "Yılmaz")
        XCTAssertTrue(model.founderMember?.isFounder ?? false)
        XCTAssertEqual(model.founderMember?.assignedProjectID, model.projects.first?.id,
                       "Kurucu yeni ilk projeye atanmış olmalı")
    }
}

