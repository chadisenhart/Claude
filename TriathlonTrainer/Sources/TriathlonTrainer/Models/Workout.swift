import Foundation
import SwiftData

@Model
final class Workout {
    var id: UUID
    var scheduledDate: Date
    var sport: Sport
    var workoutType: WorkoutType
    var plannedDuration: TimeInterval // seconds
    var plannedDistance: Double? // km
    var plannedIntensity: Intensity
    var trainingZones: [TrainingZoneBlock]

    // Coaching content
    var sessionTitle: String
    var sessionGoal: String
    var warmupInstructions: String
    var mainSetInstructions: String
    var cooldownInstructions: String
    var coachingTips: [CoachingTip]
    var techniqueFocus: [TechniqueCue]
    var postWorkoutGuidance: String

    // Status & result
    var status: WorkoutStatus
    var calendarEventId: String?
    var stravaActivityId: Int?
    var result: WorkoutResult?
    var weatherSnapshot: WeatherSnapshot?
    var indoorAlternative: IndoorAlternative?

    // Plan context
    var trainingPhase: TrainingPhase
    var weekNumber: Int

    init(
        scheduledDate: Date,
        sport: Sport,
        workoutType: WorkoutType,
        plannedDuration: TimeInterval,
        plannedDistance: Double?,
        plannedIntensity: Intensity,
        trainingZones: [TrainingZoneBlock],
        sessionTitle: String,
        sessionGoal: String,
        warmupInstructions: String,
        mainSetInstructions: String,
        cooldownInstructions: String,
        coachingTips: [CoachingTip],
        techniqueFocus: [TechniqueCue],
        postWorkoutGuidance: String,
        trainingPhase: TrainingPhase,
        weekNumber: Int
    ) {
        self.id = UUID()
        self.scheduledDate = scheduledDate
        self.sport = sport
        self.workoutType = workoutType
        self.plannedDuration = plannedDuration
        self.plannedDistance = plannedDistance
        self.plannedIntensity = plannedIntensity
        self.trainingZones = trainingZones
        self.sessionTitle = sessionTitle
        self.sessionGoal = sessionGoal
        self.warmupInstructions = warmupInstructions
        self.mainSetInstructions = mainSetInstructions
        self.cooldownInstructions = cooldownInstructions
        self.coachingTips = coachingTips
        self.techniqueFocus = techniqueFocus
        self.postWorkoutGuidance = postWorkoutGuidance
        self.trainingPhase = trainingPhase
        self.weekNumber = weekNumber
        self.status = .scheduled
    }
}

enum Sport: String, Codable, CaseIterable {
    case swim = "Swim"
    case bike = "Bike"
    case run = "Run"
    case brick = "Brick"
    case strength = "Strength"
    case rest = "Rest"

    var systemImage: String {
        switch self {
        case .swim: return "figure.pool.swim"
        case .bike: return "bicycle"
        case .run: return "figure.run"
        case .brick: return "bicycle"
        case .strength: return "dumbbell"
        case .rest: return "bed.double"
        }
    }

    var color: String {
        switch self {
        case .swim: return "blue"
        case .bike: return "orange"
        case .run: return "green"
        case .brick: return "purple"
        case .strength: return "red"
        case .rest: return "gray"
        }
    }
}

enum WorkoutType: String, Codable {
    // Swim types
    case swimEasy = "Easy Swim"
    case swimEndurance = "Swim Endurance"
    case swimThreshold = "Swim Threshold"
    case swimIntervals = "Swim Intervals"
    case swimTechnique = "Swim Technique"
    case openWaterSwim = "Open Water Swim"

    // Bike types
    case bikeEasy = "Easy Ride"
    case bikeEndurance = "Endurance Ride"
    case bikeThreshold = "Threshold Ride"
    case bikeIntervals = "Bike Intervals"
    case bikeHill = "Hill Ride"
    case bikeIndoorTrainer = "Indoor Trainer"

    // Run types
    case runEasy = "Easy Run"
    case runLong = "Long Run"
    case runTempo = "Tempo Run"
    case runIntervals = "Run Intervals"
    case runHill = "Hill Run"
    case runBrick = "Brick Run"

    // Brick
    case bikeThenRun = "Bike + Run Brick"
    case swimThenBike = "Swim + Bike Brick"

    // Other
    case strengthCore = "Core & Strength"
    case rest = "Rest Day"
    case recovery = "Active Recovery"
}

enum Intensity: String, Codable, CaseIterable {
    case recovery = "Recovery"
    case easy = "Easy"
    case moderate = "Moderate"
    case threshold = "Threshold"
    case vo2max = "VO2 Max"
    case sprint = "Sprint"

    var zoneRange: ClosedRange<Int> {
        switch self {
        case .recovery: return 1...1
        case .easy: return 1...2
        case .moderate: return 2...3
        case .threshold: return 3...4
        case .vo2max: return 4...5
        case .sprint: return 5...5
        }
    }

    var rpeRange: String {
        switch self {
        case .recovery: return "RPE 1-2"
        case .easy: return "RPE 2-4"
        case .moderate: return "RPE 4-6"
        case .threshold: return "RPE 6-8"
        case .vo2max: return "RPE 8-9"
        case .sprint: return "RPE 9-10"
        }
    }
}

struct TrainingZoneBlock: Codable {
    var zone: Int // 1-5
    var durationSeconds: TimeInterval
    var description: String
}

enum WorkoutStatus: String, Codable {
    case scheduled = "Scheduled"
    case completed = "Completed"
    case skipped = "Skipped"
    case partiallyCompleted = "Partial"
    case rescheduled = "Rescheduled"
    case indoorSubstituted = "Indoor Substituted"
}

enum TrainingPhase: String, Codable, CaseIterable {
    case base = "Base"
    case build = "Build"
    case peak = "Peak"
    case taper = "Taper"
    case race = "Race Week"

    var description: String {
        switch self {
        case .base: return "Building aerobic foundation and technique"
        case .build: return "Increasing intensity and race-specific fitness"
        case .peak: return "Highest training load, race simulation"
        case .taper: return "Reducing volume, maintaining sharpness"
        case .race: return "Race preparation and execution"
        }
    }
}

struct CoachingTip: Codable, Identifiable {
    var id: UUID = UUID()
    var title: String
    var detail: String
    var timing: TipTiming

    enum TipTiming: String, Codable {
        case preWorkout = "Before"
        case duringWarmup = "Warm-up"
        case duringMainSet = "Main Set"
        case duringCooldown = "Cool-down"
        case postWorkout = "After"
        case nutrition = "Nutrition"
    }
}

struct TechniqueCue: Codable, Identifiable {
    var id: UUID = UUID()
    var sport: Sport
    var cue: String
    var drillName: String?
    var drillDescription: String?
    var commonMistake: String?
}

struct IndoorAlternative: Codable {
    var workoutType: WorkoutType
    var instructions: String
    var equipmentNeeded: [String]
}

struct WeatherSnapshot: Codable {
    var temperature: Double // Celsius
    var feelsLike: Double
    var condition: String
    var windSpeedKmh: Double
    var precipitationProbability: Double
    var isOutdoorSafe: Bool
    var warningMessage: String?
}
