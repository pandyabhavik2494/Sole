import Foundation
import Testing
@testable import Sole

/// Builds `[DayKey: Double]` series counting back from a day.
private func series(endingBefore day: DayKey, _ values: [Double]) -> [DayKey: Double] {
    var result: [DayKey: Double] = [:]
    for (index, value) in values.enumerated() {
        result[day.adding(days: -(index + 1))] = value
    }
    return result
}

private let today = DayKey(year: 2026, month: 10, day: 3)

struct BaselineTests {
    @Test func percentileInterpolates() {
        let sorted = [1.0, 2, 3, 4]
        #expect(Baseline.percentile(sorted, 0.25) == 1.75)
        #expect(Baseline.percentile(sorted, 0.5) == 2.5)
        #expect(Baseline.percentile(sorted, 0.75) == 3.25)
        #expect(Baseline.percentile([5], 0.9) == 5)
        #expect(Baseline.percentile([], 0.5).isNaN)
    }

    @Test func needsSevenDays() {
        #expect(Baseline.usualRange(series(endingBefore: today, [60, 61, 62, 59, 60, 63]), before: today) == nil)
        let range = Baseline.usualRange(series(endingBefore: today, [60, 61, 62, 59, 60, 63, 58]), before: today)
        #expect(range?.days == 7)
        #expect(range?.median == 60)
    }

    @Test func middleHalfOfTheLast28Days() {
        // 1…28 for the 28 days before today, plus a huge value on day 29 that must be ignored.
        var values = series(endingBefore: today, (1...28).map(Double.init))
        values[today.adding(days: -29)] = 1_000
        let range = Baseline.usualRange(values, before: today)!
        #expect(range.low == 7.75)
        #expect(range.median == 14.5)
        #expect(range.high == 21.25)
        #expect(range.days == 28)
    }

    @Test func neverIncludesTheDayItself() {
        var values = series(endingBefore: today, Array(repeating: 60, count: 10))
        values[today] = 200
        #expect(Baseline.usualRange(values, before: today)?.high == 60)
    }

    @Test func sickAndTravelDaysAreLeftOut() {
        // A flu week at 75 bpm would otherwise drag the usual range up.
        var values = series(endingBefore: today, Array(repeating: 60, count: 20))
        var sick: Set<DayKey> = []
        for offset in 1...5 {
            let day = today.adding(days: -offset)
            values[day] = 75
            sick.insert(day)
        }
        let withFlu = Baseline.usualRange(values, before: today)!
        let withoutFlu = Baseline.usualRange(values, before: today, excluding: sick)!
        #expect(withFlu.high > 60)
        #expect(withoutFlu.high == 60)
        #expect(withoutFlu.excludedDays == 5)
        #expect(withoutFlu.days == 15)
    }

    @Test func exclusionCanDropBelowTheMinimum() {
        let values = series(endingBefore: today, Array(repeating: 60, count: 8))
        let tagged = Set((1...2).map { today.adding(days: -$0) })
        #expect(Baseline.usualRange(values, before: today, excluding: tagged) == nil)
    }

    @Test func sparseDataStillCounts() {
        // Blood oxygen every few days: 7 readings spread across 28 days is enough.
        var values: [DayKey: Double] = [:]
        for offset in stride(from: 1, through: 28, by: 4) { values[today.adding(days: -offset)] = 97 }
        #expect(Baseline.usualRange(values, before: today)?.days == 7)
    }

    @Test func nonFiniteValuesAreIgnored() {
        var values = series(endingBefore: today, Array(repeating: 60, count: 7))
        values[today.adding(days: -8)] = .nan
        #expect(Baseline.usualRange(values, before: today)?.days == 7)
    }
}

struct StatusTests {
    let range = UsualRange(low: 58, median: 60, high: 63, days: 28, excludedDays: 0)

    @Test func insideOrJustOutsideIsUsual() {
        #expect(StatusRules.assess(.restingHeartRate, value: 60, range: range).status == .usual)
        // 2 bpm above the band is within the 3 bpm minimum.
        #expect(StatusRules.assess(.restingHeartRate, value: 65, range: range).status == .usual)
    }

    @Test func restingHeartRateHigherIsWorthALook() {
        let assessment = StatusRules.assess(.restingHeartRate, value: 69, range: range)
        #expect(assessment.status == .worthALook)
        #expect(assessment.direction == .above)
        #expect(assessment.severity == 2)
    }

    @Test func restingHeartRateLowerIsBetter() {
        #expect(StatusRules.assess(.restingHeartRate, value: 54, range: range).status == .better)
    }

