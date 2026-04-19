import Foundation
import SwiftUI

// MARK: - Клиент

struct Client: Identifiable, Codable {
    let id: UUID
    var name: String
    var phone: String
    var colorHex: String = "#6C63FF"   // 🎨 Цвет клиента в календаре

    // Абонемент
    var startDate: Date = Date()
    var totalSessions: Int = 10
    var endDate: Date = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()

    // Метаданные абонемента (для восстановления формы при редактировании)
    var weekdaySelected: [Bool]? = nil
    var trainingTime: Date? = nil
    var subscriptionNotes: String? = nil
    var packagePrice: Double? = nil

    /// ID текущего активного абонемента. nil — нет активного абонемента.
    /// Тренировки и посещаемость привязываются к абонементу через Workout.subscriptionId.
    /// При создании нового абонемента генерируется новый UUID, старые workouts
    /// остаются с прежним ID и не учитываются в счётчиках нового абонемента.
    var currentSubscriptionId: UUID? = nil

    var workouts: [Workout]
    var attendance: [AttendanceRecord]

    init(
        id: UUID = UUID(),
        name: String,
        phone: String,
        colorHex: String = "#6C63FF",
        workouts: [Workout] = [],
        attendance: [AttendanceRecord] = []
    ) {
        self.id = id
        self.name = name
        self.phone = phone
        self.colorHex = colorHex
        self.workouts = workouts
        self.attendance = attendance
    }

    // MARK: - Вычисляемые свойства

    /// ID тренировок, принадлежащих текущему абонементу. Используется для
    /// фильтрации `attendance`, чтобы счётчики не «съели» историю прошлых абонементов.
    private var currentSubscriptionWorkoutIds: Set<UUID>? {
        guard let currentId = currentSubscriptionId else { return nil }
        return Set(workouts.filter { $0.subscriptionId == currentId }.map { $0.id })
    }

    /// Фактически проведённые тренировки (клиент пришёл) — только в рамках текущего абонемента.
    /// Для legacy-данных без currentSubscriptionId — учитываются все attendance (обратная совместимость).
    var completedSessions: Int {
        if let currentIds = currentSubscriptionWorkoutIds {
            return attendance.filter { att in
                att.wasPresent && (att.workoutId.map { currentIds.contains($0) } ?? false)
            }.count
        }
        return attendance.filter { $0.wasPresent }.count
    }

    /// Неявки (клиент не пришёл) — тоже списывают занятие из абонемента.
    var noShowSessionsCount: Int {
        if let currentIds = currentSubscriptionWorkoutIds {
            return attendance.filter { att in
                !att.wasPresent && (att.workoutId.map { currentIds.contains($0) } ?? false)
            }.count
        }
        return attendance.filter { !$0.wasPresent }.count
    }

    /// Сколько занятий израсходовано из абонемента: проведено + неявки.
    var usedSessions: Int {
        completedSessions + noShowSessionsCount
    }

    var remainingSessions: Int {
        max(0, totalSessions - usedSessions)
    }

    var subscriptionProgress: Double {
        totalSessions == 0 ? 0 : Double(usedSessions) / Double(totalSessions)
    }

    var subscriptionStatus: SubscriptionStatus {
        if endDate < Date() || remainingSessions == 0 { return .expired }
        if remainingSessions <= 3 { return .low }
        return .active
    }

    // SwiftUI Color из hex
    var color: Color {
        Color(hex: colorHex) ?? .accentColor
    }
}

// MARK: - Статус абонемента

enum SubscriptionStatus {
    case active   // всё ок
    case low      // осталось мало занятий
    case expired  // истёк или занятия кончились
}
// MARK: - Тренировка

struct Workout: Identifiable, Codable {
    let id: UUID
    var date: Date
    var duration: Int = 60
    var exercises: [Exercise]
    var status: WorkoutStatus = .planned
    var price: Double? = nil
    var notes: String? = nil
    var subscriptionId: UUID? = nil
    
    var isCompleted: Bool { status == .completed }

    init(
        id: UUID = UUID(),
        date: Date,
        duration: Int = 60,
        exercises: [Exercise] = [],
        status: WorkoutStatus = .planned,
        price: Double? = nil,
        notes: String? = nil,
        subscriptionId: UUID? = nil
    ) {
        self.id = id
        self.date = date
        self.duration = duration
        self.exercises = exercises
        self.status = status
        self.price = price
        self.notes = notes
        self.subscriptionId = subscriptionId
    }
}

enum WorkoutStatus: String, Codable, CaseIterable {
    case planned   = "Запланирована"
    case completed = "Проведена"
    case cancelled = "Отменена"
    case noShow    = "Неявка"
}

// MARK: - WorkoutRef (ссылка на тренировку для календаря)

struct WorkoutRef: Identifiable {
    let workoutId: UUID
    let clientId: UUID
    let date: Date
    let duration: Int
    let clientName: String
    let clientColor: Color
    let isCompleted: Bool
    let status: WorkoutStatus

    var id: UUID { workoutId }
}

// MARK: - Упражнение

struct Exercise: Identifiable, Codable {
    let id: UUID
    var name: String
    var sets: Int
    var reps: Int
    var weight: Double
    var comment: String = ""
    var videoURL: String? = nil

    init(
        id: UUID = UUID(),
        name: String,
        sets: Int,
        reps: Int,
        weight: Double,
        comment: String = "",
        videoURL: String? = nil
    ) {
        self.id = id
        self.name = name
        self.sets = sets
        self.reps = reps
        self.weight = weight
        self.comment = comment
        self.videoURL = videoURL
    }
}

// MARK: - Запись истории тренировок
// Хранится в отдельной коллекции Firestore и переживает удаление клиента.

struct WorkoutHistoryRecord: Identifiable, Codable {
    let id: UUID              // совпадает с id тренировки
    var clientId: UUID
    var clientName: String    // снимок имени на момент завершения
    var clientColorHex: String
    var date: Date
    var duration: Int
    var status: WorkoutStatus
    var price: Double?
    var notes: String?
    var exercises: [Exercise]
    var archivedAt: Date

    init(
        id: UUID,
        clientId: UUID,
        clientName: String,
        clientColorHex: String,
        date: Date,
        duration: Int,
        status: WorkoutStatus,
        price: Double? = nil,
        notes: String? = nil,
        exercises: [Exercise] = [],
        archivedAt: Date = Date()
    ) {
        self.id = id
        self.clientId = clientId
        self.clientName = clientName
        self.clientColorHex = clientColorHex
        self.date = date
        self.duration = duration
        self.status = status
        self.price = price
        self.notes = notes
        self.exercises = exercises
        self.archivedAt = archivedAt
    }
}

// MARK: - Посещаемость

struct AttendanceRecord: Identifiable, Codable {
    let id: UUID
    var date: Date
    var wasPresent: Bool
    var workoutId: UUID? = nil

    init(
        id: UUID = UUID(),
        date: Date,
        wasPresent: Bool,
        workoutId: UUID? = nil
    ) {
        self.id = id
        self.date = date
        self.wasPresent = wasPresent
        self.workoutId = workoutId
    }
}

// MARK: - Color + Hex

extension Color {
    init?(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h = String(h.dropFirst()) }
        guard h.count == 6, let val = UInt64(h, radix: 16) else { return nil }
        let r = Double((val >> 16) & 0xFF) / 255
        let g = Double((val >> 8)  & 0xFF) / 255
        let b = Double( val        & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
