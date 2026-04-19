import SwiftUI

struct TodayWorkoutsView: View {
    @EnvironmentObject var store: ClientStore

    private struct TodayWorkoutRef: Identifiable {
        let id: UUID        // workout.id
        let clientId: UUID  // ✅ UUID вместо clientIndex
        let date: Date
        let clientName: String
        let exerciseCount: Int
    }

    private var todayWorkouts: [TodayWorkoutRef] {
        var result: [TodayWorkoutRef] = []
        for client in store.clients {
            for workout in client.workouts where Calendar.current.isDateInToday(workout.date) {
                result.append(
                    TodayWorkoutRef(
                        id: workout.id,
                        clientId: client.id,  // ✅ UUID
                        date: workout.date,
                        clientName: client.name,
                        exerciseCount: workout.exercises.count
                    )
                )
            }
        }
        return result.sorted { $0.date < $1.date }
    }

    var body: some View {
        NavigationStack {
            List {
                if todayWorkouts.isEmpty {
                    ContentUnavailableView(
                        "Сегодня нет тренировок",
                        systemImage: "calendar.badge.exclamationmark",
                        description: Text("Добавь тренировку клиенту в карточке клиента")
                    )
                } else {
                    ForEach(todayWorkouts) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.clientName)
                                    .font(.headline)
                                Text(item.date, style: .time)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text("\(item.exerciseCount)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .onDelete(perform: deleteTodayWorkout)
                }
            }
            .navigationTitle("Сегодня")
            .toolbar { EditButton() }
        }
    }

    private func deleteTodayWorkout(at offsets: IndexSet) {
        let items = todayWorkouts
        for offset in offsets {
            let item = items[offset]
            store.removeWorkout(workoutId: item.id, clientId: item.clientId)  // ✅
        }
    }
}
