import Foundation
import SwiftData

@MainActor
class WorkoutViewModel: ObservableObject {

    @Published var workout: Workout
    @Published var weatherAssessment: WeatherAssessment?
    @Published var isShowingIndoorAlternative = false
    @Published var isLoggingResult = false
    @Published var logDuration: TimeInterval
    @Published var logRPE: Int = 6
    @Published var logNotes: String = ""
    @Published var activeSection: WorkoutSection = .overview

    private let weatherService: WeatherService
    private let adaptiveEngine: AdaptiveEngine

    init(workout: Workout, weatherService: WeatherService, adaptiveEngine: AdaptiveEngine) {
        self.workout = workout
        self.weatherService = weatherService
        self.adaptiveEngine = adaptiveEngine
        self.logDuration = workout.plannedDuration
    }

    // MARK: - Weather

    func loadWeatherAssessment() {
        weatherAssessment = weatherService.assess(sport: workout.sport, on: workout.scheduledDate)
        if weatherAssessment?.indoorRecommended == true && workout.indoorAlternative == nil {
            workout.indoorAlternative = WeatherService.indoorAlternative(for: workout)
        }
        isShowingIndoorAlternative = weatherAssessment?.indoorRecommended == true
    }

    // MARK: - Tips & Coaching

    var tipsByTiming: [(timing: CoachingTip.TipTiming, tips: [CoachingTip])] {
        let grouped = Dictionary(grouping: workout.coachingTips) { $0.timing }
        let order: [CoachingTip.TipTiming] = [.preWorkout, .nutrition, .duringWarmup, .duringMainSet, .duringCooldown, .postWorkout]
        return order.compactMap { timing in
            guard let tips = grouped[timing], !tips.isEmpty else { return nil }
            return (timing: timing, tips: tips)
        }
    }

    // MARK: - Log Result

    func logCompletion(in context: ModelContext) {
        let result = WorkoutResult(
            workoutId: workout.id,
            actualDuration: logDuration,
            perceivedEffort: logRPE,
            athleteNotes: logNotes
        )
        result.complianceScore = adaptiveEngine.complianceScore(for: workout)

        workout.result = result
        workout.status = logDuration < workout.plannedDuration * 0.5 ? .partiallyCompleted : .completed

        try? context.save()
        isLoggingResult = false
    }

    func logSkip(reason: String, in context: ModelContext) {
        workout.status = .skipped
        workout.result = nil
        try? context.save()
    }

    // MARK: - Formatted Properties

    var durationFormatted: String {
        let minutes = Int(workout.plannedDuration / 60)
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 { return "\(hours)h \(mins)m" }
        return "\(mins) min"
    }

    var distanceFormatted: String? {
        guard let km = workout.plannedDistance else { return nil }
        if km < 1 { return "\(Int(km * 1000))m" }
        return String(format: "%.1f km", km)
    }

    var zoneDistribution: [(zone: Int, percent: Double)] {
        let totalDuration = workout.trainingZones.reduce(0.0) { $0 + $1.durationSeconds }
        guard totalDuration > 0 else { return [] }
        return workout.trainingZones.map { block in
            (zone: block.zone, percent: block.durationSeconds / totalDuration * 100)
        }
    }
}

enum WorkoutSection: String, CaseIterable {
    case overview = "Overview"
    case session = "Session"
    case coaching = "Coaching"
    case technique = "Technique"
    case log = "Log"
}
