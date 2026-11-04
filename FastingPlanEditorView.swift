//
//  FastingPlanEditorView.swift
//  FastFlow
//
//  Editor für die 7 Tagesregeln eines WeeklyFastingPlan:
//  pro Tag an/aus, Start- und Endzeit frei wählbar, Fenster über Mitternacht erlaubt.
//

import SwiftUI
import SwiftData

public struct FastingPlanEditorView: View {
    @Bindable private var plan: WeeklyFastingPlan

    public init(plan: WeeklyFastingPlan) {
        self.plan = plan
    }

    public var body: some View {
        Form {
            Section("Name") {
                TextField("Planname", text: $plan.name)
            }

            Section {
                ForEach(Weekday.orderedMondayFirst) { day in
                    DayRuleRow(
                        rule: binding(for: day),
                        badge: plan.protocolBadge(for: day),
                        fastingAfterMinutes: plan.fastingMinutesAfterWindow(of: day)
                    )
                }
            } header: {
                Text("Essensfenster pro Tag")
            } footer: {
                Text("Liegt das Ende vor dem Start, läuft das Fenster über Mitternacht in den Folgetag (z. B. 17:00 bis 02:00). Das Badge zeigt Fasten:Essen mit der echten Pause bis zum nächsten aktiven Fenster.")
            }

            Section("Vorlagen") {
                Button("Beispielplan (Mo–Fr 08–14, Sa 17–02, So 16–22)") {
                    plan.replaceRules(WeeklyFastingPlan.workweekExampleRules())
                }
                Button("Alle Tage 12–20 Uhr") {
                    plan.replaceRules(Weekday.orderedMondayFirst.map {
                        DayScheduleRule(weekday: $0, startHour: 12, endHour: 20)
                    })
                }
            }
        }
        .navigationTitle("Fastenplan")
    }

    private func binding(for day: Weekday) -> Binding<DayScheduleRule> {
        Binding(
            get: { plan.rule(for: day) },
            set: { plan.setRule($0) }
        )
    }
}

// MARK: - Zeile für einen Wochentag

struct DayRuleRow: View {
    @Binding var rule: DayScheduleRule
    let badge: String
    let fastingAfterMinutes: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $rule.isEnabled) {
                HStack(spacing: 8) {
                    Text(rule.weekday.fullName).font(.headline)
                    if rule.isEnabled {
                        Text(badge)
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.tint.opacity(0.15), in: .rect(cornerRadius: 4))
                    }
                }
            }

            if rule.isEnabled {
                DatePicker("Start", selection: timeBinding(\.eatingStartMinutes), displayedComponents: .hourAndMinute)
                DatePicker("Ende", selection: timeBinding(\.eatingEndMinutes), displayedComponents: .hourAndMinute)
                infoText
            } else {
                Text("Kein Essensfenster, nur Fasten.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var infoText: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Fenster \(Self.durationText(rule.eatingDurationMinutes))")
            if rule.startMinutes == rule.endMinutes {
                Label("Start = Ende ergibt ein 24-h-Essensfenster.", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            } else if rule.crossesMidnight {
                Label("Über Mitternacht bis \(rule.weekday.nextDay.shortLocalizedName) \(Self.clock(rule.endMinutes))",
                      systemImage: "moon.stars")
                    .foregroundStyle(.tint)
            }
            if let fasting = fastingAfterMinutes {
                Text("Danach \(Self.durationText(fasting)) Pause")
            }
        }
        .font(.footnote.monospacedDigit())
        .foregroundStyle(.secondary)
    }

    // MARK: Minuten <-> Date für DatePicker

    /// Fester Referenztag ohne Sommerzeitwechsel; nur Stunde/Minute zählen.
    private static let referenceDay: Date = {
        Calendar.current.date(from: DateComponents(year: 2001, month: 1, day: 1)) ?? .distantPast
    }()

    private func timeBinding(_ keyPath: WritableKeyPath<DayScheduleRule, Int>) -> Binding<Date> {
        Binding(
            get: {
                let minutes = min(max(rule[keyPath: keyPath], 0), 1439)
                return Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60,
                                             second: 0, of: Self.referenceDay) ?? Self.referenceDay
            },
            set: { newDate in
                let c = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                rule[keyPath: keyPath] = (c.hour ?? 0) * 60 + (c.minute ?? 0)
            }
        )
    }

    private static func clock(_ minutes: Int) -> String {
        String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }

    private static func durationText(_ minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        return m == 0 ? "\(h) h" : "\(h) h \(m) min"
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
        FastingPlanEditorView(plan: plan)
    }
    .modelContainer(container)
}
