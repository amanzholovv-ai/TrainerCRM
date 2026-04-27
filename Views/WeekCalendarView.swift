import SwiftUI
import UIKit
import UniformTypeIdentifiers

// MARK: - WeekCalendarView

struct WeekCalendarView: View {
    @ObservedObject var store: ClientStore
    let weekContaining: Date

    @State private var editingRef: WorkoutRef?
    @State private var addingSlot: CalendarSlot?
    @State private var now = Date()

    private let calendar  = Calendar.current
    private let rowHeight: CGFloat      = 60
    private let timeColumnWidth: CGFloat = 44
    private let headerHeight: CGFloat   = 36
    private let visibleDayCount: CGFloat = 3
    private let hours = Array(0..<24)
    private let weekdayLabels = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]

    private var currentHour: Int   { calendar.component(.hour,   from: now) }
    private var currentMinute: Int { calendar.component(.minute, from: now) }

    private var weekStart: Date {
        calendar.dateInterval(of: .weekOfYear, for: weekContaining)?.start ?? weekContaining
    }
    private var weekDays: [Date] {
        (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
    }

    var body: some View {
        GeometryReader { geo in
            let colWidth = (geo.size.width - timeColumnWidth) / visibleDayCount

            WeekCalendarContainer(
                store:           store,
                weekDays:        weekDays,
                hours:           hours,
                weekdayLabels:   weekdayLabels,
                colWidth:        colWidth,
                rowHeight:       rowHeight,
                timeColumnWidth: timeColumnWidth,
                headerHeight:    headerHeight,
                now:             now,
                currentHour:     currentHour,
                currentMinute:   currentMinute,
                weekContaining:  weekContaining,
                onTapRef: { ref in editingRef = ref },
                onTapEmpty: { date, hour in
                    if let d = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: date) {
                        addingSlot = CalendarSlot(date: d)
                    }
                },
                onDrop: { id, date, hour in
                    if let d = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: date) {
                        store.rescheduleWorkout(workoutId: id, to: d)
                    }
                }
            )
        }
        .background(Color.black)
        .sheet(item: $editingRef) { ref in
            CalendarWorkoutEditSheet(store: store, ref: ref)
        }
        .sheet(item: $addingSlot) { slot in
            AddWorkoutFromCalendarSheet(store: store, preselectedDate: slot.date)
        }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { date in
            now = date
        }
    }
}

// MARK: - UIViewRepresentable

struct WeekCalendarContainer: UIViewRepresentable {

    let store:           ClientStore
    let weekDays:        [Date]
    let hours:           [Int]
    let weekdayLabels:   [String]
    let colWidth:        CGFloat
    let rowHeight:       CGFloat
    let timeColumnWidth: CGFloat
    let headerHeight:    CGFloat
    let now:             Date
    let currentHour:     Int
    let currentMinute:   Int
    let weekContaining:  Date
    let onTapRef:        (WorkoutRef) -> Void
    let onTapEmpty:      (Date, Int) -> Void
    let onDrop:          (UUID, Date, Int) -> Void

    private var totalGridWidth: CGFloat { colWidth * CGFloat(weekDays.count) }
    private var contentWidth:  CGFloat { timeColumnWidth + totalGridWidth }
    private var gridHeight:    CGFloat { CGFloat(hours.count) * rowHeight }
    private var contentHeight: CGFloat { headerHeight + gridHeight }

