import SwiftUI

struct RescheduleWorkoutSheet: View {
    @ObservedObject var store: ClientStore
    let clientId: UUID
    let workoutId: UUID
    let clientName: String
    let initialDate: Date

    @Environment(\.dismiss) private var dismiss
    @State private var newDate: Date

    init(store: ClientStore, clientId: UUID, workoutId: UUID, clientName: String, initialDate: Date) {
        self.store = store
        self.clientId = clientId
        self.workoutId = workoutId
        self.clientName = clientName
        self.initialDate = initialDate
        _newDate = State(initialValue: initialDate)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Новая дата и время") {
                    DatePicker(
                        "Когда тренировка",
                        selection: $newDate,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }
            }
            .navigationTitle("Перенести — \(clientName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        store.rescheduleWorkout(workoutId: workoutId, to: newDate)
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }
}

