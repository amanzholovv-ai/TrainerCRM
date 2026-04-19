import SwiftUI
import UIKit
import UniformTypeIdentifiers

// MARK: - Quick-add sheet payload (avoids empty first frame with `if let hour`)

private struct QuickAddWorkoutSheetItem: Identifiable {
    let id = UUID()
    let hour: Int
}

// MARK: - Day calendar (premium dark timeline)

struct DayCalendarView: View {
    @ObservedObject var store: ClientStore
    let date: Date

    @State private var quickAddSheetItem: QuickAddWorkoutSheetItem?
    @State private var editingRef: WorkoutRef?
    /// Snapped start minute (0…1440) while a workout is dragged over the timeline; `nil` when idle.
    @State private var hoveredSnappedMinutes: Int?

    private let calendar = Calendar.current

    private var refs: [WorkoutRef] {
        store.workoutRefs(on: date)
    }

    var body: some View {
        GeometryReader { outerGeo in
            let contentWidth = outerGeo.size.width
            let cardWidth = max(
                120,
                contentWidth - DayCalendarLayout.eventLeadingInset - DayCalendarLayout.horizontalPadding
            )
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    ZStack(alignment: .topLeading) {
                        DayCalendarTimeGridView(
                            hourHeight: DayCalendarLayout.hourHeight,
                            timeColumnWidth: DayCalendarLayout.timeColumnWidth,
                            onHourTap: { hour in
                                quickAddSheetItem = QuickAddWorkoutSheetItem(hour: hour)
                            }
                        )

                        if let m = hoveredSnappedMinutes {
                            DayCalendarDragHighlightView(
                                snappedStartMinute: m,
                                contentWidth: contentWidth
                            )
                        }

                        ForEach(laneAssignments(for: refs), id: \.ref.workoutId) { lane in
                            let laneGap: CGFloat = 2
                            let total = max(1, lane.totalLanes)
                            let laneWidth = (cardWidth - laneGap * CGFloat(total - 1)) / CGFloat(total)
                            let xOffset = DayCalendarLayout.eventLeadingInset
                                + (laneWidth + laneGap) * CGFloat(lane.laneIndex)

                            DayCalendarWorkoutCardView(
                                ref: lane.ref,
                                store: store,
                                cardWidth: laneWidth,
                                onTapEdit: { editingRef = lane.ref },
                                dropDelegate: DayCalendarTimelineDropDelegate(
                                    store: store,
                                    dayDate: date,
                                    calendar: calendar,
                                    timelineYAdjustment: yOffset(for: lane.ref),
                                    hoveredSnappedMinutes: $hoveredSnappedMinutes
                                )
                            )
                            .frame(
                                width: laneWidth,
                                height: DayCalendarLayout.cardHeight(forDurationMinutes: displayDurationMinutes(lane.ref))
                            )
                            .offset(
                                x: xOffset,
                                y: yOffset(for: lane.ref)
                            )
                        }

                        if calendar.isDateInToday(date) {
                            TimelineView(.animation(minimumInterval: 30)) { timeline in
                                let yNow = CGFloat(Self.minutesFromMidnight(of: timeline.date, calendar: calendar))
                                    * DayCalendarLayout.pixelsPerMinute
                                DayCalendarCurrentTimeLineView(
                                    contentWidth: contentWidth,
                                    timeColumnWidth: DayCalendarLayout.timeColumnWidth,
                                    yOffset: yNow
                                )
                            }
                        }

                        if calendar.isDateInToday(date) {
                            TimelineView(.animation(minimumInterval: 30)) { timeline in
                                let y = CGFloat(Self.minutesFromMidnight(of: timeline.date, calendar: calendar))
                                    * DayCalendarLayout.pixelsPerMinute
                                Color.clear
                                    .frame(width: 8, height: 8)
                                    .id(DayCalendarLayout.nowScrollAnchorId)
                                    .padding(.top, max(0, y - DayCalendarLayout.hourHeight * 0.75))
                            }
                        }
                    }
                    .contentShape(Rectangle())
                    .onDrop(
                        of: [UTType.text],
                        delegate: DayCalendarTimelineDropDelegate(
                            store: store,
                            dayDate: date,
                            calendar: calendar,
                            timelineYAdjustment: 0,
                            hoveredSnappedMinutes: $hoveredSnappedMinutes
                        )
                    )
                    .coordinateSpace(name: DayCalendarLayout.coordSpace)
                    .frame(width: contentWidth, height: DayCalendarLayout.timelineHeight, alignment: .topLeading)
                }
                .scrollBounceBehavior(.basedOnSize)
                .onAppear {
                    scrollToNowIfNeeded(proxy: proxy)
                }
                .onChange(of: date) { _, _ in
                    hoveredSnappedMinutes = nil
                    scrollToNowIfNeeded(proxy: proxy)
                }
            }
            .background(Color.black)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        
        .sheet(item: $quickAddSheetItem) { item in
            QuickAddWorkoutView(hour: item.hour, date: date)
                .environmentObject(store)
                .id(item.id)
                
        }
        .sheet(item: $editingRef) { ref in
            CalendarWorkoutEditSheet(store: store, ref: ref)
               
        }
    }

    private func yOffset(for ref: WorkoutRef) -> CGFloat {
        let total = Self.minutesFromMidnight(of: ref.date, calendar: calendar)
        return CGFloat(total) * DayCalendarLayout.pixelsPerMinute
    }

    private static func minutesFromMidnight(of d: Date, calendar: Calendar) -> Int {
        let h = calendar.component(.hour, from: d)
        let m = calendar.component(.minute, from: d)
        return h * 60 + m
    }

    private func displayDurationMinutes(_ ref: WorkoutRef) -> CGFloat {
        CGFloat(max(15, ref.duration))
    }

    private func scrollToNowIfNeeded(proxy: ScrollViewProxy) {
        guard calendar.isDateInToday(date) else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.easeInOut(duration: 0.35)) {
                proxy.scrollTo(DayCalendarLayout.nowScrollAnchorId, anchor: .center)
            }
        }
    }

    // MARK: - Lane assignment (side-by-side для пересекающихся событий)

    fileprivate struct DayLaneLayout {
        let ref: WorkoutRef
        let laneIndex: Int
        let totalLanes: Int
    }

    /// Раскидывает тренировки по «дорожкам» (lanes). Пересекающиеся события
    /// группируются в кластер, внутри которого жадно назначаются колонки.
    /// Все события одного кластера получают одинаковый `totalLanes`,
    /// чтобы визуально делить ширину поровну (2→50/50, 3→33/33/33 и т.д.).
    fileprivate func laneAssignments(for refs: [WorkoutRef]) -> [DayLaneLayout] {
        guard !refs.isEmpty else { return [] }

        // Сортировка: по началу, при равенстве — длинная тренировка первой
        let sorted = refs.sorted { lhs, rhs in
            if lhs.date != rhs.date { return lhs.date < rhs.date }
            return lhs.duration > rhs.duration
        }

        func endDate(_ r: WorkoutRef) -> Date {
            r.date.addingTimeInterval(TimeInterval(max(15, r.duration) * 60))
        }

        // Группируем в кластеры транзитивно пересекающихся событий.
        var clusters: [[Int]] = []
        var currentCluster: [Int] = []
        var currentMaxEnd: Date? = nil

        for (i, ref) in sorted.enumerated() {
            let end = endDate(ref)
            if let maxEnd = currentMaxEnd, ref.date < maxEnd {
                currentCluster.append(i)
                currentMaxEnd = max(maxEnd, end)
            } else {
                if !currentCluster.isEmpty { clusters.append(currentCluster) }
                currentCluster = [i]
                currentMaxEnd = end
            }
        }
        if !currentCluster.isEmpty { clusters.append(currentCluster) }

        // Жадное раскладывание по lanes внутри каждого кластера.
        var result: [DayLaneLayout] = []
        for cluster in clusters {
            var laneEnds: [Date] = []
            var assignedLanes: [Int] = []

            for idx in cluster {
                let ref = sorted[idx]
                let start = ref.date
                let end = endDate(ref)
                var placed = false
                for (li, laneEnd) in laneEnds.enumerated() where laneEnd <= start {
                    laneEnds[li] = end
                    assignedLanes.append(li)
                    placed = true
                    break
                }
                if !placed {
                    laneEnds.append(end)
                    assignedLanes.append(laneEnds.count - 1)
                }
            }

            let total = laneEnds.count
            for (localIdx, idx) in cluster.enumerated() {
                result.append(DayLaneLayout(
                    ref: sorted[idx],
                    laneIndex: assignedLanes[localIdx],
                    totalLanes: total
                ))
            }
        }
        return result
    }

}

