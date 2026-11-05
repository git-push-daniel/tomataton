import Charts
import SwiftUI
import TomatoKit

/// Stacked column per day: focus at the bottom, rest on top.
/// Hover a day for its numbers; click to select it.
struct WeekChart: View {
    let days: [DayTotals]
    @Binding var selection: Date

    @State private var hovered: Date?
    @State private var plotHeight: CGFloat = 160
    @State private var tooltipSize: CGSize = .zero

    private static let focus = "Focus"
    private static let rest = "Rest"
    private static let barWidth: CGFloat = 22
    private static let gap: CGFloat = 2  // surface gap between stacked segments, in points

    private let calendar = Calendar.current

    var body: some View {
        let scale = YScale(maxHours: days.map { hours($0.totals.worked + $0.totals.rested) }.max() ?? 0)
        // The 2pt gap expressed in hours, so it stays 2pt whatever the scale.
        let gapHours = scale.max * Self.gap / max(plotHeight, 1)

        Chart {
            ForEach(days) { day in
                if day.day.start == selection {
                    // Faint band behind the selected day.
                    RectangleMark(x: .value("Day", day.day.start, unit: .day))
                        .foregroundStyle(Color.secondary.opacity(0.08))
                }
                ForEach(segments(for: day, gapHours: gapHours)) { segment in
                    BarMark(
                        x: .value("Day", day.day.start, unit: .day),
                        yStart: .value("From", segment.from),
                        yEnd: .value("To", segment.to),
                        width: .fixed(Self.barWidth)
                    )
                    .foregroundStyle(by: .value("Kind", segment.kind))
                    // 4pt rounded data end on the top segment only; square at the baseline.
                    .clipShape(segment.isTop ? AnyShape(topRounded) : AnyShape(Rectangle()))
                    .opacity(hovered == day.day.start ? 0.8 : 1)
                    .accessibilityLabel(day.day.start.formatted(.dateTime.weekday(.wide).day().month()))
                    .accessibilityValue("\(segment.kind) \(TimeInterval(segment.seconds).shortDuration)")
                }
                // Selective direct label: only the selected day's total, on its cap.
                if day.day.start == selection, total(day) > 0 {
                    PointMark(x: .value("Day", day.day.start, unit: .day), y: .value("Total", hours(total(day))))
                        .symbolSize(0)
                        .annotation(position: .top, spacing: 4) {
                            Text(total(day).shortDuration)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Color.secondary)
                        }
                }
            }
        }
        .chartForegroundStyleScale([Self.focus: Phase.work.tint, Self.rest: Phase.shortBreak.tint])
        .chartLegend(position: .top, alignment: .leading, spacing: 12) {
            // Square keys to mirror the bars (the default legend uses circles).
            HStack(spacing: 14) {
                LegendKey(label: Self.focus, color: Phase.work.tint)
                LegendKey(label: Self.rest, color: Phase.shortBreak.tint)
            }
        }
        // The whole week, so the last day's column isn't cut off.
        .chartXScale(domain: (days.first?.day.start ?? .now)...(days.last?.day.end ?? .now))
        .chartYScale(domain: 0...scale.max)
        .chartYAxis {
            AxisMarks(position: .leading, values: scale.ticks) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 1))
                    .foregroundStyle(Color.secondary.opacity(0.2))
                AxisValueLabel {
                    if let hours = value.as(Double.self) { Text(Self.tickLabel(hours: hours)) }
                }
            }
        }
        .chartXAxis {
            // The week's end is an extra, unlabeled tick so the last label can center too.
            AxisMarks(values: days.map(\.day.start) + [days.last?.day.end ?? .now]) { value in
                AxisValueLabel(centered: true) {
                    if let date = value.as(Date.self), date != days.last?.day.end {
                        Text(date.formatted(.dateTime.weekday(.abbreviated)))
                            .fontWeight(date == selection ? .semibold : .regular)
                            .foregroundStyle(date == selection ? Color.primary : Color.secondary)
                    }
                }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                ZStack(alignment: .topLeading) {
                    hitLayer(proxy: proxy, geometry: geometry)
                    tooltip(proxy: proxy, geometry: geometry)
                }
            }
        }
        #if DEBUG
        .onAppear {
            if let index = DebugSnapshot.hoveredDayIndex, days.indices.contains(index) {
                hovered = days[index].day.start
            }
        }
        #endif
        .overlay {
            if days.allSatisfy({ total($0) == 0 }) {
                Text("No sessions this week")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Overlay

    /// The whole day column is the hit target, not just the painted bar.
    private func hitLayer(proxy: ChartProxy, geometry: GeometryProxy) -> some View {
        Rectangle()
            .fill(.clear)
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                #if DEBUG
                if DebugSnapshot.hoveredDayIndex != nil { return }  // forced hover; ignore the real pointer
                #endif
                switch phase {
                case .active(let location): hovered = day(at: location, proxy: proxy, geometry: geometry)
                case .ended: hovered = nil
                }
            }
            .onTapGesture { location in
                if let day = day(at: location, proxy: proxy, geometry: geometry) { selection = day }
            }
            .onAppear { plotHeight = proxy.plotSize.height }
            .onChange(of: proxy.plotSize.height) { _, height in plotHeight = height }
    }

    /// Drawn above the chart (marks drawn later would cover an annotation), beside
    /// the hovered column so it never hides the mark being inspected. On the left
    /// for the last two days so it stays inside the chart.
    @ViewBuilder
    private func tooltip(proxy: ChartProxy, geometry: GeometryProxy) -> some View {
        if let hovered, let index = days.firstIndex(where: { $0.day.start == hovered }),
           let plotFrame = proxy.plotFrame,
           let centerX = proxy.position(forX: days[index].day.start.addingTimeInterval(days[index].day.duration / 2)) {
            let frame = geometry[plotFrame]
            let onLeft = index >= days.count - 2
            let clearance = Self.barWidth / 2 + 8
            let x = onLeft ? frame.minX + centerX - clearance - tooltipSize.width : frame.minX + centerX + clearance
            DayTooltip(day: days[index])
                .onGeometryChange(for: CGSize.self) { $0.size } action: { tooltipSize = $0 }
                .offset(x: x, y: frame.midY - tooltipSize.height / 2)
                .allowsHitTesting(false)
        }
    }

    // MARK: - Data

    private struct Segment: Identifiable {
        let kind: String
        let from: Double
        let to: Double
        let seconds: Double
        let isTop: Bool
        var id: String { kind }
    }

    private func segments(for day: DayTotals, gapHours: Double) -> [Segment] {
        let worked = hours(day.totals.worked), rested = hours(day.totals.rested)
        var result: [Segment] = []
        if worked > 0 {
            result.append(Segment(kind: Self.focus, from: 0, to: worked, seconds: day.totals.worked, isTop: rested == 0))
        }
        if rested > 0 {
            let from = worked > 0 ? worked + gapHours : 0
            result.append(Segment(kind: Self.rest, from: from, to: from + rested, seconds: day.totals.rested, isTop: true))
        }
        return result
    }

    private func total(_ day: DayTotals) -> TimeInterval { day.totals.worked + day.totals.rested }
    private func hours(_ seconds: TimeInterval) -> Double { seconds / 3600 }

    private var topRounded: UnevenRoundedRectangle {
        UnevenRoundedRectangle(topLeadingRadius: 4, topTrailingRadius: 4)
    }

    private func day(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) -> Date? {
        guard let plotFrame = proxy.plotFrame else { return nil }
        let x = location.x - geometry[plotFrame].origin.x
        guard let date: Date = proxy.value(atX: x) else { return nil }
        let start = calendar.startOfDay(for: date)
        return days.contains { $0.day.start == start } ? start : nil
    }

    // MARK: - Axis

    /// Clean y-axis bounds and ticks in hours, e.g. 0, 1h, 2h, 3h.
    private struct YScale {
        let max: Double
        let ticks: [Double]

        init(maxHours: Double) {
            let step: Double = switch maxHours {
            case ..<2: 0.5
            case ..<6: 1
            case ..<12: 2
            default: 4
            }
            let top = Swift.max(step * 2, (maxHours / step).rounded(.up) * step)
            // Headroom so the selected day's label above the tallest bar isn't clipped.
            max = maxHours > top - step / 3 ? top + step : top
            ticks = Array(stride(from: 0, through: max, by: step))
        }
    }

    static func tickLabel(hours: Double) -> String {
        let minutes = Int((hours * 60).rounded())
        if minutes == 0 { return "0" }
        if minutes % 60 == 0 { return "\(minutes / 60)h" }
        return minutes < 60 ? "\(minutes)m" : "\(minutes / 60)h \(minutes % 60)m"
    }
}

