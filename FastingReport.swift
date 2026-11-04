//
//  FastingReport.swift
//  FastFlow
//
//  Auswertung für Woche / Monat / Jahr aus dem Verlauf (Ist vs. Soll),
//  plus Balken pro Tag bzw. Monat für Diagramme.
//

import Foundation

public enum ReportingPeriod: String, CaseIterable, Identifiable, Sendable {
    case week = "Woche"
    case month = "Monat"
    case year = "Jahr"

    public var id: String { rawValue }

    var calendarComponent: Calendar.Component {
        switch self {
        case .week: return .weekOfYear
        case .month: return .month
        case .year: return .year
        }
    }

    /// Balkenbreite im Diagramm: Tage für Woche/Monat, Monate für das Jahr.
    public var bucketComponent: Calendar.Component {
        self == .year ? .month : .day
    }
}

public struct FastingBucket: Identifiable, Hashable, Sendable {
    public let start: Date
    public let fastedHours: Double
    public let targetHours: Double
    public var id: Date { start }
}

public struct FastingReportSummary: Equatable, Sendable {
    public let period: ReportingPeriod
    public let interval: DateInterval
    public let totalFastedHours: Double
    public let targetFastedHours: Double
    /// Stunden jenseits von 16 h Fasten (Summe über alle Phasen).
    public let longFastHours: Double
    public let completedSessions: Int
    public let goalReachedSessions: Int
    public let currentStreakDays: Int
    public let remainingStreakJokers: Int
    public let latestWeightKg: Double?
    public let trendWeightKg: Double?

    /// Anteil der Phasen mit erreichtem Ziel (0…1).
    public var goalRate: Double {
        completedSessions == 0 ? 0 : Double(goalReachedSessions) / Double(completedSessions)
    }

    /// 1 Fastenstunde = 1 Meter Höhe (Eiffelturm 330 m).
    public var eiffelTowerEquivalentRatio: Double { totalFastedHours / 330.0 }
}

public enum FastingReportBuilder {
    public static func interval(for period: ReportingPeriod, containing date: Date, calendar: Calendar) -> DateInterval {
        calendar.dateInterval(of: period.calendarComponent, for: date) ?? DateInterval(start: date, duration: 0)
    }

    /// Zusammenfassung des Zeitraums, der `now` enthält. Eine Phase zählt zu dem Zeitraum,
    /// in dem sie endet. Die Serie wird über den gesamten Verlauf berechnet.
    public static func summary(
        period: ReportingPeriod,
        sessions: [FastingSessionSummary],
        now: Date,
        calendar: Calendar,
        jokers: Int,
        weights: [WeightSample] = []
    ) -> FastingReportSummary {
        let range = interval(for: period, containing: now, calendar: calendar)
        let inPeriod = sessions.filter { $0.plannedEnd >= range.start && $0.plannedEnd < range.end && $0.plannedEnd <= now }
        let fasted = inPeriod.reduce(0) { $0 + $1.fastedMinutes }
        let target = inPeriod.reduce(0) { $0 + $1.targetMinutes }
        let long = inPeriod.reduce(0) { $0 + max(0, $1.fastedMinutes - 16 * 60) }
        let streak = FastingStreakCalculator.streak(sessions: sessions, today: now, calendar: calendar, jokers: jokers)
        let trend = WeightTrend.smoothed(weights, calendar: calendar)

        return FastingReportSummary(
            period: period,
            interval: range,
            totalFastedHours: Double(fasted) / 60,
            targetFastedHours: Double(target) / 60,
            longFastHours: Double(long) / 60,
            completedSessions: inPeriod.count,
            goalReachedSessions: inPeriod.filter(\.isGoalReached).count,
            currentStreakDays: streak.currentDays,
            remainingStreakJokers: streak.jokersRemaining,
            latestWeightKg: trend.last?.kg,
            trendWeightKg: trend.last?.trendKg
        )
    }

    /// Ein Balken pro Tag (Woche/Monat) bzw. pro Monat (Jahr), lückenlos mit Nullen aufgefüllt.
    public static func buckets(
        period: ReportingPeriod,
        sessions: [FastingSessionSummary],
        now: Date,
        calendar: Calendar
    ) -> [FastingBucket] {
        let range = interval(for: period, containing: now, calendar: calendar)
        let component = period.bucketComponent

        var fasted: [Date: Int] = [:]
        var target: [Date: Int] = [:]
        for session in sessions where session.plannedEnd >= range.start && session.plannedEnd < range.end {
            guard let key = calendar.dateInterval(of: component, for: session.plannedEnd)?.start else { continue }
            fasted[key, default: 0] += session.fastedMinutes
            target[key, default: 0] += session.targetMinutes
        }

        var result: [FastingBucket] = []
        var cursor = range.start
        while cursor < range.end {
            result.append(FastingBucket(
                start: cursor,
                fastedHours: Double(fasted[cursor] ?? 0) / 60,
                targetHours: Double(target[cursor] ?? 0) / 60
            ))
            guard let next = calendar.date(byAdding: component, value: 1, to: cursor) else { break }
            cursor = next
        }
        return result
    }
}
