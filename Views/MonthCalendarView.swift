import SwiftUI

struct MonthCalendarView: View {
    @ObservedObject var store: ClientStore
    let currentMonth: Date

    @State private var selectedDate: Date
    @State private var editingRef: WorkoutRef?

    init(store: ClientStore, currentMonth: Date) {
        self.store = store
        self.currentMonth = currentMonth
        _selectedDate = State(initialValue: currentMonth)
    }

    private let calendar = Calendar.current

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    // Сетка месяца — скроллится вместе с контентом
                    VStack(spacing: 12) {
                        weekdayLabels
                        monthGrid
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)

                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 1)

                    // Тренировки выбранного дня
                    Color.clear.frame(height: 0).id("monthTop")
                    dayWorkoutsScrollContent
                        .padding(.horizontal)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .onChange(of: currentMonth) { _, newMonth in
                if !calendar.isDate(selectedDate, equalTo: newMonth, toGranularity: .month) {
                    selectedDate = newMonth
                }
                withAnimation {
                    proxy.scrollTo("monthTop", anchor: .top)
                }
            }
            .onChange(of: selectedDate) { _, _ in
                withAnimation {
                    proxy.scrollTo("monthTop", anchor: .top)
                }
            }
        }
        .background(Color.black)
        .sheet(item: $editingRef) { ref in
            CalendarWorkoutEditSheet(store: store, ref: ref)
        }
    }

    private var weekdayLabels: some View {
        HStack {
            ForEach(["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"], id: \.self) { day in
                Text(day)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(Color.gray)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var monthGrid: some View {
        let days = makeDaysInMonth(for: currentMonth)

        return LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 6) {
            ForEach(days, id: \.self) { date in
                let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                let isToday = calendar.isDateInToday(date)
                let isCurrentMonth = calendar.isDate(date, equalTo: currentMonth, toGranularity: .month)
                let clientsOnDay = clientsWithWorkouts(on: date)

                VStack(spacing: 3) {
                    ZStack {
                        Circle()
                            .fill(isSelected ? Color.blue : isToday ? Color.blue.opacity(0.15) : Color.clear)
                            .frame(width: 34, height: 34)

                        Text("\(calendar.component(.day, from: date))")
                            .font(.system(size: 15, weight: isToday || isSelected ? .bold : .regular))
                            .foregroundColor(
                                isSelected ? .white :
                                isToday ? .blue :
                                isCurrentMonth ? Color.white : Color.gray.opacity(0.45)
                            )
                    }
                    HStack(spacing: 3) {
                        ForEach(clientsOnDay.prefix(3), id: \.id) { client in
                            Circle()
                                .fill(client.color)
                                .frame(width: 5, height: 5)
                        }
                        if clientsOnDay.count > 3 {
                            Text("+")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundColor(Color.gray)
                        }
                    }
                    .frame(height: 6)
                }
                .onTapGesture { selectedDate = date }
            }
        }
    }

    private var dayWorkoutsScrollContent: some View {
        let refs = store.workoutRefs(on: selectedDate)

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(selectedDate, format: .dateTime.day().month().year())
                    .font(.headline)
                    .foregroundColor(Color.white)
                Spacer()
            }
            .padding(.horizontal, 4)
            .padding(.top, 12)

            if refs.isEmpty {
                ContentUnavailableView(
                    "Нет тренировок",
                    systemImage: "calendar.badge.exclamationmark",
                    description: Text("Добавь тренировку клиенту на этот день")
                )
                .frame(maxWidth: .infinity)
                .frame(minHeight: 180)
            } else {
                VStack(spacing: 12) {
                    ForEach(refs) { ref in
                        Button {
                            editingRef = ref
                        } label: {
                            monthWorkoutCard(ref: ref)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 2)
                .padding(.bottom, 24)
            }
        }
    }

    private func monthWorkoutCard(ref: WorkoutRef) -> some View {
        HStack(alignment: .center, spacing: 14) {
            RoundedRectangle(cornerRadius: 3)
                .fill(ref.clientColor)
                .frame(width: 4)
            VStack(alignment: .leading, spacing: 4) {
                Text(ref.clientName)
                    .font(.headline)
                    .foregroundColor(Color.white)
                Text(ref.date, style: .time)
                    .font(.subheadline)
                    .foregroundColor(Color.gray)
            }
            Spacer(minLength: 8)
            Image(systemName: ref.status.calendarStatusIconName)
                .font(.system(size: 16))
                .foregroundStyle(ref.status.calendarStatusIconColor)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(ref.status.calendarCardBackgroundTint)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 3)
    }

    private func clientsWithWorkouts(on date: Date) -> [Client] {
        store.clients.filter { client in
            client.workouts.contains { calendar.isDate($0.date, inSameDayAs: date) }
        }
    }

    private func makeDaysInMonth(for date: Date) -> [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: date),
              let firstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start)
        else { return [] }
        return (0..<42).compactMap {
            calendar.date(byAdding: .day, value: $0, to: firstWeek.start)
        }
    }
}
