//
//  FastingScheduleEngineTests.swift
//  FastFlow
//
//  Gleiche Szenarien, die in der Web-Version (JS-Port) geprüft wurden.
//  Feste Zeitzone Europe/Berlin, damit die Sommerzeit-Fälle reproduzierbar sind.
//

import Foundation
import Testing
@testable import FastFlow

@Suite("FastingScheduleEngine")
struct FastingScheduleEngineTests {
    let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return c
    }()

    var engine: FastingScheduleEngine { FastingScheduleEngine(calendar: calendar) }

    func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    func hm(_ date: Date) -> String {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", c.hour!, c.minute!)
    }

    // 07.11.2026 = Samstag
    @Test func saturdayEveningIsOvernightEatingWindow() throws {
        let plan = WeeklyFastingPlan.createWorkweek18_6Weekend14_10Plan()
        let snap = try #require(engine.resolveSnapshot(for: date(2026, 11, 7, 18), plan: plan))
        #expect(snap.mode == .eatingWindow)
        #expect(hm(snap.windowStart) == "17:00")
        #expect(hm(snap.windowEnd) == "02:00")
        #expect(Weekday(date: snap.windowEnd, calendar: calendar) == .sunday)
    }

    @Test func sundayAfterOvernightWindowIsFasting() throws {
        let plan = WeeklyFastingPlan.createWorkweek18_6Weekend14_10Plan()
        let snap = try #require(engine.resolveSnapshot(for: date(2026, 11, 8, 3), plan: plan))
        #expect(snap.mode == .fasting)
        #expect(hm(snap.windowStart) == "02:00")
        #expect(hm(snap.windowEnd) == "16:00")
        #expect(snap.todayRule.weekday == .sunday)
        #expect(snap.windowRule.weekday == .saturday)
    }

    @Test func sundayOneFifteenStillInSaturdayWindow() throws {
        let plan = WeeklyFastingPlan.createWorkweek18_6Weekend14_10Plan()
        let snap = try #require(engine.resolveSnapshot(for: date(2026, 11, 8, 1, 15), plan: plan))
        #expect(snap.mode == .eatingWindow)
        #expect(snap.currentWeekday == .sunday)
        #expect(snap.windowRule.weekday == .saturday)
    }

    @Test func mondayMorningFastingStartsSundayNight() throws {
        let plan = WeeklyFastingPlan.createWorkweek18_6Weekend14_10Plan()
        let snap = try #require(engine.resolveSnapshot(for: date(2026, 11, 9, 7), plan: plan))
        #expect(snap.mode == .fasting)
        #expect(hm(snap.windowStart) == "22:00")
        #expect(hm(snap.windowEnd) == "08:00")
    }

    @Test func badgesUseRealFastingGap() {
        let plan = WeeklyFastingPlan.createWorkweek18_6Weekend14_10Plan()
        let badges = Weekday.orderedMondayFirst.map { plan.protocolBadge(for: $0) }
        #expect(badges == ["18:6", "18:6", "18:6", "18:6", "27:6", "14:9", "10:6"])
    }

    @Test func disabledDayIsSkipped() throws {
        let plan = WeeklyFastingPlan.createWorkweek18_6Weekend14_10Plan()
        var sat = plan.rule(for: .saturday)
        sat.isEnabled = false
        plan.setRule(sat)
        // Fr 15:00 → nächstes Fenster ist So 16:00
        let snap = try #require(engine.resolveSnapshot(for: date(2026, 11, 6, 15), plan: plan))
        #expect(snap.mode == .fasting)
        #expect(Weekday(date: snap.windowEnd, calendar: calendar) == .sunday)
        #expect(hm(snap.windowEnd) == "16:00")
    }

    @Test func noEnabledDayReturnsNil() {
        let rules = Weekday.orderedMondayFirst.map {
            DayScheduleRule(weekday: $0, isEnabled: false, startHour: 8, endHour: 14)
        }
        let plan = WeeklyFastingPlan(name: "leer", dayRules: rules)
        #expect(engine.resolveSnapshot(for: date(2026, 11, 4, 12), plan: plan) == nil)
    }

    @Test func overlappingWindowsAreMerged() throws {
        let plan = WeeklyFastingPlan.createWorkweek18_6Weekend14_10Plan()
        // Sa 17:00 → So 16:30 überlappt mit So 16:00–22:00 → ein Fenster Sa 17:00 bis So 22:00
        plan.setRule(DayScheduleRule(weekday: .saturday, startHour: 17, endHour: 16, endMinute: 30))
        let snap = try #require(engine.resolveSnapshot(for: date(2026, 11, 8, 16, 15), plan: plan))
        #expect(snap.mode == .eatingWindow)
        #expect(hm(snap.windowStart) == "17:00")
        #expect(hm(snap.windowEnd) == "22:00")
    }

    // Sommerzeit-Beginn 29.03.2026: 02:00 existiert nicht
    @Test func springForwardOvernightEnd() throws {
        let plan = WeeklyFastingPlan.createWorkweek18_6Weekend14_10Plan()
        let snap = try #require(engine.resolveSnapshot(for: date(2026, 3, 29, 9), plan: plan))
        #expect(snap.mode == .fasting)
        #expect(hm(snap.windowStart) == "03:00")
        #expect(hm(snap.windowEnd) == "16:00")
    }

    // Winterzeit-Beginn 25.10.2026
    @Test func fallBackKeepsWallClockTimes() throws {
        let plan = WeeklyFastingPlan.createWorkweek18_6Weekend14_10Plan()
        let snap = try #require(engine.resolveSnapshot(for: date(2026, 10, 25, 14), plan: plan))
        #expect(snap.mode == .fasting)
        #expect(hm(snap.windowEnd) == "16:00")
        #expect(snap.remainingDuration == 2 * 3600)
    }

    @Test func rulesAreNormalizedToSevenDays() {
        let plan = WeeklyFastingPlan(name: "teilweise", dayRules: [
            DayScheduleRule(weekday: .monday, startHour: 8, endHour: 14),
            DayScheduleRule(weekday: .monday, startHour: 9, endHour: 15),
        ])
        #expect(plan.dayRules.count == 7)
        #expect(plan.rule(for: .monday).startMinutes == 8 * 60)
        #expect(plan.rule(for: .friday).isEnabled == false)
    }
}

