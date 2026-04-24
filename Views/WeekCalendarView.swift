import SwiftUI
import UniformTypeIdentifiers


struct WeekCalendarView: View {
    @ObservedObject var store: ClientStore
    let weekContaining: Date

    @State private var editingRef: WorkoutRef?
    @State private var now = Date()
    // Горизонтальное смещение сетки для синхронизации заголовков дней
    @State private var gridHorizontalOffset: CGFloat = 0

    private let calendar = Calendar.current
    private let hours = Array(0..<24)
    private let weekdayLabels = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]
    private let rowHeight: CGFloat = 60
    private let timeColumnWidth: CGFloat = 44
    private let headerHeight: CGFloat = 36
    // 3 дня видны на экране — остальные доступны горизонтальным скроллом
    private let visibleDayCount: CGFloat = 3

    private var currentHour: Int { calendar.component(.hour, from: now) }
    private var currentMinute: Int { calendar.component(.minute, from: now) }

    private var weekStart: Date {
        calendar.dateInterval(of: .weekOfYear, for: weekContaining)?.start ?? weekContaining
    }

    private var weekDays: [Date] {
        (0..<7).compactMap {
            calendar.date(byAdding: .day, value: $0, to: weekStart)
        }
    }

    var body: some View {
        GeometryReader { outerGeo in
            let colWidth = (outerGeo.size.width - timeColumnWidth) / visibleDayCount
            let totalGridWidth = colWidth * 7
            let bodyHeight = outerGeo.size.height - headerHeight

            VStack(spacing: 0) {

                // ── Заголовки дней (фиксированы вертикально, синхронизированы горизонтально) ──
                HStack(spacing: 0) {
                    Color.black.frame(width: timeColumnWidth, height: headerHeight)

                    HStack(spacing: 0) {
                        ForEach(weekDays.indices, id: \.self) { i in
                            let isToday = calendar.isDateInToday(weekDays[i])
                            VStack(spacing: 3) {
                                Text(weekdayLabels[i])
                                    .font(.caption2)
                                    .foregroundColor(isToday ? Color.blue : Color.gray)
                                Text("\(calendar.component(.day, from: weekDays[i]))")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 26, height: 26)
                                    .background(isToday ? Color.blue : Color.clear, in: Circle())
                            }
                            .frame(width: colWidth, height: headerHeight)
                        }
                    }
                    .offset(x: -gridHorizontalOffset)
                    .frame(width: outerGeo.size.width - timeColumnWidth, alignment: .leading)
                    .clipped()
                }
                .frame(height: headerHeight)
                .background(Color.black)

                // ── Тело: время + сетка в одном вертикальном скролле ──
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 0) {

                            // Метки времени — в том же вертикальном скролле, синхронизация не нужна
                            VStack(spacing: 0) {
                                ForEach(hours, id: \.self) { hour in
                                    Text(String(format: "%02d:00", hour))
                                        .font(.caption2)
                                        .foregroundColor(Color.gray)
                                        .frame(width: timeColumnWidth, height: rowHeight, alignment: .topLeading)
                                        .padding(.top, 2)
                                        .id(hour)
                                }
                            }
                            .background(Color.black)

                            // Сетка — горизонтальный скролл
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 0) {
                                    ForEach(weekDays.indices, id: \.self) { dayIndex in
                                        let dayDate = weekDays[dayIndex]
                                        VStack(spacing: 0) {
                                            ForEach(hours, id: \.self) { hour in
                                                let refs = workouts(in: hour, on: dayDate)
                                                cellContent(refs: refs, dayDate: dayDate, hour: hour)
                                                    .frame(width: colWidth, height: rowHeight)
                                            }
                                        }
                                        .frame(width: colWidth)
                                    }
                                }
                                .frame(width: totalGridWidth)
                            }
                            .onScrollGeometryChange(for: CGFloat.self) { scrollGeo in
                                scrollGeo.contentOffset.x
                            } action: { _, newOffset in
                                gridHorizontalOffset = max(0, newOffset)
                            }
                        }
                    }
                    .frame(height: bodyHeight)
                    .onAppear {
                        let target = max(0, currentHour - 1)
                        proxy.scrollTo(target, anchor: .top)
                    }
                    .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { date in
                        now = date
                    }
                }
            }
        }
        .background(Color.black)
        .sheet(item: $editingRef) { ref in
            CalendarWorkoutEditSheet(store: store, ref: ref)
        }
    }

    // MARK: - Ячейка часа (один столбец × одна строка)

    @ViewBuilder
    private func cellContent(refs: [WorkoutRef], dayDate: Date, hour: Int) -> some View {
        let sortedRefs = refs.sorted { $0.date < $1.date }

        GeometryReader { geo in
            let cellWidth = geo.size.width
            let gap: CGFloat = 2
            let count = max(1, sortedRefs.count)
            let blockWidth = max(0, (cellWidth - gap * CGFloat(count - 1)) / CGFloat(count))

            ZStack(alignment: .topLeading) {
                Rectangle()
                    .stroke(Color.white.opacity(0.13), lineWidth: 0.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Линия текущего времени
                if calendar.isDateInToday(dayDate) && calendar.component(.hour, from: now) == hour {
                    let progress = CGFloat(currentMinute) / 60.0
                    Rectangle()
                        .fill(Color.red)
                        .frame(height: 1.5)
                        .offset(y: rowHeight * progress - rowHeight / 2)
                }

                ForEach(Array(sortedRefs.enumerated()), id: \.element.id) { idx, ref in
                    workoutBlock(ref: ref, dayDate: dayDate, hour: hour)
                        .frame(width: blockWidth, height: rowHeight)
                        .offset(x: CGFloat(idx) * (blockWidth + gap), y: 0)
                }
            }
        }
        .frame(height: rowHeight)
        .background(
            calendar.isDateInToday(dayDate)
                ? Color.blue.opacity(0.08)
                : Color(white: 0.1).opacity(0.35)
        )
        .contentShape(Rectangle())
        .onDrop(of: [.text], isTargeted: nil) { providers in
            handleDrop(providers: providers, dayDate: dayDate, hour: hour)
        }
    }

    // MARK: - Блок тренировки

    private func workoutBlock(ref: WorkoutRef, dayDate: Date, hour: Int) -> some View {
        Button {
            editingRef = ref
        } label: {
            blockContent(ref: ref, height: rowHeight)
        }
        .buttonStyle(.plain)
        .onDrag {
            NSItemProvider(object: ref.workoutId.uuidString as NSString)
        }
    }

    // MARK: - Адаптивное содержимое блока (S / M / L по высоте)

    @ViewBuilder
    private func blockContent(ref: WorkoutRef, height: CGFloat) -> some View {
        if height < 26 {
            // S — цветная полоска + 2 символа имени
            HStack(spacing: 3) {
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(ref.clientColor)
                    .frame(width: 3)
                Text(String(ref.clientName.prefix(2)))
                    .font(.system(size: 9, weight: .bold))
                    .lineLimit(1)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 1)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(ref.clientColor.opacity(0.32))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .strokeBorder(ref.clientColor.opacity(0.55), lineWidth: 1)
                    )
            )
        } else if height < 46 {
            // M — имя + цветная точка статуса, без времени
            HStack(alignment: .center, spacing: 4) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(ref.clientColor)
                    .frame(width: 3)
                Text(ref.clientName)
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(1)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Circle()
                    .fill(ref.status.calendarStatusDotColor)
                    .frame(width: 6, height: 6)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 3)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(ref.clientColor.opacity(0.24))
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .strokeBorder(ref.clientColor.opacity(0.50), lineWidth: 0.75)
                    )
            )
        } else {
            // L — полный вид: имя + время + иконка статуса
            HStack(alignment: .top, spacing: 5) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(ref.clientColor)
                    .frame(width: 4)
                VStack(alignment: .leading, spacing: 2) {
                    Text(ref.clientName)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .foregroundColor(.white)
                    Text(ref.date, style: .time)
                        .font(.system(size: 9))
                        .foregroundColor(Color.white.opacity(0.55))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: ref.status.calendarStatusIconName)
                    .font(.system(size: 11))
                    .foregroundStyle(ref.status.calendarStatusIconColor)
            }
            .padding(.horizontal, 5)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(ref.clientColor.opacity(0.22))
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(ref.status.calendarCardBackgroundTint)
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(ref.clientColor.opacity(0.45), lineWidth: 0.75)
                }
            )
        }
    }

    // MARK: - Helpers

    private func handleDrop(providers: [NSItemProvider], dayDate: Date, hour: Int) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadObject(ofClass: NSString.self) { object, _ in
            guard let uuidString = object as? String,
                  let workoutId = UUID(uuidString: uuidString) else { return }
            if let newDate = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: dayDate) {
                DispatchQueue.main.async {
                    store.rescheduleWorkout(workoutId: workoutId, to: newDate)
                }
            }
        }
        return true
    }

    private func workouts(in hour: Int, on date: Date) -> [WorkoutRef] {
        store.workoutRefs(weekContaining: weekContaining).filter { ref in
            calendar.isDate(ref.date, inSameDayAs: date) &&
            calendar.component(.hour, from: ref.date) == hour
        }
    }
}
