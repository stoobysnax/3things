import XCTest
@testable import ThreeThingsCore

final class DroppedTextTests: XCTestCase {
    private let today = Day(year: 2026, month: 11, day: 13)

    private func tasks(_ text: String) -> [DroppedText.Task] { DroppedText.tasks(from: text, today: today) }

    func testThingsToDoWithWhenDate() {
        XCTAssertEqual(
            tasks("MAXWELL - CANCEL SEASON 2 WHITECAPS\nWhen: 2026-11-15"),
            [.init(title: "MAXWELL - CANCEL SEASON 2 WHITECAPS", day: Day(year: 2026, month: 11, day: 15))]
        )
    }

    func testThingsDetailsAndNotesAreNotTasks() {
        let text = """
        Call the bank
        When: Today
        Deadline: 2026-11-20
        Tags: Errand
        Ask about the fee
        and the card

        Book flights
        When: Someday
        """
        XCTAssertEqual(tasks(text), [.init(title: "Call the bank", day: today), .init(title: "Book flights")])
    }

    func testThingsTomorrowAndEvening() {
        XCTAssertEqual(tasks("A\nWhen: Tomorrow"), [.init(title: "A", day: today.adding(days: 1))])
        XCTAssertEqual(tasks("B\nWhen: This Evening"), [.init(title: "B", day: today)])
    }

    func testPlainTextIsOneTaskPerLine() {
        XCTAssertEqual(tasks("- milk\n[ ] eggs\n\nhttps://example.com\nbread"),
                       [.init(title: "milk"), .init(title: "eggs"), .init(title: "bread")])
    }

    func testColonInATitleIsKept() {
        XCTAssertEqual(tasks("Call: mom"), [.init(title: "Call: mom")])
    }
}