// MARK: - Timeline drop (UUID as plain text)

private struct DayCalendarTimelineDropDelegate: DropDelegate {
    var store: ClientStore
    var dayDate: Date
    var calendar: Calendar
    /// Add card’s top Y when `onDrop` is on the card (location is local to the card).
    var timelineYAdjustment: CGFloat = 0
    var hoveredSnappedMinutes: Binding<Int?>

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [.text])
    }

    func dropEntered(info: DropInfo) {
        updateHover(from: info.location)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        updateHover(from: info.location)
        return DropProposal(operation: .copy)
    }

    func dropExited(info: DropInfo) {
        hoveredSnappedMinutes.wrappedValue = nil
    }

    func performDrop(info: DropInfo) -> Bool {
        hoveredSnappedMinutes.wrappedValue = nil
        print("DROP TRIGGERED")
        let location = info.location
        guard let provider = info.itemProviders(for: [.text]).first else {
            return false
        }
        let ppm = DayCalendarLayout.pixelsPerMinute
        let timelineY = location.y + timelineYAdjustment
        let yClamped = max(0, min(timelineY, DayCalendarLayout.timelineHeight))
        let rawMinutes = Int(yClamped / ppm)
        let bounded = min(max(rawMinutes, 0), 24 * 60 - 1)
        let snapped = DayCalendarLayout.snapToQuarterHour(bounded)

        provider.loadObject(ofClass: NSString.self) { object, _ in
            let uuidString = (object as? NSString) as String? ?? ""
            DispatchQueue.main.async {
                guard let workoutId = UUID(uuidString: uuidString) else { return }
                let startOfDay = calendar.startOfDay(for: dayDate)
                guard let newDate = calendar.date(byAdding: .minute, value: snapped, to: startOfDay) else {
                    print("NEW DATE: failed to build")
                    return
                }
                print("NEW DATE: \(newDate)")
                store.rescheduleWorkout(workoutId: workoutId, to: newDate)
                print("WORKOUT MOVED")
            }
        }
        return true
    }

    private func updateHover(from location: CGPoint) {
        let ppm = DayCalendarLayout.pixelsPerMinute
        let timelineY = location.y + timelineYAdjustment
        let yClamped = max(0, min(timelineY, DayCalendarLayout.timelineHeight))
        let rawMinutes = Int(yClamped / ppm)
        let bounded = min(max(rawMinutes, 0), 24 * 60 - 1)
        let snapped = DayCalendarLayout.snapToQuarterHour(bounded)
        if hoveredSnappedMinutes.wrappedValue != snapped {
            hoveredSnappedMinutes.wrappedValue = snapped
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.prepare()
            generator.impactOccurred()
        }
    }
}

