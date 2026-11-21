import Foundation

/// A timezone-independent Gregorian calendar date.
///
/// Meal planning must not shift days because of time zones, so the domain uses
/// this value type instead of `Date`. It encodes as `YYYY-MM-DD`.
public struct CalendarDate: Hashable, Comparable, Codable, Sendable, CustomStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int

    public static let reference = CalendarDate(uncheckedYear: 2000, month: 1, day: 1)

    public init?(year: Int, month: Int, day: Int) {
        guard (1...12).contains(month), (1...31).contains(day) else { return nil }
        let jdn = Self.julianDayNumber(year: year, month: month, day: day)
        let roundTrip = Self.gregorianDate(from: jdn)
        guard roundTrip.year == year, roundTrip.month == month, roundTrip.day == day else {
            return nil
        }
        self.year = year
        self.month = month
        self.day = day
    }

    private init(uncheckedYear year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    public init?(isoString: String) {
        let parts = isoString.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
              parts[0].count == 4,
              parts[1].count == 2,
              parts[2].count == 2,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2])
        else {
            return nil
        }
        self.init(year: year, month: month, day: day)
    }

    public init?(date: Date, timeZone: TimeZone = TimeZone(secondsFromGMT: 0) ?? .current) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = components.year, let month = components.month, let day = components.day else {
            return nil
        }
        self.init(year: year, month: month, day: day)
    }

    public var isoString: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    public var description: String { isoString }

    public var date: Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return calendar.date(from: components) ?? Date(timeIntervalSince1970: 0)
    }

    public func adding(days: Int) -> CalendarDate {
        let jdn = Self.julianDayNumber(year: year, month: month, day: day) + days
        let result = Self.gregorianDate(from: jdn)
        return CalendarDate(uncheckedYear: result.year, month: result.month, day: result.day)
    }

    public func days(until other: CalendarDate) -> Int {
        Self.julianDayNumber(year: other.year, month: other.month, day: other.day)
            - Self.julianDayNumber(year: year, month: month, day: day)
    }

    public func dates(count: Int) -> [CalendarDate] {
        guard count > 0 else { return [] }
        return (0..<count).map { adding(days: $0) }
    }

    public var weekday: Weekday {
        let index = Self.julianDayNumber(year: year, month: month, day: day) % 7
        return Weekday(rawValue: index) ?? .monday
    }

    public var isWeekend: Bool {
        weekday == .saturday || weekday == .sunday
    }

    public static func < (lhs: CalendarDate, rhs: CalendarDate) -> Bool {
        lhs.julianDayNumber < rhs.julianDayNumber
    }

    private var julianDayNumber: Int {
        Self.julianDayNumber(year: year, month: month, day: day)
    }

    private static func julianDayNumber(year: Int, month: Int, day: Int) -> Int {
        let a = (14 - month) / 12
        let y = year + 4800 - a
        let m = month + 12 * a - 3
        return day + (153 * m + 2) / 5 + 365 * y + y / 4 - y / 100 + y / 400 - 32045
    }

    private static func gregorianDate(from julianDayNumber: Int) -> (year: Int, month: Int, day: Int) {
        let a = julianDayNumber + 32044
        let b = (4 * a + 3) / 146097
        let c = a - (146097 * b) / 4
        let d = (4 * c + 3) / 1461
        let e = c - (1461 * d) / 4
        let m = (5 * e + 2) / 153
        let day = e - (153 * m + 2) / 5 + 1
        let month = m + 3 - 12 * (m / 10)
        let year = 100 * b + d - 4800 + m / 10
        return (year, month, day)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        guard let date = CalendarDate(isoString: string) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected a calendar date in YYYY-MM-DD format."
            )
        }
        self = date
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(isoString)
    }
}

public enum Weekday: Int, CaseIterable, Codable, Sendable {
    case monday = 0
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday
    case sunday
}