    @Test func bloodOxygenOnlyFlagsLow() {
        let oxygen = UsualRange(low: 96, median: 97, high: 98, days: 20, excludedDays: 0)
        #expect(StatusRules.assess(.bloodOxygen, value: 93, range: oxygen).status == .worthALook)
        #expect(StatusRules.assess(.bloodOxygen, value: 100.5, range: oxygen).status == .usual)
    }

    @Test func relativeThresholdsScaleWithTheMedian() {
        let energy = UsualRange(low: 520, median: 640, high: 780, days: 28, excludedDays: 0)
        // 10% of 640 is 64 kcal.
        #expect(StatusRules.assess(.activeEnergy, value: 840, range: energy).status == .usual)
        #expect(StatusRules.assess(.activeEnergy, value: 850, range: energy).status == .better)
        #expect(StatusRules.assess(.activeEnergy, value: 450, range: energy).status == .worthALook)
    }

    @Test func weightIsNeverJudged() {
        let weight = UsualRange(low: 74, median: 74.5, high: 75, days: 20, excludedDays: 0)
        #expect(StatusRules.assess(.weight, value: 80, range: weight).status == .usual)
    }

    @Test func missingDataAndMissingRange() {
        #expect(StatusRules.assess(.restingHeartRate, value: nil, range: range).status == .noData)
        #expect(StatusRules.assess(.restingHeartRate, value: 60, range: nil).status == .learning)
    }

    @Test func paceUsesTheThresholdAndAFloor() {
        // Early morning: 300 vs a usual 100 is +200 steps, under the 500-step floor.
        #expect(StatusRules.assess(.steps, pace: PaceComparison(actual: 300, expected: 100), hasHistory: true).status == .usual)
        #expect(StatusRules.assess(.steps, pace: PaceComparison(actual: 7_000, expected: 5_000), hasHistory: true).status == .better)
        #expect(StatusRules.assess(.steps, pace: PaceComparison(actual: 3_000, expected: 5_000), hasHistory: true).status == .worthALook)
        #expect(StatusRules.assess(.steps, pace: nil, hasHistory: true).status == .learning)
        #expect(StatusRules.assess(.steps, pace: nil, hasHistory: false).status == .noData)
    }
}

struct UsualPaceTests {
    let calendar = TestCalendars.losAngeles

    /// The same hourly pattern on each of the previous `weeks` same weekdays.
    func hourly(weeks: [Int], before day: DayKey, perHour: (Int) -> Double) -> [Date: Double] {
        var result: [Date: Double] = [:]
        for week in weeks {
            let start = day.adding(days: -7 * week).start(in: calendar)
            for hour in 0..<24 {
                let value = perHour(hour)
                if value > 0 { result[calendar.date(byAdding: .hour, value: hour, to: start)!] = value }
            }
        }
        return result
    }

    @Test func medianOfTheSameWeekdayByTheSameTime() {
        // Saturday 3 Oct at 9:30: each past Saturday walked 1,000 steps an hour from 7 am.
        var data = hourly(weeks: Array(1...8), before: today) { $0 >= 7 ? 1_000 : 0 }
        // A Friday must not count.
        data[calendar.date(byAdding: .hour, value: 8, to: today.adding(days: -1).start(in: calendar))!] = 50_000
        let now = TestCalendars.date(2026, 10, 3, 9, 30)
        #expect(UsualPace.expected(hourly: data, at: now, calendar: calendar) == 2_500)
    }

    @Test func daysWithoutDataAreSkipped() {
        // Only 3 Saturdays have data; the 5 empty ones (phone off) don't pull the median to zero.
        let data = hourly(weeks: [1, 3, 5], before: today) { $0 >= 7 ? 1_000 : 0 }
        let now = TestCalendars.date(2026, 10, 3, 10)
        #expect(UsualPace.expected(hourly: data, at: now, calendar: calendar) == 3_000)
    }

    @Test func needsThreeDays() {
        let data = hourly(weeks: [1, 2], before: today) { _ in 100 }
        #expect(UsualPace.expected(hourly: data, at: TestCalendars.date(2026, 10, 3, 12), calendar: calendar) == nil)
    }

