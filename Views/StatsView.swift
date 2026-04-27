import SwiftUI

struct StatsView: View {
    @EnvironmentObject var store: ClientStore
    @State private var currentWeek = Date()
    @State private var currentMonth = Date()
    @State private var selectedDay = Date()
    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            Group {
                if store.isLoadingClients {
                    VStack(spacing: 12) {
                        Spacer()
                        ProgressView()
                            .scaleEffect(1.4)
                        Text("Загрузка данных...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if store.clients.isEmpty {
                    EmptyStateView(
                        icon: "chart.bar",
                        title: "Нет данных",
                        subtitle: "Добавьте клиентов и проведите первые тренировки — здесь появится статистика"
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            summaryCards
                            workloadChart
                            subscriptionStatus
                            topClients
                        }
                        .padding(16)
                    }
                    .background(Color(.systemGroupedBackground))
                }
            }
            .navigationTitle("Статистика")
            .onAppear {
                currentMonth = Date()
                selectedDay = Date()
            }
            .background(Color(.systemGroupedBackground))
        }
    }

    // MARK: - Переключатель месяца

    private var monthPicker: some View {
        HStack {
            Button {
                currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
            } label: {
                Image(systemName: "chevron.left").fontWeight(.semibold)
            }

            Spacer()

            Text(currentMonth, format: .dateTime.year().month(.wide))
                .font(.headline)

            Spacer()

            Button {
                currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
            } label: {
                Image(systemName: "chevron.right").fontWeight(.semibold)
            }
        }
        .padding(.horizontal, 8)
    }

    // MARK: - Главные цифры

    private var summaryCards: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button {
                    selectedDay = calendar.date(byAdding: .day, value: -1, to: selectedDay) ?? selectedDay
                } label: {
                    Image(systemName: "chevron.left").fontWeight(.semibold)
                }
                Spacer()
                Text(calendar.isDateInToday(selectedDay)
                     ? "Сегодня"
                     : selectedDay.formatted(.dateTime.day().month().year()))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Spacer()
                Button {
                    selectedDay = calendar.date(byAdding: .day, value: 1, to: selectedDay) ?? selectedDay
                } label: {
                    Image(systemName: "chevron.right").fontWeight(.semibold)
                }
            }
            .padding(.horizontal, 4)

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                spacing: 12
            ) {
                StatBigCard(
                    title: "Клиентов",
                    value: "\(todayClientsCount)",
                    subtitle: calendar.isDateInToday(selectedDay) ? "сегодня" : "за день",
                    icon: "person.2.fill",
                    color: .blue
                )
                StatBigCard(
                    title: "Часов",
                    value: formattedHours(todayChargeableHours),
                    subtitle: "отработано",
                    icon: "clock.fill",
                    color: .orange
                )
                StatBigCard(
                    title: "Заработано",
                    value: compactMoney(todayChargeableIncome),
                    subtitle: calendar.isDateInToday(selectedDay) ? "сегодня" : "за день",
                    icon: "banknote.fill",
                    color: .green
                )
            }

            sectionHeader("За месяц").padding(.top, 4)

            HStack {
                    Button {
                        currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
                    } label: {
                        Image(systemName: "chevron.left").fontWeight(.semibold)
                    }
                    Spacer()
                    Text(currentMonth, format: .dateTime.year().month(.wide))
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Button {
                        currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
                    } label: {
                        Image(systemName: "chevron.right").fontWeight(.semibold)
                    }
                }
                .padding(.horizontal, 4)

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                spacing: 12
            ) {
                StatBigCard(
                    title: "Абонементов",
                    value: "\(activeSubscriptionsCount)",
                    subtitle: "активных",
                    icon: "ticket.fill",
                    color: .teal
                )   
                StatBigCard(
                    title: "Часов",
                    value: formattedHours(monthChargeableHours),
                    subtitle: "отработано",
                    icon: "clock.fill",
                    color: .orange
                )
                StatBigCard(
                    title: "Заработано",
                    value: compactMoney(monthChargeableIncome),
                    subtitle: "за месяц",
                    icon: "banknote.fill",
                    color: .green
                )
                
            }
        }
    }

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(.secondary)
            .textCase(.uppercase)
            .tracking(0.5)
    }
    
    private var activeSubscriptionsCount: Int {
        store.clients.filter {
            $0.subscriptionStatus == .active || $0.subscriptionStatus == .low
        }.count
    }
    // MARK: - Загрузка по дням недели

    private var workloadChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Загрузка по неделям")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)

            // Переключатель недели
            HStack {
                Button {
                    currentWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: currentWeek) ?? currentWeek
                } label: {
                    Image(systemName: "chevron.left").fontWeight(.semibold)
                }

                Spacer()

                Text(weekRangeLabel)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                Button {
                    currentWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: currentWeek) ?? currentWeek
                } label: {
                    Image(systemName: "chevron.right").fontWeight(.semibold)
                }
            }
            .padding(.horizontal, 4)

            let dayNames = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]
            let counts = workoutsPerWeekday
            let maxCount = counts.max() ?? 1

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(0..<7, id: \.self) { i in
                    VStack(spacing: 4) {
                        Text("\(counts[i])")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(counts[i] > 0 ? .primary : .secondary)

                        RoundedRectangle(cornerRadius: 6)
                            .fill(counts[i] > 0 ? Color.accentColor : Color(.systemFill))
                            .frame(
                                height: maxCount > 0
                                    ? max(8, CGFloat(counts[i]) / CGFloat(maxCount) * 80)
                                    : 8
                            )

                        Text(dayNames[i])
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(16)
            .background(Color(.systemBackground))
            .cornerRadius(14)
        }
    }
    // MARK: - Статус абонементов

    private var subscriptionStatus: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Абонементы клиентов")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)

            VStack(spacing: 8) {
                ForEach(store.clients) { client in
                    HStack(spacing: 12) {
                        // Инициалы
                        ZStack {
                            Circle()
                                .fill(client.subscriptionStatus.swiftUIColor.opacity(0.15))
                                .frame(width: 36, height: 36)
                            Text(initials(client.name))
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(client.subscriptionStatus.swiftUIColor)
                        }
                      
                        VStack(alignment: .leading, spacing: 2) {
                            Text(client.name)
                                .font(.system(size: 14, weight: .semibold))
                            
                            if client.totalSessions > 0 {
                                Text("Истекает: \(shortDate(client.endDate))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(client.remainingSessions) зан.")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(client.subscriptionStatus.swiftUIColor)
                            Text(client.subscriptionStatus.label)
                                .font(.system(size: 10, weight: .semibold))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(client.subscriptionStatus.swiftUIColor.opacity(0.12))
                                .foregroundColor(client.subscriptionStatus.swiftUIColor)
                                .cornerRadius(20)
                        }
                    }
                    .padding(12)
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                }
            }
        }
    }

    // MARK: - Топ клиенты

    private var topClients: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Топ клиенты в этом месяце")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)

            let ranked = clientWorkoutCounts.sorted { $0.value > $1.value }

            if ranked.isEmpty {
                Text("Тренировок в этом месяце нет")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(20)
                    .background(Color(.systemBackground))
                    .cornerRadius(14)
            } else {
                VStack(spacing: 0) {
                    let clientsById = Dictionary(uniqueKeysWithValues: store.clients.map { ($0.id, $0) })
                    ForEach(Array(ranked.prefix(5).enumerated()), id: \.element.key) { i, pair in
                        let client = clientsById[pair.key]
                        let name = client?.name ?? "—"
                        HStack(spacing: 12) {
                            Text("\(i + 1)")
                                .font(.system(size: 14, weight: .black))
                                .foregroundColor(.secondary)
                                .frame(width: 20)

                            Text(name)
                                .font(.system(size: 14, weight: .semibold))

                            Spacer()

                            Text("\(pair.value) тр.")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.accentColor)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)

                        if i < ranked.prefix(5).count - 1 {
                            Divider().padding(.leading, 46)
                        }
                    }
                }
                .background(Color(.systemBackground))
                .cornerRadius(14)
            }
        }
    }

    // MARK: - Вычисляемые данные

    /// Все тренировки месяца (любой статус) — используется для графиков загрузки и топ-клиентов.
    private var monthWorkouts: [Workout] {
        store.clients.flatMap { client in
            client.workouts.filter {
                calendar.isDate($0.date, equalTo: currentMonth, toGranularity: .month)
            }
        }
    }

    /// «Зачётные» тренировки — только проведённые и неявки. Отмены/переносы (план) исключены.
    private func isChargeable(_ workout: Workout) -> Bool {
        workout.status == .completed || workout.status == .noShow
    }

    private var todayChargeableWorkouts: [Workout] {
        store.clients.flatMap { client in
            client.workouts.filter {
                calendar.isDate($0.date, inSameDayAs: selectedDay) && self.isChargeable($0)
            }
        }
    }

    private var monthChargeableWorkouts: [Workout] {
        store.clients.flatMap { client in
            client.workouts.filter {
                calendar.isDate($0.date, equalTo: currentMonth, toGranularity: .month) &&
                self.isChargeable($0)
            }
        }
    }

    private var todayChargeableCount: Int { todayChargeableWorkouts.count }

    private var todayClientsCount: Int {
        let clientIds = store.clients.flatMap { client in
            client.workouts.filter {
                calendar.isDate($0.date, inSameDayAs: selectedDay) && $0.status == .completed
            }.map { _ in client.id }
        }
        return Set(clientIds).count
    }

    private var todayChargeableHours: Double {
        let completed = store.clients.flatMap { client in
            client.workouts.filter {
                calendar.isDate($0.date, inSameDayAs: selectedDay) && $0.status == .completed
            }
        }
        let uniqueHours = Set(completed.map { calendar.component(.hour, from: $0.date) })
        return Double(uniqueHours.count)
    }

    private var todayChargeableIncome: Double {
        todayChargeableWorkouts.reduce(0.0) { $0 + ($1.price ?? 0) }
    }

    private var monthChargeableHours: Double {
        let completed = store.clients.flatMap { client in
            client.workouts.filter {
                calendar.isDate($0.date, equalTo: currentMonth, toGranularity: .month) &&
                $0.status == .completed
            }
        }
        // Уникальные слоты: (день, час) — два клиента в один час = 1 час
        let uniqueSlots = Set(completed.map { workout -> String in
            let day  = calendar.component(.day,  from: workout.date)
            let hour = calendar.component(.hour, from: workout.date)
            return "\(day)-\(hour)"
        })
        return Double(uniqueSlots.count)
    }

    private var monthChargeableIncome: Double {
        monthChargeableWorkouts.reduce(0.0) { $0 + ($1.price ?? 0) }
    }

    private func compactMoney(_ value: Double) -> String {
        if value == 0 { return "0" }
        if value >= 1_000_000 {
            let m = value / 1_000_000
            return m.truncatingRemainder(dividingBy: 1) == 0
                ? String(format: "%.0fM", m)
                : String(format: "%.1fM", m)
        } else if value >= 1000 {
            let k = value / 1000
            return k.truncatingRemainder(dividingBy: 1) == 0
                ? String(format: "%.0fK", k)
                : String(format: "%.1fK", k)
        }
        return String(format: "%.0f", value)
    }

    private func formattedHours(_ hours: Double) -> String {
        if hours == 0 { return "0" }
        return hours.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", hours)
            : String(format: "%.1f", hours)
    }
    
    private var weekRangeLabel: String {
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: currentWeek) else { return "" }
        let start = weekInterval.start
        let end = calendar.date(byAdding: .day, value: 6, to: start) ?? start
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "ru_RU")
        fmt.dateFormat = "d MMM"
        return "\(fmt.string(from: start)) – \(fmt.string(from: end))"
    }
    
    // Кол-во тренировок по дням недели (Пн=0 ... Вс=6)
    private var workoutsPerWeekday: [Int] {
        var counts = Array(repeating: 0, count: 7)
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: currentWeek) else { return counts }

        // Считаем только реально проведённые: .completed и .noShow
        // Отменённые и запланированные не учитываются — они не были проведены
        let weekWorkouts = store.clients.flatMap { client in
            client.workouts.filter {
                $0.date >= weekInterval.start &&
                $0.date < weekInterval.end &&
                ($0.status == .completed || $0.status == .noShow)
            }
        }
        for workout in weekWorkouts {
            let weekday = calendar.component(.weekday, from: workout.date)
            let idx = (weekday + 5) % 7
            counts[idx] += 1
        }
        return counts
    }

    private var clientWorkoutCounts: [UUID: Int] {
        var result: [UUID: Int] = [:]
        for client in store.clients {
            
            let count = client.workouts.filter {
                $0.status == .completed &&
                calendar.isDate($0.date, equalTo: currentMonth, toGranularity: .month)
            }.count
            if count > 0 { result[client.id] = count }
        }
        return result
    }

    private func initials(_ name: String) -> String {
        name.components(separatedBy: " ")
            .compactMap { $0.first.map(String.init) }
            .joined()
    }

    private func shortDate(_ date: Date) -> String {
        guard date > Date(timeIntervalSince1970: 0) else { return "" }
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "ru_RU")
        fmt.dateFormat = "d MMM yyyy"
        return fmt.string(from: date)
    }
}

// MARK: - StatBigCard

struct StatBigCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
                Spacer()
            }
            Text(value)
                .font(.system(size: 26, weight: .black))
                .foregroundColor(color)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(14)
        .background(Color(.systemBackground))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(color.opacity(0.2), lineWidth: 1))
    }
}
