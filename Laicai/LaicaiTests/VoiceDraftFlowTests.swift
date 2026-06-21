import XCTest
@testable import Laicai

final class VoiceDraftFlowTests: XCTestCase {
    func testVoiceTranscriptCanProduceDraft() {
        let transcript = "买基金 1000"
        let draft = LocalDraftParser.parse(text: transcript)
        XCTAssertEqual(draft?.amount, 1000)
    }
}
