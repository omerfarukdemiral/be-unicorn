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
