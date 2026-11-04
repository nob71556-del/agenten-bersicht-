//
//  FastingDashboardView.swift
//  FastFlow
//
//  Heute-Ansicht: aktueller Status (Fasten/Essen) mit Fortschrittsring und
//  Wochenband Mo–So inkl. Übernachtfenstern. Aktualisiert sich jede Minute.
//

import SwiftUI
import SwiftData

public struct FastingDashboardView: View {
    private let plan: WeeklyFastingPlan
    private let engine: FastingScheduleEngine

    public init(plan: WeeklyFastingPlan, engine: FastingScheduleEngine = FastingScheduleEngine()) {
        self.plan = plan
        self.engine = engine
    }

    public var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            ScrollView {
                VStack(spacing: 20) {
                    if let snapshot = engine.resolveSnapshot(for: context.date, plan: plan) {
                        FastingStatusCard(snapshot: snapshot, calendar: engine.calendar)
                    } else {
                        ContentUnavailableView(
                            "Kein aktiver Tag",
                            systemImage: "calendar.badge.exclamationmark",
                            description: Text("Aktiviere im Fastenplan mindestens einen Wochentag.")
                        )
                    }
                    WeekRibbonView(now: context.date, plan: plan, engine: engine)
                }
                .padding()
            }
        }
        .navigationTitle("Heute")
    }
}

// MARK: - Statuskarte

struct FastingStatusCard: View {
    let snapshot: ResolvedFastingSnapshot
    let calendar: Calendar

    private var isEating: Bool { snapshot.mode == .eatingWindow }
    private var tint: Color { isEating ? .teal : .indigo }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(isEating ? "Essensfenster" : "Fasten",
                  systemImage: isEating ? "fork.knife" : "moon.zzz")
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(tint)

            HStack(spacing: 16) {
                ProgressRing(progress: snapshot.progress, tint: tint)
                    .frame(width: 86, height: 86)
                VStack(alignment: .leading, spacing: 6) {
                    Text(snapshot.humanReadableHeadline)
                        .font(.title3.bold())
                    Text(snapshot.humanReadableSubline)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(alignment: .top) {
                stat("Vergangen", Self.durationText(snapshot.elapsedDuration))
                Spacer()
                stat("Verbleibend", Self.durationText(snapshot.remainingDuration))
                Spacer()
                stat("Fenster", "\(dayTime(snapshot.windowStart)) → \(dayTime(snapshot.windowEnd))")
            }

            if !isEating {
                VStack(alignment: .leading, spacing: 2) {
                    Text(snapshot.metabolicStage.rawValue)
                        .font(.subheadline.weight(.medium))
                    Text(MetabolicStage.disclaimer)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 16))
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption2).textCase(.uppercase).foregroundStyle(.secondary)
            Text(value).font(.subheadline.monospacedDigit().weight(.medium))
        }
    }

    private func dayTime(_ date: Date) -> String {
        let day = Weekday(date: date, calendar: calendar).shortLocalizedName
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return day + " " + String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }

    static func durationText(_ interval: TimeInterval) -> String {
        let minutes = Int(interval / 60)
        let h = minutes / 60, m = minutes % 60
        if h == 0 { return "\(m) min" }
        return m == 0 ? "\(h) h" : "\(h) h \(m) min"
    }
}

struct ProgressRing: View {
    let progress: Double
    let tint: Color

    var body: some View {
        ZStack {
            Circle().stroke(tint.opacity(0.2), lineWidth: 10)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(tint, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int((progress * 100).rounded())) %")
                .font(.headline.monospacedDigit())
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Fortschritt")
        .accessibilityValue("\(Int((progress * 100).rounded())) Prozent")
    }
}

// MARK: - Wochenband

struct WeekRibbonView: View {
    let now: Date
    let plan: WeeklyFastingPlan
    let engine: FastingScheduleEngine

    var body: some View {
        let calendar = engine.calendar
        let today = calendar.startOfDay(for: now)
        let todayIndex = Weekday.orderedMondayFirst.firstIndex(of: Weekday(date: now, calendar: calendar)) ?? 0

        VStack(alignment: .leading, spacing: 8) {
            Text("Woche").font(.headline)

            ForEach(0..<7, id: \.self) { i in
                let day = calendar.date(byAdding: .day, value: i - todayIndex, to: today) ?? today
                let isToday = calendar.isDate(day, inSameDayAs: now)
                HStack(spacing: 8) {
                    Text(Weekday(date: day, calendar: calendar).shortLocalizedName)
                        .font(.caption.monospaced())
                        .fontWeight(isToday ? .bold : .regular)
                        .frame(width: 24, alignment: .leading)
                    dayTrack(day: day, isToday: isToday, calendar: calendar)
                        .frame(height: 20)
                }
            }

            HStack {
                ForEach(["0", "6", "12", "18", "24"], id: \.self) { label in
                    Text(label)
                    if label != "24" { Spacer() }
                }
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.secondary)
            .padding(.leading, 32)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 16))
    }

    private func dayTrack(day: Date, isToday: Bool, calendar: Calendar) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(Color.indigo.opacity(0.15))
                ForEach(engine.eatingSegments(on: day, plan: plan), id: \.self) { segment in
                    Rectangle()
                        .fill(Color.teal.opacity(segment.continuesFromPreviousDay ? 0.6 : 1))
                        .frame(width: geo.size.width * (segment.endFraction - segment.startFraction))
                        .offset(x: geo.size.width * segment.startFraction)
                }
                if isToday, let dayEnd = calendar.date(byAdding: .day, value: 1, to: day) {
                    let fraction = now.timeIntervalSince(day) / dayEnd.timeIntervalSince(day)
                    Rectangle()
                        .fill(Color.orange)
                        .frame(width: 2)
                        .offset(x: geo.size.width * fraction - 1)
                }
            }
            .clipShape(.rect(cornerRadius: 4))
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Preview

#Preview {
    let container = try! ModelContainer(
        for: WeeklyFastingPlan.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let plan = WeeklyFastingPlan.createWorkweek18_6Weekend14_10Plan()
    container.mainContext.insert(plan)
    return NavigationStack {
        FastingDashboardView(plan: plan)
    }
    .modelContainer(container)
}
