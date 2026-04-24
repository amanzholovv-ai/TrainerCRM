import SwiftUI

struct QuickAddWorkoutView: View {
    let hour: Int
    let date: Date

    @EnvironmentObject var store: ClientStore
    @Environment(\.dismiss) private var dismiss

    @State private var pendingClient: Client? = nil

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
                            if client.totalSessions == 0 {
                                pendingClient = client
                            } else {
                                addWorkout(for: client)
                                dismiss()
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(client.color)
                                    .frame(width: 12, height: 12)
                                Text(client.name)
                                    .foregroundColor(.primary)
                                Spacer()
                                if client.totalSessions == 0 {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                        .font(.caption)
                                }
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
            .alert("Нет абонемента", isPresented: Binding(
                get: { pendingClient != nil },
                set: { if !$0 { pendingClient = nil } }
            )) {
                Button("Всё равно добавить") {
                    if let client = pendingClient {
                        addWorkout(for: client)
                    }
                    dismiss()
                }
                Button("Отмена", role: .cancel) {
                    pendingClient = nil
                }
            } message: {
                Text("У клиента «\(pendingClient?.name ?? "")» нет активного абонемента. Тренировка будет создана как запланированная.")
            }
        }
    }

    private func addWorkout(for client: Client) {
        let workoutDate = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: date) ?? date
        let workout = Workout(date: workoutDate, exercises: [])
        store.addWorkout(workout, to: client.id)
    }
}
