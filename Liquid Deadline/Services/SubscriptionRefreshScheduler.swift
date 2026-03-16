import BackgroundTasks
import Foundation

enum SubscriptionRefreshScheduler {
    static let identifier = "name.qianmo.LiquidDeadline.subscriptionRefresh"

    static func scheduleNextRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: DeadlineStore.backgroundRefreshRequestInterval)

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            #if DEBUG
            print("Failed to schedule background refresh: \(error)")
            #endif
        }
    }

    static func cancelScheduledRefresh() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: identifier)
    }
}
