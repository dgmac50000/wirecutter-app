import Foundation
import SwiftUI

// MARK: - Interest sections

/// Wirecutter sections that user interests map onto. A fuller interest→section
/// matcher will land later; watchlist ordering is built around these hubs today.
enum WirecutterInterestSection: String, CaseIterable, Identifiable, Hashable {
    case sleep
    case kitchen
    case tech

    var id: String { rawValue }

    /// Short label under the circular thumbnail.
    var displayLabel: String {
        switch self {
        case .sleep: return "Sleep"
        case .kitchen: return "Kitchen"
        case .tech: return "Tech"
        }
    }

    /// Hub path under `/wirecutter/` for editorial shortform.
    /// Only Sleep has a real `/advice` subsection; other `/…/advice/` URLs
    /// currently misfire and serve Sleep’s advice feed.
    var hubSlug: String {
        switch self {
        case .sleep: return "sleep/advice"
        case .kitchen: return "kitchen-dining"
        case .tech: return "electronics"
        }
    }

    /// Must appear in the hub’s section name so we reject CMS misfires.
    var sectionIdentityTokens: [String] {
        switch self {
        case .sleep: return ["sleep"]
        case .kitchen: return ["kitchen"]
        case .tech: return ["electronic"]
        }
    }

    /// Fallback article when the section hub cannot be fetched.
    var fallbackArticleURL: URL {
        switch self {
        case .sleep:
            return URL(string: "https://www.nytimes.com/wirecutter/reviews/ask-wirecutter-getting-better-sleep/")!
        case .kitchen:
            return URL(string: "https://www.nytimes.com/wirecutter/reviews/pfas-free-cookware-we-recommend/")!
        case .tech:
            return URL(string: "https://www.nytimes.com/wirecutter/reviews/fancy-apple-watch-bands/")!
        }
    }
}

/// Prototype of the signed-in user’s followed sections (interest → section map).
enum UserInterestStore {
    static var followedSections: [WirecutterInterestSection] = [.sleep, .kitchen, .tech]
}

// MARK: - Editorial moment

/// An editorial watchlist moment (blog / shortform), shown as a circular avatar.
struct WatchlistEditorialMoment: Identifiable, Hashable {
    let id: String
    /// Short label under the circular thumbnail (e.g. "Sleep").
    let label: String
    let articleURL: URL
    var thumbnailURL: URL?
    /// ISO local publish timestamp used to pick the freshest lead.
    var publishedLocalISO: String?
    var section: WirecutterInterestSection?

    init(
        id: String,
        label: String,
        articleURL: URL,
        thumbnailURL: URL? = nil,
        publishedLocalISO: String? = nil,
        section: WirecutterInterestSection? = nil
    ) {
        self.id = id
        self.label = label
        self.articleURL = articleURL
        self.thumbnailURL = thumbnailURL
        self.publishedLocalISO = publishedLocalISO
        self.section = section
    }
}

// MARK: - Curation

/// Editorial can always force the first watchlist slot for all (or relevant) users.
enum WatchlistCuration {
    /// When non-nil, this moment leads the watchlist for everyone (on a fresh session).
    static var forcedLead: WatchlistEditorialMoment? = nil
}

// MARK: - Completed events (suppress red dots across sessions)

enum WatchlistEventCompletionStore {
    private static let key = "watchlist.completedEventKeys"

    static var completedKeys: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: key) ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: key) }
    }

    static func completionKey(profileID: String, kind: ProfileEventKind) -> String {
        switch kind {
        case .birthday:
            return "\(profileID):birthday"
        case .anniversary:
            return "\(profileID):anniversary"
        case .holiday(let holiday):
            return "\(profileID):holiday:\(holiday.rawValue)"
        }
    }

    static func isCompleted(profileID: String, kind: ProfileEventKind) -> Bool {
        completedKeys.contains(completionKey(profileID: profileID, kind: kind))
    }

    static func markCompleted(profileID: String, kind: ProfileEventKind) {
        var keys = completedKeys
        keys.insert(completionKey(profileID: profileID, kind: kind))
        completedKeys = keys
    }

    /// True when the profile has an urgent event that has not been marked completed.
    static func hasActiveUrgentEvent(
        _ person: PersonProfile,
        within days: Int = WatchlistBuilder.upcomingEventWindowDays,
        from reference: Date = DemoTimeline.now
    ) -> Bool {
        guard let event = person.nearestUpcomingEvent(within: days, from: reference) else {
            return false
        }
        return !isCompleted(profileID: person.id, kind: event.kind)
    }
}

