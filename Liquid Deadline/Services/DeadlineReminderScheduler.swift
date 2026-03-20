import Foundation
import UserNotifications

actor DeadlineReminderScheduler {
    static let shared = DeadlineReminderScheduler()

    private let notificationCenter = UNUserNotificationCenter.current()
    private let identifierPrefix = "deadline_reminder_"
    private let maxPendingRequests = 60

    func refreshNotifications(for items: [DeadlineItem], language: AppLanguage) async {
        let now = Date()
        let scheduledReminders = upcomingReminders(from: items, now: now)

        guard scheduledReminders.isEmpty == false else {
            await clearPendingReminderNotifications()
            return
        }

        let settings = await notificationCenter.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            break
        case .notDetermined:
            do {
                let granted = try await notificationCenter.requestAuthorization(options: [.alert, .badge, .sound])
                if granted == false {
                    await clearPendingReminderNotifications()
                    return
                }
            } catch {
                return
            }
        case .denied:
            await clearPendingReminderNotifications()
            return
        @unknown default:
            return
        }

        await clearPendingReminderNotifications()

        for scheduledReminder in scheduledReminders {
            let content = UNMutableNotificationContent()
            content.title = scheduledReminder.item.title
            content.body = language.reminderNotificationBody(for: scheduledReminder.reminder)
            content.sound = .default

            let triggerInterval = scheduledReminder.triggerDate.timeIntervalSince(now)
            guard triggerInterval > 1 else { continue }

            let request = UNNotificationRequest(
                identifier: notificationIdentifier(
                    itemID: scheduledReminder.item.id,
                    reminderID: scheduledReminder.reminder.id
                ),
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: triggerInterval, repeats: false)
            )

            try? await notificationCenter.add(request)
        }
    }

    private func clearPendingReminderNotifications() async {
        let pendingRequests = await notificationCenter.pendingNotificationRequests()
        let identifiers = pendingRequests
            .map(\.identifier)
            .filter { $0.hasPrefix(identifierPrefix) }

        guard identifiers.isEmpty == false else { return }
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
        notificationCenter.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    private func upcomingReminders(from items: [DeadlineItem], now: Date) -> [ScheduledReminder] {
        items
            .filter { $0.completedAt == nil }
            .flatMap { item in
                item.reminders.compactMap { reminder in
                    let triggerDate = reminder.triggerDate(for: item)
                    guard triggerDate > now else { return nil }
                    return ScheduledReminder(item: item, reminder: reminder, triggerDate: triggerDate)
                }
            }
            .sorted { lhs, rhs in
                if lhs.triggerDate == rhs.triggerDate {
                    return lhs.item.createdAt < rhs.item.createdAt
                }
                return lhs.triggerDate < rhs.triggerDate
            }
            .prefix(maxPendingRequests)
            .map { $0 }
    }

    private func notificationIdentifier(itemID: UUID, reminderID: UUID) -> String {
        identifierPrefix + itemID.uuidString + "_" + reminderID.uuidString
    }
}

private struct ScheduledReminder {
    let item: DeadlineItem
    let reminder: DeadlineReminder
    let triggerDate: Date
}
