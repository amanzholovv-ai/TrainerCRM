import SwiftUI
import UIKit

struct ClientDetailView: View {
    
    enum ActiveSheet {
            case workout
            case subscription
        }
    
    @Binding var client: Client
    @EnvironmentObject var store: ClientStore
    @State private var activeSheet: ActiveSheet?
    @State private var showRenewalSheet = false
    @State private var showHistory = false
    @FocusState private var focusedField: ClientField?

    enum ClientField { case name, phone }

    // Сортируем один раз — используем везде
    private var sortedWorkouts: [Workout] {
        client.workouts.sorted { $0.date < $1.date }
    }

    var body: some View {
        List {
            
            // MARK: — Клиент
            Section("Клиент") {
                TextField("Имя клиента", text: $client.name)
                    .font(.headline)
                    .focused($focusedField, equals: .name)
                    .onSubmit { store.update(client) }
                TextField("Номер телефона", text: $client.phone)
                    .foregroundColor(.secondary)
                    .keyboardType(.phonePad)
                    .focused($focusedField, equals: .phone)
            }
            
            // MARK: — Абонемент
            Section {
                SubscriptionCardView(client: client)
                    .environmentObject(store)
                    .listRowInsets(EdgeInsets())  // убирает отступы List
                
            
                Button {
                    showRenewalSheet = true
                } label: {
                    Label("Продлить абонемент", systemImage: "arrow.clockwise.circle")
                }
                .buttonStyle(.borderless)

                Button {
                    sendReport()
                } label: {
                    Label("Отправить отчет", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.borderless)

                // Показываем только если есть прошлые абонементы
                if !(client.subscriptionHistory ?? []).isEmpty {
                    Button {
                        showHistory = true
                    } label: {
                        Label("История абонементов (\((client.subscriptionHistory ?? []).count))", systemImage: "clock.arrow.circlepath")
                    }
                    .buttonStyle(.borderless)
                }

                Button(role: .destructive) {
                    store.removeSubscription(for: client.id)
                } label: {
                    Label("Удалить абонемент", systemImage: "trash")
                }
                .buttonStyle(.borderless)
            } header: {
                Text("Абонемент")
            }
            
            // MARK: — Тренировки
            Section("Тренировки") {
                Button("Добавить тренировку") {
                    activeSheet = .workout
                }
                
                if client.workouts.isEmpty {
                    Text("Пока нет тренировок")
                        .foregroundColor(.secondary)
                } else {
                    // ✅ ForEach по sortedWorkouts с правильным id
                    ForEach(sortedWorkouts) { workout in
                        if let index = client.workouts.firstIndex(where: { $0.id == workout.id }) {
                            NavigationLink {
                                WorkoutDetailView(
                                    workout: $client.workouts[index],
                                    clientId: client.id,
                                    clientName: client.name
                                )
                                .environmentObject(store)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(workout.date, style: .date)
                                            .font(.subheadline).fontWeight(.semibold)
                                        Text(workout.date, style: .time)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    let status = client.workouts[index].status
                                    let iconColor = workoutStatusIcon(status)
                                    Image(systemName: iconColor.icon)
                                        .foregroundColor(iconColor.color)
                                        .font(.title3)
                                }
                            }
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet.sorted(by: >) {
                            let workout = sortedWorkouts[index]
                            store.removeWorkout(workoutId: workout.id, clientId: client.id)
                        }
                    }
                }
            }
            
            // MARK: — Прогресс
            
            Section("Прогресс") {
                if client.totalSessions > 0 {
                    Text("Занятий по абонементу: \(client.totalSessions)")
                    Text("Проведено: \(client.completedSessions)")
                    if client.noShowSessionsCount > 0 {
                        Text("Неявок: \(client.noShowSessionsCount)")
                            .foregroundColor(.orange)
                    }
                    Text("Остаток: \(client.remainingSessions)")
                        .foregroundColor(client.remainingSessions <= 3 ? .red : .primary)
                    Text("Использовано: \(Int(client.subscriptionProgress * 100))%")
                    ProgressView(value: client.subscriptionProgress)
                        .tint(client.remainingSessions <= 3 ? .red : .accentColor)
                } else {
                    Text("Нет активного абонемента")
                        .foregroundColor(.secondary)
                }

                if let lastWorkout = sortedWorkouts.last(where: { $0.status == .completed }) {
                    Text("Последняя проведённая: \(lastWorkout.date.formatted(date: .abbreviated, time: .omitted))")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle(client.name)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Готово") {
                    focusedField = nil
                    store.update(client)
                }
            }
        }
        .onChange(of: focusedField) { _, newField in
            if newField == nil {
                store.update(client)
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .workout:
                AddWorkoutView(
                    onSave: { workout in
                        store.addWorkout(workout, to: client.id)
                    },
                    hasActiveSubscription: client.totalSessions > 0
                )
                
            case .subscription:
                AddSubscriptionSheet(
                    clientId: client.id,
                    existing: nil
                )
            }
        }
        .sheet(isPresented: $showRenewalSheet) {
            AddSubscriptionSheet(
                clientId: client.id,
                existing: buildRenewalData(),
                isExtension: true
            )
            .environmentObject(store)
        }
        .sheet(isPresented: $showHistory) {
            SubscriptionHistoryView(client: client)
                .environmentObject(store)
        }
    }

    private func workoutStatusIcon(_ status: WorkoutStatus) -> (icon: String, color: Color) {
        switch status {
        case .planned:
            return ("clock", .gray)
        case .completed:
            return ("checkmark.circle.fill", .green)
        case .cancelled:
            return ("xmark.circle.fill", .red)
        case .noShow:
            return ("exclamationmark.triangle.fill", .orange)
        }
    }
    
    func sendReport() {
        let text = generateReportText()

        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)

        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(activityVC, animated: true)
        }
    }
    
    private func buildRenewalData() -> SubscriptionInitialData {
        let calendar = Calendar.current
        let today = Date()
        let newStart = max(today, client.endDate)
        let newEnd = calendar.date(byAdding: .month, value: 1, to: newStart) ?? newStart

        let weekdays: [Bool] = client.weekdaySelected ?? [true, false, true, false, true, false, false]

        let time: Date = client.trainingTime
            ?? calendar.date(from: DateComponents(hour: 10, minute: 0))!
        let totalSessions = client.totalSessions > 0 ? client.totalSessions : 10

        let avgSessionPrice: Double = {
            // 1. из абонемента
            if let package = client.packagePrice,
               client.totalSessions > 0 {
                return package / Double(client.totalSessions)
            }

            // 2. из тренировок
            let prices = client.workouts.compactMap { $0.price }.filter { $0 > 0 }

            if !prices.isEmpty {
                return prices.reduce(0, +) / Double(prices.count)
            }

            // 3. fallback
            return 0
        }()
        
        return SubscriptionInitialData(
            sessionPrice: avgSessionPrice,
            totalSessions: totalSessions,
            startDate: newStart,
            endDate: newEnd,
            weekdaySelected: weekdays,
            trainingTime: time,
            notes: client.subscriptionNotes ?? "",
            packagePrice: avgSessionPrice * Double(totalSessions)
        )
    }
    
    func renewSubscriptionAction() {
        let calendar = Calendar.current
        let today = Date()

        // Стартуем от сегодняшнего дня, либо от текущего endDate если он в будущем
        // (иначе продление «сжимается» к сегодняшней дате — неочевидно для пользователя).
        let newStart = max(today, client.endDate)
        guard let newEnd = calendar.date(byAdding: .month, value: 1, to: newStart) else { return }

        // Если у клиента уже есть расписание — используем его, иначе дефолт Пн/Ср/Пт 10:00.
        let weekdays: [Bool] = client.weekdaySelected?.count == 7
            ? (client.weekdaySelected ?? Array(repeating: false, count: 7))
            : [true, false, true, false, true, false, false]

        let time: Date = client.trainingTime
            ?? calendar.date(from: DateComponents(hour: 10, minute: 0))
            ?? today

        store.addSubscription(
            .init(
                totalSessions: 10,
                startDate: newStart,
                endDate: newEnd,
                weekdaySelected: weekdays,
                trainingTime: time,
                notes: client.subscriptionNotes ?? "",
                packagePrice: client.packagePrice
            ),
            to: client.id,
            isExtension: true // 👈 ВОТ ГЛАВНОЕ
        )
    }

    func generateReportText() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"

        let sortedWorkouts = client.workouts.sorted { $0.date < $1.date }

        var report = "Отчет по тренировкам:\n\n"
        report += "Клиент: \(client.name)\n\n"

        var completedCount = 0
        var missedCount = 0
        var cancelledCount = 0

        for workout in sortedWorkouts {
            let dateString = formatter.string(from: workout.date)

            let statusText: String

            switch workout.status {
            case .completed:
                statusText = "проведено ✅"
                completedCount += 1

            case .noShow:
                statusText = "неявка ❌"
                missedCount += 1

            case .cancelled:
                statusText = "отмена ⚠️"    
                cancelledCount += 1

            case .planned:
                statusText = "запланировано 🗓"
            }

            report += "\(dateString) — \(statusText)\n"
        }

        report += "\nИтого:\n"
        report += "Проведено: \(completedCount)\n"
        report += "Неявки: \(missedCount)\n"
        report += "Отменено: \(cancelledCount)\n"

        report += "\nПродолжай в том же духе 💪"

        return report
    }
    
}

extension ClientDetailView.ActiveSheet: Identifiable {
    var id: Int { hashValue }
}

