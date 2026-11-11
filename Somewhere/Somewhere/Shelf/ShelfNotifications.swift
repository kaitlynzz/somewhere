//
//  ShelfNotifications.swift
//  Somewhere — Cooling shelf (Kaitlyn)
//
//  "the perfect shoes have cooled for 3 days. still want it?"
//  One local notification per cooling item, at its `shelfReadyAt`.
//  Tapping it opens the shelf tab.
//

import Foundation
import UserNotifications

enum ShelfNotifications {

    static let identifierPrefix = "shelf-ready-"

    /// iOS keeps at most 64 pending notifications per app. Leave some room.
    private static let maxPending = 50

    /// What a reminder needs, copied out of `SavedItem` so it can cross into async code.
    struct Reminder: Sendable {
        let id: UUID
        let title: String
        let readyAt: Date
        let days: Int

        init(_ item: SavedItem) {
            id = item.id
            title = item.title
            readyAt = item.shelfReadyAt
            days = max(1, Int(((item.shelfReadyAt.timeIntervalSince(item.createdAt)) / 86_400).rounded()))
        }
    }

    // MARK: Permission

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// Shows the system prompt the first time. Returns whether reminders can be sent.
    @discardableResult
    static func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        switch await authorizationStatus() {
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        case .authorized, .provisional, .ephemeral:
            return true
        default:
            return false
        }
    }

    // MARK: Scheduling

    /// Replaces all shelf reminders with one per item that is still cooling.
    /// Safe to call often (app comes to the foreground, item decided, period changed…).
    static func sync(_ reminders: [Reminder]) async {
        let center = UNUserNotificationCenter.current()

        let pending = await center.pendingNotificationRequests()
        let ours = pending.map(\.identifier).filter { $0.hasPrefix(identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: ours)

        switch await authorizationStatus() {
        case .authorized, .provisional, .ephemeral: break
        default: return
        }

        let upcoming = reminders
            .filter { $0.readyAt > Date() }
            .sorted { $0.readyAt < $1.readyAt }
            .prefix(maxPending)

        for reminder in upcoming {
            let content = UNMutableNotificationContent()
            content.title = "somewhere"
            content.body = "\(reminder.title) has cooled for \(reminder.days) \(reminder.days == 1 ? "day" : "days"). still want it?"
            content.sound = .default
            content.threadIdentifier = "cooling-shelf"

            let parts = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second], from: reminder.readyAt
            )
            let request = UNNotificationRequest(
                identifier: identifierPrefix + reminder.id.uuidString,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
            )
            try? await center.add(request)
        }
    }

    /// Call once at launch (SomewhereApp.init) so taps that open the app are handled.
    static func installDelegate() {
        UNUserNotificationCenter.current().delegate = ShelfNotificationDelegate.shared
    }
}

/// Shows reminders while the app is open, and opens the shelf when one is tapped.
final class ShelfNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = ShelfNotificationDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard response.notification.request.identifier.hasPrefix(ShelfNotifications.identifierPrefix) else { return }
        await MainActor.run { AppRouter.shared.selectedTab = .shelf }
    }
}
