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
| `FastingHistory.swift` | Verlauf abgeschlossener Fastenphasen, Streak mit Jokern |
| `FastingReport.swift` | Auswertung Woche / Monat / Jahr (Ist vs. Soll, Balken pro Tag/Monat) |
| `FastingReportView.swift` | Auswertungs-Ansicht mit Swift Charts und Gewichtstrend |
| `WeightTrend.swift` | Gewicht aus Apple Health lesen, geglätteter Trend |
| `FastingPlanValidator.swift` | Hinweise im Editor (24-h-Fenster, kurze Pause, Überlappung) |
| `SharedPlanStore.swift` | Teilt den Plan per App Group mit dem Widget (App- **und** Widget-Target) |
| `FastFlowWidget/FastFlowWidget.swift` | Widget: Status, Live-Countdown, Fortschritt (nur Widget-Target) |
| `FastFlowApp.swift` | App-Einstieg mit Tabs Heute / Plan / Auswertung / Erinnerungen |
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

### Apple Health (Gewicht)

1. App-Target → Signing & Capabilities → **HealthKit** hinzufügen.
2. In der Info.plist `NSHealthShareUsageDescription` setzen, z. B. „FastFlow liest dein Gewicht, um den Trend neben deinen Fastenzeiten zu zeigen.“
3. Die App liest nur `bodyMass` und schreibt nichts.

### Widget

1. File → New → Target → **Widget Extension**, Name `FastFlowWidget`, „Include Configuration App Intent“ aus.
2. Die erzeugte Swift-Datei durch `FastFlowWidget/FastFlowWidget.swift` ersetzen.
3. `FastingScheduleModels.swift` und `SharedPlanStore.swift` zusätzlich dem Widget-Target zuordnen (Target Membership).
4. In App- **und** Widget-Target unter Signing & Capabilities **App Groups** hinzufügen, ID `group.de.fastflow.shared`
   (oder eigene ID, dann `SharedPlanStore.appGroupID` anpassen).

## Wie die Engine rechnet

- Jede Tagesregel hat Start und Ende in Minuten ab 00:00. Ende ≤ Start bedeutet: Fenster läuft in den Folgetag.
- Aus dem Plan werden konkrete Essensfenster (Datum bis Datum) für die umliegenden Tage erzeugt; dazwischen ist Fasten.
  Überlappende Fenster werden zusammengeführt, deaktivierte Tage übersprungen.
- Uhrzeiten werden über `Calendar.date(bySettingHour:…)` gesetzt, damit Sommer-/Winterzeit stimmt.
- Das Badge „Fasten:Essen“ zeigt die echte Pause bis zum nächsten aktiven Fenster, nicht `24 − Essen`.

## Web-Version zum Testen

`webapp.html` ist die vollständige Web-App (eine Datei, im Browser lauffähig): Heute, Plan, Auswertung, Gewicht, Erinnerungsvorschau. Angemeldet in claude.ai speichert sie im Konto, sonst im Browser.

Eine JavaScript-Portierung der Engine mit Editor, Plan-Hinweisen, Erinnerungsvorschau und simulierter Uhrzeit liegt als privates Artifact vor:
https://claude.ai/artifact/7SxG68pRCjRbnE9peZfg2q

## Hinweis

Die Phasen-Texte (Verdauung, Glykogen, Fettstoffwechsel) sind grobe Richtwerte und keine medizinische Beratung.
