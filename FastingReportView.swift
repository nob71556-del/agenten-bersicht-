//
//  FastingReportView.swift
//  FastFlow
//
//  Auswertung Woche / Monat / Jahr: Kennzahlen, Fastenstunden mit Soll-Linie,
//  Serie mit Jokern, Gewichtstrend aus Apple Health.
//

import SwiftUI
import SwiftData
import Charts

public struct FastingReportView: View {
    @Query(sort: \FastingSessionRecord.plannedEnd) private var records: [FastingSessionRecord]
    @AppStorage("streak.jokersPerPeriod") private var jokers = 2

    @State private var period: ReportingPeriod = .week
    @State private var weights: [WeightSample] = []
    @State private var weightError: String?
    @State private var weightService = HealthWeightService()

    private let calendar = Calendar.autoupdatingCurrent

    public init() {}

    public var body: some View {
        let sessions = records.map(\.summary)
        let now = Date.now
        let summary = FastingReportBuilder.summary(period: period, sessions: sessions, now: now,
                                                   calendar: calendar, jokers: jokers, weights: weights)
        let buckets = FastingReportBuilder.buckets(period: period, sessions: sessions, now: now, calendar: calendar)

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Picker("Zeitraum", selection: $period) {
                    ForEach(ReportingPeriod.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                if sessions.isEmpty {
                    ContentUnavailableView(
                        "Noch kein Verlauf",
                        systemImage: "chart.bar",
                        description: Text("Abgeschlossene Fastenphasen erscheinen hier automatisch.")
                    )
                } else {
                    kpiGrid(summary)
                    hoursChart(buckets)
                }
                weightSection(summary)
            }
            .padding()
        }
        .navigationTitle("Auswertung")
    }

    // MARK: Kennzahlen

    private func kpiGrid(_ s: FastingReportSummary) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            kpi("Gefastet", "\(Int(s.totalFastedHours.rounded())) h",
                "Soll \(Int(s.targetFastedHours.rounded())) h")
            kpi("Ziel erreicht", "\(Int((s.goalRate * 100).rounded())) %",
                "\(s.goalReachedSessions) von \(s.completedSessions) Phasen")
            kpi("Serie", "\(s.currentStreakDays) Tage",
                "\(s.remainingStreakJokers) Joker übrig")
            kpi("Höhenmeter", "\(Int(s.totalFastedHours.rounded())) m",
                String(format: "%.0f %% Eiffelturm", s.eiffelTowerEquivalentRatio * 100))
        }
    }

    private func kpi(_ title: String, _ value: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).textCase(.uppercase).foregroundStyle(.secondary)
            Text(value).font(.title2.bold().monospacedDigit())
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 12))
    }

    // MARK: Diagramm

    private func hoursChart(_ buckets: [FastingBucket]) -> some View {
        let unit = period.bucketComponent
        return VStack(alignment: .leading, spacing: 8) {
            Text("Fastenstunden").font(.headline)
            Chart {
                ForEach(buckets) { bucket in
                    BarMark(x: .value("Zeit", bucket.start, unit: unit),
                            y: .value("Gefastet", bucket.fastedHours))
                        .foregroundStyle(.teal)
                    LineMark(x: .value("Zeit", bucket.start, unit: unit),
                             y: .value("Soll", bucket.targetHours))
                        .foregroundStyle(.indigo)
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 3]))
                        .interpolationMethod(.stepCenter)
                }
            }
            .chartYAxisLabel("Stunden")
            .frame(height: 200)
            HStack(spacing: 16) {
                Label("Gefastet", systemImage: "square.fill").foregroundStyle(.teal)
                Label("Soll", systemImage: "line.diagonal").foregroundStyle(.indigo)
            }
            .font(.caption)
        }
    }

    // MARK: Gewicht

    @ViewBuilder
    private func weightSection(_ s: FastingReportSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Gewicht").font(.headline)
            if let latest = s.latestWeightKg, let trend = s.trendWeightKg {
                Text(String(format: "Trend %.1f kg · letzte Messung %.1f kg", trend, latest))
                    .font(.subheadline.monospacedDigit())
                let points = WeightTrend.smoothed(weights, calendar: calendar)
                Chart(points) { p in
                    PointMark(x: .value("Tag", p.date, unit: .day), y: .value("Messung", p.kg))
                        .foregroundStyle(.secondary)
                        .symbolSize(20)
                    LineMark(x: .value("Tag", p.date, unit: .day), y: .value("Trend", p.trendKg))
                        .foregroundStyle(.teal)
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .frame(height: 180)
            } else if weightService.isAvailable {
                Button("Gewicht aus Apple Health laden") {
                    Task { await loadWeights() }
                }
                if let weightError {
                    Text(weightError).font(.caption).foregroundStyle(.orange)
                }
            } else {
                Text("Apple Health ist auf diesem Gerät nicht verfügbar.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func loadWeights() async {
        do {
            try await weightService.requestAuthorization()
            weights = try await weightService.samples()
            weightError = weights.isEmpty
                ? "Keine Gewichtsdaten gefunden. Prüfe in Health, ob FastFlow Gewicht lesen darf."
                : nil
        } catch {
            weightError = "Gewicht konnte nicht geladen werden: \(error.localizedDescription)"
        }
    }
}
