# FastFlow Backlog

Wird stündlich automatisch abgearbeitet: jeweils der erste offene Punkt, danach abhaken, committen, pushen
(Branch `claude/fasting-schedule-models`). Sind alle Punkte erledigt, stoppt die Automatik.

- [x] Engine: pro Tag individuelle Zeiten, Übernachtfenster, Sommerzeit (`FastingScheduleModels.swift`)
- [x] Tests (`FastingScheduleEngineTests.swift`)
- [x] Editor für Tagesregeln (`FastingPlanEditorView.swift`)
- [x] Dashboard mit Status und Wochenband (`FastingDashboardView.swift`)
- [ ] Lokale Benachrichtigungen: Erinnerung vor Ende/Beginn des Essensfensters (Vorlaufzeit einstellbar), bei Planänderung neu planen, max. 64 ausstehende Notifications beachten
- [ ] App-Einstieg `FastFlowApp.swift`: ModelContainer, Beispielplan anlegen wenn leer, TabView Heute/Plan, aktiver Plan per `@Query`
- [ ] Selbst-Review aller Swift-Dateien auf Compilerfehler und API-Verfügbarkeit (iOS 18), gefundene Fehler beheben
- [ ] `README.md`: Dateien, Einbindung in ein Xcode-Projekt, Tests ausführen, Web-App-Link
