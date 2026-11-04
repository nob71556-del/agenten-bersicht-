//
//  FastFlowApp.swift
//  FastFlow
//
//  App-Einstieg: SwiftData-Container, Beispielplan beim ersten Start,
//  Tabs Heute / Plan / Erinnerungen, Neuplanung der Benachrichtigungen bei Änderungen.
//

import SwiftUI
import SwiftData
import WidgetKit

@main
struct FastFlowApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [WeeklyFastingPlan.self, FastingSessionRecord.self])
    }
}

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    @Query(filter: #Predicate<WeeklyFastingPlan> { $0.isActive },
           sort: \WeeklyFastingPlan.updatedAt, order: .reverse)
    private var activePlans: [WeeklyFastingPlan]

    @AppStorage("notify.enabled") private var notifyEnabled = false
    @AppStorage("notify.open") private var notifyOpen = true
    @AppStorage("notify.close") private var notifyClose = true
    @AppStorage("notify.leadMinutes") private var leadMinutes = 30

    @State private var scheduler = FastingNotificationScheduler()

    private var settings: FastingNotificationSettings {
        FastingNotificationSettings(isEnabled: notifyEnabled, remindWhenWindowOpens: notifyOpen,
                                    remindBeforeWindowEnds: notifyClose, leadTimeMinutes: leadMinutes)
    }

    var body: some View {
        if let plan = activePlans.first {
            TabView {
                Tab("Heute", systemImage: "timer") {
                    NavigationStack { FastingDashboardView(plan: plan) }
                }
                Tab("Plan", systemImage: "calendar") {
                    NavigationStack { FastingPlanEditorView(plan: plan) }
                }
                Tab("Auswertung", systemImage: "chart.bar") {
                    NavigationStack { FastingReportView() }
                }
                Tab("Erinnerungen", systemImage: "bell") {
                    NavigationStack {
                        NotificationSettingsView(
                            isEnabled: $notifyEnabled, remindOpen: $notifyOpen,
                            remindClose: $notifyClose, leadMinutes: $leadMinutes,
                            requestAuthorization: { await scheduler.requestAuthorization() }
                        )
                    }
                }
            }
            // Neu planen bei Planänderung, geänderten Einstellungen und App-Rückkehr.
            .task(id: rescheduleKey(plan)) {
                FastingHistoryRecorder.recordCompletedFasts(context: context, plan: plan)
                SharedPlanStore.save(plan.schedule)
                WidgetCenter.shared.reloadAllTimelines()
                await scheduler.reschedule(plan: plan, settings: settings)
            }
        } else {
            ProgressView()
                .task { ensureActivePlan() }
        }
    }

    private func rescheduleKey(_ plan: WeeklyFastingPlan) -> String {
        "\(plan.updatedAt.timeIntervalSince1970)|\(settings.isEnabled)|\(notifyOpen)|\(notifyClose)|\(leadMinutes)|\(scenePhase == .active)"
    }

    /// Legt beim ersten Start den Beispielplan an oder aktiviert einen vorhandenen Plan.
    private func ensureActivePlan() {
        let all = (try? context.fetch(FetchDescriptor<WeeklyFastingPlan>())) ?? []
        if let existing = all.first {
            existing.isActive = true
        } else {
            context.insert(WeeklyFastingPlan.createWorkweek18_6Weekend14_10Plan())
        }
        try? context.save()
    }
}

// MARK: - Einstellungen für Erinnerungen

struct NotificationSettingsView: View {
    @Binding var isEnabled: Bool
    @Binding var remindOpen: Bool
    @Binding var remindClose: Bool
    @Binding var leadMinutes: Int
    let requestAuthorization: @MainActor () async -> Bool

    @State private var deniedHint = false

    var body: some View {
        Form {
            Section {
                Toggle("Erinnerungen aktiv", isOn: Binding(
                    get: { isEnabled },
                    set: { newValue in
                        if newValue {
                            Task {
                                let granted = await requestAuthorization()
                                isEnabled = granted
                                deniedHint = !granted
                            }
                        } else {
                            isEnabled = false
                        }
                    }
                ))
            } footer: {
                if deniedHint {
                    Text("Mitteilungen sind nicht erlaubt. Du kannst sie in den iOS-Einstellungen für FastFlow aktivieren.")
                        .foregroundStyle(.orange)
                }
            }

            if isEnabled {
                Section("Wann") {
                    Toggle("Wenn das Essensfenster öffnet", isOn: $remindOpen)
                    Toggle("Bevor das Essensfenster schließt", isOn: $remindClose)
                    if remindClose {
                        Stepper("Vorlauf: \(leadMinutes) min", value: $leadMinutes, in: 5...120, step: 5)
                    }
                }
            }
        }
        .navigationTitle("Erinnerungen")
    }
}
