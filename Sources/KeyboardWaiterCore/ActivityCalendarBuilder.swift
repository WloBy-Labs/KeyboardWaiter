import Foundation

enum CalendarGranularity: Int, CaseIterable {
    case year
    case month
    case day

    var title: String {
        AppLocalizer.calendarGranularityTitle(self)
    }
}

struct CalendarGridCell: Equatable {
    let title: String
    let subtitle: String?
    let total: Int
    let isMuted: Bool
    let isHighlighted: Bool
    let representedDate: Date?
}

struct CalendarGridModel: Equatable {
    let periodTitle: String
    let total: Int
    let columns: Int
    let headerTitles: [String]
    let cells: [CalendarGridCell]
}

enum ActivityCalendarBuilder {
    static func queryRange(
        for referenceDate: Date,
        granularity: CalendarGranularity,
        calendar: Calendar = .current
    ) -> DateInterval {
        switch granularity {
        case .year:
            return calendar.dateInterval(of: .year, for: referenceDate) ?? HourlyBucket.todayRange(containing: referenceDate, calendar: calendar)
        case .month:
            let monthInterval = calendar.dateInterval(of: .month, for: referenceDate) ?? HourlyBucket.todayRange(containing: referenceDate, calendar: calendar)
            let firstVisibleDate = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start)?.start ?? monthInterval.start
            let end = calendar.date(byAdding: .day, value: 42, to: firstVisibleDate) ?? monthInterval.end
            return DateInterval(start: firstVisibleDate, end: end)
        case .day:
            return HourlyBucket.todayRange(containing: referenceDate, calendar: calendar)
        }
    }

    static func shiftedReferenceDate(
        from referenceDate: Date,
        granularity: CalendarGranularity,
        step: Int,
        calendar: Calendar = .current
    ) -> Date {
        switch granularity {
        case .year:
            return calendar.date(byAdding: .year, value: step, to: referenceDate) ?? referenceDate
        case .month:
            return calendar.date(byAdding: .month, value: step, to: referenceDate) ?? referenceDate
        case .day:
            return calendar.date(byAdding: .day, value: step, to: referenceDate) ?? referenceDate
        }
    }

    static func build(
        referenceDate: Date,
        granularity: CalendarGranularity,
        hourlySeries: [HourCount],
        calendar: Calendar = .current,
        locale: Locale = .current
    ) -> CalendarGridModel {
        switch granularity {
        case .year:
            return buildYearModel(referenceDate: referenceDate, hourlySeries: hourlySeries, calendar: calendar, locale: locale)
        case .month:
            return buildMonthModel(referenceDate: referenceDate, hourlySeries: hourlySeries, calendar: calendar, locale: locale)
        case .day:
            return buildDayModel(referenceDate: referenceDate, hourlySeries: hourlySeries, calendar: calendar, locale: locale)
        }
    }

    private static func buildYearModel(
        referenceDate: Date,
        hourlySeries: [HourCount],
        calendar: Calendar,
        locale: Locale
    ) -> CalendarGridModel {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.dateFormat = locale.identifier.hasPrefix("zh") ? "yyyy年" : "yyyy"

        let monthFormatter = DateFormatter()
        monthFormatter.locale = locale
        monthFormatter.calendar = calendar
        monthFormatter.dateFormat = locale.identifier.hasPrefix("zh") ? "M月" : "MMM"

        let currentDate = Date()
        let currentYear = calendar.component(.year, from: currentDate)
        let selectedYear = calendar.component(.year, from: referenceDate)
        let totalsByMonth = aggregate(hourlySeries: hourlySeries, component: .month, calendar: calendar)

        let cells = (1...12).compactMap { month -> CalendarGridCell? in
            var components = calendar.dateComponents([.year], from: referenceDate)
            components.month = month
            components.day = 1

            guard let cellDate = calendar.date(from: components) else { return nil }

            return CalendarGridCell(
                title: monthFormatter.string(from: cellDate),
                subtitle: nil,
                total: totalsByMonth[month] ?? 0,
                isMuted: false,
                isHighlighted: selectedYear == currentYear && month == calendar.component(.month, from: currentDate),
                representedDate: cellDate
            )
        }

        return CalendarGridModel(
            periodTitle: formatter.string(from: referenceDate),
            total: cells.reduce(0) { $0 + $1.total },
            columns: 4,
            headerTitles: [],
            cells: cells
        )
    }

    private static func buildMonthModel(
        referenceDate: Date,
        hourlySeries: [HourCount],
        calendar: Calendar,
        locale: Locale
    ) -> CalendarGridModel {
        let monthInterval = calendar.dateInterval(of: .month, for: referenceDate) ?? HourlyBucket.todayRange(containing: referenceDate, calendar: calendar)
        let firstVisibleDate = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start)?.start ?? monthInterval.start
        let totalsByDay = aggregateByDay(hourlySeries: hourlySeries, calendar: calendar)

        let titleFormatter = DateFormatter()
        titleFormatter.locale = locale
        titleFormatter.calendar = calendar
        titleFormatter.dateFormat = locale.identifier.hasPrefix("zh") ? "yyyy年M月" : "MMMM yyyy"

        let weekdayFormatter = DateFormatter()
        weekdayFormatter.locale = locale
        weekdayFormatter.calendar = calendar

        let currentDate = Date()
        let selectedMonth = calendar.component(.month, from: referenceDate)
        let selectedYear = calendar.component(.year, from: referenceDate)

        var cells: [CalendarGridCell] = []
        for offset in 0..<42 {
            guard let cellDate = calendar.date(byAdding: .day, value: offset, to: firstVisibleDate) else { continue }

            let dayKey = startOfDayTimestamp(for: cellDate, calendar: calendar)
            let total = totalsByDay[dayKey] ?? 0
            let cellMonth = calendar.component(.month, from: cellDate)
            let cellYear = calendar.component(.year, from: cellDate)

            cells.append(
                CalendarGridCell(
                    title: String(calendar.component(.day, from: cellDate)),
                    subtitle: nil,
                    total: total,
                    isMuted: cellMonth != selectedMonth || cellYear != selectedYear,
                    isHighlighted: calendar.isDate(cellDate, inSameDayAs: currentDate),
                    representedDate: cellDate
                )
            )
        }

        let headerTitles = reorderedWeekdaySymbols(calendar: calendar, locale: locale)
        let total = cells.reduce(into: 0) { partialResult, cell in
            if !cell.isMuted {
                partialResult += cell.total
            }
        }

        return CalendarGridModel(
            periodTitle: titleFormatter.string(from: referenceDate),
            total: total,
            columns: 7,
            headerTitles: headerTitles,
            cells: cells
        )
    }

    private static func buildDayModel(
        referenceDate: Date,
        hourlySeries: [HourCount],
        calendar: Calendar,
        locale: Locale
    ) -> CalendarGridModel {
        let titleFormatter = DateFormatter()
        titleFormatter.locale = locale
        titleFormatter.calendar = calendar
        titleFormatter.dateStyle = .medium
        titleFormatter.timeStyle = .none

        let currentDate = Date()
        let selectedHourIfToday = calendar.isDate(referenceDate, inSameDayAs: currentDate)
            ? calendar.component(.hour, from: currentDate)
            : nil

        let totalsByHour = aggregate(hourlySeries: hourlySeries, component: .hour, calendar: calendar)

        let cells = (0..<24).map { hour -> CalendarGridCell in
            CalendarGridCell(
                title: String(format: "%02d:00", hour),
                subtitle: nil,
                total: totalsByHour[hour] ?? 0,
                isMuted: false,
                isHighlighted: selectedHourIfToday == hour,
                representedDate: nil
            )
        }

        return CalendarGridModel(
            periodTitle: titleFormatter.string(from: referenceDate),
            total: cells.reduce(0) { $0 + $1.total },
            columns: 4,
            headerTitles: [],
            cells: cells
        )
    }

    private static func aggregate(
        hourlySeries: [HourCount],
        component: Calendar.Component,
        calendar: Calendar
    ) -> [Int: Int] {
        hourlySeries.reduce(into: [Int: Int]()) { partialResult, entry in
            guard entry.total > 0 else { return }
            let date = HourlyBucket.date(for: entry.bucketStart)
            let bucket = calendar.component(component, from: date)
            partialResult[bucket, default: 0] += entry.total
        }
    }

    private static func aggregateByDay(hourlySeries: [HourCount], calendar: Calendar) -> [Int64: Int] {
        hourlySeries.reduce(into: [Int64: Int]()) { partialResult, entry in
            guard entry.total > 0 else { return }
            let date = HourlyBucket.date(for: entry.bucketStart)
            let dayKey = startOfDayTimestamp(for: date, calendar: calendar)
            partialResult[dayKey, default: 0] += entry.total
        }
    }

    private static func startOfDayTimestamp(for date: Date, calendar: Calendar) -> Int64 {
        Int64(calendar.startOfDay(for: date).timeIntervalSince1970)
    }

    private static func reorderedWeekdaySymbols(calendar: Calendar, locale: Locale) -> [String] {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar

        let symbols = formatter.shortStandaloneWeekdaySymbols ?? formatter.shortWeekdaySymbols ?? []
        guard !symbols.isEmpty else { return [] }

        let firstWeekdayIndex = max(0, calendar.firstWeekday - 1)
        return Array(symbols[firstWeekdayIndex...] + symbols[..<firstWeekdayIndex])
    }
}
