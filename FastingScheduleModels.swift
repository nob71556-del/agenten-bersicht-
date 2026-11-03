//
//  FastingScheduleModels.swift
//  FastFlow (iOS 18 / SwiftUI / SwiftData / HealthKit)
//
//  Wochentagsbasierte Fastenpläne mit pro Tag frei einstellbarem Essensfenster,
//  inklusive Fenstern, die über Mitternacht in den Folgetag laufen.
//
//  Kernidee der Engine: Aus dem Plan werden konkrete Essens-Intervalle (Date…Date)
//  für ±Tage um den Referenzzeitpunkt erzeugt. Alles dazwischen ist Fasten.
//  Dadurch sind Übernachtfenster, deaktivierte Tage und Sommerzeit ohne
//  Sonderfälle korrekt.
//

import Foundation
import SwiftData

// MARK: - 1. Wochentage & Strategie

/// Wochentage, rawValue entspricht `Calendar.Component.weekday` (So = 1, Mo = 2, …, Sa = 7).
public enum Weekday: Int, Codable, CaseIterable, Identifiable, Sendable {
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7
    case sunday = 1

    public var id: Int { rawValue }

    public static var orderedMondayFirst: [Weekday] {
        [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]
    }

    public init(date: Date, calendar: Calendar) {
        self = Weekday(rawValue: calendar.component(.weekday, from: date)) ?? .monday
    }

    public var shortLocalizedName: String {
        switch self {
        case .monday: return "Mo"
        case .tuesday: return "Di"
        case .wednesday: return "Mi"
        case .thursday: return "Do"
        case .friday: return "Fr"
        case .saturday: return "Sa"
        case .sunday: return "So"
        }
    }

    public var isWeekend: Bool { self == .saturday || self == .sunday }

    public var previousDay: Weekday { shifted(by: -1) }
    public var nextDay: Weekday { shifted(by: 1) }

    private func shifted(by offset: Int) -> Weekday {
        let ordered = Self.orderedMondayFirst
        guard let idx = ordered.firstIndex(of: self) else { return .monday }
        return ordered[((idx + offset) % 7 + 7) % 7]
    }
}

/// Nur Beschriftung/Icon. Die Zeiten kommen immer aus der `DayScheduleRule`.
public enum FastingFocusStrategy: String, Codable, CaseIterable, Sendable {
    case skipDinner = "dinner_skip"
    case skipBreakfast = "breakfast_skip"
    case lateNightOvernight = "late_night_overnight"
    case custom = "custom"

    public var humanReadableTitle: String {
        switch self {
        case .skipDinner: return "Abendessen auslassen"
        case .skipBreakfast: return "Frühstück auslassen"
        case .lateNightOvernight: return "Übernacht-Fenster (bis Folgetag)"
        case .custom: return "Individuelles Zeitfenster"
        }
    }

    public var systemImageName: String {
        switch self {
        case .skipDinner: return "moon.stars.fill"
        case .skipBreakfast: return "cup.and.saucer.fill"
        case .lateNightOvernight: return "sparkles"
        case .custom: return "slider.horizontal.3"
        }
    }
}

// MARK: - 2. Tages-Regel

/// Essensfenster eines einzelnen Wochentags. Start und Ende sind frei wählbar (Minuten ab 00:00).
/// Ist das Ende <= Start, läuft das Fenster über Mitternacht in den Folgetag
/// (z. B. 17:00 → 02:00). Ende == Start bedeutet 24 h Essensfenster; wer kein
/// Fenster möchte, setzt `isEnabled = false`.
public struct DayScheduleRule: Codable, Hashable, Identifiable, Sendable {
    public var id: Weekday { weekday }
    public let weekday: Weekday
    public var isEnabled: Bool
    public var strategy: FastingFocusStrategy
    public var eatingStartMinutes: Int
    public var eatingEndMinutes: Int

    public init(
        weekday: Weekday,
        isEnabled: Bool = true,
        strategy: FastingFocusStrategy = .custom,
        eatingStartMinutes: Int,
        eatingEndMinutes: Int
    ) {
        self.weekday = weekday
        self.isEnabled = isEnabled
        self.strategy = strategy
        self.eatingStartMinutes = eatingStartMinutes
        self.eatingEndMinutes = eatingEndMinutes
    }

    /// Bequemer Initializer mit Uhrzeiten, z. B. `hour: 17` → `endHour: 2`.
    public init(
        weekday: Weekday,
        isEnabled: Bool = true,
        strategy: FastingFocusStrategy = .custom,
        startHour: Int, startMinute: Int = 0,
        endHour: Int, endMinute: Int = 0
    ) {
        self.init(
            weekday: weekday,
            isEnabled: isEnabled,
            strategy: strategy,
            eatingStartMinutes: startHour * 60 + startMinute,
            eatingEndMinutes: endHour * 60 + endMinute
        )
    }

