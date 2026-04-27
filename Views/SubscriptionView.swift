import SwiftUI

// MARK: - Карточка абонемента (встраивается в ClientDetailView)

struct SubscriptionCardView: View {
    let client: Client
    @EnvironmentObject var store: ClientStore
    @State private var showAddSheet = false
    @State private var showEditSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if client.totalSessions > 0 {
                activeCard
            } else {
                noSubscriptionCard
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddSubscriptionSheet(clientId: client.id, existing: nil)
                .environmentObject(store)
        }
        .sheet(isPresented: $showEditSheet) {
            AddSubscriptionSheet(
                clientId: client.id,
                existing: buildInitialData()
            )
            .environmentObject(store)
        }
    }

    // Собирает начальные данные для формы редактирования.
    // Если метаданные сохранены на клиенте — берёт их.
    // Иначе пытается восстановить из уже запланированных тренировок.
    private func buildInitialData() -> SubscriptionInitialData {
        let calendar = Calendar.current
        let planned = client.workouts.filter { $0.status == .planned }.sorted { $0.date < $1.date }

        let weekdays: [Bool] = {
            if let saved = client.weekdaySelected, saved.count == 7 { return saved }
            var wd = Array(repeating: false, count: 7)
            for w in planned {
                let cal = calendar.component(.weekday, from: w.date)
                if let ui = uiIndex(forCalendarWeekday: cal) {
                    wd[ui] = true
                }
            }
            return wd
        }()

        let time: Date = {
            if let saved = client.trainingTime { return saved }
            if let first = planned.first {
                let h = calendar.component(.hour, from: first.date)
                let m = calendar.component(.minute, from: first.date)
                return calendar.date(from: DateComponents(hour: h, minute: m)) ?? first.date
            }
            return calendar.date(from: DateComponents(hour: 10, minute: 0)) ?? Date()
        }()

        let notes: String = {
            if let saved = client.subscriptionNotes { return saved }
            return planned.first?.notes ?? ""
        }()

        let price: Double? = {
            if let saved = client.packagePrice { return saved }
            // Ищем цену в любой тренировке — не только запланированной
            let anyWorkout = client.workouts.first { $0.price != nil && $0.price != 0 }
            if let per = anyWorkout?.price, client.totalSessions > 0 {
                return per * Double(client.totalSessions)
            }
            return nil
        }()

        return SubscriptionInitialData(
            sessionPrice: (price ?? 0) / Double(max(client.totalSessions, 1)),
            totalSessions: client.totalSessions,
            startDate: client.startDate,
            endDate: client.endDate,
            weekdaySelected: weekdays,
            trainingTime: time,
            notes: notes,
            packagePrice: price
        )
    }

    private func uiIndex(forCalendarWeekday wd: Int) -> Int? {
        switch wd {
        case 2: return 0; case 3: return 1; case 4: return 2
        case 5: return 3; case 6: return 4; case 7: return 5
        case 1: return 6; default: return nil
        }
    }

    // MARK: - Активный абонемент

    private var activeCard: some View {
        VStack(alignment: .leading, spacing: 14) {

            // Статус
            HStack {
                Text("Абонемент")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.8)
                Spacer()
                HStack(spacing: 5) {
                    Image(systemName: client.subscriptionStatus.icon)
                        .font(.system(size: 12))
                    Text(client.subscriptionStatus.label)
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(client.subscriptionStatus.swiftUIColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(client.subscriptionStatus.swiftUIColor.opacity(0.12))
                .cornerRadius(20)
            }

            // Главные цифры
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("Осталось")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                Text("\(client.remainingSessions)")
                    .font(.system(size: 32, weight: .black))
                    .foregroundColor(client.subscriptionStatus.swiftUIColor)
                Text("из \(client.totalSessions)")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
            }

            // Прогресс-бар
            VStack(alignment: .leading, spacing: 6) {
                ProgressView(value: client.subscriptionProgress)
                    .tint(client.subscriptionStatus.swiftUIColor)
                    .scaleEffect(x: 1, y: 2, anchor: .center)

                HStack {
                    Text("Проведено: \(client.completedSessions)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int((client.subscriptionProgress * 100).rounded()))%")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(client.subscriptionStatus.swiftUIColor)
                }
            }

            Divider()

            // Даты
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Начало")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    Text(formatDate(client.startDate))
                        .font(.system(size: 13, weight: .semibold))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text("Истекает")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    Text(formatDate(client.endDate))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(client.endDate < Date() ? .red : .primary)
                }
            }

            // Кнопка редактирования
            Button { showEditSheet = true } label: {
                HStack {
                    Image(systemName: "pencil")
                    Text("Редактировать абонемент")
                }
                .font(.system(size: 14, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(Color.accentColor.opacity(0.12))
                .foregroundColor(.accentColor)
                .cornerRadius(10)
            }
        }
        .padding(18)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(client.subscriptionStatus.swiftUIColor.opacity(0.3), lineWidth: 1.5)
        )
        // Убрали тап-по-всей-карточке: он конфликтовал с кнопками Section
        // в ClientDetailView. Для редактирования используется явная кнопка
        // «Редактировать абонемент» ниже.
    }

    // MARK: - Нет абонемента

    private var noSubscriptionCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "ticket")
                .font(.system(size: 28))
                .foregroundColor(.secondary)
            
            Text("Нет активного абонемента")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.primary)
            Text("Оформите абонемент, чтобы начать тренировки")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button { showAddSheet = true } label: {
                Text("Оформить абонемент")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.separator).opacity(0.4), lineWidth: 1)
        )
    }

    private func formatDate(_ date: Date) -> String {
        guard date > Date(timeIntervalSince1970: 0) else { return "—" }
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "ru_RU")
        fmt.dateFormat = "d MMM yyyy"
        return fmt.string(from: date)
    }
}

