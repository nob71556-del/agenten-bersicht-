//
//  SharedPlanStore.swift
//  FastFlow (App- und Widget-Target)
//
//  Teilt den aktiven Wochenplan als JSON über eine App Group mit dem Widget.
//  Die App-Group-ID muss in beiden Targets unter „Signing & Capabilities“
//  eingetragen sein (siehe README).
//

import Foundation

public enum SharedPlanStore {
    public static let appGroupID = "group.de.fastflow.shared"
    private static let key = "sharedWeeklySchedule"

    public static func save(_ schedule: WeeklySchedule) {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = try? JSONEncoder().encode(schedule) else { return }
        defaults.set(data, forKey: key)
    }

    public static func load() -> WeeklySchedule? {
        guard let data = UserDefaults(suiteName: appGroupID)?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WeeklySchedule.self, from: data)
    }
}
