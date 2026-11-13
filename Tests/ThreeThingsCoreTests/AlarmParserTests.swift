import XCTest
@testable import ThreeThingsCore

final class AlarmParserTests: XCTestCase {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    /// 2:40 PM
    private var now: Date { calendar.date(from: DateComponents(year: 2026, month: 11, day: 13, hour: 14, minute: 40))! }

    private func parse(_ text: String) -> AlarmTime? { AlarmParser.parse(text, now: now, calendar: calendar) }
    private func at(_ h: Int, _ m: Int) -> AlarmTime { AlarmTime(hour: h, minute: m) }

    func testHowLongFromNow() {
        XCTAssertEqual(parse("5 mins"), at(14, 45))
        XCTAssertEqual(parse("in 20 minutes"), at(15, 0))
        XCTAssertEqual(parse("4 hours"), at(18, 40))
        XCTAssertEqual(parse("1h 30m"), at(16, 10))
        XCTAssertEqual(parse("1 hour and 15 min"), at(15, 55))
        XCTAssertEqual(parse("1.5h"), at(16, 10))
        XCTAssertEqual(parse("half an hour"), at(15, 10))
        XCTAssertEqual(parse("an hour"), at(15, 40))
        XCTAssertEqual(parse("45"), at(15, 25))
        XCTAssertEqual(parse("10 hours"), at(0, 40)) // past midnight wraps to tomorrow's time
    }

    func testClockTimes() {
        XCTAssertEqual(parse("9pm"), at(21, 0))
        XCTAssertEqual(parse("at 9:30 pm"), at(21, 30))
        XCTAssertEqual(parse("9 p.m."), at(21, 0))
        XCTAssertEqual(parse("7am"), at(7, 0))
        XCTAssertEqual(parse("12am"), at(0, 0))
        XCTAssertEqual(parse("12pm"), at(12, 0))
        XCTAssertEqual(parse("21:00"), at(21, 0))
        XCTAssertEqual(parse("noon"), at(12, 0))
        XCTAssertEqual(parse("midnight"), at(0, 0))
    }

    func testClockWithoutAmPmPicksTheNextOne() {
        XCTAssertEqual(parse("9:30"), at(21, 30)) // it's 2:40 PM, so 9:30 tonight
        XCTAssertEqual(parse("3:00"), at(15, 0))  // 3 PM is next
        XCTAssertEqual(parse("2:00"), at(2, 0))   // 2 PM has passed, so 2 AM
    }

    func testNonsense() {
        XCTAssertNil(parse(""))
        XCTAssertNil(parse("tomorrow"))
        XCTAssertNil(parse("13pm"))
        XCTAssertNil(parse("0 min"))
        XCTAssertNil(parse("9:75"))
    }
}