    // MARK: Make

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIScrollView {
        let sv = UIScrollView()
        sv.contentSize = CGSize(width: contentWidth, height: contentHeight)
        sv.backgroundColor = .black
        sv.showsHorizontalScrollIndicator = false
        sv.showsVerticalScrollIndicator   = false
        sv.contentInsetAdjustmentBehavior = .never

        // 1. Grid — scrolls in both directions freely
        let gridHC = makeHC(gridContent())
        sv.addSubview(gridHC.view)
        let gridTopC     = gridHC.view.topAnchor.constraint(equalTo: sv.contentLayoutGuide.topAnchor, constant: headerHeight)
        let gridLeadingC = gridHC.view.leadingAnchor.constraint(equalTo: sv.contentLayoutGuide.leadingAnchor, constant: timeColumnWidth)
        let gridWidthC   = gridHC.view.widthAnchor.constraint(equalToConstant: totalGridWidth)
        let gridHeightC  = gridHC.view.heightAnchor.constraint(equalToConstant: gridHeight)
        NSLayoutConstraint.activate([gridTopC, gridLeadingC, gridWidthC, gridHeightC])
        context.coordinator.gridHC       = gridHC
        context.coordinator.gridWidthC   = gridWidthC
        context.coordinator.gridHeightC  = gridHeightC
        context.coordinator.gridLeadingC = gridLeadingC

        // 2. Time column — sticky LEFT (frame), scrolls vertically (content)
        let timeHC = makeHC(timeColumnContent())
        timeHC.view.backgroundColor = .black
        sv.addSubview(timeHC.view)
        let timeTopC    = timeHC.view.topAnchor.constraint(equalTo: sv.contentLayoutGuide.topAnchor, constant: headerHeight)
        let timeLeadingC = timeHC.view.leadingAnchor.constraint(equalTo: sv.frameLayoutGuide.leadingAnchor)
        let timeWidthC  = timeHC.view.widthAnchor.constraint(equalToConstant: timeColumnWidth)
        let timeHeightC = timeHC.view.heightAnchor.constraint(equalToConstant: gridHeight)
        NSLayoutConstraint.activate([timeTopC, timeLeadingC, timeWidthC, timeHeightC])
        context.coordinator.timeHC      = timeHC
        context.coordinator.timeHeightC = timeHeightC

        // 3. Day headers — sticky TOP (frame), scrolls horizontally (content)
        let dayHC = makeHC(dayHeadersContent())
        dayHC.view.backgroundColor = .black
        sv.addSubview(dayHC.view)
        let dayTopC     = dayHC.view.topAnchor.constraint(equalTo: sv.frameLayoutGuide.topAnchor)
        let dayLeadingC = dayHC.view.leadingAnchor.constraint(equalTo: sv.contentLayoutGuide.leadingAnchor, constant: timeColumnWidth)
        let dayWidthC   = dayHC.view.widthAnchor.constraint(equalToConstant: totalGridWidth)
        let dayHeightC  = dayHC.view.heightAnchor.constraint(equalToConstant: headerHeight)
        NSLayoutConstraint.activate([dayTopC, dayLeadingC, dayWidthC, dayHeightC])
        context.coordinator.dayHC       = dayHC
        context.coordinator.dayWidthC   = dayWidthC
        context.coordinator.dayLeadingC = dayLeadingC

        // 4. Corner — fixed top-left
        let corner = UIView()
        corner.backgroundColor = .black
        corner.translatesAutoresizingMaskIntoConstraints = false
        sv.addSubview(corner)
        NSLayoutConstraint.activate([
            corner.topAnchor.constraint(equalTo: sv.frameLayoutGuide.topAnchor),
            corner.leadingAnchor.constraint(equalTo: sv.frameLayoutGuide.leadingAnchor),
            corner.widthAnchor.constraint(equalToConstant: timeColumnWidth),
            corner.heightAnchor.constraint(equalToConstant: headerHeight),
        ])

        // Scroll to current hour on appear
        let targetY = max(0, CGFloat(currentHour - 1) * rowHeight)
        sv.setContentOffset(CGPoint(x: 0, y: targetY), animated: false)

        return sv
    }

    // MARK: Update

    func updateUIView(_ sv: UIScrollView, context: Context) {
        let newSize = CGSize(width: contentWidth, height: contentHeight)
        if sv.contentSize != newSize {
            sv.contentSize = newSize
            // Обновляем constraint-ы, зависящие от ширины колонки (поворот устройства)
            context.coordinator.gridWidthC?.constant   = totalGridWidth
            context.coordinator.gridHeightC?.constant  = gridHeight
            context.coordinator.gridLeadingC?.constant = timeColumnWidth
            context.coordinator.timeHeightC?.constant  = gridHeight
            context.coordinator.dayWidthC?.constant    = totalGridWidth
            context.coordinator.dayLeadingC?.constant  = timeColumnWidth
            sv.setNeedsLayout()
            sv.layoutIfNeeded()
        }
        context.coordinator.gridHC?.rootView = AnyView(gridContent())
        context.coordinator.timeHC?.rootView = AnyView(timeColumnContent())
        context.coordinator.dayHC?.rootView  = AnyView(dayHeadersContent())
    }

