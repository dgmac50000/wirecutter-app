import Foundation

/// A gift / shopping profile shown in the people row and profile page.
struct PersonProfile: Identifiable, Hashable {
    let id: String
    let name: String
    /// Month + day only; year is intentionally omitted from display.
    let birthday: DateComponents
    let holidays: [Holiday]
    /// Month + day for anniversary when the profile observes one.
    let anniversary: DateComponents?

    init(
        id: String,
        name: String,
        birthday: DateComponents,
        holidays: [Holiday],
        anniversary: DateComponents? = nil
    ) {
        self.id = id
        self.name = name
        self.birthday = birthday
        self.holidays = holidays
        self.anniversary = anniversary
    }

    var birthdayDisplay: String {
        Self.formatMonthDay(birthday)
    }

    var holidaysDisplay: String {
        holidays.map(\.rawValue).joined(separator: ", ")
    }

    /// True when birthday, anniversary, or a dated holiday falls within the next `days` days.
    func hasUpcomingEvent(
        within days: Int = 21,
        from reference: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        nearestUpcomingEvent(within: days, from: reference, calendar: calendar) != nil
    }

    /// Banner copy for the soonest event in the window, e.g. "Dad's birthday is in 12 days".
    func upcomingEventBannerMessage(
        within days: Int = 21,
        from reference: Date = Date(),
        calendar: Calendar = .current
    ) -> String? {
        guard let event = nearestUpcomingEvent(within: days, from: reference, calendar: calendar) else {
            return nil
        }
        let possessive = namePossessive
        let label = event.kind.bannerLabel
        switch event.daysUntil {
        case 0:
            return "\(possessive) \(label) is today"
        case 1:
            return "\(possessive) \(label) is tomorrow"
        default:
            return "\(possessive) \(label) is in \(event.daysUntil) days"
        }
    }

    /// Soonest birthday / anniversary / fixed holiday within the next `days` days.
    func nearestUpcomingEvent(
        within days: Int = 21,
        from reference: Date = Date(),
        calendar: Calendar = .current
    ) -> (kind: ProfileEventKind, date: Date, daysUntil: Int)? {
        let start = calendar.startOfDay(for: reference)
        guard let end = calendar.date(byAdding: .day, value: days, to: start) else { return nil }

        let candidates = upcomingEvents(from: reference, calendar: calendar)
            .compactMap { event -> (ProfileEventKind, Date, Int)? in
                guard event.date >= start, event.date <= end else { return nil }
                let daysUntil = calendar.dateComponents([.day], from: start, to: event.date).day ?? 0
                return (event.kind, event.date, daysUntil)
            }
            .sorted { $0.1 < $1.1 }

        guard let first = candidates.first else { return nil }
        return (kind: first.0, date: first.1, daysUntil: first.2)
    }

    /// Next occurrences of tracked profile events (birthday, anniversary, fixed-date holidays).
    func upcomingEventDates(
        from reference: Date = Date(),
        calendar: Calendar = .current
    ) -> [Date] {
        upcomingEvents(from: reference, calendar: calendar).map(\.date)
    }

    private func upcomingEvents(
        from reference: Date,
        calendar: Calendar
    ) -> [(kind: ProfileEventKind, date: Date)] {
        var events: [(ProfileEventKind, Date)] = []

        if let month = birthday.month, let day = birthday.day,
           let date = Self.nextAnnualDate(month: month, day: day, from: reference, calendar: calendar) {
            events.append((.birthday, date))
        }

        if holidays.contains(.anniversary),
           let anniversary,
           let month = anniversary.month,
           let day = anniversary.day,
           let date = Self.nextAnnualDate(month: month, day: day, from: reference, calendar: calendar) {
            events.append((.anniversary, date))
        }

        for holiday in holidays {
            if let fixed = holiday.fixedMonthDay,
               let date = Self.nextAnnualDate(
                month: fixed.month,
                day: fixed.day,
                from: reference,
                calendar: calendar
               ) {
                events.append((.holiday(holiday), date))
            }
        }

        return events
    }