    /// Auf 0…1439 begrenzt, damit fehlerhafte Eingaben/Altdaten nichts zerlegen.
    public var startMinutes: Int { min(max(eatingStartMinutes, 0), 1439) }
    public var endMinutes: Int { min(max(eatingEndMinutes, 0), 1439) }

    public var crossesMidnight: Bool { endMinutes <= startMinutes }

    public var eatingDurationMinutes: Int {
        crossesMidnight ? (1440 - startMinutes) + endMinutes : endMinutes - startMinutes
    }

    public var eatingHours: Int { Int((Double(eatingDurationMinutes) / 60).rounded()) }
}

// MARK: - 3. SwiftData-Modell

@Model
public final class WeeklyFastingPlan {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var isActive: Bool
    /// Immer genau 7 Regeln, je Wochentag eine (wird im init normalisiert).
    public var dayRules: [DayScheduleRule]
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        isActive: Bool = true,
        dayRules: [DayScheduleRule],
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.isActive = isActive
        self.dayRules = Self.normalized(dayRules)
        self.updatedAt = updatedAt
    }

    /// Stellt sicher: genau eine Regel pro Wochentag. Fehlende Tage werden deaktiviert ergänzt,
    /// Duplikate verworfen (erste gewinnt).
    private static func normalized(_ rules: [DayScheduleRule]) -> [DayScheduleRule] {
        Weekday.orderedMondayFirst.map { day in
            rules.first(where: { $0.weekday == day })
                ?? DayScheduleRule(weekday: day, isEnabled: false, eatingStartMinutes: 8 * 60, eatingEndMinutes: 14 * 60)
        }
    }

    /// Praxisbeispiel:
    /// - Mo–Fr: 08:00–14:00
    /// - Sa: 17:00 → So 02:00 (Übernacht)
    /// - So: 16:00–22:00
    public static func createWorkweek18_6Weekend14_10Plan() -> WeeklyFastingPlan {
        let rules: [DayScheduleRule] = Weekday.orderedMondayFirst.map { day in
            switch day {
            case .saturday:
                return DayScheduleRule(weekday: day, strategy: .lateNightOvernight,
                                       startHour: 17, endHour: 2)
            case .sunday:
                return DayScheduleRule(weekday: day, strategy: .skipBreakfast,
                                       startHour: 16, endHour: 22)
            default:
                return DayScheduleRule(weekday: day, strategy: .skipDinner,
                                       startHour: 8, endHour: 14)
            }
        }
        return WeeklyFastingPlan(name: "Werktags 08–14 · Sa 17–02 Uhr · So 16–22", dayRules: rules)
    }

    /// Regel für einen Wochentag. Crasht nie; liefert im Notfall eine deaktivierte Regel.
    public func rule(for weekday: Weekday) -> DayScheduleRule {
        dayRules.first(where: { $0.weekday == weekday })
            ?? DayScheduleRule(weekday: weekday, isEnabled: false, eatingStartMinutes: 8 * 60, eatingEndMinutes: 14 * 60)
    }

    /// Setzt/ersetzt die Regel eines Tages (z. B. aus dem Editor-UI) und aktualisiert `updatedAt`.
    public func setRule(_ rule: DayScheduleRule) {
        var copy = dayRules
        if let idx = copy.firstIndex(where: { $0.weekday == rule.weekday }) {
            copy[idx] = rule
        } else {
            copy.append(rule)
        }
        dayRules = Self.normalized(copy)
        updatedAt = .now
    }

    /// Echte Fastendauer in Minuten nach dem Essensfenster dieses Tages bis zum nächsten
    /// aktiven Fenster (kann Tage überspringen). `nil`, wenn kein Tag aktiv ist.
    /// Näherung ohne Sommerzeit-Korrektur; reicht für Anzeige-Badges.
    public func fastingMinutesAfterWindow(of weekday: Weekday) -> Int? {
        let rule = rule(for: weekday)
        guard rule.isEnabled else { return nil }
        let endAbs = rule.startMinutes + rule.eatingDurationMinutes
        var day = weekday
        for k in 1...7 {
            day = day.nextDay
            let next = self.rule(for: day)
            if next.isEnabled {
                return max(0, k * 1440 + next.startMinutes - endAbs)
            }
        }
        return nil
    }

    /// Badge "Fasten:Essen" mit der tatsächlichen Pause danach, z. B. Mo–Fr "18:6", Sa "14:9".
    public func protocolBadge(for weekday: Weekday) -> String {
        let rule = rule(for: weekday)
        guard let fasting = fastingMinutesAfterWindow(of: weekday) else { return "–" }
        return "\(Int((Double(fasting) / 60).rounded())):\(rule.eatingHours)"
    }
}