// MARK: - Начальные данные для формы (используются в режиме редактирования)

struct SubscriptionInitialData {
    let sessionPrice: Double
    var totalSessions: Int
    var startDate: Date
    var endDate: Date
    var weekdaySelected: [Bool]
    var trainingTime: Date
    var notes: String
    var packagePrice: Double?
}

// MARK: - Шит оформления / редактирования абонемента

struct AddSubscriptionSheet: View {
    let clientId: UUID
    let existing: SubscriptionInitialData?
    let isExtension: Bool

    @EnvironmentObject var store: ClientStore
    @Environment(\.dismiss) var dismiss

    @State private var totalSessions: Int
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var packagePriceText: String
    @State private var trainingTime: Date
    @State private var weekdaySelected: [Bool]
    @State private var subscriptionNotes: String

    private var isEditing: Bool { existing != nil }

    
    init(clientId: UUID, existing: SubscriptionInitialData?, isExtension: Bool = false) {
        self.clientId = clientId
        self.isExtension = isExtension
        self.existing = existing
        if let e = existing {
            _totalSessions = State(initialValue: e.totalSessions)
            _startDate = State(initialValue: e.startDate)
            _endDate = State(initialValue: e.endDate)
            _trainingTime = State(initialValue: e.trainingTime)
            _weekdaySelected = State(initialValue: e.weekdaySelected.count == 7 ? e.weekdaySelected : Array(repeating: false, count: 7))
            _subscriptionNotes = State(initialValue: e.notes)
            if let price = e.packagePrice {
                let f = NumberFormatter()
                f.locale = Locale(identifier: "ru_RU")
                f.numberStyle = .decimal
                f.maximumFractionDigits = 2
                _packagePriceText = State(initialValue: f.string(from: NSNumber(value: price)) ?? String(price))
            } else {
                _packagePriceText = State(initialValue: "")
            }
        } else {
            _totalSessions = State(initialValue: 12)
            _startDate = State(initialValue: Date())
            _endDate = State(initialValue: Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date())
            _trainingTime = State(initialValue: Calendar.current.date(from: DateComponents(hour: 10, minute: 0)) ?? Date())
            _weekdaySelected = State(initialValue: Array(repeating: false, count: 7))
            _subscriptionNotes = State(initialValue: "")
            _packagePriceText = State(initialValue: "")
        }
    }