    @Test func followsTheClockAcrossDaylightSaving() {
        // Sunday 8 Mar 2026 lost 2–3 am. "By 10 am" on that day still means 10 am on the clock.
        let sunday = DayKey(year: 2026, month: 3, day: 15)
        let springForward = DayKey(year: 2026, month: 3, day: 8)
        var data: [Date: Double] = [:]
        for day in [springForward, sunday.adding(days: -14), sunday.adding(days: -21)] {
            let start = day.start(in: calendar)
            // One hourly bucket starting at 9 am wall-clock time.
            data[calendar.date(bySettingHour: 9, minute: 0, second: 0, of: start)!] = 600
        }
        let now = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: sunday.start(in: calendar))!
        #expect(UsualPace.expected(hourly: data, at: now, calendar: calendar) == 600)
    }

    @Test func comparisonPositions() {
        let threshold = Metric.Threshold.relative(0.15)
        #expect(PaceComparison(actual: 6_000, expected: 5_000).position(threshold: threshold, floor: 500) == .ahead)
        #expect(PaceComparison(actual: 5_400, expected: 5_000).position(threshold: threshold, floor: 500) == .onPace)
        #expect(PaceComparison(actual: 4_000, expected: 5_000).position(threshold: threshold, floor: 500) == .behind)
    }
}

struct TrendTests {
    func values(recent: Double, prior: Double, recentDays: Int = 28, priorDays: Int = 84) -> [DayKey: Double] {
        var result: [DayKey: Double] = [:]
        for offset in 1...recentDays { result[today.adding(days: -offset)] = recent }
        for offset in 29...(28 + priorDays) { result[today.adding(days: -offset)] = prior }
        return result
    }

    @Test func restingHeartRateFallingIsBetter() {
        let trend = TrendRules.trend(.restingHeartRate, values: values(recent: 57.6, prior: 61.7), today: today)!
        #expect(trend.direction == .down)
        #expect(trend.meaning == .better)
        #expect(abs(trend.change + 4.1) < 0.0001)
    }

    @Test func smallChangesAreSteady() {
        #expect(TrendRules.trend(.restingHeartRate, values: values(recent: 60, prior: 61.5), today: today)?.meaning == .steady)
        // Steps: 10% of 8,000 is 800.
        #expect(TrendRules.trend(.steps, values: values(recent: 8_700, prior: 8_000), today: today)?.direction == .steady)
        #expect(TrendRules.trend(.steps, values: values(recent: 8_900, prior: 8_000), today: today)?.meaning == .better)
    }

    @Test func fallingStepsAreChanging() {
        #expect(TrendRules.trend(.steps, values: values(recent: 6_000, prior: 8_000), today: today)?.meaning == .worse)
    }

    @Test func weightIsNeutral() {
        let trend = TrendRules.trend(.weight, values: values(recent: 74, prior: 76), today: today)
        #expect(trend?.direction == .down)
        #expect(trend?.meaning == .neutral)
    }

    @Test func needsFourteenDaysInEachWindow() {
        #expect(TrendRules.trend(.restingHeartRate, values: values(recent: 57, prior: 62, recentDays: 13), today: today) == nil)
        #expect(TrendRules.trend(.restingHeartRate, values: values(recent: 57, prior: 62, recentDays: 14), today: today) != nil)
        #expect(TrendRules.trend(.restingHeartRate, values: values(recent: 57, prior: 62, priorDays: 13), today: today) == nil)
    }

    @Test func taggedDaysAreLeftOut() {
        var data = values(recent: 60, prior: 60)
        var sick: Set<DayKey> = []
        for offset in 1...7 {
            data[today.adding(days: -offset)] = 80
            sick.insert(today.adding(days: -offset))
        }
        #expect(TrendRules.trend(.restingHeartRate, values: data, today: today)?.meaning == .worse)
        #expect(TrendRules.trend(.restingHeartRate, values: data, today: today, excluding: sick)?.meaning == .steady)
    }

    @Test func metricsWithoutATrend() {
        #expect(TrendRules.trend(.heartRate, values: values(recent: 70, prior: 80), today: today) == nil)
    }

    @Test func trendWeightSmoothsOneSaltyDinner() {
        var weights: [DayKey: Double] = [:]
        for offset in 1...10 { weights[today.adding(days: -offset)] = 75 }
        weights[today] = 76.5
        let smoothed = TrendWeight.smoothed(weights)
        #expect(abs(smoothed[today]! - 75.15) < 0.0001)
    }

    @Test func trendWeightWeeklyChange() {
        var weights: [DayKey: Double] = [:]
        for offset in 0...30 { weights[today.adding(days: -offset)] = 70 + Double(offset) * 0.1 }
        let smoothed = TrendWeight.smoothed(weights)
        let change = TrendWeight.change(smoothed, overDays: 7, endingOn: today)!
        #expect(change < 0)
        #expect(TrendWeight.change([:], overDays: 7, endingOn: today) == nil)
        // A single weigh-in has nothing to compare with.
        #expect(TrendWeight.change([today: 70], overDays: 7, endingOn: today) == nil)
    }
}

