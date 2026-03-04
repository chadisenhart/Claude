import Foundation
import SwiftData

@MainActor
class OnboardingViewModel: ObservableObject {

    @Published var name: String = ""
    @Published var raceDate: Date = Calendar.current.date(byAdding: .month, value: 6, to: Date())!
    @Published var raceDistance: RaceDistance = .olympic
    @Published var experienceLevel: ExperienceLevel = .beginner
    @Published var weeklyAvailableHours: Double = 8
    @Published var preferredDays: Set<Int> = [2, 3, 4, 6, 7] // Mon, Tue, Wed, Fri, Sat
    @Published var isGeneratingPlan = false
    @Published var planGenerationError: String?
    @Published var step: OnboardingStep = .welcome

    var isFormValid: Bool {
        !name.isEmpty &&
        raceDate > Date() &&
        preferredDays.count >= 3 &&
        weeklyAvailableHours >= 3
    }

    var weeksToRace: Int {
        Calendar.current.dateComponents([.weekOfYear], from: Date(), to: raceDate).weekOfYear ?? 0
    }

    var minimumWeeksWarning: String? {
        let needed = raceDistance.totalWeeksNeeded
        if weeksToRace < needed {
            return "You have \(weeksToRace) weeks — ideally \(needed)+ for a \(raceDistance.rawValue). We'll create the best plan possible with the time available."
        }
        return nil
    }

    // MARK: - Generate Plan

    func generatePlan(in context: ModelContext) async -> AthleteProfile? {
        guard isFormValid else { return nil }
        isGeneratingPlan = true
        defer { isGeneratingPlan = false }

        let profile = AthleteProfile(
            name: name,
            raceDate: raceDate,
            raceDistance: raceDistance,
            experienceLevel: experienceLevel,
            weeklyAvailableHours: weeklyAvailableHours,
            preferredWorkoutDays: Array(preferredDays).sorted()
        )

        context.insert(profile)

        let plan = TrainingPlan(
            athleteProfileId: profile.id,
            raceDate: raceDate,
            raceDistance: raceDistance,
            totalWeeks: weeksToRace
        )
        context.insert(plan)

        // Generate workouts
        let plannedWeeks = TrainingPlanGenerator.generatePlan(for: profile)
        for week in plannedWeeks {
            for workout in week.workouts {
                context.insert(workout)
            }
        }

        do {
            try context.save()
            return profile
        } catch {
            planGenerationError = "Failed to save training plan: \(error.localizedDescription)"
            return nil
        }
    }
}

enum OnboardingStep: Int, CaseIterable {
    case welcome = 0
    case profile = 1
    case raceSetup = 2
    case schedule = 3
    case permissions = 4
    case generating = 5

    var title: String {
        switch self {
        case .welcome: return "Welcome"
        case .profile: return "About You"
        case .raceSetup: return "Your Race"
        case .schedule: return "Your Schedule"
        case .permissions: return "Connections"
        case .generating: return "Building Your Plan"
        }
    }
}
