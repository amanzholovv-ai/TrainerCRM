import SwiftUI

// MARK: - CalendarMode

enum CalendarMode: String, CaseIterable {
    case day = "День"
    case week = "Неделя"
    case month = "Месяц"
}

// MARK: - CalendarContainerView

struct CalendarContainerView: View {
    @EnvironmentObject var store: ClientStore

    @State private var selectedMode: CalendarMode = .day
    @State private var referenceDate: Date = Date()

    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Режим", selection: $selectedMode) {
                    ForEach(CalendarMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                dateNavigationHeader

                Group {
                    switch selectedMode {
                    case .day:
                        DayCalendarView(store: store, date: referenceDate)
                    case .week:
                        WeekCalendarView(store: store, weekContaining: referenceDate)
                    case .month:
                        MonthCalendarView(store: store, currentMonth: referenceDate)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .navigationTitle("Календарь")
        }
    }

    private var dateNavigationHeader: some View {
        HStack {
            Button {
                referenceDate = stepDate(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .fontWeight(.semibold)
            }

            Spacer()

            Text(formatHeaderDate)
                .font(.headline)

            Spacer()

            Button {
                referenceDate = stepDate(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .fontWeight(.semibold)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var formatHeaderDate: String {
        switch selectedMode {
        case .day:
            return referenceDate.formatted(date: .abbreviated, time: .omitted)
        case .week:
            guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: referenceDate)?.start,
                  let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart)
            else { return referenceDate.formatted(date: .abbreviated, time: .omitted) }
            return "\(weekStart.formatted(date: .abbreviated, time: .omitted)) – \(weekEnd.formatted(date: .abbreviated, time: .omitted))"
        case .month:
            return referenceDate.formatted(.dateTime.year().month(.wide))
        }
    }

    private func stepDate(by value: Int) -> Date {
        switch selectedMode {
        case .day:
            return calendar.date(byAdding: .day, value: value, to: referenceDate) ?? referenceDate
        case .week:
            return calendar.date(byAdding: .weekOfYear, value: value, to: referenceDate) ?? referenceDate
        case .month:
            return calendar.date(byAdding: .month, value: value, to: referenceDate) ?? referenceDate
        }
    }
}
