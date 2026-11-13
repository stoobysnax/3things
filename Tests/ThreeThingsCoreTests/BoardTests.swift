import XCTest
@testable import ThreeThingsCore

final class BoardTests: XCTestCase {
    /// Friday, Nov 13 2026
    private let friday = Day(year: 2026, month: 11, day: 13)
    private var saturday: Day { friday.adding(days: 1) }
    private var monday: Day { friday.adding(days: 3) }

    private func board(three: [String], next: [String] = []) -> Board {
        var b = Board()
        b.rollOver(to: friday)
        three.forEach { b.add($0, to: .three) }
        next.forEach { b.add($0, to: .next) }
        return b
    }

    private func titles(_ b: Board, _ list: ListKind) -> [String] { b.items(in: list).map(\.title) }
    private func id(_ b: Board, _ title: String) -> UUID {
        ListKind.allCases.flatMap { b.items(in: $0) }.first { $0.title == title }!.id
    }

    // MARK: 3 Today

    func testTodayNeverHoldsMoreThanThree() {
        var b = board(three: ["a", "b", "c"])
        b.add("d", to: .three)
        XCTAssertEqual(titles(b, .three), ["a", "b", "c"])
        XCTAssertEqual(titles(b, .next), ["d"])
    }

    func testCompletingPullsTopUnscheduledItem() {
        var b = board(three: ["a", "b", "c"], next: ["d", "e"])
        b.schedule(id(b, "d"), on: monday, today: friday) // d is scheduled, so it waits for Monday
        b.complete(id(b, "a"))
        XCTAssertEqual(titles(b, .three), ["b", "c", "e"])
        XCTAssertEqual(titles(b, .next), ["d"])
        XCTAssertEqual(titles(b, .done), ["a"])
    }

    func testMoveBeforeAnItem() {
        var b = board(three: ["a", "b", "c"])
        b.move(id(b, "a"), to: .three, before: id(b, "c"))
        XCTAssertEqual(titles(b, .three), ["b", "a", "c"])
        b.move(id(b, "c"), to: .three, before: id(b, "b"))
        XCTAssertEqual(titles(b, .three), ["c", "b", "a"])
        b.move(id(b, "c"), to: .three)
        XCTAssertEqual(titles(b, .three), ["b", "a", "c"])
    }

    func testDeleteFromTodayRefills() {
        var b = board(three: ["a", "b", "c"], next: ["d"])
        b.delete(id(b, "b"))
        XCTAssertEqual(titles(b, .three), ["a", "c", "d"])
    }

    // MARK: Swapping

    func testSwapIntoTodayTakesExactSlotAndBumpsToTopOfUnscheduled() {
        var b = board(three: ["a", "b", "c"], next: ["d", "e"])
        b.swap(id(b, "e"), with: id(b, "c"))
        XCTAssertEqual(titles(b, .three), ["a", "b", "e"])
        XCTAssertEqual(titles(b, .next), ["c", "d"])
        XCTAssertNil(b.item(id(b, "c"))?.day)
    }

    func testSwapIntoAFullDayTakesThatDay() {
        var b = board(three: ["a"], next: ["m1", "m2", "m3", "x"])
        for t in ["m1", "m2", "m3"] { b.schedule(id(b, t), on: monday, today: friday) }
        XCTAssertFalse(b.hasRoom(on: monday))
        b.swap(id(b, "x"), with: id(b, "m2"))
        XCTAssertEqual(b.scheduled(on: monday).map(\.title), ["m1", "x", "m3"])
        XCTAssertEqual(b.sections(today: friday).unscheduled.map(\.title), ["m2"])
    }

    // MARK: Scheduling

    func testScheduleAndSections() {
        var b = board(three: ["a"], next: ["soon", "far", "loose", "tomorrow"])
        b.schedule(id(b, "far"), on: friday.adding(days: 10), today: friday)
        b.schedule(id(b, "soon"), on: monday, today: friday)
        b.schedule(id(b, "tomorrow"), on: saturday, today: friday)
        let s = b.sections(today: friday)
        XCTAssertEqual(s.thisWeek.map(\.title), ["tomorrow", "soon"])
        XCTAssertEqual(s.later.map(\.title), ["far"])
        XCTAssertEqual(s.unscheduled.map(\.title), ["loose"])
    }

