import SwiftUI

struct AddWorkoutView: View {
    var onSave: (Workout) -> Void
    var hasActiveSubscription: Bool = true  // ← новый параметр

    @Environment(\.dismiss) private var dismiss
    @State private var date = Date()
    @State private var duration = 60
    @State private var status: WorkoutStatus = .planned

    private let durationOptions = [45, 60, 90, 120]

    var body: some View {
        NavigationStack {
            Form {
                // Баннер если нет абонемента
                if !hasActiveSubscription {
                    Section {
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Нет активного абонемента")
                                    .font(.subheadline).fontWeight(.semibold)
                                Text("Тренировка будет создана со статусом «Запланировано»")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

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

                // Статус — только если есть абонемент
                if hasActiveSubscription {
                    Section("Статус") {
                        Picker("Статус", selection: $status) {
                            ForEach(WorkoutStatus.allCases, id: \.self) { s in
                                Text(s.rawValue).tag(s)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
            }
            .navigationTitle("Новая тренировка")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Сохранить") {
                        let finalStatus: WorkoutStatus = hasActiveSubscription ? status : .planned
                        let workout = Workout(
                            date: date,
                            duration: duration,
                            exercises: [],
                            status: finalStatus
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