// MARK: - Layout

private enum DayCalendarLayout {
    static let hourHeight: CGFloat = 80
    static let timeColumnWidth: CGFloat = 50
    static let horizontalPadding: CGFloat = 12
    static var pixelsPerMinute: CGFloat { hourHeight / 60 }
    static var timelineHeight: CGFloat { hourHeight * 24 }
    static let nowScrollAnchorId = "dayCalendarNowAnchor"
    static var eventLeadingInset: CGFloat { timeColumnWidth + horizontalPadding }
    static let coordSpace = "dayTimelineZStack"

    static func cardHeight(forDurationMinutes duration: CGFloat) -> CGFloat {
        max(hourHeight * 0.35, duration * pixelsPerMinute)
    }

    static func snapMinutes(_ minutes: Int, step: Int) -> Int {
        let s = max(1, step)
        let q = Int(round(Double(minutes) / Double(s))) * s
        return min(24 * 60, max(0, q))
    }

    /// Floor to 15-minute boundary (matches drag label & drop time).
    static func snapToQuarterHour(_ totalMinutes: Int) -> Int {
        let step = 15
        let clamped = min(max(totalMinutes, 0), 24 * 60 - 1)
        let snapped = (clamped / step) * step
        return min(max(snapped, 0), 24 * 60 - step)
    }
}

// MARK: - Time grid (0…23)

