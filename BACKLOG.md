# FastFlow Backlog

Wird stündlich automatisch abgearbeitet: jeweils der erste offene Punkt, danach abhaken, committen, pushen
(Branch `claude/fasting-schedule-models`). Sind alle Punkte erledigt, stoppt die Automatik.

- [x] Engine: pro Tag individuelle Zeiten, Übernachtfenster, Sommerzeit (`FastingScheduleModels.swift`)
- [x] Tests (`FastingScheduleEngineTests.swift`)
- [x] Editor für Tagesregeln (`FastingPlanEditorView.swift`)
- [x] Dashboard mit Status und Wochenband (`FastingDashboardView.swift`)
- [x] Lokale Benachrichtigungen (`FastingNotificationScheduler.swift`) inkl. Tests
- [x] App-Einstieg `FastFlowApp.swift` mit Tabs Heute / Plan / Erinnerungen
- [x] Selbst-Review: MainActor-Isolation im Scheduler, `String(format:)` mit `%@` entfernt
- [x] `README.md`
- [x] Verlauf (`FastingHistory.swift`): abgeschlossene Fastenphasen als `@Model FastingSessionRecord` speichern (Start, Ende, Plan-Soll), Streak-Berechnung mit Jokern, Tests
- [x] Auswertung (`FastingReport.swift`): `FastingReportSummary` aus dem Verlauf für Woche/Monat/Jahr berechnen (Ist vs. Soll), Tests
- [x] Report-View (`FastingReportView.swift`): Woche/Monat/Jahr mit Swift Charts (Fastenstunden pro Tag, Soll-Linie), Streak-Anzeige
- [x] Gewicht aus HealthKit (`WeightTrend.swift`) lesen (bodyMass), geglätteter Trend (EMA), Tests für EMA; Info.plist-Hinweis in README
- [x] Widget (`FastFlowWidget/`) mit Status und Restzeit, nutzt die Engine; Anleitung für App Group in README
- [x] Web-App angleichen: Erinnerungsvorschau (welche Mitteilungen wann) und Dashboard-Texte wie in Swift
- [x] Extra: Plan-Prüfung mit Hinweisen im Editor und in der Web-App (`FastingPlanValidator.swift`)
- [x] Extra: Engine arbeitet mit `WeeklySchedule` (Werttyp) – Widget und Tests ohne SwiftData
- [x] Fix: Zeitangaben unter 1 h zeigten „0 h 30 min“

Alle Punkte erledigt. Nächster sinnvoller Schritt: Build in Xcode und Compilerfehler beheben.
