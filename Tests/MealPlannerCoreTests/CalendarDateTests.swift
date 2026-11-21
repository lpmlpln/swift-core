import Testing
import Foundation
@testable import MealPlannerCore

@Suite("CalendarDate")
struct CalendarDateTests {
    @Test("Round trips ISO strings")
    func isoRoundTrip() throws {
        let date = try #require(CalendarDate(isoString: "2026-02-28"))
        #expect(date.year == 2026)
        #expect(date.month == 2)
        #expect(date.day == 28)
        #expect(date.isoString == "2026-02-28")
    }

    @Test("Rejects invalid dates")
    func invalidDates() {
        #expect(CalendarDate(year: 2026, month: 2, day: 30) == nil)
        #expect(CalendarDate(year: 2026, month: 13, day: 1) == nil)
        #expect(CalendarDate(isoString: "2026-2-3") == nil)
        #expect(CalendarDate(isoString: "not-a-date") == nil)
    }

    @Test("Handles leap years")
    func leapYears() {
        #expect(CalendarDate(year: 2024, month: 2, day: 29) != nil)
        #expect(CalendarDate(year: 2025, month: 2, day: 29) == nil)
    }

    @Test("Adds days across month and year boundaries")
    func addingDays() throws {
        let date = try #require(CalendarDate(isoString: "2026-12-30"))
        #expect(date.adding(days: 3).isoString == "2027-01-02")
        #expect(date.adding(days: -30).isoString == "2026-11-30")
    }

    @Test("Computes distances")
    func distance() throws {
        let start = try #require(CalendarDate(isoString: "2026-01-01"))
        let end = try #require(CalendarDate(isoString: "2026-01-08"))
        #expect(start.days(until: end) == 7)
        #expect(end.days(until: start) == -7)
    }

    @Test("Computes weekday")
    func weekday() throws {
        // 2026-11-21 is a Saturday.
        let date = try #require(CalendarDate(isoString: "2026-11-21"))
        #expect(date.weekday == .saturday)
        #expect(date.isWeekend)
    }

    @Test("Generates date ranges")
    func dateRange() throws {
        let start = try #require(CalendarDate(isoString: "2026-03-01"))
        let dates = start.dates(count: 3)
        #expect(dates.map(\.isoString) == ["2026-03-01", "2026-03-02", "2026-03-03"])
        #expect(start.dates(count: 0).isEmpty)
    }

    @Test("Encodes as a plain string")
    func encoding() throws {
        let date = try #require(CalendarDate(isoString: "2026-05-09"))
        let data = try JSONEncoder().encode(date)
        #expect(String(data: data, encoding: .utf8) == "\"2026-05-09\"")
        let decoded = try JSONDecoder().decode(CalendarDate.self, from: data)
        #expect(decoded == date)
    }
}
