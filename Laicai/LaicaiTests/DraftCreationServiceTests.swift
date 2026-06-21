import XCTest
@testable import Laicai

final class DraftCreationServiceTests: XCTestCase {
    func testCreateDraftBuildsDraftFromParsedText() {
        let draft = DraftCreationService.createDraft(
            sourceType: "voice",
            originalText: "买基金 1000"
        )

        XCTAssertNotNil(draft)
        XCTAssertEqual(draft?.sourceType, "voice")
        XCTAssertEqual(draft?.originalText, "买基金 1000")
        XCTAssertEqual(draft?.suggestedType, .investmentBuy)
        XCTAssertEqual(draft?.amount, 1000)
        XCTAssertEqual(draft?.note, "买基金")
    }

    func testCreateDraftReturnsNilWhenAmountCannotBeParsed() {
        let draft = DraftCreationService.createDraft(
            sourceType: "screenshot",
            originalText: "今天只是记一下"
        )

        XCTAssertNil(draft)
    }
}
