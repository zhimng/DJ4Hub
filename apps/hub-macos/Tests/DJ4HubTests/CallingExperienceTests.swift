import XCTest
@testable import DJ4Hub

final class CallingExperienceTests: XCTestCase {
    func call(_ id: Int = 1, _ number: String = "", _ state: Int = 4) -> HubValue {
        HubValue(["id": id, "number": number, "state": state])
    }
    func testDelayedCallerIDAndRepeatedCalls() {
        var tracker = CallerAlertTracker()
        XCTAssertEqual(tracker.update([call()]).first?.number, "未知／隐藏号码")
        XCTAssertTrue(tracker.update([call()]).isEmpty)
        XCTAssertEqual(tracker.update([call(1, "+12025550123")]).first?.number, "+12025550123")
        XCTAssertTrue(tracker.update([call(1, "+12025550123", 0)]).isEmpty)
        XCTAssertEqual(tracker.update([call(1, "+12025550123")]).count, 1)
        XCTAssertTrue(tracker.update([]).isEmpty)
        XCTAssertEqual(tracker.update([call(1, "", 5)]).count, 1)
    }
    func testStaleNotificationCannotControlReusedCallID() {
        var sessions = IncomingSessions()
        XCTAssertTrue(sessions.update([call()]).isEmpty)
        let old = sessions.tokens["1"]!
        XCTAssertTrue(sessions.matches(id: "1", token: old))
        XCTAssertTrue(sessions.update([call(1, "+12025550123")]).isEmpty)
        XCTAssertEqual(sessions.tokens["1"], old)
        XCTAssertEqual(sessions.update([]), [old])
        XCTAssertFalse(sessions.matches(id: "1", token: old))
        _ = sessions.update([call()])
        XCTAssertFalse(sessions.matches(id: "1", token: old))
    }
    func testSIMNotesNeverCrossCards() {
        let a = HubValue(["iccid": "test-card-a", "sim_inserted": true, "phone_number": "+12025550101"])
        let b = HubValue(["iccid": "test-card-b", "sim_inserted": true])
        let notes = ["test-card-a": "+12025550102"]
        XCTAssertEqual(PhonePresentation.ownNumber(a, notes: notes), "+12025550102")
        XCTAssertEqual(PhonePresentation.ownNumber(a, notes: [:]), "+12025550101")
        XCTAssertEqual(PhonePresentation.ownNumber(b, notes: notes), "未读取到号码")
        XCTAssertEqual(PhonePresentation.ownNumber(HubValue(), notes: notes), "未识别 SIM")
    }
}