// MARK: - 4. Biologische Phasen & Snapshot

public enum MetabolicStage: String, Sendable {
    case anabolicEating = "Nährstoffaufnahme (Essensfenster)"
    case postAbsorptive = "Blutzucker-Stabilisierung (0–4h)"
    case glycogenolysis = "Blutzucker-Reset & Glykogen-Abbau (4–12h)"
    case ketosisOnset   = "Fettverbrennung & milde Ketose (12–16h)"
    case autophagyPulse = "Zellreinigung & Autophagie-Impuls (16h+)"
}

public struct ResolvedFastingSnapshot: Sendable {
    public enum Mode: Sendable {
        case fasting
        case eatingWindow
    }

    public let referenceDate: Date
    /// Kalendertag von `referenceDate`.
    public let currentWeekday: Weekday
    public let todayRule: DayScheduleRule
    public let tomorrowRule: DayScheduleRule
    /// Regel, die das aktuelle bzw. zuletzt beendete Essensfenster erzeugt hat
    /// (nachts um 01:15 also die Regel des Vortags).
    public let windowRule: DayScheduleRule
    public let mode: Mode
    public let windowStart: Date
    public let windowEnd: Date
    public let metabolicStage: MetabolicStage
    public let humanReadableHeadline: String
    public let humanReadableSubline: String

    public var totalDuration: TimeInterval { windowEnd.timeIntervalSince(windowStart) }
    public var elapsedDuration: TimeInterval { max(0, referenceDate.timeIntervalSince(windowStart)) }
    public var remainingDuration: TimeInterval { max(0, windowEnd.timeIntervalSince(referenceDate)) }

    public var progress: Double {
        guard totalDuration > 0 else { return 0 }
        return min(1.0, max(0.0, elapsedDuration / totalDuration))
    }
}

// MARK: - 5. Berechnungs-Engine

public final class FastingScheduleEngine {
    public var calendar: Calendar

    public init(calendar: Calendar = .autoupdatingCurrent) {
        self.calendar = calendar
    }

    private struct EatingInterval {
        var start: Date
        var end: Date
        var rule: DayScheduleRule
    }

    /// Liefert den exakten Fasten-/Essensstatus für `date`.
    /// `nil`, wenn der Plan keinen aktiven Tag enthält.
    public func resolveSnapshot(for date: Date, plan: WeeklyFastingPlan) -> ResolvedFastingSnapshot? {
        let intervals = eatingIntervals(around: date, plan: plan)
        guard !intervals.isEmpty else { return nil }

        let weekday = Weekday(date: date, calendar: calendar)
        let todayRule = plan.rule(for: weekday)
        let tomorrowRule = plan.rule(for: weekday.nextDay)

        // Essensfenster aktiv (inkl. Übernachtfenster des Vortags)
        if let active = intervals.first(where: { date >= $0.start && date < $0.end }) {
            let endText = formatTime(active.end)
            let subline: String
            if !calendar.isDate(active.end, inSameDayAs: date) {
                subline = "Dein Fenster läuft über Mitternacht bis \(weekdayName(active.end)) \(endText) Uhr."
            } else if active.start < calendar.startOfDay(for: date) {
                subline = "Dein Übernacht-Fenster endet heute um \(endText) Uhr."
            } else if let pause = plan.fastingMinutesAfterWindow(of: active.rule.weekday) {
                subline = "Genieße deine Mahlzeiten. Ab \(endText) Uhr startet eine \(Self.hoursText(minutes: pause))-Fastenpause."
            } else {
                subline = "Genieße deine Mahlzeiten."
            }
            return ResolvedFastingSnapshot(
                referenceDate: date,
                currentWeekday: weekday,
                todayRule: todayRule,
                tomorrowRule: tomorrowRule,
                windowRule: active.rule,
                mode: .eatingWindow,
                windowStart: active.start,
                windowEnd: active.end,
                metabolicStage: .anabolicEating,
                humanReadableHeadline: "Essensfenster geöffnet bis \(endText) Uhr (\(plan.protocolBadge(for: active.rule.weekday)))",
                humanReadableSubline: subline
            )
        }

        // Fasten: zwischen letztem Ende und nächstem Start
        guard let previous = intervals.last(where: { $0.end <= date }),
              let next = intervals.first(where: { $0.start > date })
        else { return nil }

        let elapsedHours = date.timeIntervalSince(previous.end) / 3600.0
        let nextText = "\(weekdayName(next.start)) \(formatTime(next.start)) Uhr"
        let remaining = next.start.timeIntervalSince(date)
        return ResolvedFastingSnapshot(
            referenceDate: date,
            currentWeekday: weekday,
            todayRule: todayRule,
            tomorrowRule: tomorrowRule,
            windowRule: previous.rule,
            mode: .fasting,
            windowStart: previous.end,
            windowEnd: next.start,
            metabolicStage: Self.resolveStage(elapsedHours: elapsedHours),
            humanReadableHeadline: "Fastenphase seit \(formatTime(previous.end)) Uhr aktiv",
            humanReadableSubline: "Nächstes Essensfenster: \(nextText) (in \(Self.hoursText(minutes: Int(remaining / 60))))."
        )
    }

