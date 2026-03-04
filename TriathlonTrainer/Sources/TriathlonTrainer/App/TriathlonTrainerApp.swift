import SwiftUI
import SwiftData

@main
struct TriathlonTrainerApp: App {

    let container: ModelContainer
    let calendarService = CalendarService()
    let weatherService = WeatherService()
    let healthKitService = HealthKitService()
    let stravaService = StravaService()
    let adaptiveEngine = AdaptiveEngine()

    init() {
        do {
            container = try ModelContainer(for: AthleteProfile.self, Workout.self, WorkoutResult.self, TrainingPlan.self)
        } catch {
            fatalError("Failed to initialize SwiftData container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(container)
                .environmentObject(calendarService)
                .environmentObject(weatherService)
                .environmentObject(healthKitService)
                .environmentObject(stravaService)
                .environmentObject(adaptiveEngine)
                .onOpenURL { url in
                    // Handle Strava OAuth callback
                    if url.scheme == "triathlontrainer" && url.host == "strava" {
                        Task { await stravaService.handleCallback(url: url) }
                    }
                }
        }
    }
}

struct RootView: View {
    @Query private var profiles: [AthleteProfile]

    var body: some View {
        if profiles.isEmpty {
            OnboardingView()
        } else {
            MainTabView(profile: profiles[0])
        }
    }
}
