import Foundation
import SwiftUI
import Firebase
import FirebaseFirestore

final class ClientStore: ObservableObject {
    @Published var clients: [Client] = []
    @Published var history: [WorkoutHistoryRecord] = []
    /// Последнее сообщение об ошибке Firestore. UI может показать баннер/алерт.
    @Published var lastError: String?

    private var db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var historyListener: ListenerRegistration?
    private(set) var userId: String?

    init() {}

    // MARK: - Обработка ошибок

    /// Пишет человекочитаемое сообщение об ошибке Firestore в `lastError`
    /// на главном потоке. Сохраняет и контекст (например, «Сохранение клиента»).
    private func reportError(_ error: Error, context: String) {
        let message = "\(context): \(error.localizedDescription)"
        DispatchQueue.main.async { [weak self] in
            self?.lastError = message
        }
        #if DEBUG
        print("[ClientStore] \(message)")
        #endif
    }

    /// Очищает текущую ошибку (вызывается из UI по кнопке «Понятно»).
    func clearLastError() {
        DispatchQueue.main.async { [weak self] in
            self?.lastError = nil
        }
    }

    // MARK: - Конфигурация

    func configure(userId: String) {
        self.userId = userId
        startListening()
    }

    func reset() {
        listener?.remove()
        listener = nil
        historyListener?.remove()
        historyListener = nil
        clients = []
        history = []
        userId = nil
    }

    // MARK: - Firestore слушатель

    private func startListening() {
        guard let userId = userId else { return }
        listener = db.collection("users").document(userId).collection("clients")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                if let error = error {
                    self.reportError(error, context: "Загрузка клиентов")
                    return
                }
                guard let snapshot = snapshot else { return }
                // СТАЛО:
                let decoded = snapshot.documents.compactMap { doc -> Client? in
                    guard let jsonString = doc.data()["json"] as? String,
                          let data = jsonString.data(using: .utf8) else { return nil }
                    do {
                        return try JSONDecoder().decode(Client.self, from: data)
                    } catch {
                        #if DEBUG
                        print("[ClientStore] Ошибка декодирования клиента \(doc.documentID): \(error)")
                        #endif
                        return nil
                    }
                }
                
                DispatchQueue.main.async {
                    self.clients = decoded.sorted { $0.name < $1.name }
                }
            }