// MARK: - Session + interaction

/// In-session watchlist visit order (memory only) and persistent dismissals.
///
/// In-session:
/// - Most recently opened item stays in slot 1 at 70% opacity
/// - Earlier opened items move to the end
/// - Red dots clear for opened urgent profiles until the next app session
///
/// Across sessions (app backgrounded / relaunched):
/// - Visit order + dimming reset; editorial feed refreshes
/// - Urgent red dots return unless the event was marked completed
/// - Non-urgent profiles the user already opened are omitted
enum WatchlistInteractionStore {
    private static let interactionKey = "watchlist.lastInteractionAt"
    private static let dismissedNonUrgentKey = "watchlist.dismissedNonUrgentProfileIDs"
    private static let idleInterval: TimeInterval = 48 * 60 * 60

    /// Oldest → newest opens this session. Newest pins to slot 1.
    private(set) static var sessionVisitOrder: [String] = []

    /// Set while backgrounded so the next `.active` refreshes the watchlist session.
    private static var pendingSessionRefresh = false

    static var lastInteractionAt: Date? {
        get {
            let interval = UserDefaults.standard.double(forKey: interactionKey)
            guard interval > 0 else { return nil }
            return Date(timeIntervalSince1970: interval)
        }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue.timeIntervalSince1970, forKey: interactionKey)
            } else {
                UserDefaults.standard.removeObject(forKey: interactionKey)
            }
        }
    }

    static var hasInteractedWithin48Hours: Bool {
        guard let last = lastInteractionAt else { return false }
        return Date().timeIntervalSince(last) < idleInterval
    }

    static func recordInteraction(at date: Date = Date()) {
        lastInteractionAt = date
    }

    // MARK: Session lifecycle

    static func beginSession() {
        sessionVisitOrder = []
        pendingSessionRefresh = false
    }

    static func markAppBackgrounded() {
        pendingSessionRefresh = true
    }

    /// Returns true once when returning from background so home can refresh.
    static func consumePendingSessionRefresh() -> Bool {
        guard pendingSessionRefresh else { return false }
        pendingSessionRefresh = false
        return true
    }

    static var sessionVisitedIDs: Set<String> {
        Set(sessionVisitOrder)
    }

    static func hasVisitedThisSession(_ entryID: String) -> Bool {
        sessionVisitOrder.contains(entryID)
    }

    /// Records an open: pins this id as most-recent; prior visits stay for end-of-list.
    static func recordSessionVisit(_ entryID: String) {
        sessionVisitOrder.removeAll { $0 == entryID }
        sessionVisitOrder.append(entryID)
    }

    // MARK: Cross-session non-urgent dismissals

    static var dismissedNonUrgentProfileIDs: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: dismissedNonUrgentKey) ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: dismissedNonUrgentKey) }
    }

    /// Persist a non-urgent profile open so it can be omitted after the next app return.
    static func recordPersonOpen(
        _ person: PersonProfile,
        referenceDate: Date = DemoTimeline.now
    ) {
        let isUrgent = WatchlistEventCompletionStore.hasActiveUrgentEvent(
            person,
            from: referenceDate
        )
        guard !isUrgent else { return }
        var ids = dismissedNonUrgentProfileIDs
        ids.insert(person.id)
        dismissedNonUrgentProfileIDs = ids
    }

    static func shouldIncludePerson(
        _ person: PersonProfile,
        referenceDate: Date = DemoTimeline.now
    ) -> Bool {
        if WatchlistEventCompletionStore.hasActiveUrgentEvent(person, from: referenceDate) {
            return true
        }
        return !dismissedNonUrgentProfileIDs.contains(person.id)
    }
}

