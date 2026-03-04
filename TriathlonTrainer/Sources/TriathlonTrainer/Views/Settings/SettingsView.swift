import SwiftUI
import SwiftData

struct SettingsView: View {
    var profile: AthleteProfile

    @EnvironmentObject var calendarService: CalendarService
    @EnvironmentObject var weatherService: WeatherService
    @EnvironmentObject var healthKitService: HealthKitService
    @EnvironmentObject var stravaService: StravaService
    @Environment(\.modelContext) private var context

    @State private var showStravaAuth = false
    @State private var showResetConfirm = false
    @State private var showRaceDatePicker = false
    @State private var newRaceDate: Date = Date()

    var body: some View {
        NavigationStack {
            Form {
                // Athlete
                Section("Athlete") {
                    LabeledContent("Name", value: profile.name)
                    LabeledContent("Race", value: profile.raceDistance.rawValue)
                    HStack {
                        Text("Race Date")
                        Spacer()
                        Text(profile.raceDate.formatted(date: .abbreviated, time: .omitted))
                            .foregroundStyle(.blue)
                            .onTapGesture { showRaceDatePicker = true }
                    }
                    LabeledContent("Level", value: profile.experienceLevel.rawValue)
                }

                // Calendar
                Section("Apple Calendar") {
                    HStack {
                        Label("Calendar Access", systemImage: "calendar")
                        Spacer()
                        if calendarService.isAuthorized {
                            Label("Connected", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                        } else {
                            Button("Connect") {
                                Task { await calendarService.requestAccess() }
                            }
                            .font(.caption)
                        }
                    }

                    if calendarService.isAuthorized {
                        Text("Workouts will be added to your 'Triathlon Training' calendar. Your busy times are used to avoid scheduling conflicts.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                // Health
                Section("Apple Health") {
                    HStack {
                        Label("HealthKit Access", systemImage: "heart.fill")
                        Spacer()
                        if healthKitService.isAuthorized {
                            Label("Connected", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green).font(.caption)
                        } else {
                            Button("Connect") {
                                Task { await healthKitService.requestAuthorization() }
                            }.font(.caption)
                        }
                    }
                    if healthKitService.isAuthorized {
                        Text("Garmin and Strava workouts are read via Apple Health to track completion automatically.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                // Strava
                Section("Strava") {
                    HStack {
                        Label("Strava", systemImage: "figure.run.circle.fill")
                        Spacer()
                        if stravaService.isAuthenticated {
                            HStack(spacing: 6) {
                                if let athlete = stravaService.athlete {
                                    Text(athlete.firstname + " " + athlete.lastname)
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Button("Disconnect") {
                                    stravaService.disconnect()
                                }
                                .font(.caption).foregroundStyle(.red)
                            }
                        } else {
                            Button("Connect Strava") {
                                showStravaAuth = true
                            }.font(.caption)
                        }
                    }
                    if stravaService.isAuthenticated {
                        Button("Sync Activities Now") {
                            Task { await stravaService.fetchRecentActivities() }
                        }
                        .font(.caption)
                    }
                }

                // Weather
                Section("Weather") {
                    Label("Apple WeatherKit", systemImage: "cloud.sun.fill")
                    Text("Weather forecasts are used to flag unsafe outdoor conditions and suggest indoor alternatives for your workouts.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                // Training preferences
                Section("Training Preferences") {
                    LabeledContent("Weekly Hours Target", value: String(format: "%.0f hours", profile.weeklyAvailableHours))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Training Days")
                            .font(.subheadline)
                        Text(trainingDaysText)
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                // About
                Section("About") {
                    LabeledContent("Plan Phase", value: currentPhase)
                    LabeledContent("Weeks to Race", value: "\(weeksToRace)")
                }

                // Danger zone
                Section {
                    Button("Reset All Training Data", role: .destructive) {
                        showResetConfirm = true
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showStravaAuth) {
                StravaAuthView()
            }
            .sheet(isPresented: $showRaceDatePicker) {
                NavigationStack {
                    Form {
                        DatePicker("New Race Date", selection: $newRaceDate, in: Date()..., displayedComponents: .date)
                            .datePickerStyle(.graphical)
                    }
                    .navigationTitle("Change Race Date")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Save") {
                                profile.raceDate = newRaceDate
                                try? context.save()
                                showRaceDatePicker = false
                            }
                        }
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Cancel") { showRaceDatePicker = false }
                        }
                    }
                }
                .presentationDetents([.medium])
            }
            .confirmationDialog("Reset all data?", isPresented: $showResetConfirm) {
                Button("Reset Everything", role: .destructive) {
                    resetAllData()
                }
            } message: {
                Text("This deletes your training plan, all workouts, and results. This cannot be undone.")
            }
            .onAppear { newRaceDate = profile.raceDate }
        }
    }

    private var trainingDaysText: String {
        let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return profile.preferredWorkoutDays
            .compactMap { $0 >= 1 && $0 <= 7 ? dayNames[$0 - 1] : nil }
            .joined(separator: ", ")
    }

    private var currentPhase: String {
        "Base" // TODO: derive from plan
    }

    private var weeksToRace: Int {
        max(0, Calendar.current.dateComponents([.weekOfYear], from: Date(), to: profile.raceDate).weekOfYear ?? 0)
    }

    private func resetAllData() {
        // Delete all workouts and profiles
        try? context.delete(model: Workout.self)
        try? context.delete(model: WorkoutResult.self)
        try? context.delete(model: TrainingPlan.self)
        try? context.delete(model: AthleteProfile.self)
        try? context.save()
    }
}

// MARK: - Strava Auth Sheet

struct StravaAuthView: View {
    @EnvironmentObject var stravaService: StravaService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "figure.run.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.orange)

                Text("Connect Strava")
                    .font(.title2).bold()

                Text("Connecting Strava lets the app automatically import your completed activities, track performance trends, and adapt your training plan based on actual effort data.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 8) {
                    Label("Reads completed runs, rides & swims", systemImage: "checkmark")
                    Label("No posting on your behalf", systemImage: "checkmark")
                    Label("You can disconnect anytime", systemImage: "checkmark")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 32)

                if let url = stravaService.authorizationURL {
                    Link(destination: url) {
                        Label("Connect with Strava", systemImage: "arrow.right.circle.fill")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .padding(.horizontal)
                    }
                }

                Spacer()
            }
            .padding(.top, 32)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