    func testSchedulingForTodayMovesIntoToday() {
        var b = board(three: ["a"], next: ["x"])
        b.schedule(id(b, "x"), on: friday, today: friday)
        XCTAssertEqual(titles(b, .three), ["a", "x"])
    }

    func testUnschedulingGoesToTopOfUnscheduled() {
        var b = board(three: ["a"], next: ["x", "y"])
        b.schedule(id(b, "a"), on: nil, today: friday)
        XCTAssertEqual(titles(b, .three), [])
        XCTAssertEqual(b.sections(today: friday).unscheduled.map(\.title), ["a", "x", "y"])
    }

    // MARK: The day changing

    func testRollOverMissesUnfinishedAndBringsInScheduled() {
        var b = board(three: ["a", "b"], next: ["sat1", "sat2", "loose"])
        b.schedule(id(b, "sat1"), on: saturday, today: friday)
        b.schedule(id(b, "sat2"), on: saturday, today: friday)
        b.complete(id(b, "a")) // "loose" moves up into today
        b.rollOver(to: saturday)
        XCTAssertEqual(titles(b, .three), ["sat1", "sat2"])
        XCTAssertEqual(titles(b, .missed), ["b", "loose"])
        XCTAssertEqual(b.missed.first?.missedOn, friday)
        XCTAssertEqual(b.currentDay, saturday)
        XCTAssertNil(b.three.first?.day)
    }

    func testRollOverIsOncePerDay() {
        var b = board(three: ["a"])
        b.rollOver(to: friday)
        XCTAssertEqual(titles(b, .three), ["a"])
        XCTAssertEqual(titles(b, .missed), [])
    }

    func testSkippedDaysScheduledItemsBecomeMissed() {
        var b = board(three: [], next: ["sat", "mon"])
        b.schedule(id(b, "sat"), on: saturday, today: friday)
        b.schedule(id(b, "mon"), on: monday, today: friday)
        b.rollOver(to: monday) // Mac was off all weekend
        XCTAssertEqual(titles(b, .three), ["mon"])
        XCTAssertEqual(titles(b, .missed), ["sat"])
        XCTAssertEqual(b.missed.first?.missedOn, saturday)
    }

    func testMissedKeepInTodayAndMoveToNext() {
        var b = board(three: ["a", "b"])
        b.rollOver(to: saturday)
        b.move(id(b, "a"), to: .three)
        b.schedule(id(b, "b"), on: nil, today: saturday)
        XCTAssertEqual(titles(b, .three), ["a"])
        XCTAssertEqual(titles(b, .next), ["b"])
        XCTAssertEqual(titles(b, .missed), [])
        XCTAssertNil(b.item(id(b, "a"))?.missedOn)
    }

    // MARK: Alarms and saving

    func testOnlyTodayAlarmsAreLive() {
        var b = board(three: ["a"], next: ["b"])
        b.setAlarm(AlarmTime(hour: 9, minute: 0), for: id(b, "a"))
        b.setAlarm(AlarmTime(hour: 10, minute: 0), for: id(b, "b"))
        XCTAssertEqual(b.liveAlarms.map(\.title), ["a"])
        b.schedule(id(b, "b"), on: monday, today: friday)
        XCTAssertEqual(b.scheduledAlarms.map(\.title), ["b"])
    }

    func testReadsOlderSaves() throws {
        let old = #"{"three":[{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","title":"a"}],"next":[],"done":[]}"#
        let b = try JSONDecoder().decode(Board.self, from: Data(old.utf8))
        XCTAssertEqual(titles(b, .three), ["a"])
        XCTAssertEqual(b.missed, [])
        XCTAssertNil(b.currentDay)
    }

    func testRoundTripsThroughFile() throws {
        var b = board(three: ["a"], next: ["b"])
        b.setAlarm(AlarmTime(hour: 7, minute: 30), for: id(b, "a"))
        b.schedule(id(b, "b"), on: monday, today: friday)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("board.json")
        let file = BoardFile(url: url)
        try file.save(b)
        XCTAssertEqual(file.load(), b)
    }
}
