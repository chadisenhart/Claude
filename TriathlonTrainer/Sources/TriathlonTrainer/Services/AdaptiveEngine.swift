import Foundation
import SwiftData

/// The brain of the training app.
/// Analyzes actual performance vs plan, then adjusts upcoming workouts intelligently.
@MainActor
class AdaptiveEngine: ObservableObject {

    @Published var adaptationHistory: [AdaptationEvent] = []
    @Published var weeklyAnalysis: WeeklyAnalysis?
    @Published var fitnessMetrics: FitnessMetrics = FitnessMetrics()

    // MARK: - Weekly Compliance Analysis

    /// Analyzes the past week and returns recommendations for the upcoming week.
    func analyzeWeek(workouts: [Workout]) -> WeeklyAnalysis {
        let completed = workouts.filter { $0.status == .completed || $0.status == .partiallyCompleted }
        let skipped = workouts.filter { $0.status == .skipped }
        let scheduled = workouts.filter { $0.status != .rest }

        let complianceRate = scheduled.isEmpty ? 1.0 : Double(completed.count) / Double(scheduled.count)

        let plannedHours = workouts.reduce(0.0) { $0 + $1.plannedDuration / 3600 }
        let actualHours = workouts.compactMap { $0.result?.actualDuration }.reduce(0.0) { $0 + $1 / 3600 }
        let volumeCompliance = plannedHours > 0 ? min(actualHours / plannedHours, 1.5) : 1.0

        let avgRPE = workouts.compactMap { $0.result?.perceivedEffort }.average()
        let avgCompliance = workouts.compactMap { $0.result?.complianceScore }.average()

        let trend: PerformanceTrend
        switch complianceRate {
        case 0.9...: trend = .improving
        case 0.7..<0.9: trend = .stable
        case 0.5..<0.7: trend = .declining
        default: trend = .poor
        }

        let analysis = WeeklyAnalysis(
            complianceRate: complianceRate,
            volumeCompliance: volumeCompliance,
            workoutsCompleted: completed.count,
            workoutsSkipped: skipped.count,
            plannedHours: plannedHours,
            actualHours: actualHours,
            averageRPE: avgRPE ?? 0,
            averageComplianceScore: avgCompliance ?? 0,
            trend: trend,
            recommendations: buildRecommendations(
                complianceRate: complianceRate,
                volumeCompliance: volumeCompliance,
                averageRPE: avgRPE ?? 0
            )
        )

        weeklyAnalysis = analysis
        updateFitnessMetrics(from: workouts)
        return analysis
    }

    // MARK: - Adaptive Adjustments

    /// Main adaptation function: adjusts upcoming workouts based on performance.
    func adaptPlan(
        upcomingWorkouts: inout [Workout],
        basedOn recentWorkouts: [Workout],
        athleteProfile: AthleteProfile
    ) -> [AdaptationEvent] {
        let analysis = analyzeWeek(workouts: recentWorkouts)
        var events: [AdaptationEvent] = []

        // --- Low compliance: reduce volume ---
        if analysis.complianceRate < 0.6 {
            let event = reduceVolume(workouts: &upcomingWorkouts, by: 0.20, reason: .lowCompliance)
            events.append(event)
        } else if analysis.complianceRate < 0.75 {
            let event = reduceVolume(workouts: &upcomingWorkouts, by: 0.10, reason: .lowCompliance)
            events.append(event)
        }

        // --- High compliance + low RPE: can increase load ---
        if analysis.complianceRate >= 0.9 && analysis.averageRPE < 6 {
            let event = increaseVolume(workouts: &upcomingWorkouts, by: 0.08, reason: .highCompliance)
            events.append(event)
        }

        // --- High RPE (>8.5 on easy days): athlete is accumulating fatigue ---
        let easyWorkoutsWithHighRPE = recentWorkouts.filter {
            ($0.plannedIntensity == .easy || $0.plannedIntensity == .recovery) &&
            ($0.result?.perceivedEffort ?? 0) > 8
        }
        if easyWorkoutsWithHighRPE.count >= 2 {
            let event = insertRecoveryWeek(workouts: &upcomingWorkouts, reason: .fatigue)
            events.append(event)
        }

        // --- Skipped multiple sessions in a row: reschedule if possible ---
        let consecutiveSkips = consecutiveSkippedWorkouts(in: recentWorkouts)
        if consecutiveSkips >= 3 {
            let event = AdaptationEvent(
                date: Date(),
                reason: .lowCompliance,
                description: "3+ consecutive skipped sessions detected. Check for illness or overtraining. This week focuses on easy re-entry.",
                weeksAffected: [1],
                changeType: .intensityReduced
            )
            softLoadNextWeek(workouts: &upcomingWorkouts)
            events.append(event)
        }

        adaptationHistory.append(contentsOf: events)
        return events
    }

    // MARK: - Volume Adjustments

