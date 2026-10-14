import Foundation
import Observation
import UserNotifications

/// Bringt die geplanten Benachrichtigungen zum System. Die Planung selbst steckt in `ReminderPlanner`.
@MainActor
@Observable
final class NotificationScheduler {
    enum Authorization {
        case unknown, notDetermined, denied, authorized
    }

    private(set) var authorization: Authorization = .unknown

    @ObservationIgnored private var lastPlans: [PlannedNotification] = []
    @ObservationIgnored private let center: UNUserNotificationCenter?
    @ObservationIgnored private let delegate = ForegroundNotificationDelegate()

    /// Mit `isActive: false` (Tests) passiert nichts und es erscheint keine Systemabfrage.
    init(isActive: Bool = true) {
        if isActive {
            let center = UNUserNotificationCenter.current()
            center.delegate = delegate
            self.center = center
        } else {
            self.center = nil
        }
    }

    func refreshAuthorization() async {
        guard let center else { return }
        let settings = await center.notificationSettings()
        authorization = switch settings.authorizationStatus {
        case .notDetermined: .notDetermined
        case .denied: .denied
        case .authorized, .provisional, .ephemeral: .authorized
        @unknown default: .unknown
        }
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        guard let center else { return false }
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
        await refreshAuthorization()
        if authorization == .authorized {
            await apply(lastPlans)
        }
        return authorization == .authorized
    }

    /// Ersetzt alle ausstehenden Benachrichtigungen durch den aktuellen Plan.
    func apply(_ plans: [PlannedNotification], calendar: Calendar = .current) async {
        guard let center else { return }
        lastPlans = plans
        center.removeAllPendingNotificationRequests()
        await refreshAuthorization()
        guard authorization == .authorized else { return }

        for plan in plans {
            let content = UNMutableNotificationContent()
            content.title = plan.title
            content.body = plan.body
            content.sound = .default
            let components = calendar.dateComponents(
                [.year, .month, .day, .hour, .minute, .second], from: plan.fireDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: plan.id, content: content, trigger: trigger)
            try? await center.add(request)
        }
    }
}

/// Zeigt Hinweise auch an, während die App im Vordergrund ist.
private final class ForegroundNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
