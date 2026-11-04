//
//  WeightTrend.swift
//  FastFlow
//
//  Gewicht aus Apple Health (nur lesen) und geglätteter Trend (exponentieller
//  gleitender Durchschnitt), damit Tagesschwankungen durch Wasser & Co. nicht
//  den Verlauf dominieren.
//

import Foundation
import HealthKit

public struct WeightSample: Hashable, Sendable {
    public let date: Date
    public let kg: Double

    public init(date: Date, kg: Double) {
        self.date = date
        self.kg = kg
    }
}

public struct WeightTrendPoint: Identifiable, Hashable, Sendable {
    /// Kalendertag der Messung(en).
    public let date: Date
    /// Tagesmittel der Messungen.
    public let kg: Double
    /// Geglätteter Trendwert.
    public let trendKg: Double
    public var id: Date { date }
}

public enum WeightTrend {
    /// Mehrere Messungen pro Tag werden gemittelt, dann wird je Tag geglättet:
    /// trend = trend + alpha * (messung − trend). Startwert ist die erste Messung.
    /// alpha 0,1 entspricht etwa einem 10-Tage-Fenster.
    public static func smoothed(_ samples: [WeightSample], alpha: Double = 0.1, calendar: Calendar = .current) -> [WeightTrendPoint] {
        let a = min(max(alpha, 0.01), 1)
        let byDay = Dictionary(grouping: samples.filter { $0.kg > 0 }) { calendar.startOfDay(for: $0.date) }
        var trend: Double?
        return byDay.keys.sorted().map { day in
            let values = byDay[day]!.map(\.kg)
            let mean = values.reduce(0, +) / Double(values.count)
            let next = trend.map { $0 + a * (mean - $0) } ?? mean
            trend = next
            return WeightTrendPoint(date: day, kg: mean, trendKg: next)
        }
    }
}

/// Liest Körpergewicht aus Apple Health. Benötigt die HealthKit-Capability und
/// `NSHealthShareUsageDescription` in der Info.plist (siehe README).
@MainActor
public final class HealthWeightService {
    private let store = HKHealthStore()
    private let bodyMass = HKQuantityType(.bodyMass)

    public init() {}

    public var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    public func requestAuthorization() async throws {
        try await store.requestAuthorization(toShare: [], read: [bodyMass])
    }

    /// Messungen der letzten `days` Tage, aufsteigend sortiert. Ohne Leserecht liefert
    /// HealthKit aus Datenschutzgründen einfach eine leere Liste.
    public func samples(days: Int = 365, now: Date = .now) async throws -> [WeightSample] {
        let start = Calendar.current.date(byAdding: .day, value: -days, to: now) ?? now
        let predicate = HKQuery.predicateForSamples(withStart: start, end: now)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: bodyMass, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        let results = try await descriptor.result(for: store)
        return results.map {
            WeightSample(date: $0.startDate, kg: $0.quantity.doubleValue(for: .gramUnit(with: .kilo)))
        }
    }
}
