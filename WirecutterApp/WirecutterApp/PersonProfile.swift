import Foundation

/// Fixed “today” for the gift-shopping demo so Upcoming cards stay stable.
enum DemoTimeline {
    /// Three weeks before Christmas 2026 (Dec 4 → Christmas Dec 25).
    static var now: Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 12, day: 4)) ?? Date()
    }
}

/// A gift / shopping profile shown in the people row and profile page.
struct PersonProfile: Identifiable, Hashable {
    let id: String
    let name: String
    /// Month + day only; year is intentionally omitted from display.
    let birthday: DateComponents
    let holidays: [Holiday]
    /// Month + day for anniversary when the profile observes one.
    let anniversary: DateComponents?
    /// Interest keywords used to match gift-guide / category hero art for birthday cards.
    let interests: [String]

    init(
        id: String,
        name: String,
        birthday: DateComponents,
        holidays: [Holiday],
        anniversary: DateComponents? = nil,
        interests: [String] = []
    ) {
        self.id = id
        self.name = name
        self.birthday = birthday
        self.holidays = holidays
        self.anniversary = anniversary
        self.interests = interests
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
        from reference: Date = DemoTimeline.now,
        calendar: Calendar = .current
    ) -> Bool {
        nearestUpcomingEvent(within: days, from: reference, calendar: calendar) != nil
    }

    /// Banner copy for the soonest event in the window, e.g. "Dad's birthday is in 12 days".
    func upcomingEventBannerMessage(
        within days: Int = 21,
        from reference: Date = DemoTimeline.now,
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
        from reference: Date = DemoTimeline.now,
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
        from reference: Date = DemoTimeline.now,
        calendar: Calendar = .current
    ) -> [Date] {
        upcomingEvents(from: reference, calendar: calendar).map(\.date)
    }

