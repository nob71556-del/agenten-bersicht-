//
//  FastingPlanValidator.swift
//  FastFlow
//
//  Prüft einen Wochenplan auf typische Eingabefehler und zeigt verständliche Hinweise
//  im Editor an (z. B. Fenster überlappen, 24-h-Fenster, sehr kurze Pause).
//

import Foundation

public struct FastingPlanIssue: Identifiable, Hashable, Sendable {
    public enum Severity: Int, Comparable, Sendable {
        case info, warning

        public static func < (lhs: Severity, rhs: Severity) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    public let weekday: Weekday?
    public let severity: Severity
    public let message: String

    public var id: String { "\(weekday?.rawValue ?? 0)-\(message)" }
}

public enum FastingPlanValidator {
    /// Fastenpause unter diesem Wert wird als Hinweis gemeldet (in Minuten).
    public static let shortFastingThreshold = 12 * 60
    /// Essensfenster über diesem Wert wird als Hinweis gemeldet (in Minuten).
    public static let longEatingThreshold = 12 * 60

    public static func issues(for plan: some FastingScheduleSource) -> [FastingPlanIssue] {
        let days = Weekday.orderedMondayFirst
        let enabled = days.filter { plan.rule(for: $0).isEnabled }
        guard !enabled.isEmpty else {
            return [FastingPlanIssue(weekday: nil, severity: .warning,
                                     message: "Kein Tag aktiv. Aktiviere mindestens einen Wochentag.")]
        }

        var result: [FastingPlanIssue] = []
        for day in enabled {
            let rule = plan.rule(for: day)
            if rule.startMinutes == rule.endMinutes {
                result.append(.init(weekday: day, severity: .warning,
                                    message: "\(day.fullName): Start und Ende sind gleich. Das ergibt 24 Stunden Essen."))
                continue
            }
            if rule.eatingDurationMinutes > longEatingThreshold {
                result.append(.init(weekday: day, severity: .info,
                                    message: "\(day.fullName): Essensfenster länger als 12 Stunden."))
            }
            if let pause = plan.fastingMinutesAfterWindow(of: day) {
                let next = nextEnabled(after: day, in: plan)
                if pause == 0 {
                    result.append(.init(weekday: day, severity: .warning,
                                        message: "\(day.fullName): Fenster reicht bis in das Fenster von \(next?.fullName ?? "morgen"). Beide werden zu einem Fenster zusammengelegt."))
                } else if pause < shortFastingThreshold {
                    let h = pause / 60, m = pause % 60
                    let text = m == 0 ? "\(h) h" : "\(h) h \(m) min"
                    result.append(.init(weekday: day, severity: .info,
                                        message: "\(day.fullName): Nur \(text) Pause bis \(next?.fullName ?? "zum nächsten Fenster")."))
                }
            }
        }
        // Warnungen zuerst, innerhalb gleicher Stufe in Wochentags-Reihenfolge (Mo–So).
        return result.sorted { lhs, rhs in
            if lhs.severity != rhs.severity { return lhs.severity > rhs.severity }
            return sortIndex(lhs.weekday) < sortIndex(rhs.weekday)
        }
    }

    private static func nextEnabled(after day: Weekday, in plan: some FastingScheduleSource) -> Weekday? {
        var d = day
        for _ in 0..<7 {
            d = d.nextDay
            if plan.rule(for: d).isEnabled { return d }
        }
        return nil
    }

    private static func sortIndex(_ day: Weekday?) -> Int {
        day.flatMap { Weekday.orderedMondayFirst.firstIndex(of: $0) } ?? -1
    }
}
