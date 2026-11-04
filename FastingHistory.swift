//
//  FastingHistory.swift
//  FastFlow
//
//  Verlauf abgeschlossener Fastenphasen und Streak-Berechnung.
//  Fastenphasen werden automatisch aus dem Plan übernommen, sobald sie vorbei sind.
//  Wer früher gegessen hat, setzt `actualEnd` (dann zählt das Ziel ggf. als verfehlt).
//

import Foundation
import SwiftData

// MARK: - Persistenz

@Model
public final class FastingSessionRecord {
    @Attribute(.unique) public var id: UUID
    /// Geplanter Beginn (Ende des vorherigen Essensfensters).
    public var start: Date
    /// Geplantes Ende (Beginn des nächsten Essensfensters).
    public var plannedEnd: Date
    /// Tatsächliches Ende, falls früher gegessen wurde. `nil` = wie geplant.
    public var actualEnd: Date?

    public init(id: UUID = UUID(), start: Date, plannedEnd: Date, actualEnd: Date? = nil) {
        self.id = id
        self.start = start
        self.plannedEnd = plannedEnd
        self.actualEnd = actualEnd
    }

    public var summary: FastingSessionSummary {
        FastingSessionSummary(start: start, plannedEnd: plannedEnd, actualEnd: actualEnd)
    }
}

/// Wertkopie eines Eintrags für reine, testbare Berechnungen.
public struct FastingSessionSummary: Hashable, Sendable {
    public let start: Date
    public let plannedEnd: Date
    public let actualEnd: Date?

    public init(start: Date, plannedEnd: Date, actualEnd: Date? = nil) {
        self.start = start
        self.plannedEnd = plannedEnd
        self.actualEnd = actualEnd
    }

    public var end: Date { min(actualEnd ?? plannedEnd, plannedEnd) }
    public var targetMinutes: Int { Int(plannedEnd.timeIntervalSince(start) / 60) }
    public var fastedMinutes: Int { max(0, Int(end.timeIntervalSince(start) / 60)) }
    public var isGoalReached: Bool { fastedMinutes >= targetMinutes }
}

// MARK: - Automatisches Erfassen

@MainActor
public enum FastingHistoryRecorder {
    /// Übernimmt alle seit dem letzten Eintrag beendeten Fastenphasen des Plans
    /// (höchstens `lookbackDays` zurück). Doppelte Einträge werden vermieden.
    public static func recordCompletedFasts(
        context: ModelContext,
        plan: WeeklyFastingPlan,
        engine: FastingScheduleEngine = FastingScheduleEngine(),
        now: Date = .now,
        lookbackDays: Int = 7
    ) {
        var latest = FetchDescriptor<FastingSessionRecord>(sortBy: [SortDescriptor(\.plannedEnd, order: .reverse)])
        latest.fetchLimit = 1
        let lastEnd = (try? context.fetch(latest))?.first?.plannedEnd

        let lookback = engine.calendar.date(byAdding: .day, value: -lookbackDays, to: now) ?? now
        let from = max(lastEnd ?? lookback, lookback)

        let windows = engine.fastingWindows(between: from, and: now, plan: plan)
            .filter { window in lastEnd.map { window.start >= $0 } ?? true }

        for window in windows {
            context.insert(FastingSessionRecord(start: window.start, plannedEnd: window.end))
        }
        if !windows.isEmpty { try? context.save() }
    }
}

// MARK: - Streak

public struct FastingStreak: Equatable, Sendable {
    public let currentDays: Int
    public let jokersUsed: Int
    public let jokersRemaining: Int
}

public enum FastingStreakCalculator {
    /// Zählt rückwärts ab heute (bzw. gestern, wenn heute noch nichts beendet ist) die Tage in Folge,
    /// an denen alle beendeten Fastenphasen ihr Ziel erreicht haben. Ein verfehlter Tag verbraucht
    /// einen Joker; sind keine mehr übrig, endet die Serie. Tage ohne Fastenphase (z. B. deaktivierte
    /// Wochentage) sind neutral: sie unterbrechen nicht und zählen nicht mit.
    public static func streak(
        sessions: [FastingSessionSummary],
        today: Date,
        calendar: Calendar,
        jokers: Int
    ) -> FastingStreak {
        let byDay = Dictionary(grouping: sessions) { calendar.startOfDay(for: $0.plannedEnd) }
        guard let earliest = byDay.keys.min() else {
            return FastingStreak(currentDays: 0, jokersUsed: 0, jokersRemaining: jokers)
        }

        var day = calendar.startOfDay(for: today)
        if byDay[day] == nil, let yesterday = calendar.date(byAdding: .day, value: -1, to: day) {
            day = yesterday
        }

        var count = 0
        var used = 0
        while day >= earliest {
            if let entries = byDay[day] {
                if entries.allSatisfy(\.isGoalReached) {
                    count += 1
                } else if used < jokers {
                    used += 1
                    count += 1
                } else {
                    break
                }
            }
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return FastingStreak(currentDays: count, jokersUsed: used, jokersRemaining: max(0, jokers - used))
    }
}