    /// All next birthday / anniversary / fixed-holiday occurrences from today forward.
    func upcomingEvents(
        from reference: Date = DemoTimeline.now,
        calendar: Calendar = .current
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

    /// Keywords used to find a matching gift-guide / article hero image.
    var heroSearchKeywords: [String] {
        switch self {
        case .birthday:
            return ["birthday", "gift guide", "gifts"]
        case .anniversary:
            return ["anniversary", "romantic", "gift guide", "gifts"]
        case .holiday(let holiday):
            return holiday.heroSearchKeywords
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

    var heroSearchKeywords: [String] {
        switch self {
        case .christmas:
            return ["christmas", "holiday gift", "gift guide", "gifts"]
        case .hanukkah:
            return ["hanukkah", "holiday gift", "gift guide", "gifts"]
        case .kwanzaa:
            return ["kwanzaa", "holiday gift", "gift guide", "gifts"]
        case .fathersDay:
            return ["father", "dad", "gift guide", "gifts"]
        case .mothersDay:
            return ["mother", "mom", "gift guide", "gifts"]
        case .anniversary:
            return ["anniversary", "romantic", "gift guide", "gifts"]
        case .valentinesDay:
            return ["valentine", "romantic", "gift guide", "gifts"]
        }
    }
}

/// A Wirecutter gift-guide article hero used by Upcoming cards.
struct GiftGuideHero: Identifiable, Hashable {
    let id: String
    let title: String
    let articleURL: URL
    let keywords: [String]
    let heroImageURL: URL
}

/// Curated gift guides + live hero fetch. Upcoming cards use these page heroes
/// (not product catalog shots from the commerce feed).
enum GiftGuideHeroCatalog {
    /// Seed guides covering prototype profile interests + common holidays.
    private static let seedGuides: [(slug: String, title: String, keywords: [String])] = [
        ("best-gifts-for-travelers", "Gifts for Travelers",
         ["travel", "luggage", "backpack", "bags", "traveler", "frequent"]),
        ("best-gifts-for-dad", "Gifts for Dads",
         ["dad", "father", "grill", "outdoors", "tools", "electronics", "fathers"]),
        ("best-gifts-for-foodies", "Gifts for Foodies",
         ["kitchen", "cooking", "food", "appliances", "foodie"]),
        ("best-anniversary-gifts", "Anniversary Gifts",
         ["anniversary", "romantic", "valentine"]),
        ("best-gifts-for-book-lovers", "Gifts for Book Lovers",
         ["books", "book", "reading", "lighting"]),
        ("best-gifts-for-coworkers", "Gifts for Co-Workers",
         ["office", "work", "coworker", "desk"]),
        ("best-baby-shower-gifts", "Baby Shower Gifts",
         ["baby", "kid", "parent", "shower", "play", "toys"]),
        ("best-hostess-gifts", "Host and Hostess Gifts",
         ["home", "host", "hostess"]),
        ("best-gifts-under-50", "Gifts Under $50",
         ["birthday", "gift", "holiday", "christmas", "hanukkah", "kwanzaa", "valentine"]),
        ("best-golf-gifts", "Gifts for Golfers",
         ["outdoors", "golf", "sport"]),
        ("best-gifts-for-dogs", "Gifts for Dogs",
         ["pets", "dog"]),
        ("best-alcohol-gifts", "Alcohol Gifts",
         ["cocktail", "alcohol", "drink"]),
    ]

    /// Fetches each guide’s editorial `heroImage` in parallel and returns only successes.
    static func loadHeroes() async -> [GiftGuideHero] {
        await withTaskGroup(of: GiftGuideHero?.self) { group in
            for guide in seedGuides {
                group.addTask {
                    let articleURL = URL(string: "https://www.nytimes.com/wirecutter/gifts/\(guide.slug)/")!
                    guard let hero = await ArticlePageFeedParser.fetchHeroImageURL(from: articleURL) else {
                        return nil
                    }
                    return GiftGuideHero(
                        id: guide.slug,
                        title: guide.title,
                        articleURL: articleURL,
                        keywords: guide.keywords,
                        heroImageURL: UpcomingEventsBuilder.compactHeroURL(hero)
                    )
                }
            }

            var heroes: [GiftGuideHero] = []
            for await hero in group {
                if let hero { heroes.append(hero) }
            }
            return heroes
        }
    }
}

/// A home-feed Upcoming card: a personalized calendar event, or a specialty
/// editorial highlight (e.g. Black Friday) with no profiles / countdown.
struct UpcomingEventCard: Identifiable, Hashable {
    let id: String
    let kind: ProfileEventKind
    let date: Date
    let profiles: [PersonProfile]
    let heroImageURL: URL?
    /// Non-nil for non-personalized specialty cards (title only; no countdown / avatars).
    let specialtyTitle: String?
    /// Article opened from a specialty card (bottom sheet).
    let articleURL: URL?

    init(
        id: String,
        kind: ProfileEventKind,
        date: Date,
        profiles: [PersonProfile],
        heroImageURL: URL?,
        specialtyTitle: String? = nil,
        articleURL: URL? = nil
    ) {
        self.id = id
        self.kind = kind
        self.date = date
        self.profiles = profiles
        self.heroImageURL = heroImageURL
        self.specialtyTitle = specialtyTitle
        self.articleURL = articleURL
    }

    var isSpecialty: Bool { specialtyTitle != nil }

    var tagLabel: String {
        if profiles.count > 1 {
            return "\(profiles.count) People"
        }
        return profiles.first?.name ?? ""
    }

    /// All-caps countdown, e.g. "11 DAYS" / "TODAY".
    func countdownLabel(
        from reference: Date = DemoTimeline.now,
        calendar: Calendar = .current
    ) -> String {
        let start = calendar.startOfDay(for: reference)
        let end = calendar.startOfDay(for: date)
        let days = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        switch days {
        case ...0:
            return "TODAY"
        case 1:
            return "1 DAY"
        default:
            return "\(days) DAYS"
        }
    }

    /// Human event title, e.g. "Christmas", "Dad’s Birthday", or "Black Friday".
    var eventTitle: String {
        if let specialtyTitle { return specialtyTitle }
        switch kind {
        case .holiday(let holiday):
            return holiday.rawValue
        case .birthday:
            if let name = profiles.first?.name {
                return "\(Self.possessive(name)) Birthday"
            }
            return "Birthday"
        case .anniversary:
            if profiles.count > 1 {
                return "Anniversary"
            }
            if let name = profiles.first?.name {
                return "\(Self.possessive(name)) Anniversary"
            }
            return "Anniversary"
        }
    }

    var accessibilityLabel: String {
        if isSpecialty {
            return eventTitle
        }
        return "\(countdownLabel()), \(eventTitle)"
    }

    private static func possessive(_ name: String) -> String {
        if let last = name.last, "sS".contains(last) {
            return "\(name)’"
        }
        return "\(name)’s"
    }
}

/// Loads the non-personalized lead card for the Upcoming row.
enum UpcomingSpecialtyCatalog {
    /// Fallback when the Money section has no recent deals coverage.
    private static let fallbackURL = URL(
        string: "https://www.nytimes.com/wirecutter/money/cyber-monday-deals/"
    )!

    static func loadLeadCard() async -> UpcomingEventCard {
        let articleURL = await ArticlePageFeedParser.fetchLatestSectionArticleURL(
            sectionSlug: "money",
            titleKeywords: ["black friday", "cyber monday", "deal", "sale"]
        ) ?? fallbackURL

        var heroURL: URL?
        if let hero = await ArticlePageFeedParser.fetchHeroImageURL(from: articleURL) {
            heroURL = UpcomingEventsBuilder.compactHeroURL(hero)
        }
        return UpcomingEventCard(
            id: "specialty-black-friday",
            kind: .holiday(.christmas),
            date: DemoTimeline.now,
            profiles: [],
            heroImageURL: heroURL,
            specialtyTitle: "Black Friday",
            articleURL: articleURL
        )
    }
}

enum UpcomingEventsBuilder {
    /// Collects events across gift profiles, merges shared holidays, and returns the
    /// `limit` nearest cards with heroes from live gift-guide article pages.
    /// When `specialtyLead` is provided, it is prepended and counts toward `limit`.
    static func cards(
        from profiles: [PersonProfile],
        giftGuideHeroes: [GiftGuideHero],
        limit: Int = 4,
        specialtyLead: UpcomingEventCard? = nil,
        from reference: Date = DemoTimeline.now,
        calendar: Calendar = .current
    ) -> [UpcomingEventCard] {
        struct Acc {
            var kind: ProfileEventKind
            var date: Date
            var profiles: [PersonProfile]
        }

        var grouped: [String: Acc] = [:]

        for profile in profiles {
            for event in profile.upcomingEvents(from: reference, calendar: calendar) {
                let key = groupKey(kind: event.kind, profileID: profile.id, date: event.date, calendar: calendar)
                if var existing = grouped[key] {
                    if !existing.profiles.contains(where: { $0.id == profile.id }) {
                        existing.profiles.append(profile)
                    }
                    if event.date < existing.date {
                        existing.date = event.date
                    }
                    grouped[key] = existing
                } else {
                    grouped[key] = Acc(kind: event.kind, date: event.date, profiles: [profile])
                }
            }
        }

        var usedGuideIDs = Set<String>()
        let personalizedLimit = max(limit - (specialtyLead == nil ? 0 : 1), 0)

        let personalized: [UpcomingEventCard] = grouped.values
            .sorted { lhs, rhs in
                if lhs.date != rhs.date { return lhs.date < rhs.date }
                return lhs.profiles.first?.name.localizedCaseInsensitiveCompare(
                    rhs.profiles.first?.name ?? ""
                ) == .orderedAscending
            }
            .prefix(personalizedLimit)
            .map { acc in
                let profiles = acc.profiles.sorted {
                    $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }
                let keywords = heroKeywords(kind: acc.kind, profiles: profiles)
                let hero = resolveGiftGuideHero(
                    keywords: keywords,
                    guides: giftGuideHeroes,
                    excluding: &usedGuideIDs
                )
                return UpcomingEventCard(
                    id: groupKey(kind: acc.kind, profileID: profiles.first?.id ?? "x", date: acc.date, calendar: calendar),
                    kind: acc.kind,
                    date: acc.date,
                    profiles: profiles,
                    heroImageURL: hero?.heroImageURL
                )
            }

        if let specialtyLead {
            return [specialtyLead] + personalized
        }
        return personalized
    }

    /// Shared holidays collapse across profiles; birthdays / anniversaries stay per-person.
    private static func groupKey(
        kind: ProfileEventKind,
        profileID: String,
        date: Date,
        calendar: Calendar
    ) -> String {
        let year = calendar.component(.year, from: date)
        switch kind {
        case .birthday:
            return "birthday-\(profileID)-\(year)"
        case .anniversary:
            return "anniversary-\(profileID)-\(year)"
        case .holiday(let holiday):
            return "holiday-\(holiday.rawValue)-\(year)"
        }
    }

    private static func heroKeywords(kind: ProfileEventKind, profiles: [PersonProfile]) -> [String] {
        switch kind {
        case .birthday, .anniversary:
            return profiles.flatMap(\.interests) + kind.heroSearchKeywords
        case .holiday:
            return kind.heroSearchKeywords + profiles.flatMap(\.interests)
        }
    }

    /// Pick the best unused gift-guide hero for this event’s keywords.
    private static func resolveGiftGuideHero(
        keywords: [String],
        guides: [GiftGuideHero],
        excluding: inout Set<String>
    ) -> GiftGuideHero? {
        guard !guides.isEmpty else { return nil }

        let needles = keywords
            .map { $0.lowercased() }
            .filter { !$0.isEmpty }

        func score(_ guide: GiftGuideHero) -> Int {
            var value = 0
            let haystack = (guide.keywords + [guide.title, guide.id]).joined(separator: " ").lowercased()
            for needle in needles where haystack.contains(needle) {
                value += needle.count >= 5 ? 20 : 8
            }
            return value
        }

        let ranked = guides
            .map { (guide: $0, score: score($0)) }
            .sorted { $0.score > $1.score }

        // Prefer a keyword match that hasn’t been used yet.
        for entry in ranked where entry.score > 0 {
            if excluding.insert(entry.guide.id).inserted {
                return entry.guide
            }
        }

        // Fall back to any remaining guide (still a real gift-guide hero).
        for entry in ranked {
            if excluding.insert(entry.guide.id).inserted {
                return entry.guide
            }
        }

        return ranked.first?.guide
    }

    /// Request the smallest useful variant for a 250pt card (~640px wide).
    static func compactHeroURL(_ url: URL) -> URL {
        var raw = url.absoluteString.replacingOccurrences(of: "&amp;", with: "&")

        let isWirecutter = raw.lowercased().contains("cdn.thewirecutter.com")
            || raw.lowercased().contains("/wp-content/media/")
            || raw.lowercased().contains("/wp-content/uploads/")

        if isWirecutter {
            guard var components = URLComponents(string: raw) else { return url }
            var items = (components.queryItems ?? []).filter { item in
                let name = item.name.lowercased()
                return name != "width" && name != "w" && name != "quality"
                    && name != "auto" && name != "dpr" && name != "crop"
            }
            items.append(URLQueryItem(name: "auto", value: "webp"))
            items.append(URLQueryItem(name: "quality", value: "60"))
            items.append(URLQueryItem(name: "width", value: "640"))
            components.queryItems = items
            return components.url ?? url
        }

        let replacements = [
            "_AC_SL1500_": "_AC_SL500_",
            "_SL1500_": "_SL500_",
            "_AC_SL1200_": "_AC_SL500_",
            "_SL1200_": "_SL500_",
        ]
        for (from, to) in replacements where raw.contains(from) {
            raw = raw.replacingOccurrences(of: from, with: to)
            break
        }
        return URL(string: raw) ?? url
    }
}

enum PersonProfileStore {
    /// Prototype profiles for the people row. Preferences are data-driven so
    /// production can replace this with API / local persistence later.
    ///
    /// Demo timeline (`DemoTimeline.now` = Dec 4, 2026 — three weeks before Christmas):
    /// - Gandalf: birthday Dec 11 (7 days)
    /// - Dad: birthday Dec 18 (14 days)
    /// - Christmas Dec 25 (21 days) — Dad, Sam, Pippin, Gandalf
    /// - Pippin: Kwanzaa Dec 26 (22 days)
    static let prototypes: [PersonProfile] = [
        PersonProfile(
            id: "dad",
            name: "Dad",
            birthday: DateComponents(month: 12, day: 18),
            holidays: [.christmas, .fathersDay],
            interests: ["grill", "outdoors", "tools", "electronics"]
        ),
        PersonProfile(
            id: "sam",
            name: "Sam",
            birthday: DateComponents(month: 9, day: 22),
            holidays: [.christmas],
            interests: ["kitchen", "cooking", "home", "appliances"]
        ),
        PersonProfile(
            id: "frodo",
            name: "Frodo",
            birthday: DateComponents(month: 9, day: 22),
            holidays: [.hanukkah],
            interests: ["travel", "luggage", "backpack", "bags"]
        ),
        PersonProfile(
            id: "pippin",
            name: "Pippin",
            birthday: DateComponents(month: 4, day: 3),
            holidays: [.christmas, .kwanzaa],
            interests: ["baby", "kid", "toys", "play"]
        ),
        /// Sole profile that includes Valentine's Day + Anniversary (plus Christmas).
        PersonProfile(
            id: "gandalf",
            name: "Gandalf",
            birthday: DateComponents(month: 12, day: 11),
            holidays: [.christmas, .valentinesDay, .anniversary],
            anniversary: DateComponents(month: 8, day: 12),
            interests: ["books", "office", "home", "lighting"]
        ),
    ]
}
