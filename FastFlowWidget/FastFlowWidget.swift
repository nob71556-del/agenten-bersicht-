//
//  FastFlowWidget.swift
//  FastFlowWidget (Widget-Extension-Target)
//
//  Home- und Sperrbildschirm-Widget: Fasten/Essen, Live-Countdown, Fortschritt.
//  Benötigt im Widget-Target zusätzlich: FastingScheduleModels.swift, SharedPlanStore.swift.
//

import WidgetKit
import SwiftUI

struct FastingEntry: TimelineEntry {
    let date: Date
    let snapshot: ResolvedFastingSnapshot?
}

struct FastingTimelineProvider: TimelineProvider {
    private var schedule: WeeklySchedule {
        SharedPlanStore.load() ?? WeeklySchedule(rules: WeeklyFastingPlan.workweekExampleRules())
    }

    func placeholder(in context: Context) -> FastingEntry {
        entry(at: .now, schedule: WeeklySchedule(rules: WeeklyFastingPlan.workweekExampleRules()))
    }

    func getSnapshot(in context: Context, completion: @escaping (FastingEntry) -> Void) {
        completion(entry(at: .now, schedule: schedule))
    }

    /// Einträge alle 15 Minuten für 6 Stunden, plus genau an jedem Fensterwechsel,
    /// damit Fasten/Essen pünktlich umspringt. Countdown und Fortschritt laufen live.
    func getTimeline(in context: Context, completion: @escaping (Timeline<FastingEntry>) -> Void) {
        let schedule = schedule
        let now = Date.now
        let horizon = now.addingTimeInterval(6 * 3600)

        var dates = (0..<24).map { now.addingTimeInterval(Double($0) * 15 * 60) }
        let windows = FastingScheduleEngine().upcomingEatingWindows(after: now, plan: schedule, days: 2)
        dates += windows.flatMap { [$0.start, $0.end] }.filter { $0 > now && $0 < horizon }

        let entries = Set(dates).sorted().map { entry(at: $0, schedule: schedule) }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func entry(at date: Date, schedule: WeeklySchedule) -> FastingEntry {
        FastingEntry(date: date, snapshot: FastingScheduleEngine().resolveSnapshot(for: date, plan: schedule))
    }
}

struct FastingWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: FastingEntry

    var body: some View {
        if let s = entry.snapshot {
            let isEating = s.mode == .eatingWindow
            let title = isEating ? "Essen" : "Fasten"
            let icon = isEating ? "fork.knife" : "moon.zzz"
            let tint: Color = isEating ? .teal : .indigo
            let range = s.windowStart...max(s.windowEnd, s.windowStart)

            switch family {
            case .accessoryCircular:
                ProgressView(timerInterval: range, countsDown: false) {
                    Image(systemName: icon)
                } currentValueLabel: {
                    Image(systemName: icon)
                }
                .progressViewStyle(.circular)

            case .accessoryRectangular:
                VStack(alignment: .leading, spacing: 2) {
                    Label(title, systemImage: icon).font(.headline)
                    Text(timerInterval: range, countsDown: true).monospacedDigit()
                    Text("bis \(Self.time(s.windowEnd))").font(.caption)
                }

            default:
                VStack(alignment: .leading, spacing: 6) {
                    Label(title, systemImage: icon)
                        .font(.caption.bold())
                        .textCase(.uppercase)
                        .foregroundStyle(tint)
                    Text(timerInterval: range, countsDown: true)
                        .font(.title2.bold().monospacedDigit())
                    ProgressView(timerInterval: range, countsDown: false)
                        .tint(tint)
                        .labelsHidden()
                    Text("bis \(Self.time(s.windowEnd)) Uhr")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            Text("Kein aktiver Tag im Plan").font(.caption)
        }
    }

    private static func time(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }
}

struct FastFlowStatusWidget: Widget {
    let kind = "FastFlowStatus"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FastingTimelineProvider()) { entry in
            FastingWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Fastenstatus")
        .description("Zeigt, ob du gerade fastest oder isst, mit Restzeit.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}

@main
struct FastFlowWidgetBundle: WidgetBundle {
    var body: some Widget {
        FastFlowStatusWidget()
    }
}
