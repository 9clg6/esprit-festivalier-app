import Foundation

/// "13–15 juin 2027": one text for the list row and the detail header, always fr_FR, Europe/Paris.
public enum FestivalDates {
    private static let locale = Locale(identifier: "fr_FR")
    private static let paris = TimeZone(identifier: "Europe/Paris") ?? .current

    public static func text(from start: Date, to end: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = paris
        calendar.locale = locale
        return (start..<max(start, end)).formatted(
            Date.IntervalFormatStyle(locale: locale, calendar: calendar, timeZone: paris)
                .day().month(.wide).year()
        )
    }
}
