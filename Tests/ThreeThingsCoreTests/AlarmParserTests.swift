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

    // MARK: Days

    private func when(_ text: String) -> AlarmParser.When? { AlarmParser.parseWhen(text, now: now, calendar: calendar) }
    private var today: Day { Day(now, calendar: calendar) } // Friday, Nov 13 2026
    private func plus(_ n: Int) -> Day { today.adding(days: n, calendar: calendar) }

    func testDays() {
        XCTAssertEqual(when("tomorrow"), .init(day: plus(1), time: nil))
        XCTAssertEqual(when("mon"), .init(day: plus(3), time: nil))
        XCTAssertEqual(when("next monday"), .init(day: plus(3), time: nil))
        XCTAssertEqual(when("fri"), .init(day: plus(7), time: nil)) // it's Friday: next Friday
        XCTAssertEqual(when("today"), .init(day: today, time: nil))
        XCTAssertEqual(when("in 3 days"), .init(day: plus(3), time: nil))
        XCTAssertEqual(when("next week"), .init(day: plus(3), time: nil)) // Monday
    }

    func testDaysWithTimes() {
        XCTAssertEqual(when("fri 3pm"), .init(day: plus(7), time: at(15, 0)))
        XCTAssertEqual(when("tomorrow at 9"), .init(day: plus(1), time: at(9, 0)))
        XCTAssertEqual(when("mon 3"), .init(day: plus(3), time: at(15, 0)))
        XCTAssertEqual(when("9am tomorrow"), .init(day: plus(1), time: at(9, 0)))
        XCTAssertEqual(when("in 2 days at 7:30pm"), .init(day: plus(2), time: at(19, 30)))
    }

    func testTimesAlone() {
        XCTAssertEqual(when("9pm"), .init(day: nil, time: at(21, 0)))
        XCTAssertEqual(when("5 min"), .init(day: today, time: at(14, 45)))
        XCTAssertEqual(when("10 hours"), .init(day: plus(1), time: at(0, 40)))
        XCTAssertNil(when("mon 5 min"))
        XCTAssertNil(when("someday"))
    }

    // MARK: Dates

    private func on(_ y: Int, _ m: Int, _ d: Int) -> Day { Day(year: y, month: m, day: d) }

    func testWrittenDates() {
        XCTAssertEqual(when("November 25"), .init(day: on(2026, 11, 25), time: nil))
        XCTAssertEqual(when("nov 25"), .init(day: on(2026, 11, 25), time: nil))
        XCTAssertEqual(when("Nov. 25th"), .init(day: on(2026, 11, 25), time: nil))
        XCTAssertEqual(when("25 november"), .init(day: on(2026, 11, 25), time: nil))
        XCTAssertEqual(when("the 25th of nov"), .init(day: on(2026, 11, 25), time: nil))
        XCTAssertEqual(when("11/25"), .init(day: on(2026, 11, 25), time: nil))
        XCTAssertEqual(when("2026-11-25"), .init(day: on(2026, 11, 25), time: nil))
        XCTAssertEqual(when("jan 5"), .init(day: on(2027, 1, 5), time: nil)) // passed this year
        XCTAssertEqual(when("dec 25, 2027"), .init(day: on(2027, 12, 25), time: nil))
        XCTAssertNil(when("feb 30"))
    }

    func testRelativeDays() {
        XCTAssertEqual(when("1 week"), .init(day: plus(7), time: nil))
        XCTAssertEqual(when("1 weeks"), .init(day: plus(7), time: nil))
        XCTAssertEqual(when("in 2 weeks"), .init(day: plus(14), time: nil))
        XCTAssertEqual(when("a week"), .init(day: plus(7), time: nil))
        XCTAssertEqual(when("10 days"), .init(day: plus(10), time: nil))
        XCTAssertEqual(when("next month"), .init(day: on(2026, 12, 13), time: nil))
        XCTAssertEqual(when("this weekend"), .init(day: plus(1), time: nil)) // Saturday
        XCTAssertEqual(when("the 25th"), .init(day: on(2026, 11, 25), time: nil))
        XCTAssertEqual(when("the 2nd"), .init(day: on(2026, 12, 2), time: nil)) // passed this month
    }

    func testDatesWithTimes() {
        XCTAssertEqual(when("nov 25 3pm"), .init(day: on(2026, 11, 25), time: at(15, 0)))
        XCTAssertEqual(when("November 25 at 9:30am"), .init(day: on(2026, 11, 25), time: at(9, 30)))
        XCTAssertEqual(when("3pm nov 25"), .init(day: on(2026, 11, 25), time: at(15, 0)))
        XCTAssertEqual(when("1 week 9am"), .init(day: plus(7), time: at(9, 0)))
        XCTAssertEqual(when("11/25 noon"), .init(day: on(2026, 11, 25), time: at(12, 0)))
    }
}