private struct LegendKey: View {
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 8, height: 8)
            // Explicit Color: inside a chart legend `.secondary` resolves against the series colors.
            Text(label).font(.caption).foregroundStyle(Color.secondary)
        }
    }
}

/// Hover readout for one day. Values lead, labels follow; series keyed by a short line.
private struct DayTooltip: View {
    let day: DayTotals

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(day.day.start.formatted(.dateTime.weekday(.wide).month().day()))
                .font(.caption)
                .foregroundStyle(Color.secondary)
            row(day.totals.worked.shortDuration, "Focus", color: Phase.work.tint)
            row(day.totals.rested.shortDuration, "Rest", color: Phase.shortBreak.tint)
            Text("\(day.totals.pomodoros) 🍅")
                .font(.callout.weight(.semibold))
        }
        .padding(8)
        // Opaque, so bars behind it don't show through.
        .background(Color(nsColor: .windowBackgroundColor), in: .rect(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.secondary.opacity(0.25)))
        .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
        .fixedSize()
    }

    private func row(_ value: String, _ label: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Capsule().fill(color).frame(width: 10, height: 2)
            Text(value).font(.callout.weight(.semibold)).monospacedDigit()
            Text(label).font(.caption).foregroundStyle(Color.secondary)
        }
    }
}
