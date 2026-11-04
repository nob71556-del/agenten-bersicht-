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