@Suite("FastingNotificationScheduler")
struct FastingNotificationSchedulerTests {
    let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    func window(startIn hours: Double, length: Double) -> DateInterval {
        DateInterval(start: t0.addingTimeInterval(hours * 3600), duration: length * 3600)
    }

    @Test func plansOpenAndCloseReminders() {
        let settings = FastingNotificationSettings(isEnabled: true, leadTimeMinutes: 30)
        let planned = FastingNotificationScheduler.plannedNotifications(
            windows: [window(startIn: 2, length: 6)], settings: settings, now: t0)
        #expect(planned.count == 2)
        #expect(planned[0].fireDate == t0.addingTimeInterval(2 * 3600))
        #expect(planned[1].fireDate == t0.addingTimeInterval(7.5 * 3600))
    }

    @Test func skipsPastAndDisabled() {
        // Fenster läuft bereits: nur „schließt bald“
        let open = FastingNotificationScheduler.plannedNotifications(
            windows: [window(startIn: -1, length: 6)],
            settings: FastingNotificationSettings(isEnabled: true), now: t0)
        #expect(open.map(\.identifier).allSatisfy { $0.contains("close") })

        let off = FastingNotificationScheduler.plannedNotifications(
            windows: [window(startIn: 2, length: 6)],
            settings: FastingNotificationSettings(isEnabled: false), now: t0)
        #expect(off.isEmpty)
    }

    @Test func respectsPendingLimit() {
        let windows = (0..<100).map { window(startIn: Double($0) * 24 + 1, length: 6) }
        let planned = FastingNotificationScheduler.plannedNotifications(
            windows: windows, settings: FastingNotificationSettings(isEnabled: true), now: t0)
        #expect(planned.count == FastingNotificationScheduler.maxPending)
        #expect(planned == planned.sorted { $0.fireDate < $1.fireDate })
    }
}

@Suite("FastingHistory")
struct FastingHistoryTests {
    let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return c
    }()

    func date(_ d: Int, _ h: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: d, hour: h))!
    }

    /// Fastenphase, die am Tag `d` um 08:00 endet; `brokenAt` = früher gegessen.
    func session(endingOn d: Int, brokenAt hour: Int? = nil) -> FastingSessionSummary {
        FastingSessionSummary(start: date(d - 1, 14), plannedEnd: date(d, 8),
                              actualEnd: hour.map { date(d, $0) })
    }

    @Test func fastingWindowsMatchPlan() {
        let engine = FastingScheduleEngine(calendar: calendar)
        let plan = WeeklyFastingPlan.createWorkweek18_6Weekend14_10Plan()
        // Sa 07.11. 00:00 bis Mo 09.11. 12:00: So 02:00–16:00 und So 22:00–Mo 08:00
        let windows = engine.fastingWindows(between: date(7, 0), and: date(9, 12), plan: plan)
        #expect(windows.count == 2)
        #expect(windows.first?.duration == 14 * 3600)
        #expect(windows.last?.duration == 10 * 3600)
    }

    @Test func streakCountsConsecutiveDays() {
        let sessions = (1...5).map { session(endingOn: $0) }
        let result = FastingStreakCalculator.streak(sessions: sessions, today: date(5, 12),
                                                    calendar: calendar, jokers: 0)
        #expect(result.currentDays == 5)
    }

    @Test func missedDayUsesJokerThenBreaks() {
        let sessions = [session(endingOn: 1, brokenAt: 6), session(endingOn: 2, brokenAt: 6),
                        session(endingOn: 3), session(endingOn: 4)]
        let result = FastingStreakCalculator.streak(sessions: sessions, today: date(4, 12),
                                                    calendar: calendar, jokers: 1)
        #expect(result.currentDays == 3)
        #expect(result.jokersUsed == 1)
        #expect(result.jokersRemaining == 0)
    }

    @Test func dayWithoutSessionIsNeutral() {
        let sessions = [session(endingOn: 1), session(endingOn: 3)]
        let result = FastingStreakCalculator.streak(sessions: sessions, today: date(3, 12),
                                                    calendar: calendar, jokers: 0)
        #expect(result.currentDays == 2)
    }

    @Test func todayWithoutSessionStartsAtYesterday() {
        let sessions = [session(endingOn: 2), session(endingOn: 3)]
        let result = FastingStreakCalculator.streak(sessions: sessions, today: date(4, 6),
                                                    calendar: calendar, jokers: 0)
        #expect(result.currentDays == 2)
    }

    @Test func brokenFastCountsFastedMinutes() {
        let s = session(endingOn: 2, brokenAt: 6)
        #expect(s.targetMinutes == 18 * 60)
        #expect(s.fastedMinutes == 16 * 60)
        #expect(!s.isGoalReached)
    }
}