    @discardableResult
    private func reduceVolume(workouts: inout [Workout], by factor: Double, reason: AdaptationEvent.AdaptationReason) -> AdaptationEvent {
        for i in 0..<workouts.count {
            workouts[i].plannedDuration *= (1.0 - factor)
            if let distance = workouts[i].plannedDistance {
                workouts[i].plannedDistance = distance * (1.0 - factor)
            }
        }
        return AdaptationEvent(
            date: Date(),
            reason: reason,
            description: "Volume reduced by \(Int(factor * 100))% due to \(reason.rawValue.lowercased()). Focus on quality over quantity this week.",
            weeksAffected: [1],
            changeType: .volumeReduced
        )
    }

    @discardableResult
    private func increaseVolume(workouts: inout [Workout], by factor: Double, reason: AdaptationEvent.AdaptationReason) -> AdaptationEvent {
        for i in 0..<workouts.count {
            // Only increase easy/moderate sessions, not hard intervals
            if workouts[i].plannedIntensity == .easy || workouts[i].plannedIntensity == .moderate {
                workouts[i].plannedDuration *= (1.0 + factor)
            }
        }
        return AdaptationEvent(
            date: Date(),
            reason: reason,
            description: "Great compliance! Easy session volume increased by \(Int(factor * 100))% to reflect your improving fitness.",
            weeksAffected: [1],
            changeType: .volumeIncreased
        )
    }

    private func insertRecoveryWeek(workouts: inout [Workout], reason: AdaptationEvent.AdaptationReason) -> AdaptationEvent {
        for i in 0..<workouts.count {
            workouts[i].plannedDuration *= 0.60
            if workouts[i].plannedIntensity == .threshold || workouts[i].plannedIntensity == .vo2max {
                workouts[i].plannedIntensity = .easy
                workouts[i].sessionTitle = "Recovery: " + workouts[i].sessionTitle
                workouts[i].sessionGoal = "Recovery week — keep effort very easy. Let your body absorb the recent training load."
            }
        }
        return AdaptationEvent(
            date: Date(),
            reason: reason,
            description: "Fatigue signals detected. Unplanned recovery week inserted — volume reduced 40%, intensity lowered. Your body needs this.",
            weeksAffected: [1],
            changeType: .recoveryWeekAdded
        )
    }

    private func softLoadNextWeek(workouts: inout [Workout]) {
        for i in 0..<workouts.count {
            workouts[i].plannedDuration *= 0.70
            if workouts[i].plannedIntensity != .recovery {
                workouts[i].plannedIntensity = .easy
            }
        }
    }

    // MARK: - Weather-Based Adaptation

    /// Adjusts a workout for bad weather conditions.
    func adaptForWeather(workout: inout Workout, assessment: WeatherAssessment) -> AdaptationEvent? {
        guard assessment.indoorRecommended else { return nil }

        let alternative = WeatherService.indoorAlternative(for: workout)
        workout.indoorAlternative = alternative
        workout.status = .indoorSubstituted

        if let adjustedIntensity = assessment.adjustedIntensity {
            workout.mainSetInstructions += "\n\n⚠️ WEATHER ADJUSTMENT: \(adjustedIntensity)"
        }

        return AdaptationEvent(
            date: Date(),
            reason: .weatherImpact,
            description: "Workout moved indoors due to: \(assessment.warnings.first?.message ?? "poor conditions"). Indoor alternative provided.",
            weeksAffected: [0],
            changeType: .workoutsRescheduled
        )
    }

    // MARK: - Calendar-Based Adaptation

    /// Reschedules workouts that conflict with calendar events.
    func adaptForCalendar(workouts: inout [Workout], calendarService: CalendarService) -> [AdaptationEvent] {
        var events: [AdaptationEvent] = []

        for i in 0..<workouts.count {
            let start = workouts[i].scheduledDate
            let end = start.addingTimeInterval(workouts[i].plannedDuration)

            if !calendarService.isTimeFree(start: start, end: end) {
                // Find next available slot
                let slots = calendarService.availableSlots(
                    on: start,
                    durationMinutes: Int(workouts[i].plannedDuration / 60)
                )

                if let bestSlot = slots.first {
                    workouts[i].scheduledDate = bestSlot.start
                    workouts[i].status = .rescheduled

                    events.append(AdaptationEvent(
                        date: Date(),
                        reason: .calendarConflict,
                        description: "'\(workouts[i].sessionTitle)' rescheduled to avoid calendar conflict. New time: \(bestSlot.start.formatted(date: .omitted, time: .shortened)).",
                        weeksAffected: [0],
                        changeType: .workoutsRescheduled
                    ))
                }
            }
        }

        return events
    }

    // MARK: - Fitness Metrics