    private let sessionPresets = [8, 10, 12, 16]
    private let weekdayShortLabels = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]

    private var packagePriceValue: Double? {
        // Сначала пробуем NumberFormatter с ru_RU — он корректно читает "54 800" и "54 800,50"
        let ruFormatter = NumberFormatter()
        ruFormatter.locale = Locale(identifier: "ru_RU")
        ruFormatter.numberStyle = .decimal
        if let n = ruFormatter.number(from: packagePriceText), n.doubleValue >= 0 {
            return n.doubleValue
        }
        // Fallback: убираем пробелы (включая неразрывные), заменяем запятую на точку
        let stripped = packagePriceText
            .components(separatedBy: CharacterSet.whitespaces)
            .joined()
            .replacingOccurrences(of: "\u{00A0}", with: "")
            .replacingOccurrences(of: ",", with: ".")
        guard !stripped.isEmpty, let v = Double(stripped), v >= 0 else { return nil }
        return v
    }

    private var pricePerSessionText: String {
        guard totalSessions > 0, let total = packagePriceValue else { return "—" }
        let per = total / Double(totalSessions)
        let f = NumberFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.numberStyle = .decimal
        f.maximumFractionDigits = 2
        return f.string(from: NSNumber(value: per)) ?? String(format: "%.2f", per)
    }
    
    private var datesAreValid: Bool {
        endDate >= startDate
    }

    private var canSave: Bool {
        guard let price = packagePriceValue else { return false }
        return price > 0 && totalSessions > 0 && datesAreValid
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Количество занятий") {
                    HStack(spacing: 8) {
                        ForEach(sessionPresets, id: \.self) { n in
                            Button {
                                totalSessions = n
                            } label: {
                                Text("\(n)")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(totalSessions == n ? Color.accentColor.opacity(0.2) : Color(.systemGray5))
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                        Button {
                            totalSessions += 1
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .symbolRenderingMode(.hierarchical)
                        }
                        .buttonStyle(.plain)
                    }
                    Text("Всего: \(totalSessions) занятий")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Section("Период") {
                    DatePicker("Начало", selection: $startDate, displayedComponents: .date)
                        .onChange(of: startDate) { _, newStart in
                            // Если начало переехало позже конца — сдвигаем конец
                            if endDate < newStart {
                                endDate = Calendar.current.date(byAdding: .month, value: 1, to: newStart) ?? newStart
                            }
                        }
                    DatePicker("Истекает", selection: $endDate, in: startDate..., displayedComponents: .date)
                    if !datesAreValid {
                        Text("Дата окончания не может быть раньше даты начала")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                Section("Стоимость") {
                    TextField("Стоимость пакета", text: $packagePriceText)
                        .keyboardType(.decimalPad)
                    
                    if let price = packagePriceValue, price == 0 {
                            Text("Цена не может быть 0")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    
                    HStack {
                        Text("Цена за тренировку")
                        Spacer()
                        Text(pricePerSessionText)
                            .foregroundColor(.secondary)
                    }
                }
                Section("Дни недели") {
                    HStack(spacing: 6) {
                        ForEach(0..<7, id: \.self) { i in
                            Button {
                                var next = weekdaySelected
                                next[i].toggle()
                                weekdaySelected = next
                            } label: {
                                Text(weekdayShortLabels[i])
                                    .font(.caption.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(weekdaySelected[i] ? Color.accentColor : Color(.systemGray5))
                                    .foregroundColor(weekdaySelected[i] ? .white : .primary)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Section("Время тренировки") {
                    DatePicker("Время", selection: $trainingTime, displayedComponents: .hourAndMinute)
                }
                Section("Заметки") {
                    TextEditor(text: $subscriptionNotes)
                        .frame(minHeight: 100)
                }
                Section {
                    HStack {
                        Text("Итого")
                        Spacer()
                        Text("\(totalSessions) занятий до \(formatDate(endDate))")
                            .foregroundColor(.secondary)
                            .font(.system(size: 13))
                    }
                }
            }
            .navigationTitle(isExtension ? "Продление абонемента" : isEditing ? "Редактирование абонемента" : "Новый абонемент")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        let sub = ClientStore.Subscription(
                            totalSessions: max(1, totalSessions),
                            startDate: startDate,
                            endDate: endDate,
                            weekdaySelected: weekdaySelected,
                            trainingTime: trainingTime,
                            notes: subscriptionNotes,
                            packagePrice: packagePriceValue
                        )
                       
                        if isExtension {
                            store.addSubscription(sub, to: clientId, isExtension: true)
                        } else if isEditing {
                            store.updateSubscription(sub, for: clientId)
                        } else {
                            store.addSubscription(sub, to: clientId)
                        }
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .disabled(!canSave)
                }
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "ru_RU")
        fmt.dateFormat = "d MMM yyyy"
        return fmt.string(from: date)
    }
}

// MARK: - SubscriptionStatus расширение

extension SubscriptionStatus {
    var icon: String {
        switch self {
        case .active:  return "checkmark.circle.fill"
        case .low:     return "exclamationmark.circle.fill"
        case .expired: return "xmark.circle.fill"
        }
    }

    var label: String {
        switch self {
        case .active:  return "Активен"
        case .low:     return "Заканчивается"
        case .expired: return "Истёк"
        }
    }

    var swiftUIColor: Color {
        switch self {
        case .active:  return .green
        case .low:     return .orange
        case .expired: return .red
        }
    }
    
}
