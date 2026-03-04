import SwiftUI
import SwiftData

struct DashboardView: View {
    var profile: AthleteProfile

    @EnvironmentObject var calendarService: CalendarService
    @EnvironmentObject var weatherService: WeatherService
    @EnvironmentObject var stravaService: StravaService
    @EnvironmentObject var adaptiveEngine: AdaptiveEngine
    @EnvironmentObject var healthKitService: HealthKitService

    @Query private var allWorkouts: [Workout]
    @State private var viewModel: DashboardViewModel?
    @State private var selectedWorkout: Workout?
    @State private var showAdaptationAlert = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    headerSection

                    // Adaptation alerts
                    if let vm = viewModel, !vm.adaptationAlerts.isEmpty {
                        adaptationAlertsSection(vm.adaptationAlerts)
                    }

                    // Today's workout
                    if let vm = viewModel {
                        todaysWorkoutSection(vm)
                    }

                    // Weekly snapshot
                    if let vm = viewModel {
                        weeklySnapshotSection(vm)
                    }

                    // Upcoming workouts
                    if let vm = viewModel {
                        upcomingSection(vm)
                    }

                    // Weekly analysis
                    if let analysis = viewModel?.weeklyAnalysis {
                        weeklyAnalysisSection(analysis)
                    }
                }
                .padding()
            }
            .navigationTitle("Training")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await loadDashboard()
            }
            .task {
                await setupAndLoad()
            }
            .sheet(item: $selectedWorkout) { workout in
                WorkoutDetailView(workout: workout)
            }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Hey, \(profile.name.components(separatedBy: " ").first ?? profile.name)!")
                    .font(.title2).bold()
                if let vm = viewModel {
                    Text("\(vm.weeksToRace) weeks to \(profile.raceDistance.rawValue)")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text("Phase: \(vm.currentPhase.rawValue) · Week \(vm.weekNumber)")
                        .font(.caption).foregroundStyle(.blue)
                }
            }
            Spacer()
            raceCountdownBadge
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8)
    }

    private var raceCountdownBadge: some View {
        VStack(spacing: 2) {
            Text("\(viewModel?.weeksToRace ?? 0)")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.blue)
            Text("weeks")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(width: 60, height: 60)
        .background(Color.blue.opacity(0.1))
        .clipShape(Circle())
    }

    private func adaptationAlertsSection(_ alerts: [AdaptationEvent]) -> some View {
        VStack(spacing: 8) {
            ForEach(alerts, id: \.date) { alert in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "brain.head.profile")
                        .foregroundStyle(.purple)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Plan Adapted: \(alert.reason.rawValue)")
                            .font(.subheadline).bold()
                        Text(alert.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(Color.purple.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func todaysWorkoutSection(_ vm: DashboardViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Today", systemImage: "sun.max.fill")
                .font(.headline)
                .foregroundStyle(.orange)

            if let workout = vm.todaysWorkout {
                TodayWorkoutCard(workout: workout, weatherService: weatherService)
                    .onTapGesture { selectedWorkout = workout }
            } else {
                Text("Rest day — recovery is training too.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func weeklySnapshotSection(_ vm: DashboardViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("This Week", systemImage: "calendar.badge.clock")
                    .font(.headline)
                Spacer()
                if let analysis = vm.weeklyAnalysis {
                    HStack(spacing: 4) {
                        Image(systemName: analysis.trend.icon)
                        Text(analysis.trend.label)
                            .font(.caption)
                    }
                    .foregroundStyle(Color(analysis.trend.color))
                }
            }

            WeekStripView(workouts: vm.weeklyWorkouts) { workout in
                selectedWorkout = workout
            }

            HStack(spacing: 20) {
                StatPill(
                    label: "Done",
                    value: "\(vm.weeklyWorkouts.filter { $0.status == .completed }.count)/\(vm.weeklyWorkouts.filter { $0.sport != .rest }.count)",
                    color: .green
                )
                StatPill(
                    label: "Hours",
                    value: String(format: "%.1fh", vm.weeklyWorkouts.compactMap { $0.result?.actualDuration }.reduce(0, +) / 3600),
                    color: .blue
                )
                StatPill(
                    label: "Phase",
                    value: vm.currentPhase.rawValue,
                    color: .purple
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8)
    }

    private func upcomingSection(_ vm: DashboardViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Upcoming", systemImage: "clock.arrow.circlepath")
                .font(.headline)

            ForEach(vm.upcomingWorkouts.prefix(5)) { workout in
                UpcomingWorkoutRow(workout: workout)
                    .onTapGesture { selectedWorkout = workout }
            }
        }
    }

    private func weeklyAnalysisSection(_ analysis: WeeklyAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Last Week's Analysis", systemImage: "brain.head.profile")
                .font(.headline)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Compliance")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("\(analysis.compliancePercent)%")
                        .font(.title2).bold()
                        .foregroundStyle(analysis.complianceRate >= 0.8 ? .green : .orange)
                }
                Spacer()
                VStack(alignment: .center, spacing: 4) {
                    Text("Hours")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(String(format: "%.1f / %.1f", analysis.actualHours, analysis.plannedHours))
                        .font(.title3).bold()
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Avg RPE")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(String(format: "%.1f", analysis.averageRPE))
                        .font(.title3).bold()
                }
            }

            if !analysis.recommendations.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(analysis.recommendations, id: \.self) { rec in
                        HStack(alignment: .top, spacing: 8) {
                            Text("→")
                                .foregroundStyle(.blue)
                            Text(rec)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8)
    }

    // MARK: - Load

    private func setupAndLoad() async {
        let vm = DashboardViewModel(
            calendarService: calendarService,
            weatherService: weatherService,
            healthKitService: healthKitService,
            stravaService: stravaService,
            adaptiveEngine: adaptiveEngine
        )
        viewModel = vm
        await loadDashboard()
    }

    private func loadDashboard() async {
        await viewModel?.loadDashboard(profile: profile, allWorkouts: allWorkouts)
    }
}

// MARK: - Week Strip

struct WeekStripView: View {
    var workouts: [Workout]
    var onTap: (Workout) -> Void

    private let dayNames = ["M", "T", "W", "T", "F", "S", "S"]
    private let calendar = Calendar.current

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<7, id: \.self) { offset in
                let date = calendar.date(byAdding: .day, value: offset - weekdayOffset, to: Date())!
                let workout = workouts.first(where: { calendar.isDate($0.scheduledDate, inSameDayAs: date) })
                let isToday = calendar.isDateInToday(date)

                VStack(spacing: 4) {
                    Text(dayNames[offset])
                        .font(.system(size: 10))
                        .foregroundStyle(isToday ? .blue : .secondary)
                    if let w = workout {
                        Circle()
                            .fill(sportColor(w.sport))
                            .frame(width: 28, height: 28)
                            .overlay {
                                Image(systemName: w.sport.systemImage)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.white)
                            }
                            .overlay {
                                if w.status == .completed {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundStyle(.white)
                                        .offset(x: 9, y: -9)
                                        .background(Circle().fill(.green).frame(width: 14, height: 14).offset(x: 9, y: -9))
                                }
                            }
                            .onTapGesture { onTap(w) }
                    } else {
                        Circle()
                            .stroke(Color(.systemGray4), lineWidth: 1)
                            .frame(width: 28, height: 28)
                    }
                    if isToday {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 4, height: 4)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var weekdayOffset: Int {
        let wd = calendar.component(.weekday, from: Date())
        return wd == 1 ? 6 : wd - 2 // Monday=0
    }

    private func sportColor(_ sport: Sport) -> Color {
        switch sport {
        case .swim: return .blue
        case .bike: return .orange
        case .run: return .green
        case .brick: return .purple
        default: return .gray
        }
    }
}

// MARK: - Today Workout Card

struct TodayWorkoutCard: View {
    var workout: Workout
    var weatherService: WeatherService

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: workout.sport.systemImage)
                        .font(.title3)
                        .foregroundStyle(sportColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(workout.sessionTitle)
                            .font(.headline)
                        Text(workout.sport.rawValue + " · " + durationFormatted)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                statusBadge
            }

            Text(workout.sessionGoal)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            // Weather warning if applicable
            let assessment = weatherService.assess(sport: workout.sport, on: workout.scheduledDate)
            if let warning = assessment.warnings.first {
                HStack(spacing: 8) {
                    Image(systemName: warning.icon)
                        .foregroundStyle(assessment.riskLevel == .extreme ? .red : .orange)
                    Text(warning.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .padding(8)
                .background((assessment.riskLevel == .extreme ? Color.red : Color.orange).opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            HStack {
                Label(workout.trainingPhase.rawValue, systemImage: "waveform")
                    .font(.caption).foregroundStyle(.blue)
                Spacer()
                Text("Tap for full session")
                    .font(.caption2).foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.08), radius: 8)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(sportColor.opacity(0.3), lineWidth: 1.5)
        )
    }

    private var sportColor: Color {
        switch workout.sport {
        case .swim: return .blue
        case .bike: return .orange
        case .run: return .green
        case .brick: return .purple
        default: return .gray
        }
    }

    private var durationFormatted: String {
        let m = Int(workout.plannedDuration / 60)
        let h = m / 60
        let rem = m % 60
        return h > 0 ? "\(h)h \(rem)m" : "\(m) min"
    }

    private var statusBadge: some View {
        Text(workout.status.rawValue)
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.15))
            .foregroundStyle(statusColor)
            .clipShape(Capsule())
    }

    private var statusColor: Color {
        switch workout.status {
        case .completed: return .green
        case .skipped: return .red
        case .indoorSubstituted: return .purple
        default: return .blue
        }
    }
}

// MARK: - Upcoming Row

struct UpcomingWorkoutRow: View {
    var workout: Workout

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(sportColor.opacity(0.15))
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: workout.sport.systemImage)
                        .foregroundStyle(sportColor)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(workout.sessionTitle)
                    .font(.subheadline).bold()
                Text(workout.scheduledDate.formatted(date: .abbreviated, time: .omitted) + " · " + durationFormatted)
                    .font(.caption).foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.04), radius: 4)
    }

    private var sportColor: Color {
        switch workout.sport {
        case .swim: return .blue
        case .bike: return .orange
        case .run: return .green
        case .brick: return .purple
        default: return .gray
        }
    }

    private var durationFormatted: String {
        let m = Int(workout.plannedDuration / 60)
        let h = m / 60
        let rem = m % 60
        return h > 0 ? "\(h)h \(rem)m" : "\(m) min"
    }
}

// MARK: - Stat Pill

struct StatPill: View {
    var label: String
    var value: String
    var color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
