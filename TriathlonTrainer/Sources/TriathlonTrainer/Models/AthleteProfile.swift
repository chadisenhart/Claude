import Foundation
import SwiftData

@Model
final class AthleteProfile {
    var id: UUID
    var name: String
    var raceDate: Date
    var raceDistance: RaceDistance
    var experienceLevel: ExperienceLevel
    var weeklyAvailableHours: Double
    var preferredWorkoutDays: [Int] // 1=Sunday, 2=Monday, ...7=Saturday
    var swimFTP: Double? // CSS in seconds per 100m
    var bikeFTP: Double? // watts
    var runFTP: Double? // pace in seconds per km (threshold pace)
    var stravaAccessToken: String?
    var stravaRefreshToken: String?
    var stravaTokenExpiry: Date?
    var stravaAthleteId: Int?
    var createdAt: Date
    var homeLocation: LocationCoordinate?

    init(
        name: String,
        raceDate: Date,
        raceDistance: RaceDistance,
        experienceLevel: ExperienceLevel,
        weeklyAvailableHours: Double,
        preferredWorkoutDays: [Int]
    ) {
        self.id = UUID()
        self.name = name
        self.raceDate = raceDate
        self.raceDistance = raceDistance
        self.experienceLevel = experienceLevel
        self.weeklyAvailableHours = weeklyAvailableHours
        self.preferredWorkoutDays = preferredWorkoutDays
        self.createdAt = Date()
    }
}

enum RaceDistance: String, Codable, CaseIterable {
    case sprint = "Sprint"
    case olympic = "Olympic"
    case halfIronman = "70.3 Half Ironman"
    case fullIronman = "140.6 Full Ironman"

    var swimKm: Double {
        switch self {
        case .sprint: return 0.75
        case .olympic: return 1.5
        case .halfIronman: return 1.93
        case .fullIronman: return 3.86
        }
    }

    var bikeKm: Double {
        switch self {
        case .sprint: return 20
        case .olympic: return 40
        case .halfIronman: return 90
        case .fullIronman: return 180
        }
    }

    var runKm: Double {
        switch self {
        case .sprint: return 5
        case .olympic: return 10
        case .halfIronman: return 21.1
        case .fullIronman: return 42.2
        }
    }

    var totalWeeksNeeded: Int {
        switch self {
        case .sprint: return 8
        case .olympic: return 12
        case .halfIronman: return 20
        case .fullIronman: return 30
        }
    }
}

enum ExperienceLevel: String, Codable, CaseIterable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"

    var weeklyVolumeMultiplier: Double {
        switch self {
        case .beginner: return 0.7
        case .intermediate: return 1.0
        case .advanced: return 1.35
        }
    }
}

struct LocationCoordinate: Codable {
    var latitude: Double
    var longitude: Double
}
