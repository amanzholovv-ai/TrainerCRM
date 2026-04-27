import UserNotifications
import Foundation

// MARK: - NotificationManager

final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    private let center = UNUserNotificationCenter.current()

    // MARK: - Разрешение

    func requestPermission(completion: @escaping (Bool) -> Void) {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async { completion(granted) }
        }
    }

    func checkStatus(completion: @escaping (UNAuthorizationStatus) -> Void) {
        center.getNotificationSettings { settings in
            DispatchQueue.main.async { completion(settings.authorizationStatus) }
        }
    }

    // MARK: - Планирование одного напоминания

    /// Планирует напоминание о тренировке. Ничего не делает если до уведомления уже прошло время.
    func scheduleWorkoutReminder(workoutId: UUID,
                                 clientName: String,
                                 date: Date,
                                 minutesBefore: Int) {
        let fireDate = date.addingTimeInterval(-Double(minutesBefore) * 60)
        guard fireDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = minutesBefore < 60
            ? "Тренировка через \(minutesBefore) мин"
            : "Тренировка через \(minutesBefore / 60) ч"
        content.body  = "\(clientName) · \(timeString(date))"
        content.sound = .default

        let comps   = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute], from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(
            identifier: workoutId.uuidString,
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    // MARK: - Отмена

    func cancelReminder(workoutId: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: [workoutId.uuidString])
    }

    // MARK: - Полный пересчёт (при входе или смене настроек)

    func rescheduleAll(clients: [Client]) {
        guard UserDefaults.standard.bool(forKey: "notifications_enabled") else { return }
        let minutesBefore = UserDefaults.standard.integer(forKey: "notifications_minutesBefore")
        let minutes = minutesBefore == 0 ? 60 : minutesBefore

        center.removeAllPendingNotificationRequests()
        let now = Date()
        for client in clients {
            for workout in client.workouts
            where workout.status == .planned && workout.date > now {
                scheduleWorkoutReminder(
                    workoutId: workout.id,
                    clientName: client.name,
                    date: workout.date,
                    minutesBefore: minutes
                )
            }
        }
    }

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }

    // MARK: - Helpers

    private func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}
