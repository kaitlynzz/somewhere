//
//  ShelfSettings.swift
//  Somewhere — Cooling shelf (Kaitlyn)
//
//  How long new saves rest on the cooling shelf before you decide.
//  Lives in Model/ because the Share Extension needs it too: `SavedItem`
//  reads it when a new item is created.
//
//  ⚠️ Add to BOTH targets: the app and the Share Extension.
//

import Foundation

enum ShelfSettings {

    static let defaultDays = 3
    /// The choices offered in the shelf's settings sheet.
    static let dayOptions = [1, 2, 3, 5, 7]
    static let allowedDays = 1...14

    private static let key = "somewhere.coolingDays"

    /// Muskaan's onboarding saves the user's choices here (OnboardingFlow.swift).
    private static let onboardingKey = "somewhere.onboardingResult"

    /// Shared with the Share Extension through the App Group, when it's set up.
    static var store: UserDefaults {
        let hasAppGroup = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier) != nil
        return hasAppGroup ? (UserDefaults(suiteName: AppGroup.identifier) ?? .standard) : .standard
    }

    /// The user's waiting period in days.
    /// Order: what they picked on the shelf → what they picked in onboarding → 3.
    static var coolingDays: Int {
        get {
            if let days = store.object(forKey: key) as? Int, allowedDays.contains(days) { return days }
            if let days = onboardingCoolingDays { return days }
            return defaultDays
        }
        set {
            store.set(min(max(newValue, allowedDays.lowerBound), allowedDays.upperBound), forKey: key)
        }
    }

    static var coolingPeriod: TimeInterval {
        TimeInterval(coolingDays) * 24 * 60 * 60
    }

    /// Reads `coolingDays` out of the onboarding result without needing
    /// Muskaan's `OnboardingResult` type in this target.
    private static var onboardingCoolingDays: Int? {
        guard
            let data = UserDefaults.standard.data(forKey: onboardingKey),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let days = json["coolingDays"] as? Int,
            allowedDays.contains(days)
        else { return nil }
        return days
    }
}

extension SavedItem {
    /// Whole days this item has been resting since it was saved (at least 1).
    var daysCooled: Int {
        max(1, Calendar.current.dateComponents([.day], from: createdAt, to: Date()).day ?? 1)
    }

    /// Re-times an item that is still cooling after the waiting period changes.
    func applyCoolingPeriod(_ period: TimeInterval) {
        guard isCooling else { return }
        shelfReadyAt = createdAt.addingTimeInterval(period)
    }
}
