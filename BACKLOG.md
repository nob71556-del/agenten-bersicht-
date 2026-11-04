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
- [ ] Auswertung: `FastingReportSummary` aus dem Verlauf für Woche/Monat/Jahr berechnen (Ist vs. Soll), Tests
- [ ] Report-View: Woche/Monat/Jahr mit Swift Charts (Fastenstunden pro Tag, Soll-Linie), Streak-Anzeige
- [ ] Gewicht aus HealthKit lesen (bodyMass), geglätteter Trend (EMA), Tests für EMA; Info.plist-Hinweis in README
- [ ] Widget (WidgetKit) mit Status und Restzeit, nutzt die Engine; Anleitung für App Group in README
- [ ] Web-App angleichen: Erinnerungsvorschau (welche Mitteilungen wann) und Dashboard-Texte wie in Swift
