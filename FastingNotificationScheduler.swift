//
//  FastingNotificationScheduler.swift
//  FastFlow
//
//  Lokale Erinnerungen: „Essensfenster öffnet“ und „Essensfenster schließt in X min“.
//  Die Planung ist eine reine Funktion (testbar), das Eintragen in
//  UNUserNotificationCenter passiert im @MainActor-Scheduler.
//

import Foundation
import UserNotifications

public struct FastingNotificationSettings: Codable, Equatable, Sendable {
    public var isEnabled: Bool
    public var remindWhenWindowOpens: Bool
    public var remindBeforeWindowEnds: Bool
    /// Vorlaufzeit vor dem Fensterende in Minuten.
    public var leadTimeMinutes: Int

    public init(
        isEnabled: Bool = false,
        remindWhenWindowOpens: Bool = true,
        remindBeforeWindowEnds: Bool = true,
        leadTimeMinutes: Int = 30
    ) {
        self.isEnabled = isEnabled
        self.remindWhenWindowOpens = remindWhenWindowOpens
        self.remindBeforeWindowEnds = remindBeforeWindowEnds
        self.leadTimeMinutes = leadTimeMinutes
    }
}

public struct PlannedFastingNotification: Equatable, Sendable {
    public let identifier: String
    public let fireDate: Date
    public let title: String
    public let body: String
}

@MainActor
public final class FastingNotificationScheduler {
    /// iOS hält max. 64 ausstehende lokale Notifications pro App. Etwas Puffer lassen.
    public nonisolated static let maxPending = 60
    nonisolated static let identifierPrefix = "fastflow."

    private let center: UNUserNotificationCenter
    private let engine: FastingScheduleEngine

    public init(center: UNUserNotificationCenter = .current(), engine: FastingScheduleEngine = FastingScheduleEngine()) {
        self.center = center
        self.engine = engine
    }

    /// Fragt die Berechtigung an. `false`, wenn abgelehnt oder Fehler.
    public func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    /// Entfernt alle FastFlow-Erinnerungen und plant sie für die nächsten `days` Tage neu.
    /// Bei jeder Planänderung und beim App-Start aufrufen.
    public func reschedule(plan: WeeklyFastingPlan, settings: FastingNotificationSettings,
                           now: Date = .now, days: Int = 14) async {
        await removeAll()
        guard settings.isEnabled else { return }

        let windows = engine.upcomingEatingWindows(after: now, plan: plan, days: days)
        let planned = Self.plannedNotifications(windows: windows, settings: settings, now: now)

        for item in planned {
            let content = UNMutableNotificationContent()
            content.title = item.title
            content.body = item.body
            content.sound = .default
            let components = engine.calendar.dateComponents(
                [.year, .month, .day, .hour, .minute], from: item.fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: item.identifier, content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    public func removeAll() async {
        let pending = await center.pendingNotificationRequests()
        let ids = pending.map(\.identifier).filter { $0.hasPrefix(Self.identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    /// Reine Planungsfunktion: welche Erinnerungen wann. Sortiert, ohne Vergangenes,
    /// begrenzt auf `maxPending`.
    public nonisolated static func plannedNotifications(
        windows: [DateInterval],
        settings: FastingNotificationSettings,
        now: Date
    ) -> [PlannedFastingNotification] {
        guard settings.isEnabled else { return [] }
        let lead = max(1, settings.leadTimeMinutes)
        var result: [PlannedFastingNotification] = []

        for window in windows {
            let key = Int(window.start.timeIntervalSince1970)
            if settings.remindWhenWindowOpens, window.start > now {
                result.append(PlannedFastingNotification(
                    identifier: "\(identifierPrefix)open.\(key)",
                    fireDate: window.start,
                    title: "Essensfenster ist offen",
                    body: "Dein Fenster läuft \(durationText(minutes: Int(window.duration / 60)))."
                ))
            }
            let warnDate = window.end.addingTimeInterval(TimeInterval(-lead * 60))
            if settings.remindBeforeWindowEnds, warnDate > now, warnDate > window.start {
                result.append(PlannedFastingNotification(
                    identifier: "\(identifierPrefix)close.\(key)",
                    fireDate: warnDate,
                    title: "Essensfenster schließt bald",
                    body: "Noch \(durationText(minutes: lead)), dann beginnt deine Fastenphase."
                ))
            }
        }

        return Array(result.sorted { $0.fireDate < $1.fireDate }.prefix(maxPending))
    }

    nonisolated static func durationText(minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        if h == 0 { return "\(m) min" }
        return m == 0 ? "\(h) h" : "\(h) h \(m) min"
    }
}
