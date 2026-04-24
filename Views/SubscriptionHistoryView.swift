import SwiftUI

// MARK: - Список прошлых абонементов

struct SubscriptionHistoryView: View {
    let client: Client
    @EnvironmentObject var store: ClientStore
    @State private var recordToDelete: SubscriptionRecord?

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM yyyy"
        f.locale = Locale(identifier: "ru_RU")
        return f
    }()

    /// Берём актуального клиента из store, чтобы список обновлялся после удаления
    private var currentClient: Client {
        store.clients.first { $0.id == client.id } ?? client
    }

    private var sortedHistory: [SubscriptionRecord] {
        (currentClient.subscriptionHistory ?? []).sorted { $0.startDate > $1.startDate }
    }

    var body: some View {
        NavigationStack {
            Group {
                if sortedHistory.isEmpty {
                    ContentUnavailableView(
                        "Нет истории",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Прошлые абонементы появятся здесь после создания нового")
                    )
                } else {
                    List(sortedHistory) { record in
                        NavigationLink {
                            SubscriptionHistoryDetailView(
                                record: record,
                                client: currentClient
                            )
                        } label: {
                            SubscriptionHistoryRow(
                                record: record,
                                workouts: workouts(for: record),
                                formatter: dateFormatter
                            )
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                recordToDelete = record
                            } label: {
                                Label("Удалить", systemImage: "trash")
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("История абонементов")
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog(
                "Удалить запись из истории?",
                isPresented: Binding(
                    get: { recordToDelete != nil },
                    set: { if !$0 { recordToDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Удалить", role: .destructive) {
                    if let record = recordToDelete {
                        store.removeSubscriptionRecord(recordId: record.id, for: client.id)
                    }
                    recordToDelete = nil
                }
                Button("Отмена", role: .cancel) { recordToDelete = nil }
            } message: {
                Text("Запись будет удалена без возможности восстановления.")
            }
        }
    }

    private func workouts(for record: SubscriptionRecord) -> [Workout] {
        currentClient.workouts.filter { $0.subscriptionId == record.id }
    }
}

// MARK: - Строка абонемента в списке

private struct SubscriptionHistoryRow: View {
    let record: SubscriptionRecord
    let workouts: [Workout]
    let formatter: DateFormatter

    private var completedCount: Int { workouts.filter { $0.status == .completed }.count }
    private var noShowCount: Int    { workouts.filter { $0.status == .noShow    }.count }
    private var cancelledCount: Int { workouts.filter { $0.status == .cancelled }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Период
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(formatter.string(from: record.startDate)) – \(formatter.string(from: record.endDate))")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            // Статистика
            HStack(spacing: 12) {
                Label("\(record.totalSessions) занятий", systemImage: "list.number")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if completedCount > 0 {
                    Label("\(completedCount)", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                if noShowCount > 0 {
                    Label("\(noShowCount)", systemImage: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                if cancelledCount > 0 {
                    Label("\(cancelledCount)", systemImage: "minus.circle.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            // Стоимость абонемента
            if let price = record.packagePrice, price > 0 {
                Text(price, format: .currency(code: "KZT").precision(.fractionLength(0)))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Детальный экран одного абонемента

struct SubscriptionHistoryDetailView: View {
    let record: SubscriptionRecord
    let client: Client

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        f.locale = Locale(identifier: "ru_RU")
        return f
    }()

    /// Тренировки этого абонемента, отсортированные по дате
    private var subscriptionWorkouts: [Workout] {
        client.workouts
            .filter { $0.subscriptionId == record.id }
            .sorted { $0.date < $1.date }
    }

    private var completedCount: Int { subscriptionWorkouts.filter { $0.status == .completed }.count }
    private var noShowCount: Int    { subscriptionWorkouts.filter { $0.status == .noShow    }.count }
    private var cancelledCount: Int { subscriptionWorkouts.filter { $0.status == .cancelled }.count }

    var body: some View {
        List {
            // MARK: Сводка по абонементу
            Section("Абонемент") {
                periodRow
                statsRow

                if let price = record.packagePrice, price > 0 {
                    LabeledContent("Стоимость") {
                        Text(price, format: .currency(code: "KZT").precision(.fractionLength(0)))
                            .foregroundColor(.secondary)
                    }
                }
                if let notes = record.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // MARK: Тренировки
            Section("Тренировки") {
                if subscriptionWorkouts.isEmpty {
                    Text("Нет тренировок в этом абонементе")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(subscriptionWorkouts) { workout in
                        WorkoutHistoryRow(workout: workout, formatter: dateFormatter)
                    }
                }
            }

            // MARK: Отчёт
            Section {
                Button {
                    sendReport()
                } label: {
                    Label("Отправить отчёт за этот абонемент", systemImage: "square.and.arrow.up")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(periodTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Subviews

    private var periodTitle: String {
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        f.locale = Locale(identifier: "ru_RU")
        return "\(f.string(from: record.startDate)) – \(f.string(from: record.endDate))"
    }

    private var periodRow: some View {
        LabeledContent("Период") {
            Text(periodTitle)
                .foregroundColor(.secondary)
        }
    }

    private var statsRow: some View {
        HStack(spacing: 16) {
            statBadge(count: completedCount, icon: "checkmark.circle.fill", color: .green,  label: "Проведено")
            statBadge(count: noShowCount,    icon: "xmark.circle.fill",     color: .red,    label: "Неявки")
            statBadge(count: cancelledCount, icon: "minus.circle.fill",     color: .orange, label: "Отмены")
        }
        .padding(.vertical, 4)
    }

    private func statBadge(count: Int, icon: String, color: Color, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(count > 0 ? color : .secondary.opacity(0.4))
            Text("\(count)")
                .font(.headline)
                .foregroundColor(count > 0 ? .primary : .secondary)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Отчёт

    private func sendReport() {
        let text = generateReportText()
        let vc = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(vc, animated: true)
        }
    }

    private func generateReportText() -> String {
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        f.locale = Locale(identifier: "ru_RU")

        var text = "Отчёт по абонементу\n\n"
        text += "Клиент: \(client.name)\n"
        text += "Период: \(periodTitle)\n\n"

        for workout in subscriptionWorkouts {
            let dateStr = f.string(from: workout.date)
            let statusStr: String
            switch workout.status {
            case .completed: statusStr = "✅ проведено"
            case .noShow:    statusStr = "❌ неявка"
            case .cancelled: statusStr = "⚠️ отмена"
            case .planned:   statusStr = "📅 запланировано"
            }
            text += "\(dateStr) — \(statusStr)\n"
        }

        text += "\nИтого:\n"
        text += "✅ Проведено: \(completedCount)\n"
        if noShowCount > 0    { text += "❌ Неявки: \(noShowCount)\n" }
        if cancelledCount > 0 { text += "⚠️ Отмены: \(cancelledCount)\n" }

        if let price = record.packagePrice, price > 0 {
            let priceStr = String(format: "%.0f ₸", price)
            text += "\nСтоимость абонемента: \(priceStr)"
        }
        return text
    }
}

// MARK: - Строка тренировки

private struct WorkoutHistoryRow: View {
    let workout: Workout
    let formatter: DateFormatter

    var body: some View {
        HStack {
            Text(formatter.string(from: workout.date))
                .font(.subheadline)
                .foregroundColor(.primary)

            Text(workout.date, style: .time)
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            statusIcon
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch workout.status {
        case .completed:
            Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
        case .noShow:
            Image(systemName: "xmark.circle.fill").foregroundColor(.red)
        case .cancelled:
            Image(systemName: "minus.circle.fill").foregroundColor(.orange)
        case .planned:
            Image(systemName: "clock").foregroundColor(.gray)
        }
    }
}