    // MARK: Coordinator

    class Coordinator: NSObject {
        var gridHC: UIHostingController<AnyView>?
        var timeHC: UIHostingController<AnyView>?
        var dayHC:  UIHostingController<AnyView>?
        // Size-dependent constraints updated on rotation
        var gridWidthC:   NSLayoutConstraint?
        var gridHeightC:  NSLayoutConstraint?
        var gridLeadingC: NSLayoutConstraint?
        var timeHeightC:  NSLayoutConstraint?
        var dayWidthC:    NSLayoutConstraint?
        var dayLeadingC:  NSLayoutConstraint?
    }

    // MARK: - View builders

    private func gridContent() -> some View {
        VStack(spacing: 0) {
            ForEach(hours, id: \.self) { hour in
                HStack(spacing: 0) {
                    ForEach(weekDays.indices, id: \.self) { di in
                        cellView(dayDate: weekDays[di], hour: hour)
                            .frame(width: colWidth, height: rowHeight)
                    }
                }
                .frame(height: rowHeight)
            }
        }
        .frame(width: totalGridWidth, height: gridHeight)
    }

    private func timeColumnContent() -> some View {
        VStack(spacing: 0) {
            ForEach(hours, id: \.self) { hour in
                Text(String(format: "%02d:00", hour))
                    .font(.caption2)
                    .foregroundColor(.gray)
                    // padding BEFORE frame — не увеличивает строку
                    .padding(.top, 2)
                    .frame(width: timeColumnWidth, height: rowHeight, alignment: .topLeading)
            }
        }
        .frame(width: timeColumnWidth, height: gridHeight)
        .background(Color.black)
    }