private struct DayCalendarTimeGridView: View {
    let hourHeight: CGFloat
    let timeColumnWidth: CGFloat
    var onHourTap: (Int) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<24, id: \.self) { hour in
                HStack(alignment: .top, spacing: 8) {
                    Text(String(format: "%02d:00", hour))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.gray)
                        .frame(width: timeColumnWidth, alignment: .leading)
                        .padding(.top, 2)

                    ZStack(alignment: .topLeading) {
                        Rectangle()
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 2)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        Rectangle()
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 1)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                            .offset(y: hourHeight / 2)
                    }
                    .frame(height: hourHeight)
                    .frame(maxWidth: .infinity)
                }
                .frame(height: hourHeight)
                .frame(maxWidth: .infinity)
                .background(Color(white: 0.1))
                .contentShape(Rectangle())
                .onTapGesture { onHourTap(hour) }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Current time line

private struct DayCalendarCurrentTimeLineView: View {
    let contentWidth: CGFloat
    let timeColumnWidth: CGFloat
    let yOffset: CGFloat

    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
                .shadow(color: .red.opacity(0.4), radius: 3)
            Rectangle()
                .fill(Color.red.opacity(0.95))
                .frame(height: 2)
                .frame(width: max(40, contentWidth - timeColumnWidth - 16))
        }
        .padding(.leading, max(0, timeColumnWidth - 4))
        .offset(y: yOffset)
        .allowsHitTesting(false)
    }
}

// MARK: - Drag hover highlight

private struct DayCalendarDragHighlightView: View {
    let snappedStartMinute: Int
    let contentWidth: CGFloat

    private var hoveredY: CGFloat {
        CGFloat(snappedStartMinute) * DayCalendarLayout.pixelsPerMinute
    }

    /// One 15-minute slot tall (matches grid snap).
    private var slotHeight: CGFloat {
        15 * DayCalendarLayout.pixelsPerMinute
    }

    private var timeLabel: String {
        let snapped = snappedStartMinute
        let hour = snapped / 60
        let minute = snapped % 60
        return String(format: "%02d:%02d", hour, minute)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.blue.opacity(0.22))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.blue.opacity(0.35), lineWidth: 1)
                }
                .frame(
                    width: max(0, contentWidth - DayCalendarLayout.eventLeadingInset),
                    height: max(slotHeight, 20)
                )
                .offset(x: DayCalendarLayout.eventLeadingInset, y: hoveredY)

            Rectangle()
                .fill(Color.blue.opacity(0.9))
                .frame(width: 2, height: max(slotHeight, 24) + 6)
                .offset(
                    x: DayCalendarLayout.eventLeadingInset - 5,
                    y: hoveredY - 3
                )

            Text(timeLabel)
                .font(.caption.bold())
                .monospacedDigit()
                .foregroundStyle(Color.white)
                .padding(.vertical, 7)
                .padding(.horizontal, 8)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(white: 0.12))
                }
                .shadow(color: .black.opacity(0.28), radius: 4, x: 0, y: 2)
                .offset(x: DayCalendarLayout.eventLeadingInset + 6, y: hoveredY - 20)
        }
        .allowsHitTesting(false)
        .animation(.easeInOut(duration: 0.12), value: snappedStartMinute)
    }
}

// MARK: - Workout card + drag

private struct DayCalendarWorkoutCardView: View {
    let ref: WorkoutRef
    @ObservedObject var store: ClientStore
    let cardWidth: CGFloat
    var onTapEdit: () -> Void
    var dropDelegate: DayCalendarTimelineDropDelegate

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(ref.clientColor)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(ref.clientName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.white)
                    .lineLimit(2)
                Text(ref.date, style: .time)
                    .font(.caption)
                    .foregroundStyle(Color.gray)
            }
            Spacer(minLength: 0)
            Image(systemName: ref.status.calendarStatusIconName)
                .font(.system(size: 14))
                .foregroundStyle(ref.status.calendarStatusIconColor)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(ref.status.calendarCardBackgroundTint)
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            }
        }
        .shadow(color: .black.opacity(0.35), radius: 10, x: 0, y: 4)
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onTapGesture { onTapEdit() }
        .onDrag {
            NSItemProvider(object: ref.workoutId.uuidString as NSString)
        }
        .onDrop(of: [UTType.text], delegate: dropDelegate)
    }
}

