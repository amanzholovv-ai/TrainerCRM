import SwiftUI

// MARK: - Slot wrapper (Identifiable для sheet)

struct CalendarSlot: Identifiable {
    let id = UUID()
    let date: Date   // уже содержит нужный час
}

// MARK: - AddWorkoutFromCalendarSheet

struct AddWorkoutFromCalendarSheet: View {
    @ObservedObject var store: ClientStore
    let preselectedDate: Date

    @Environment(\.dismiss) private var dismiss
    @State private var selectedClientId: UUID? = nil
    @State private var date: Date
    @State private var duration: Int = 60
    @State private var status: WorkoutStatus = .planned

    private let durationOptions = [45, 60, 90, 120]

    init(store: ClientStore, preselectedDate: Date) {
        self.store = store
        self.preselectedDate = preselectedDate
        _date = State(initialValue: preselectedDate)
    }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Клиент
                Section("Клиент") {
                    if store.clients.isEmpty {
                        Text("Нет клиентов")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(store.clients) { client in
                            Button {
                                selectedClientId = (selectedClientId == client.id) ? nil : client.id
                            } label: {
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(client.color)
                                        .frame(width: 10, height: 10)
                                    Text(client.name)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if selectedClientId == client.id {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                            .fontWeight(.semibold)
                                    }
                                }
                            }
                        }
                    }
                }

                // MARK: Дата и время
                Section("Дата и время") {
                    DatePicker(
                        "Когда",
                        selection: $date,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }

                // MARK: Длительность
                Section("Длительность") {
                    Picker("Длительность", selection: $duration) {
                        ForEach(durationOptions, id: \.self) { min in
                            Text("\(min) мин").tag(min)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // MARK: Статус
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
                        guard let clientId = selectedClientId else { return }
                        let workout = Workout(
                            date: date,
                            duration: duration,
                            exercises: [],
                            status: status
                        )
                        store.addWorkout(workout, to: clientId)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(selectedClientId == nil)
                }
            }
        }
    }
}