    private func dayHeadersContent() -> some View {
        HStack(spacing: 0) {
            ForEach(weekDays.indices, id: \.self) { i in
                let isToday = Calendar.current.isDateInToday(weekDays[i])
                VStack(spacing: 3) {
                    Text(weekdayLabels[i])
                        .font(.caption2)
                        .foregroundColor(isToday ? .blue : .gray)
                    Text("\(Calendar.current.component(.day, from: weekDays[i]))")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 26, height: 26)
                        .background(isToday ? Color.blue : Color.clear, in: Circle())
                }
                .frame(width: colWidth, height: headerHeight)
            }
        }
        .frame(width: totalGridWidth, height: headerHeight)
        .background(Color.black)
    }

    // MARK: - Cell

    @ViewBuilder
    private func cellView(dayDate: Date, hour: Int) -> some View {
        let cal       = Calendar.current
        let refs      = workoutRefs(in: hour, on: dayDate)
        let sorted    = refs.sorted { $0.date < $1.date }
        let isToday   = cal.isDateInToday(dayDate)
        let gap: CGFloat = 2
        let count     = max(1, sorted.count)
        let blockW    = max(0, (colWidth - gap * CGFloat(count - 1)) / CGFloat(count))

        ZStack(alignment: .topLeading) {
            // Grid line
            Rectangle()
                .stroke(Color.white.opacity(0.13), lineWidth: 0.5)
                .frame(width: colWidth, height: rowHeight)

            // Current-time indicator
            if isToday && currentHour == hour {
                let progress = CGFloat(currentMinute) / 60.0
                Rectangle()
                    .fill(Color.red)
                    .frame(width: colWidth, height: 1.5)
                    .offset(y: rowHeight * progress)
            }

            // Workout blocks
            ForEach(Array(sorted.enumerated()), id: \.element.id) { idx, ref in
                Button { onTapRef(ref) } label: { blockContent(ref: ref) }
                    .buttonStyle(.plain)
                    .frame(width: blockW, height: rowHeight)
                    .offset(x: CGFloat(idx) * (blockW + gap))
                    .onDrag { NSItemProvider(object: ref.workoutId.uuidString as NSString) }
            }
        }
        .frame(width: colWidth, height: rowHeight)
        .background(isToday ? Color.blue.opacity(0.08) : Color(white: 0.1).opacity(0.35))
        .contentShape(Rectangle())
        // Тап на пустое место → добавить тренировку
        .onTapGesture { onTapEmpty(dayDate, hour) }
        .onDrop(of: [.text], isTargeted: nil) { providers in
            guard let p = providers.first else { return false }
            p.loadObject(ofClass: NSString.self) { obj, _ in
                guard let s = obj as? String, let id = UUID(uuidString: s) else { return }
                DispatchQueue.main.async { onDrop(id, dayDate, hour) }
            }
            return true
        }
    }

    // MARK: - Block content (S / M / L)

    @ViewBuilder
    private func blockContent(ref: WorkoutRef) -> some View {
        if rowHeight < 26 {
            HStack(spacing: 3) {
                RoundedRectangle(cornerRadius: 1.5).fill(ref.clientColor).frame(width: 3)
                Text(String(ref.clientName.prefix(2)))
                    .font(.system(size: 9, weight: .bold)).lineLimit(1).foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 2).padding(.vertical, 1)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 4).fill(ref.clientColor.opacity(0.32))
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(ref.clientColor.opacity(0.55), lineWidth: 1))
            )
        } else if rowHeight < 46 {
            HStack(alignment: .center, spacing: 4) {
                RoundedRectangle(cornerRadius: 2).fill(ref.clientColor).frame(width: 3)
                Text(ref.clientName)
                    .font(.system(size: 10, weight: .semibold)).lineLimit(1).foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Circle().fill(ref.status.calendarStatusDotColor).frame(width: 6, height: 6)
            }
            .padding(.horizontal, 4).padding(.vertical, 3)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 7).fill(ref.clientColor.opacity(0.24))
                    .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(ref.clientColor.opacity(0.50), lineWidth: 0.75))
            )
        } else {
            HStack(alignment: .top, spacing: 5) {
                RoundedRectangle(cornerRadius: 2).fill(ref.clientColor).frame(width: 4)
                VStack(alignment: .leading, spacing: 2) {
                    Text(ref.clientName)
                        .font(.caption2).fontWeight(.semibold).lineLimit(1).foregroundColor(.white)
                    Text(ref.date, style: .time)
                        .font(.system(size: 9)).foregroundColor(Color.white.opacity(0.55))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: ref.status.calendarStatusIconName)
                    .font(.system(size: 11)).foregroundStyle(ref.status.calendarStatusIconColor)
            }
            .padding(.horizontal, 5).padding(.vertical, 4)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(ZStack {
                RoundedRectangle(cornerRadius: 10).fill(ref.clientColor.opacity(0.22))
                RoundedRectangle(cornerRadius: 10).fill(ref.status.calendarCardBackgroundTint)
                RoundedRectangle(cornerRadius: 10).strokeBorder(ref.clientColor.opacity(0.45), lineWidth: 0.75)
            })
        }
    }

    // MARK: - Helpers

    private func workoutRefs(in hour: Int, on date: Date) -> [WorkoutRef] {
        store.workoutRefs(weekContaining: weekContaining).filter {
            Calendar.current.isDate($0.date, inSameDayAs: date) &&
            Calendar.current.component(.hour, from: $0.date) == hour
        }
    }

    private func makeHC(_ view: some View) -> UIHostingController<AnyView> {
        let hc = UIHostingController(rootView: AnyView(view))
        hc.view.backgroundColor = .clear
        hc.view.translatesAutoresizingMaskIntoConstraints = false
        return hc
    }

    /// Универсальный pin: top/leading могут быть из frameLayoutGuide или contentLayoutGuide
    private func pin(_ v: UIView,
                     top: NSLayoutAnchor<NSLayoutYAxisAnchor>, topC: CGFloat = 0,
                     leading: NSLayoutAnchor<NSLayoutXAxisAnchor>, leadingC: CGFloat = 0,
                     width: CGFloat, height: CGFloat) {
        NSLayoutConstraint.activate([
            v.topAnchor.constraint(equalTo: top, constant: topC),
            v.leadingAnchor.constraint(equalTo: leading, constant: leadingC),
            v.widthAnchor.constraint(equalToConstant: width),
            v.heightAnchor.constraint(equalToConstant: height),
        ])
    }
}