struct HeadlineTests {
    func insight(_ metric: Metric, _ status: Status, severity: Double = 1, direction: Assessment.Direction? = nil, pace: PaceComparison? = nil) -> MetricInsight {
        MetricInsight(metric: metric, value: nil, range: nil, assessment: Assessment(status: status, direction: direction, severity: severity), trend: nil, pace: pace)
    }

    func metrics(_ list: [MetricInsight]) -> [Metric: MetricInsight] {
        Dictionary(uniqueKeysWithValues: list.map { ($0.metric, $0) })
    }

    @Test func worthALookComesFirst() {
        let headline = InsightBuilder.headline(metrics: metrics([
            insight(.restingHeartRate, .better, severity: 5),
            insight(.bloodOxygen, .worthALook, severity: 1.2, direction: .below),
            insight(.walkingHeartRate, .usual),
        ]), weekday: "Saturday")
        #expect(headline.title == "Blood oxygen is lower than usual.")
        #expect(headline.detail == "One more is better than usual.")
    }

    @Test func largestDeviationWins() {
        let headline = InsightBuilder.headline(metrics: metrics([
            insight(.restingHeartRate, .worthALook, severity: 1.5, direction: .above),
            insight(.walkingHeartRate, .worthALook, severity: 3, direction: .above),
        ]), weekday: "Saturday")
        #expect(headline.title == "Walking heart rate is higher than usual.")
        #expect(headline.detail == "One more thing is worth a look.")
    }

    @Test func tiesFollowMetricOrder() {
        let headline = InsightBuilder.headline(metrics: metrics([
            insight(.walkingHeartRate, .better, severity: 2),
            insight(.restingHeartRate, .better, severity: 2),
        ]), weekday: "Saturday")
        #expect(headline.title == "Resting heart rate is better than usual.")
    }

    @Test func betterWithStepsPace() {
        let headline = InsightBuilder.headline(metrics: metrics([
            insight(.restingHeartRate, .better, severity: 1.3, direction: .below),
            insight(.walkingHeartRate, .usual),
            insight(.steps, .better, pace: PaceComparison(actual: 7_842, expected: 6_700)),
        ]), weekday: "Saturday")
        #expect(headline == Headline(title: "Resting heart rate is better than usual.", detail: "Everything else is in your usual range. You're ahead of a usual Saturday."))
    }

    @Test func allUsual() {
        let headline = InsightBuilder.headline(metrics: metrics([
            insight(.restingHeartRate, .usual),
            insight(.steps, .usual, pace: PaceComparison(actual: 5_000, expected: 5_100)),
        ]), weekday: "Monday")
        #expect(headline == Headline(title: "Everything is in your usual range.", detail: "You're on pace for a usual Monday."))
    }

    @Test func stepsAloneNeverMakeTheTitle() {
        let headline = InsightBuilder.headline(metrics: metrics([
            insight(.restingHeartRate, .usual),
            insight(.steps, .worthALook, severity: 4, direction: .below, pace: PaceComparison(actual: 1_000, expected: 6_000)),
        ]), weekday: "Monday")
        #expect(headline.title == "Everything is in your usual range.")
        #expect(headline.detail == "You're behind a usual Monday.")
    }

    @Test func learningAndNoData() {
        #expect(InsightBuilder.headline(metrics: metrics([insight(.restingHeartRate, .learning)]), weekday: "Monday").title == "Sole is learning your normal.")
        #expect(InsightBuilder.headline(metrics: metrics([insight(.restingHeartRate, .noData)]), weekday: "Monday") == Headline(title: "Here's your day so far.", detail: ""))
    }
}

struct InsightBuilderTests {
    let calendar = TestCalendars.losAngeles

    func daily(_ metric: Metric, _ values: [DayKey: Double]) -> [DayKey: DailyValue] {
        values.reduce(into: [:]) { $0[$1.key] = DailyValue(day: $1.key, metric: metric, value: $1.value, min: nil, max: nil) }
    }

    func input(series: [Metric: [DayKey: DailyValue]], tags: [DayKey: Set<DayTagKind>] = [:]) -> InsightBuilder.Input {
        InsightBuilder.Input(series: series, tags: tags, hourlySteps: [:], hourlyActiveEnergy: [:], now: TestCalendars.date(2026, 10, 3, 9, 41), calendar: calendar, locale: Locale(identifier: "en_US"))
    }

    @Test func usesYesterdaysRestingHeartRateUntilTodaysArrives() {
        var values = series(endingBefore: today.adding(days: -1), Array(repeating: 60, count: 20))
        values[today.adding(days: -1)] = 52
        let insights = InsightBuilder.build(input(series: [.restingHeartRate: daily(.restingHeartRate, values)]))
        #expect(insights[.restingHeartRate].value?.day == today.adding(days: -1))
        #expect(insights[.restingHeartRate].status == .better)
        #expect(insights.headline.title == "Resting heart rate is better than usual.")
    }

