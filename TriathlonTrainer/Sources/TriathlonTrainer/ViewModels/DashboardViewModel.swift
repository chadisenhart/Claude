import Foundation
import SwiftData
import CoreLocation

@MainActor
class DashboardViewModel: ObservableObject {

    @Published var upcomingWorkouts: [Workout] = []
    @Published var todaysWorkout: Workout?
    @Published var weeklyWorkouts: [Workout] = []
    @Published var currentPhase: TrainingPhase = .base
    @Published var weekNumber: Int = 1
    @Published var weeksToRace: Int = 0
    @Published var fitnessMetrics: FitnessMetrics = FitnessMetrics()
    @Published var weeklyAnalysis: WeeklyAnalysis?
    @Published var adaptationAlerts: [AdaptationEvent] = []
    @Published var isLoading = false
    @Published var locationAuthorizationNeeded = false

    private let calendarService: CalendarService
    private let weatherService: WeatherService
    private let healthKitService: HealthKitService
    private let stravaService: StravaService
    private let adaptiveEngine: AdaptiveEngine
    private let locationManager = LocationManager()

    init(
        calendarService: CalendarService,
        weatherService: WeatherService,
        healthKitService: HealthKitService,
        stravaService: StravaService,
        adaptiveEngine: AdaptiveEngine
    ) {
        self.calendarService = calendarService
        self.weatherService = weatherService
        self.healthKitService = healthKitService
        self.stravaService = stravaService
        self.adaptiveEngine = adaptiveEngine
    }

    // MARK: - Load Dashboard

    func loadDashboard(profile: AthleteProfile, allWorkouts: [Workout]) async {
        isLoading = true
        defer { isLoading = false }

        let calendar = Calendar.current
        let today = Date()

        // Today's workout
        todaysWorkout = allWorkouts.first(where: {
            calendar.isDate($0.scheduledDate, inSameDayAs: today)
        })

        // Current week
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))!
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart)!
        weeklyWorkouts = allWorkouts.filter {
            $0.scheduledDate >= weekStart && $0.scheduledDate < weekEnd
        }.sorted { $0.scheduledDate < $1.scheduledDate }

        // Upcoming (next 7 days)
        let nextWeek = calendar.date(byAdding: .day, value: 7, to: today)!
        upcomingWorkouts = allWorkouts.filter {
            $0.scheduledDate > today && $0.scheduledDate <= nextWeek && $0.status == .scheduled
        }.sorted { $0.scheduledDate < $1.scheduledDate }

        // Race countdown
        weeksToRace = max(0, calendar.dateComponents([.weekOfYear], from: today, to: profile.raceDate).weekOfYear ?? 0)

        // Current phase (from first upcoming workout)
        currentPhase = upcomingWorkouts.first?.trainingPhase ?? weeklyWorkouts.first?.trainingPhase ?? .base
        weekNumber = upcomingWorkouts.first?.weekNumber ?? 1

        // Fetch weather for today's workout
        if let workout = todaysWorkout, let location = locationManager.currentLocation {
            await weatherService.fetchForecast(for: location)
            let assessment = weatherService.assess(sport: workout.sport, on: workout.scheduledDate)
            if assessment.indoorRecommended {
                var mutable = workout
                if let event = adaptiveEngine.adaptForWeather(workout: &mutable, assessment: assessment) {
                    adaptationAlerts.append(event)
                }
            }
        }

        // Sync Strava activities
        if stravaService.isAuthenticated {
            await stravaService.fetchRecentActivities()
        }

        // Analyze last week and apply adaptations
        let lastWeekStart = calendar.date(byAdding: .day, value: -7, to: weekStart)!
        let lastWeekWorkouts = allWorkouts.filter {
            $0.scheduledDate >= lastWeekStart && $0.scheduledDate < weekStart
        }

        if !lastWeekWorkouts.isEmpty {
            weeklyAnalysis = adaptiveEngine.analyzeWeek(workouts: lastWeekWorkouts)
        }

        fitnessMetrics = adaptiveEngine.fitnessMetrics
    }

    // MARK: - Mark Workout Complete

    func markWorkoutComplete(
        workout: Workout,
        duration: TimeInterval,
        rpe: Int,
        notes: String
    ) {
        let result = WorkoutResult(
            workoutId: workout.id,
            actualDuration: duration,
            perceivedEffort: rpe,
            athleteNotes: notes
        )
        result.complianceScore = adaptiveEngine.complianceScore(for: workout)
        workout.result = result
        workout.status = .completed
    }

    func markWorkoutSkipped(workout: Workout, reason: String) {
        workout.status = .skipped
        workout.result = nil
    }

    // MARK: - Calendar Sync

    func syncWorkoutsToCalendar(workouts: [Workout]) async {
        guard calendarService.isAuthorized else {
            await calendarService.requestAccess()
            return
        }

        for workout in workouts where workout.calendarEventId == nil {
            let eventId = calendarService.createWorkoutEvent(for: workout)
            workout.calendarEventId = eventId
        }
    }

    // MARK: - Weather Check for Tomorrow

    func weatherForWorkout(_ workout: Workout) -> WeatherAssessment? {
        guard let location = locationManager.currentLocation else { return nil }
        // Weather already fetched in loadDashboard; return assessment
        let _ = location // location used in initial fetch
        return weatherService.assess(sport: workout.sport, on: workout.scheduledDate)
    }
}

// MARK: - Location Manager

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var currentLocation: CLLocation?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        manager.requestWhenInUseAuthorization()
        manager.requestLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.first
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Fall back gracefully — weather just won't show
    }
}