    private var namePossessive: String {
        if let last = name.last, "sS".contains(last) {
            return "\(name)’"
        }
        return "\(name)’s"
    }

    private static func formatMonthDay(_ components: DateComponents) -> String {
        guard let month = components.month, let day = components.day else { return "—" }
        var resolved = DateComponents()
        resolved.month = month
        resolved.day = day
        // Use a leap-safe placeholder year for formatting.
        resolved.year = 2000
        guard let date = Calendar.current.date(from: resolved) else { return "—" }
        return birthdayFormatter.string(from: date)
    }

    private static func nextAnnualDate(
        month: Int,
        day: Int,
        from reference: Date,
        calendar: Calendar
    ) -> Date? {
        let start = calendar.startOfDay(for: reference)
        var components = DateComponents()
        components.month = month
        components.day = day
        components.year = calendar.component(.year, from: start)
        guard var date = calendar.date(from: components) else { return nil }
        date = calendar.startOfDay(for: date)
        if date < start {
            components.year = (components.year ?? 0) + 1
            guard let next = calendar.date(from: components) else { return nil }
            date = calendar.startOfDay(for: next)
        }
        return date
    }

    private static let birthdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("MMMMd")
        return formatter
    }()
}

enum ProfileEventKind: Hashable {
    case birthday
    case anniversary
    case holiday(Holiday)

    var bannerLabel: String {
        switch self {
        case .birthday:
            return "birthday"
        case .anniversary:
            return "anniversary"
        case .holiday(let holiday):
            return holiday.rawValue
        }
    }
}

enum Holiday: String, CaseIterable, Hashable {
    case christmas = "Christmas"
    case hanukkah = "Hanukkah"
    case kwanzaa = "Kwanzaa"
    case fathersDay = "Father's Day"
    case mothersDay = "Mother's Day"
    case anniversary = "Anniversary"
    case valentinesDay = "Valentine's Day"

    /// Fixed month/day holidays used for upcoming-event detection.
    /// Floating holidays (Father's/Mother's Day) and lunar ones are omitted for now.
    var fixedMonthDay: (month: Int, day: Int)? {
        switch self {
        case .christmas: return (12, 25)
        case .valentinesDay: return (2, 14)
        case .kwanzaa: return (12, 26)
        case .hanukkah, .fathersDay, .mothersDay, .anniversary:
            return nil
        }
    }
}

enum PersonProfileStore {
    /// Prototype profiles for the people row. Preferences are data-driven so
    /// production can replace this with API / local persistence later.
    ///
    /// Demo upcoming-event badges (relative to ~Jul 27, 2026 — within 3 weeks):
    /// - Dad: birthday Aug 8
    /// - Gandalf: anniversary Aug 12
    static let prototypes: [PersonProfile] = [
        PersonProfile(
            id: "dad",
            name: "Dad",
            birthday: DateComponents(month: 8, day: 8),
            holidays: [.christmas, .fathersDay]
        ),
        PersonProfile(
            id: "sam",
            name: "Sam",
            birthday: DateComponents(month: 9, day: 22),
            holidays: [.christmas]
        ),
        PersonProfile(
            id: "frodo",
            name: "Frodo",
            birthday: DateComponents(month: 9, day: 22),
            holidays: [.hanukkah]
        ),
        PersonProfile(
            id: "pippin",
            name: "Pippin",
            birthday: DateComponents(month: 4, day: 3),
            holidays: [.christmas, .kwanzaa]
        ),
        /// Sole profile that includes Valentine's Day + Anniversary (plus Christmas).
        PersonProfile(
            id: "gandalf",
            name: "Gandalf",
            birthday: DateComponents(month: 12, day: 1),
            holidays: [.christmas, .valentinesDay, .anniversary],
            anniversary: DateComponents(month: 8, day: 12)
        ),
    ]
}