    @Test func sickDaysDontHideAHighReading() {
        // A sick week inflated the raw range; leaving it out keeps today's 66 worth a look.
        var values = series(endingBefore: today, Array(repeating: 60, count: 28))
        var tags: [DayKey: Set<DayTagKind>] = [:]
        for offset in 1...10 {
            values[today.adding(days: -offset)] = 70
            tags[today.adding(days: -offset)] = [.sick]
        }
        values[today] = 67
        let untagged = InsightBuilder.build(input(series: [.restingHeartRate: daily(.restingHeartRate, values)]))
        let tagged = InsightBuilder.build(input(series: [.restingHeartRate: daily(.restingHeartRate, values)], tags: tags))
        #expect(untagged[.restingHeartRate].status == .usual)
        #expect(tagged[.restingHeartRate].status == .worthALook)
    }

    @Test func otherTagsDontExclude() {
        var values = series(endingBefore: today, Array(repeating: 60, count: 8))
        values[today] = 60
        let tags: [DayKey: Set<DayTagKind>] = [today.adding(days: -1): [.lateNight], today.adding(days: -2): [.alcohol]]
        let insights = InsightBuilder.build(input(series: [.restingHeartRate: daily(.restingHeartRate, values)], tags: tags))
        #expect(insights[.restingHeartRate].range?.days == 8)
    }

    @Test func tallyCountsOnlyJudgedMetrics() {
        let usualDays = series(endingBefore: today, Array(repeating: 60, count: 10))
        var rhr = usualDays
        rhr[today] = 50
        var walking = usualDays.mapValues { $0 + 40 }
        walking[today] = 100
        var weight = usualDays.mapValues { _ in 74.0 }
        weight[today] = 90
        let insights = InsightBuilder.build(input(series: [
            .restingHeartRate: daily(.restingHeartRate, rhr),
            .walkingHeartRate: daily(.walkingHeartRate, walking),
            .weight: daily(.weight, weight),
        ]))
        #expect(insights.tally == Tally(usual: 1, better: 1, worthALook: 0))
        #expect(insights[.weight].status == .usual)
        #expect(insights[.bloodOxygen].status == .noData)
    }

    @Test func emptyInputIsCalm() {
        let insights = InsightBuilder.build(input(series: [:]))
        #expect(insights.tally.total == 0)
        #expect(insights.headline.title == "Here's your day so far.")
    }
}

struct WeekPatternTests {
    @Test func weekdaysVersusWeekends() {
        var values: [DayKey: Double] = [:]
        for offset in 1...56 {
            let day = today.adding(days: -offset)
            values[day] = (day.weekday == 1 || day.weekday == 7) ? 6_000 : 10_000
        }
        #expect(WeekPattern.weekdayVersusWeekend(values, endingBefore: today) == "higher on weekdays")
        #expect(WeekPattern.weekdayVersusWeekend(values.mapValues { 16_000 - $0 }, endingBefore: today) == "higher at weekends")
        #expect(WeekPattern.weekdayVersusWeekend(values.mapValues { _ in 8_000 }, endingBefore: today) == nil)
        #expect(WeekPattern.weekdayVersusWeekend([:], endingBefore: today) == nil)
    }

    @Test func mostActiveWeekday() {
        var values: [DayKey: Double] = [:]
        for offset in 1...84 {
            let day = today.adding(days: -offset)
            values[day] = day.weekday == 7 ? 14_000 : 8_000 + Double(day.weekday) * 100
        }
        #expect(WeekPattern.mostActiveWeekday(values, endingBefore: today) == 7)
        #expect(WeekPattern.mostActiveWeekday(values.mapValues { _ in 8_000 }, endingBefore: today) == nil)
    }

    @Test func spans() {
        let start = DayKey(year: 2024, month: 6, day: 10)
        #expect(Span.describe(from: start, to: DayKey(year: 2026, month: 10, day: 3)) == "2 years, 3 months")
        #expect(Span.describe(from: start, to: DayKey(year: 2026, month: 10, day: 10)) == "2 years, 4 months")
        #expect(Span.describe(from: start, to: DayKey(year: 2025, month: 6, day: 10)) == "1 year")
        #expect(Span.describe(from: start, to: DayKey(year: 2024, month: 7, day: 1)) == "3 weeks")
        #expect(Span.describe(from: start, to: DayKey(year: 2024, month: 6, day: 11)) == "1 day")
    }
}