// MARK: - Entries

enum WatchlistEntry: Identifiable, Hashable {
    case editorial(WatchlistEditorialMoment)
    case person(PersonProfile)
    case viewAll

    var id: String {
        switch self {
        case .editorial(let moment): return "editorial:\(moment.id)"
        case .person(let person): return "person:\(person.id)"
        case .viewAll: return "viewAll"
        }
    }
}

// MARK: - Builder

enum WatchlistBuilder {
    /// Max content avatars before the trailing “View all” control.
    static let maxAvatars = 20
    static let upcomingEventWindowDays = 21

    /// Assembles the home watchlist.
    ///
    /// Fresh session (no visits):
    /// 1. Lead editorial (curation or freshest interest match)
    /// 2. Urgent gift profiles (active red-dot cohort)
    /// 3. Remaining profiles + editorials, semi-random
    ///
    /// After opens this session:
    /// 1. Most recently opened item (dimmed)
    /// 2. Unvisited items in the fresh order above
    /// 3. Earlier opened items at the end (dimmed)
    /// 4. Cap at 20, then View all
    static func build(
        people: [PersonProfile],
        editorials: [WatchlistEditorialMoment],
        forcedLead: WatchlistEditorialMoment? = WatchlistCuration.forcedLead,
        sessionVisitOrder: [String] = WatchlistInteractionStore.sessionVisitOrder,
        referenceDate: Date = DemoTimeline.now,
        seed: UInt64 = 42
    ) -> [WatchlistEntry] {
        let eligiblePeople: [PersonProfile]
        if sessionVisitOrder.isEmpty {
            // New session: drop non-urgent profiles opened in a prior session.
            eligiblePeople = people.filter {
                WatchlistInteractionStore.shouldIncludePerson($0, referenceDate: referenceDate)
            }
        } else {
            // Same session: keep opened items visible (dimmed / reordered) until app exit.
            eligiblePeople = people
        }

        let base = buildFreshBase(
            people: eligiblePeople,
            editorials: editorials,
            forcedLead: forcedLead,
            referenceDate: referenceDate,
            seed: seed
        )

        let ordered = applySessionVisitOrder(base: base, sessionVisitOrder: sessionVisitOrder)
        var capped = Array(ordered.prefix(maxAvatars))
        capped.append(.viewAll)
        return capped
    }

    /// Default ordering before any in-session opens.
    private static func buildFreshBase(
        people: [PersonProfile],
        editorials: [WatchlistEditorialMoment],
        forcedLead: WatchlistEditorialMoment?,
        referenceDate: Date,
        seed: UInt64
    ) -> [WatchlistEntry] {
        var result: [WatchlistEntry] = []
        var usedPeople = Set<String>()
        var usedEditorials = Set<String>()

        if let lead = resolveLead(forcedLead: forcedLead, editorials: editorials) {
            result.append(.editorial(lead))
            usedEditorials.insert(lead.id)
        }

        let urgent = people
            .filter {
                WatchlistEventCompletionStore.hasActiveUrgentEvent($0, from: referenceDate)
            }
            .sorted { lhs, rhs in
                let left = lhs.nearestUpcomingEvent(
                    within: upcomingEventWindowDays,
                    from: referenceDate
                )?.daysUntil ?? Int.max
                let right = rhs.nearestUpcomingEvent(
                    within: upcomingEventWindowDays,
                    from: referenceDate
                )?.daysUntil ?? Int.max
                if left != right { return left < right }
                return lhs.name < rhs.name
            }

        for person in urgent {
            result.append(.person(person))
            usedPeople.insert(person.id)
        }

        var pool: [WatchlistEntry] = []
        for person in people where !usedPeople.contains(person.id) {
            pool.append(.person(person))
        }
        for moment in editorials where !usedEditorials.contains(moment.id) {
            pool.append(.editorial(moment))
        }

        var rng = SeededRandomNumberGenerator(seed: seed)
        pool.shuffle(using: &rng)
        result.append(contentsOf: pool)
        return result
    }