    // MARK: Intervall-Erzeugung

    /// Konkrete Essensfenster von 2 Tagen vor bis 8 Tage nach `date`, sortiert und überlappungsfrei.
    private func eatingIntervals(around date: Date, plan: WeeklyFastingPlan) -> [EatingInterval] {
        let startOfToday = calendar.startOfDay(for: date)
        var result: [EatingInterval] = []

        for offset in -2...8 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: startOfToday) else { continue }
            let rule = plan.rule(for: Weekday(date: day, calendar: calendar))
            guard rule.isEnabled else { continue }

            let endDay = rule.crossesMidnight
                ? (calendar.date(byAdding: .day, value: 1, to: day) ?? day)
                : day
            let start = time(minutes: rule.startMinutes, on: day)
            let end = time(minutes: rule.endMinutes, on: endDay)
            guard end > start else { continue }
            result.append(EatingInterval(start: start, end: end, rule: rule))
        }

        result.sort { $0.start < $1.start }

        // Überlappende/angrenzende Fenster verschmelzen (z. B. Sa bis 18:00, So ab 16:00)
        var merged: [EatingInterval] = []
        for interval in result {
            if var last = merged.last, interval.start <= last.end {
                last.end = max(last.end, interval.end)
                merged[merged.count - 1] = last
            } else {
                merged.append(interval)
            }
        }
        return merged
    }

    /// Uhrzeit auf einem Kalendertag, sommerzeitsicher (nicht „Minuten addieren“).
    private func time(minutes: Int, on day: Date) -> Date {
        calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: day) ?? day
    }

    // MARK: Hilfsfunktionen

    private static func resolveStage(elapsedHours: Double) -> MetabolicStage {
        switch elapsedHours {
        case ..<4: return .postAbsorptive
        case 4..<12: return .glycogenolysis
        case 12..<16: return .ketosisOnset
        default: return .autophagyPulse
        }
    }

    private func formatTime(_ date: Date) -> String {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }

    private func weekdayName(_ date: Date) -> String {
        Weekday(date: date, calendar: calendar).shortLocalizedName
    }

    private static func hoursText(minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        return m == 0 ? "\(h) h" : "\(h) h \(m) min"
    }
}

// MARK: - 6. Reporting

public enum ReportingPeriod: String, CaseIterable, Sendable {
    case week = "Woche"
    case month = "Monat"
    case year = "Jahr"
}

public struct FastingReportSummary: Sendable {
    public let period: ReportingPeriod
    public let totalFastedHours: Double
    public let targetFastedHours: Double
    public let deepKetosisHours: Double
    public let currentStreakDays: Int
    public let remainingStreakJokers: Int
    public let latestScaleWeightKg: Double
    public let smoothedTrendWeightKg: Double

    public init(
        period: ReportingPeriod,
        totalFastedHours: Double,
        targetFastedHours: Double,
        deepKetosisHours: Double,
        currentStreakDays: Int,
        remainingStreakJokers: Int,
        latestScaleWeightKg: Double,
        smoothedTrendWeightKg: Double
    ) {
        self.period = period
        self.totalFastedHours = totalFastedHours
        self.targetFastedHours = targetFastedHours
        self.deepKetosisHours = deepKetosisHours
        self.currentStreakDays = currentStreakDays
        self.remainingStreakJokers = remainingStreakJokers
        self.latestScaleWeightKg = latestScaleWeightKg
        self.smoothedTrendWeightKg = smoothedTrendWeightKg
    }

    /// 1 Fastenstunde = 1 Meter Höhe (Eiffelturm 330 m).
    public var eiffelTowerEquivalentRatio: Double { totalFastedHours / 330.0 }
}
