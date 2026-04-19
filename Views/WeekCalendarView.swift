import SwiftUI
import UniformTypeIdentifiers

struct WeekCalendarView: View {
    @ObservedObject var store: ClientStore
    let weekContaining: Date

    @State private var editingRef: WorkoutRef?

    private let calendar = Calendar.current
    private let hours = Array(0..<24)
    private let weekdayLabels = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]
    private let hourRowHeight: CGFloat = 48
    private let timeColumnWidth: CGFloat = 44
    private let headerHeight: CGFloat = 32

    private var weekStart: Date {
        calendar.dateInterval(of: .weekOfYear, for: weekContaining)?.start ?? weekContaining
    }

    private var weekDays: [Date] {
        (0..<7).compactMap {
            calendar.date(byAdding: .day, value: $0, to: weekStart)
        }
    }

    var body: some View {
        GeometryReader { geo in
            let colWidth = max(48, (geo.size.width - timeColumnWidth) / 7)
            let dayStripMinWidth = colWidth * 7

            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Color.black
                        .frame(width: timeColumnWidth, height: headerHeight)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 0) {
                            ForEach(weekDays.indices, id: \.self) { i in
                                VStack(spacing: 2) {
                                    Text(weekdayLabels[i])
                                        .font(.caption2)
                                        .foregroundColor(Color.gray)
                                    Text("\(calendar.component(.day, from: weekDays[i]))")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(Color.white)
                                }
                                .frame(width: colWidth, height: headerHeight)
                            }
                        }
                        .frame(minWidth: dayStripMinWidth)
                    }
                }
                .background(Color.black)

                ScrollView(.vertical, showsIndicators: true) {
                    HStack(alignment: .top, spacing: 0) {
                        VStack(spacing: 0) {
                            ForEach(hours, id: \.self) { hour in
                                Text(String(format: "%02d:00", hour))
                                    .font(.caption2)
                                    .foregroundColor(Color.gray)
                                    .frame(width: timeColumnWidth, height: hourRowHeight, alignment: .topLeading)
                                    .padding(.top, 2)
                            }
                        }
                        .frame(width: timeColumnWidth)
                        .background(Color.black)

                        ScrollView(.horizontal, showsIndicators: false) {
                            VStack(spacing: 0) {
                                ForEach(hours, id: \.self) { hour in
                                    HStack(spacing: 0) {
                                        ForEach(weekDays.indices, id: \.self) { dayIndex in
                                            let dayDate = weekDays[dayIndex]
                                            let refs = workouts(in: hour, on: dayDate)

                                            cellContent(refs: refs, dayDate: dayDate, hour: hour)
                                                .frame(width: colWidth)
                                        }
                                    }
                                    .frame(height: hourRowHeight)
                                }
                            }
                            .frame(minWidth: dayStripMinWidth)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.black)
        
        .sheet(item: $editingRef) { ref in
            CalendarWorkoutEditSheet(store: store, ref: ref)
        }
    }

    @ViewBuilder
    private func cellContent(refs: [WorkoutRef], dayDate: Date, hour: Int) -> some View {
        // Несколько тренировок в одной часовой клетке отображаем бок-о-бок,
        // поровну деля ширину (2→50/50, 3→33/33/33 и т.д.).
        let sortedRefs = refs.sorted { $0.date < $1.date }

        GeometryReader { geo in
            let cellWidth = geo.size.width
            let gap: CGFloat = 2
            let count = max(1, sortedRefs.count)
            let blockWidth = max(
                0,
                (cellWidth - gap * CGFloat(count - 1)) / CGFloat(count)
            )

            ZStack(alignment: .topLeading) {
                Rectangle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                ForEach(Array(sortedRefs.enumerated()), id: \.element.id) { idx, ref in
                    workoutBlock(ref: ref, dayDate: dayDate, hour: hour)
                        .frame(width: blockWidth, height: hourRowHeight)
                        .offset(x: CGFloat(idx) * (blockWidth + gap), y: 0)
                }
            }
        }
        .frame(height: hourRowHeight)
        .background(Color(white: 0.1).opacity(0.35))
        .contentShape(Rectangle())
        .onDrop(of: [.text], isTargeted: nil) { providers in
            handleDrop(providers: providers, dayDate: dayDate, hour: hour)
        }
    }

    private func workoutBlock(ref: WorkoutRef, dayDate: Date, hour: Int) -> some View {
        Button {
            editingRef = ref
        } label: {
            HStack(alignment: .top, spacing: 6) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(ref.clientColor)
                    .frame(width: 3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(ref.clientName)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .foregroundColor(Color.white)
                    Text(ref.date, style: .time)
                        .font(.system(size: 9))
                        .foregroundColor(Color.gray)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: ref.status.calendarStatusIconName)
                    .font(.system(size: 12))
                    .foregroundStyle(ref.status.calendarStatusIconColor)
            }
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(ref.status.calendarCardBackgroundTint)
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                }
            )
        }
        .buttonStyle(.plain)
        .onDrag {
            NSItemProvider(object: ref.workoutId.uuidString as NSString)
        }
    }

    private func handleDrop(providers: [NSItemProvider], dayDate: Date, hour: Int) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadObject(ofClass: NSString.self) { object, _ in
            guard let uuidString = object as? String,
                  let workoutId = UUID(uuidString: uuidString) else { return }
            let minute = 0
            if let newDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: dayDate) {
                DispatchQueue.main.async {
                    store.rescheduleWorkout(workoutId: workoutId, to: newDate)
                }
            }
        }
        return true
    }

    private func workouts(in hour: Int, on date: Date) -> [WorkoutRef] {
        store.workoutRefs(weekContaining: weekContaining).filter { ref in
            calendar.isDate(ref.date, inSameDayAs: date) && calendar.component(.hour, from: ref.date) == hour
        }
    }
}
