import SwiftUI

struct AddWorkoutView: View {
    var onSave: (Workout) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var date = Date()
    @State private var duration = 60
    @State private var status: WorkoutStatus = .planned

    private let durationOptions = [45, 60, 90, 120]

    var body: some View {
        NavigationStack {
            Form {
                Section("Дата и время") {
                    DatePicker(
                        "Когда тренировка",
                        selection: $date,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }

                Section("Длительность") {
                    Picker("Длительность", selection: $duration) {
                        ForEach(durationOptions, id: \.self) { min in
                            Text("\(min) мин").tag(min)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Статус") {
                    Picker("Статус", selection: $status) {
                        ForEach(WorkoutStatus.allCases, id: \.self) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("Новая тренировка")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Сохранить") {
                        let workout = Workout(
                            date: date,
                            duration: duration,
                            exercises: [],
                            status: status
                        )
                        onSave(workout)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
