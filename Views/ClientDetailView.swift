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
    
    // Сортируем один раз — используем везде
    private var sortedWorkouts: [Workout] {
        client.workouts.sorted { $0.date < $1.date }
    }

    var body: some View {
        List {
            
            // MARK: — Клиент
            Section("Клиент") {
                Text(client.name).font(.headline)
                Text(client.phone).foregroundColor(.secondary)
            }
            
            // MARK: — Абонемент
            Section {
                SubscriptionCardView(client: client)
                    .environmentObject(store)
                    .listRowInsets(EdgeInsets())  // убирает отступы List
                
            
                Button("Продлить абонемент") {
                    showRenewalSheet = true
                }
                .buttonStyle(.borderless)
                
                Button("Отправить отчет") {
                    sendReport()
                }
                .buttonStyle(.borderless)
                
                Button("Удалить абонемент", role: .destructive) {
                    store.removeSubscription(for: client.id)
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
                let total = client.workouts.count
                let completed = client.workouts.filter { $0.isCompleted }.count
                let progress = total == 0 ? 0.0 : Double(completed) / Double(total)
                
                Text("Всего тренировок: \(total)")
                Text("Завершено: \(completed)")
                Text("Процент выполнения: \(Int(progress * 100))%")
                ProgressView(value: progress)
                
                if let lastWorkout = sortedWorkouts.last {
                    Text("Последняя: \(lastWorkout.date.formatted(date: .abbreviated, time: .omitted))")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle(client.name)
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .workout:
                AddWorkoutView(onSave: { workout in
                    store.addWorkout(workout, to: client.id)
                })
                
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
        let weekdays: [Bool] = client.weekdaySelected?.count == 7
            ? client.weekdaySelected!
            : [true, false, true, false, true, false, false]
        let time: Date = client.trainingTime
            ?? calendar.date(from: DateComponents(hour: 10, minute: 0))
            ?? today
        return SubscriptionInitialData(
            totalSessions: client.totalSessions > 0 ? client.totalSessions : 10,
            startDate: newStart,
            endDate: newEnd,
            weekdaySelected: weekdays,
            trainingTime: time,
            notes: client.subscriptionNotes ?? "",
            packagePrice: client.packagePrice
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