    /// Pins the latest open first; earlier opens go to the end so the middle stays fresh.
    private static func applySessionVisitOrder(
        base: [WatchlistEntry],
        sessionVisitOrder: [String]
    ) -> [WatchlistEntry] {
        guard let mostRecentID = sessionVisitOrder.last else { return base }

        var byID = Dictionary(uniqueKeysWithValues: base.map { ($0.id, $0) })
        let olderVisitedIDs = sessionVisitOrder.dropLast().filter { byID[$0] != nil }

        var result: [WatchlistEntry] = []
        if let recent = byID.removeValue(forKey: mostRecentID) {
            result.append(recent)
        }

        for entry in base where byID[entry.id] != nil && !olderVisitedIDs.contains(entry.id) {
            if let item = byID.removeValue(forKey: entry.id) {
                result.append(item)
            }
        }

        for id in olderVisitedIDs {
            if let item = byID.removeValue(forKey: id) {
                result.append(item)
            }
        }

        return result
    }

    private static func resolveLead(
        forcedLead: WatchlistEditorialMoment?,
        editorials: [WatchlistEditorialMoment]
    ) -> WatchlistEditorialMoment? {
        if let forcedLead { return forcedLead }
        return freshestEditorial(from: editorials)
    }

    static func freshestEditorial(from editorials: [WatchlistEditorialMoment]) -> WatchlistEditorialMoment? {
        editorials.max { lhs, rhs in
            (lhs.publishedLocalISO ?? "") < (rhs.publishedLocalISO ?? "")
        }
    }
}

// MARK: - Loader

enum WatchlistStore {
    /// Placeholder used before the first network resolve completes.
    static var placeholderEntries: [WatchlistEntry] {
        WatchlistBuilder.build(
            people: PersonProfileStore.prototypes,
            editorials: []
        )
    }

    /// Loads one latest advice/shortform piece per followed section, then builds the row.
    static func loadEntries(
        people: [PersonProfile] = PersonProfileStore.prototypes,
        sections: [WirecutterInterestSection] = UserInterestStore.followedSections
    ) async -> (entries: [WatchlistEntry], editorials: [WatchlistEditorialMoment]) {
        let moments = await loadEditorials(for: sections)
        let entries = WatchlistBuilder.build(
            people: people,
            editorials: moments,
            seed: UInt64(people.count &* 31 &+ moments.count)
        )
        return (entries, moments)
    }

    static func loadEditorials(
        for sections: [WirecutterInterestSection]
    ) async -> [WatchlistEditorialMoment] {
        await withTaskGroup(of: WatchlistEditorialMoment?.self) { group in
            for section in sections {
                group.addTask { await loadEditorial(for: section) }
            }
            var results: [WatchlistEditorialMoment] = []
            for await moment in group {
                if let moment { results.append(moment) }
            }
            return results.sorted { ($0.publishedLocalISO ?? "") > ($1.publishedLocalISO ?? "") }
        }
    }

    private static func loadEditorial(
        for section: WirecutterInterestSection
    ) async -> WatchlistEditorialMoment {
        let candidate = await ArticlePageFeedParser.fetchLatestSectionArticleCandidate(
            sectionSlug: section.hubSlug,
            sortByPublishedOnly: true,
            preferShortform: true,
            expectedSectionNameTokens: section.sectionIdentityTokens
        )

        let articleURL = candidate?.url ?? section.fallbackArticleURL
        var moment = WatchlistEditorialMoment(
            id: section.rawValue,
            label: section.displayLabel,
            articleURL: articleURL,
            thumbnailURL: nil,
            publishedLocalISO: candidate?.publishedLocalISO,
            section: section
        )

        if let headshot = await ArticlePageFeedParser.fetchLeadAuthorImageURL(from: moment.articleURL) {
            moment.thumbnailURL = UpcomingEventsBuilder.compactHeroURL(headshot)
        } else if let featured = candidate?.featuredImageURL {
            moment.thumbnailURL = UpcomingEventsBuilder.compactHeroURL(featured)
        }
        return moment
    }
}