// MARK: - Редактирование тренировки (календарь: день / неделя / месяц)

struct CalendarWorkoutEditSheet: View {
    @ObservedObject var store: ClientStore
    let ref: WorkoutRef

    @Environment(\.dismiss) private var dismiss
    private let calendar = Calendar.current

    private var workoutBinding: Binding<Workout> {
        store.bindingForWorkout(workoutId: ref.workoutId, clientId: ref.clientId)
    }

    private var dateOnlyBinding: Binding<Date> {
        Binding(
            get: { calendar.startOfDay(for: workoutBinding.wrappedValue.date) },
            set: { newDay in
                var w = workoutBinding.wrappedValue
                let h = calendar.component(.hour, from: w.date)
                let mi = calendar.component(.minute, from: w.date)
                w.date = calendar.date(bySettingHour: h, minute: mi, second: 0, of: newDay) ?? newDay
                workoutBinding.wrappedValue = w
            }
        )
    }

    private var timeOnlyBinding: Binding<Date> {
        Binding(
            get: {
                let d = workoutBinding.wrappedValue.date
                let anchor = calendar.startOfDay(for: Date())
                let h = calendar.component(.hour, from: d)
                let mi = calendar.component(.minute, from: d)
                return calendar.date(bySettingHour: h, minute: mi, second: 0, of: anchor) ?? d
            },
            set: { picked in
                var w = workoutBinding.wrappedValue
                let day = calendar.startOfDay(for: w.date)
                let h = calendar.component(.hour, from: picked)
                let mi = calendar.component(.minute, from: picked)
                w.date = calendar.date(bySettingHour: h, minute: mi, second: 0, of: day) ?? w.date
                workoutBinding.wrappedValue = w
            }
        )
    }

    private var durationBinding: Binding<Int> {
        Binding(
            get: { workoutBinding.wrappedValue.duration },
            set: { newVal in
                var w = workoutBinding.wrappedValue
                w.duration = newVal
                workoutBinding.wrappedValue = w
            }
        )
    }

    private var statusBinding: Binding<WorkoutStatus> {
        Binding(
            get: { workoutBinding.wrappedValue.status },
            set: { newStatus in
                store.setWorkoutStatus(newStatus, workoutId: ref.workoutId, for: ref.clientId)
            }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Клиент") {
                    Text(ref.clientName)
                        .foregroundStyle(.primary)
                }
                .listRowBackground(Color(white: 0.1))

                Section("Дата и время") {
                    DatePicker("Дата", selection: dateOnlyBinding, displayedComponents: .date)
                    DatePicker("Время", selection: timeOnlyBinding, displayedComponents: .hourAndMinute)
                }
                .listRowBackground(Color(white: 0.1))

                Section("Параметры") {
                    Stepper("Длительность: \(workoutBinding.wrappedValue.duration) мин", value: durationBinding, in: 15...300, step: 15)
                    Picker("Статус", selection: statusBinding) {
                        ForEach(WorkoutStatus.allCases, id: \.self) { status in
                            Text(status.rawValue).tag(status)
                        }
                    }
                }
                .listRowBackground(Color(white: 0.1))

                Section {
                    Button("Удалить тренировку", role: .destructive) {
                        store.removeWorkout(workoutId: ref.workoutId, clientId: ref.clientId)
                        dismiss()
                    }
                }
                .listRowBackground  (Color(white: 0.1))
            }
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .navigationTitle("Тренировка")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Отображение статуса в календаре (день / неделя / месяц)

extension WorkoutStatus {
    var calendarStatusIconName: String {
        switch self {
        case .planned: return "clock"
        case .completed: return "checkmark.circle.fill"
        case .cancelled: return "xmark.circle.fill"
        case .noShow: return "exclamationmark.triangle.fill"
        }
    }

    var calendarStatusIconColor: Color {
        switch self {
        case .planned: return Color.gray.opacity(0.45)
        case .completed: return .green
        case .cancelled: return .red
        case .noShow: return .orange
        }
    }

    var calendarCardBackgroundTint: Color {
        switch self {
        case .planned: return .clear
        case .completed: return Color.green.opacity(0.14)
        case .cancelled: return Color.red.opacity(0.14)
        case .noShow: return Color.orange.opacity(0.14)
        }
    }
}