        historyListener = db.collection("users").document(userId).collection("history")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                if let error = error {
                    self.reportError(error, context: "Загрузка истории")
                    return
                }
                guard let snapshot = snapshot else { return }
                let decoded = snapshot.documents.compactMap { doc -> WorkoutHistoryRecord? in
                    guard let jsonString = doc.data()["json"] as? String,
                          let data = jsonString.data(using: .utf8) else { return nil }
                    return try? JSONDecoder().decode(WorkoutHistoryRecord.self, from: data)
                }
                DispatchQueue.main.async {
                    self.history = decoded.sorted { $0.date < $1.date }
                }
            }
    }

    // MARK: - Сохранение в Firestore

    private func saveClient(_ client: Client) {
        guard let userId = userId else { return }
        guard let data = try? JSONEncoder().encode(client),
              let jsonString = String(data: data, encoding: .utf8)
        else {
            DispatchQueue.main.async { [weak self] in
                self?.lastError = "Сохранение клиента: не удалось сериализовать данные"
            }
            return
        }
        db.collection("users").document(userId).collection("clients")
            .document(client.id.uuidString)
            .setData(["json": jsonString]) { [weak self] error in
                if let error = error {
                    self?.reportError(error, context: "Сохранение клиента")
                }
            }
    }

    private func deleteClientFromFirestore(_ clientId: UUID) {
        guard let userId = userId else { return }
        db.collection("users").document(userId).collection("clients")
            .document(clientId.uuidString)
            .delete { [weak self] error in
                if let error = error {
                    self?.reportError(error, context: "Удаление клиента")
                }
            }
    }

    // MARK: - История

    private func saveHistory(_ record: WorkoutHistoryRecord) {
        guard let userId = userId else { return }
        guard let data = try? JSONEncoder().encode(record),
              let jsonString = String(data: data, encoding: .utf8)
        else {
            DispatchQueue.main.async { [weak self] in
                self?.lastError = "Сохранение истории: не удалось сериализовать данные"
            }
            return
        }
        db.collection("users").document(userId).collection("history")
            .document(record.id.uuidString)
            .setData(["json": jsonString]) { [weak self] error in
                if let error = error {
                    self?.reportError(error, context: "Сохранение истории")
                }
            }
    }

    private func deleteHistory(recordId: UUID) {
        guard let userId = userId else { return }
        db.collection("users").document(userId).collection("history")
            .document(recordId.uuidString)
            .delete { [weak self] error in
                if let error = error {
                    self?.reportError(error, context: "Удаление из истории")
                }
            }
    }

    /// Копирует состояние тренировки в историю. Используется при переходе статуса
    /// в .completed / .cancelled / .noShow, а также при ручном редактировании.
    private func archiveWorkoutToHistory(workout: Workout, client: Client) {
        let record = WorkoutHistoryRecord(
            id: workout.id,
            clientId: client.id,
            clientName: client.name,
            clientColorHex: client.colorHex,
            date: workout.date,
            duration: workout.duration,
            status: workout.status,
            price: workout.price,
            notes: workout.notes,
            exercises: workout.exercises,
            archivedAt: Date()
        )
        // локальный upsert (сортировка произойдёт через snapshot listener)
        if let idx = history.firstIndex(where: { $0.id == record.id }) {
            history[idx] = record
        } else {
            history.append(record)
        }
        saveHistory(record)
    }

    /// Возвращает true, если тренировка в «историческом» статусе.
    private func isHistoricalStatus(_ status: WorkoutStatus) -> Bool {
        status == .completed || status == .cancelled || status == .noShow
    }

    // MARK: - Клиенты

    func add(_ client: Client) { addClient(client) }

    func addClient(_ client: Client) {
        var c = client
        c.workouts = []
        c.totalSessions = 0
        c.startDate = Date.distantPast
        c.endDate = Date.distantPast
        clients.append(c)
        saveClient(c)
    }

    func remove(at offsets: IndexSet) {
        let toDelete = offsets.map { clients[$0] }
        clients.remove(atOffsets: offsets)
        toDelete.forEach { deleteClientFromFirestore($0.id) }
    }

    func update(_ client: Client) {
        guard let idx = clients.firstIndex(where: { $0.id == client.id }) else { return }
        clients[idx] = client
        saveClient(client)
    }

    // MARK: - Тренировки

    func addWorkout(_ workout: Workout, to clientId: UUID) {
        guard let idx = clients.firstIndex(where: { $0.id == clientId }) else { return }

        var client = clients[idx]

        let pricePerWorkout: Double = {
            let total = client.packagePrice ?? 0
            return client.totalSessions > 0 ? total / Double(client.totalSessions) : 0
        }()

        var newWorkout = workout
        newWorkout.price = pricePerWorkout   // 🔥 ВОТ ЭТО КЛЮЧ

        client.workouts.append(newWorkout)

        clients[idx] = client
        saveClient(client)
    }
    
    func removeWorkout(workoutId: UUID, clientId: UUID) {
        guard let cIdx = clients.firstIndex(where: { $0.id == clientId }),
              let wIdx = clients[cIdx].workouts.firstIndex(where: { $0.id == workoutId })
        else { return }
        clients[cIdx].workouts.remove(at: wIdx)
        // Чистим привязанную запись посещаемости, чтобы не осталась «зомби»
        // и не продолжала списывать занятие из абонемента.
        clients[cIdx].attendance.removeAll { $0.workoutId == workoutId }
        saveClient(clients[cIdx])
        // Явное удаление отдельной тренировки — снимаем и из истории
        deleteHistory(recordId: workoutId)
        history.removeAll { $0.id == workoutId }
    }

    func setWorkoutStatus(_ newStatus: WorkoutStatus, workoutId: UUID, for clientId: UUID) {
        guard let idx = clients.firstIndex(where: { $0.id == clientId }),
              let wIdx = clients[idx].workouts.firstIndex(where: { $0.id == workoutId })
        else { return }

        var client = clients[idx]
        let previous = client.workouts[wIdx].status
        client.workouts[wIdx].status = newStatus

        // Учёт посещаемости: только .completed и .noShow списывают занятие.
        // Поддерживаем инвариант «одна запись attendance на workoutId»
        // — upsert при переходе в chargeable, remove при переходе из него.
        let isChargeable = (newStatus == .completed || newStatus == .noShow)
        if isChargeable {
            let wasPresent = (newStatus == .completed)
            let workoutDate = client.workouts[wIdx].date
            if let attIdx = client.attendance.firstIndex(where: { $0.workoutId == workoutId }) {
                client.attendance[attIdx].wasPresent = wasPresent
                client.attendance[attIdx].date = workoutDate
            } else {
                client.attendance.append(AttendanceRecord(
                    date: workoutDate,
                    wasPresent: wasPresent,
                    workoutId: workoutId
                ))
            }
        } else {
            // Переход в .planned или .cancelled — убираем запись посещаемости,
            // если она была создана ранее (из completed/noShow).
            client.attendance.removeAll { $0.workoutId == workoutId }
        }

        clients[idx] = client
        saveClient(client)

        // Архивируем в историю, если статус исторический; иначе убираем из истории.
        if isHistoricalStatus(newStatus) {
            archiveWorkoutToHistory(workout: client.workouts[wIdx], client: client)
        } else if isHistoricalStatus(previous) {
            deleteHistory(recordId: workoutId)
            history.removeAll { $0.id == workoutId }
        }
    }

    func completeWorkout(_ workoutId: UUID, for clientId: UUID) {
        setWorkoutStatus(.completed, workoutId: workoutId, for: clientId)
    }

    func cancelWorkout(_ workoutId: UUID, for clientId: UUID) {
        setWorkoutStatus(.cancelled, workoutId: workoutId, for: clientId)
    }

    func rescheduleWorkout(workoutId: UUID, to newDate: Date) {
        for clientIdx in clients.indices {
            if let wIdx = clients[clientIdx].workouts.firstIndex(where: { $0.id == workoutId }) {
                clients[clientIdx].workouts[wIdx].date = newDate
                saveClient(clients[clientIdx])
                return
            }
        }
    }

    func toggleWorkoutComplete(workoutId: UUID, clientId: UUID) {
        completeWorkout(workoutId, for: clientId)
    }

    func bindingForWorkout(workoutId: UUID, clientId: UUID) -> Binding<Workout> {
        Binding(
            get: {
                guard let cIdx = self.clients.firstIndex(where: { $0.id == clientId }),
                      let wIdx = self.clients[cIdx].workouts.firstIndex(where: { $0.id == workoutId })
                else { return Workout(date: Date(), exercises: []) }
                return self.clients[cIdx].workouts[wIdx]
            },
            set: { newValue in
                guard let cIdx = self.clients.firstIndex(where: { $0.id == clientId }),
                      let wIdx = self.clients[cIdx].workouts.firstIndex(where: { $0.id == workoutId })
                else { return }
                self.clients[cIdx].workouts[wIdx] = newValue
                self.saveClient(self.clients[cIdx])
                // Если редактируем уже исторический — обновим запись в истории
                if self.isHistoricalStatus(newValue.status) {
                    self.archiveWorkoutToHistory(workout: newValue, client: self.clients[cIdx])
                }
            }
        )
    }

    // MARK: - WorkoutRef

    func workoutRefs(on date: Date) -> [WorkoutRef] {
        workoutRefs(matching: { calendar.isDate($0.date, inSameDayAs: date) })
    }

    func workoutRefs(weekContaining date: Date) -> [WorkoutRef] {
        workoutRefs(matching: { calendar.isDate($0.date, equalTo: date, toGranularity: .weekOfYear) })
    }

    func workoutRefs(monthContaining date: Date) -> [WorkoutRef] {
        workoutRefs(matching: { calendar.isDate($0.date, equalTo: date, toGranularity: .month) })
    }

    private let calendar = Calendar.current

    private func workoutRefs(matching predicate: (Workout) -> Bool) -> [WorkoutRef] {
        var result: [WorkoutRef] = []
        for client in clients {
            for workout in client.workouts where predicate(workout) {
                result.append(WorkoutRef(
                    workoutId: workout.id,
                    clientId: client.id,
                    date: workout.date,
                    duration: workout.duration,
                    clientName: client.name,
                    clientColor: client.color,
                    isCompleted: workout.isCompleted,
                    status: workout.status
                ))
            }
        }
        return result.sorted { $0.date < $1.date }
    }

    // MARK: - Абонемент

    struct Subscription: Equatable {
        var totalSessions: Int
        var startDate: Date
        var endDate: Date
        var weekdaySelected: [Bool]
        var trainingTime: Date
        var notes: String
        var packagePrice: Double?
    }

    func addSubscription(_ subscription: Subscription, to clientId: UUID, isExtension: Bool = false) {
        guard let idx = clients.firstIndex(where: { $0.id == clientId }) else { return }
        let sessions = max(1, subscription.totalSessions)
        let dates = Self.workoutDates(
            startDate: subscription.startDate,
            endDate: subscription.endDate,
            maxCount: sessions,
            weekdaySelected: subscription.weekdaySelected,
            trainingTime: subscription.trainingTime,
            calendar: calendar
        )
        let noteTrimmed = subscription.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let perWorkoutPrice: Double = {
            let total = subscription.packagePrice ?? 0
            return sessions > 0 ? total / Double(sessions) : 0
        }()
        var client = clients[idx]
       

        if !isExtension {
            // Новый абонемент
            client.currentSubscriptionId = UUID()
            client.startDate = subscription.startDate
            client.endDate = subscription.endDate
            client.totalSessions = sessions
        } else {
            // Продление
            client.totalSessions += sessions
            client.endDate = max(client.endDate, subscription.endDate)
        }
        // Сохраняем метаданные — пригодятся при редактировании
        client.weekdaySelected = subscription.weekdaySelected
        client.trainingTime = subscription.trainingTime
        client.subscriptionNotes = noteTrimmed.isEmpty ? nil : noteTrimmed
        client.packagePrice = subscription.packagePrice
        for d in dates {
            client.workouts.append(Workout(
                date: d, exercises: [],
                price: perWorkoutPrice,
                notes: noteTrimmed.isEmpty ? nil : noteTrimmed,
                subscriptionId: client.currentSubscriptionId
            ))
        }
        clients[idx] = client
        saveClient(client)
    }

    /// Редактирование существующего абонемента.
    /// Сохраняются проведённые/отменённые/неявки тренировки,
    /// а запланированные перегенерируются из новых настроек.
    func updateSubscription(_ subscription: Subscription, for clientId: UUID) {
        guard let idx = clients.firstIndex(where: { $0.id == clientId }) else { return }
        var client = clients[idx]

        let sessions = max(1, subscription.totalSessions)
        let noteTrimmed = subscription.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let perWorkoutPrice: Double? = {
            guard let p = subscription.packagePrice, sessions > 0 else { return nil }
            return p / Double(sessions)
        }()

        // Сохраняем проведённые/отменённые/неявки тренировки
        let preservedWorkouts = client.workouts.filter { $0.status != .planned }
        let preservedCount = preservedWorkouts.count
        let remainingToPlan = max(0, sessions - preservedCount)

        // Генерируем новые запланированные тренировки
        let newDates = Self.workoutDates(
            startDate: subscription.startDate,
            endDate: subscription.endDate,
            maxCount: remainingToPlan,
            weekdaySelected: subscription.weekdaySelected,
            trainingTime: subscription.trainingTime,
            calendar: calendar
        )

        
        let newPlanned: [Workout] = newDates.map { d in
            Workout(
                date: d, exercises: [],
                price: perWorkoutPrice,
                notes: noteTrimmed.isEmpty ? nil : noteTrimmed,
                subscriptionId: client.currentSubscriptionId
            )
        }

        client.startDate = subscription.startDate
        client.endDate = subscription.endDate
        client.totalSessions = sessions
        client.weekdaySelected = subscription.weekdaySelected
        client.trainingTime = subscription.trainingTime
        client.subscriptionNotes = noteTrimmed.isEmpty ? nil : noteTrimmed
        client.packagePrice = subscription.packagePrice
        client.workouts = preservedWorkouts + newPlanned

        clients[idx] = client
        saveClient(client)
    }

    /// Снимает активный абонемент, удаляя только запланированные тренировки.
    /// Проведённые / отменённые / неявки остаются у клиента и в истории.
    func removeSubscription(for clientId: UUID) {
        guard let idx = clients.firstIndex(where: { $0.id == clientId }) else { return }
        var client = clients[idx]
        client.workouts.removeAll { $0.status == .planned }
        client.totalSessions = 0
        client.startDate = Date.distantPast
        client.endDate = Date.distantPast
        client.weekdaySelected = nil
        client.trainingTime = nil
        client.subscriptionNotes = nil
        client.packagePrice = nil
        clients[idx] = client
        saveClient(client)
    }

    /// Продление абонемента: новые запланированные тренировки добавляются,
    /// старые проведённые / неявки / отменённые — СОХРАНЯЮТСЯ в истории клиента.
    /// Удаляем только прошлые `.planned`, чтобы не было дублей с новыми датами.
    func renewSubscription(for clientId: UUID, subscription: Subscription) {
        guard let idx = clients.firstIndex(where: { $0.id == clientId }) else { return }
        var client = clients[idx]

        let sessions = max(1, subscription.totalSessions)
        let note = subscription.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let perWorkoutPrice: Double? = {
            guard let p = subscription.packagePrice, sessions > 0 else { return nil }
            return p / Double(sessions)
        }()

        // Сохраняем всё, что НЕ запланировано: проведённые, неявки, отменённые.
        let preservedWorkouts = client.workouts.filter { $0.status != .planned }

        // Генерируем новые запланированные тренировки.
        let newDates = Self.workoutDates(
            startDate: subscription.startDate,
            endDate: subscription.endDate,
            maxCount: sessions,
            weekdaySelected: subscription.weekdaySelected,
            trainingTime: subscription.trainingTime,
            calendar: calendar
        )
        // СТАЛО:
        let newPlanned: [Workout] = newDates.map { d in
            Workout(
                date: d, exercises: [],
                price: perWorkoutPrice,
                notes: note.isEmpty ? nil : note,
                subscriptionId: client.currentSubscriptionId
            )
        }

        client.totalSessions = sessions
        client.startDate = subscription.startDate
        client.endDate = subscription.endDate
        client.weekdaySelected = subscription.weekdaySelected
        client.trainingTime = subscription.trainingTime
        client.subscriptionNotes = note.isEmpty ? nil : note
        client.packagePrice = subscription.packagePrice
        client.workouts = preservedWorkouts + newPlanned

        clients[idx] = client
        saveClient(client)
    }

    private static func workoutDates(startDate: Date, endDate: Date, maxCount: Int,
        weekdaySelected: [Bool], trainingTime: Date, calendar: Calendar) -> [Date] {
        guard maxCount > 0, weekdaySelected.count == 7 else { return [] }
        let hour = calendar.component(.hour, from: trainingTime)
        let minute = calendar.component(.minute, from: trainingTime)
        let endCap = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: endDate) ?? endDate
        var results: [Date] = []
        var day = calendar.startOfDay(for: startDate)
        let lastDay = calendar.startOfDay(for: endDate)
        while day <= lastDay && results.count < maxCount {
            let wd = calendar.component(.weekday, from: day)
            if let uiIdx = uiIndex(forCalendarWeekday: wd), weekdaySelected[uiIdx] {
                if let atTime = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) {
                    if atTime >= startDate, atTime <= endCap { results.append(atTime) }
                }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return results
    }

    private static func uiIndex(forCalendarWeekday wd: Int) -> Int? {
        switch wd {
        case 2: return 0; case 3: return 1; case 4: return 2
        case 5: return 3; case 6: return 4; case 7: return 5
        case 1: return 6; default: return nil
        }
    }
}
