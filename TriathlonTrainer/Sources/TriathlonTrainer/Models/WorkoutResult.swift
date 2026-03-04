import Foundation
import SwiftData

@Model
final class WorkoutResult {
    var id: UUID
    var workoutId: UUID
    var completedAt: Date
    var actualDuration: TimeInterval
    var actualDistance: Double?
    var averageHeartRate: Double?
    var maxHeartRate: Double?
    var averagePower: Double? // watts (bike)
    var averagePace: Double? // seconds per km (run/swim)
    var normalizedPower: Double? // watts
    var trainingStressScore: Double?
    var perceivedEffort: Int // 1-10
    var athleteNotes: String
    var complianceScore: Double // 0.0-1.0, how close to planned
    var stravaActivityId: Int?

    // Calculated fitness metrics
    var performanceIndex: Double? // actual vs expected given current fitness

    init(
        workoutId: UUID,
        actualDuration: TimeInterval,
        perceivedEffort: Int,
        athleteNotes: String = ""
    ) {
        self.id = UUID()
        self.workoutId = workoutId
        self.completedAt = Date()
        self.actualDuration = actualDuration
        self.perceivedEffort = perceivedEffort
        self.athleteNotes = athleteNotes
        self.complianceScore = 1.0
    }
}

@Model
final class TrainingPlan {
    var id: UUID
    var athleteProfileId: UUID
    var createdAt: Date
    var lastAdaptedAt: Date
    var raceDate: Date
    var raceDistance: RaceDistance
    var totalWeeks: Int
    var currentWeek: Int
    var adaptationHistory: [AdaptationEvent]

    // Weekly targets
    var weeklySwimKm: Double
    var weeklyBikeKm: Double
    var weeklyRunKm: Double
    var weeklyTSS: Double // Training Stress Score target

    init(
        athleteProfileId: UUID,
        raceDate: Date,
        raceDistance: RaceDistance,
        totalWeeks: Int
    ) {
        self.id = UUID()
        self.athleteProfileId = athleteProfileId
        self.createdAt = Date()
        self.lastAdaptedAt = Date()
        self.raceDate = raceDate
        self.raceDistance = raceDistance
        self.totalWeeks = totalWeeks
        self.currentWeek = 1
        self.adaptationHistory = []
        self.weeklySwimKm = 0
        self.weeklyBikeKm = 0
        self.weeklyRunKm = 0
        self.weeklyTSS = 0
    }
}

struct AdaptationEvent: Codable {
    var date: Date
    var reason: AdaptationReason
    var description: String
    var weeksAffected: [Int]
    var changeType: ChangeType

    enum AdaptationReason: String, Codable {
        case lowCompliance = "Low Compliance"
        case highCompliance = "High Compliance"
        case illness = "Illness / Injury"
        case weatherImpact = "Weather Impact"
        case calendarConflict = "Calendar Conflict"
        case performanceBreakthrough = "Performance Breakthrough"
        case fatigue = "Accumulated Fatigue"
        case userRequest = "Athlete Request"
    }

    enum ChangeType: String, Codable {
        case volumeReduced = "Volume Reduced"
        case volumeIncreased = "Volume Increased"
        case intensityReduced = "Intensity Reduced"
        case intensityIncreased = "Intensity Increased"
        case workoutsRescheduled = "Workouts Rescheduled"
        case recoveryWeekAdded = "Recovery Week Added"
    }
}