    private func updateFitnessMetrics(from workouts: [Workout]) {
        let completedWorkouts = workouts.filter { $0.result != nil }

        // Calculate Chronic Training Load (CTL) approximation
        let recentTSS = completedWorkouts.compactMap { $0.result?.trainingStressScore }.reduce(0, +)
        fitnessMetrics.chronicTrainingLoad = (fitnessMetrics.chronicTrainingLoad * 41 + recentTSS) / 42

        // Acute Training Load (ATL)
        fitnessMetrics.acuteTrainingLoad = (fitnessMetrics.acuteTrainingLoad * 6 + recentTSS) / 7

        // Training Stress Balance (Form)
        fitnessMetrics.trainingStressBalance = fitnessMetrics.chronicTrainingLoad - fitnessMetrics.acuteTrainingLoad
    }

    func complianceScore(for workout: Workout) -> Double {
        guard let result = workout.result else { return 0 }

        let durationScore = min(result.actualDuration / workout.plannedDuration, 1.0)
        let rpeScore: Double
        let expectedRPE: Double

        switch workout.plannedIntensity {
        case .recovery: expectedRPE = 2
        case .easy: expectedRPE = 4
        case .moderate: expectedRPE = 6
        case .threshold: expectedRPE = 7.5
        case .vo2max: expectedRPE = 9
        case .sprint: expectedRPE = 10
        }

        let rpeDifference = abs(Double(result.perceivedEffort) - expectedRPE)
        rpeScore = max(0, 1.0 - rpeDifference / 5.0)

        return (durationScore * 0.7 + rpeScore * 0.3)
    }

    // MARK: - Helpers

    private func consecutiveSkippedWorkouts(in workouts: [Workout]) -> Int {
        var maxConsecutive = 0
        var current = 0
        for workout in workouts.sorted(by: { $0.scheduledDate < $1.scheduledDate }) {
            if workout.status == .skipped {
                current += 1
                maxConsecutive = max(maxConsecutive, current)
            } else {
                current = 0
            }
        }
        return maxConsecutive
    }

    private func buildRecommendations(complianceRate: Double, volumeCompliance: Double, averageRPE: Double) -> [String] {
        var recs: [String] = []

        if complianceRate < 0.7 {
            recs.append("Compliance is low (\(Int(complianceRate * 100))%). Consider shortening sessions to ones you can actually complete — consistency beats perfection.")
        }
        if averageRPE > 8 {
            recs.append("Average effort is very high. You may be training too hard on easy days. Slow down on Zone 1-2 sessions.")
        }
        if volumeCompliance > 1.2 {
            recs.append("You're doing more volume than planned. Great enthusiasm — but be careful of injury. Stick to the plan.")
        }
        if complianceRate >= 0.9 && averageRPE < 7 {
            recs.append("Excellent week! You're handling the load well. Next week's volume can increase slightly.")
        }

        return recs
    }
}

// MARK: - Supporting Types

struct WeeklyAnalysis {
    var complianceRate: Double
    var volumeCompliance: Double
    var workoutsCompleted: Int
    var workoutsSkipped: Int
    var plannedHours: Double
    var actualHours: Double
    var averageRPE: Double
    var averageComplianceScore: Double
    var trend: PerformanceTrend
    var recommendations: [String]

    var compliancePercent: Int { Int(complianceRate * 100) }
}

enum PerformanceTrend {
    case improving, stable, declining, poor

    var color: String {
        switch self {
        case .improving: return "green"
        case .stable: return "blue"
        case .declining: return "orange"
        case .poor: return "red"
        }
    }

    var icon: String {
        switch self {
        case .improving: return "arrow.up.circle.fill"
        case .stable: return "minus.circle.fill"
        case .declining: return "arrow.down.circle.fill"
        case .poor: return "exclamationmark.circle.fill"
        }
    }

    var label: String {
        switch self {
        case .improving: return "Improving"
        case .stable: return "Stable"
        case .declining: return "Declining"
        case .poor: return "Attention Needed"
        }
    }
}

struct FitnessMetrics {
    var chronicTrainingLoad: Double = 0  // CTL (fitness)
    var acuteTrainingLoad: Double = 0    // ATL (fatigue)
    var trainingStressBalance: Double = 0 // TSB (form)
    var vo2Max: Double?

    var fitnessLabel: String {
        switch chronicTrainingLoad {
        case 0..<30: return "Building Base"
        case 30..<50: return "Developing"
        case 50..<70: return "Fit"
        case 70..<90: return "Race Ready"
        default: return "Peak Fitness"
        }
    }

    var formLabel: String {
        switch trainingStressBalance {
        case ..<(-30): return "Very Fatigued"
        case -30 ..< -10: return "Fatigued"
        case -10..<5: return "Neutral"
        case 5..<25: return "Fresh"
        default: return "Very Fresh"
        }
    }
}

extension Array where Element == Double {
    func average() -> Double? {
        guard !isEmpty else { return nil }
        return reduce(0, +) / Double(count)
    }
}

extension Array where Element == Int {
    func average() -> Double? {
        guard !isEmpty else { return nil }
        return Double(reduce(0, +)) / Double(count)
    }
}
