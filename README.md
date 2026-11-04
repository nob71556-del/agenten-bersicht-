# FastFlow

iOS-18-App (SwiftUI, SwiftData) für Intervallfasten mit eigenem Essensfenster pro Wochentag,
auch über Mitternacht (z. B. Sa 17:00 bis So 02:00).

> Stand: Die Dateien wurden ohne Xcode geschrieben und sind **nicht kompiliert**. Beim ersten Build
> in Xcode können kleine Compilerfehler auftauchen.

## Dateien

| Datei | Inhalt |
|---|---|
| `FastingScheduleModels.swift` | Wochentage, Tagesregel, SwiftData-Modell `WeeklyFastingPlan`, Engine `FastingScheduleEngine` |
| `FastingDashboardView.swift` | Heute-Ansicht: Status, Fortschrittsring, Wochenband |
| `FastingPlanEditorView.swift` | Editor für die 7 Tagesregeln |
| `FastingNotificationScheduler.swift` | Lokale Erinnerungen (Fenster öffnet / schließt bald) |
| `FastFlowApp.swift` | App-Einstieg mit Tabs Heute / Plan / Erinnerungen |
| `FastingScheduleEngineTests.swift` | Tests (Swift Testing) für Engine und Erinnerungsplanung |
| `BACKLOG.md` | Offene Aufgaben |

## In Xcode einbinden

1. Neues Projekt: iOS App, Interface SwiftUI, Storage **None**, Produktname `FastFlow`, Testing System **Swift Testing**.
2. Die von Xcode erzeugte `FastFlowApp.swift` und `ContentView.swift` löschen.
3. Alle `.swift`-Dateien außer der Testdatei ins App-Target ziehen.
4. `FastingScheduleEngineTests.swift` ins Test-Target ziehen. Heißt das App-Modul anders als `FastFlow`,
   die Zeile `@testable import FastFlow` anpassen.
5. Deployment Target iOS 18.0. Bauen (⌘B), Tests ausführen (⌘U).

Für Benachrichtigungen ist keine zusätzliche Capability nötig; die App fragt die Erlaubnis beim Einschalten im Tab „Erinnerungen“ an.

## Wie die Engine rechnet

- Jede Tagesregel hat Start und Ende in Minuten ab 00:00. Ende ≤ Start bedeutet: Fenster läuft in den Folgetag.
- Aus dem Plan werden konkrete Essensfenster (Datum bis Datum) für die umliegenden Tage erzeugt; dazwischen ist Fasten.
  Überlappende Fenster werden zusammengeführt, deaktivierte Tage übersprungen.
- Uhrzeiten werden über `Calendar.date(bySettingHour:…)` gesetzt, damit Sommer-/Winterzeit stimmt.
- Das Badge „Fasten:Essen“ zeigt die echte Pause bis zum nächsten aktiven Fenster, nicht `24 − Essen`.

## Web-Version zum Testen

Eine JavaScript-Portierung der Engine mit Editor und simulierter Uhrzeit liegt als privates Artifact vor:
https://claude.ai/artifact/7SxG68pRCjRbnE9peZfg2q

## Hinweis

Die Phasen-Texte (Verdauung, Glykogen, Fettstoffwechsel) sind grobe Richtwerte und keine medizinische Beratung.
