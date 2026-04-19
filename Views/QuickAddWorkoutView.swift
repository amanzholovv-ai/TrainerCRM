import SwiftUI

/// Быстрое добавление тренировки из таймлайна дня
struct QuickAddWorkoutView: View {
    let hour: Int
    let date: Date

    @EnvironmentObject var store: ClientStore
    @Environment(\.dismiss) private var dismiss

    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            List {
                if store.clients.isEmpty {
                    ContentUnavailableView(
                        "Нет клиентов",
                        systemImage: "person.2.slash",
                        description: Text("Добавь клиента в разделе «Клиенты»")
                    )
                } else {
                    ForEach(store.clients) { client in
                        Button {
                            addWorkout(for: client)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(client.color)
                                    .frame(width: 12, height: 12)
                                Text(client.name)
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(String(format: "%02d:00", hour))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
            }
        }
    }

    private func addWorkout(for client: Client) {
        let workoutDate = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: date) ?? date
        let workout = Workout(date: workoutDate, exercises: [])
        store.addWorkout(workout, to: client.id)
    }
}
