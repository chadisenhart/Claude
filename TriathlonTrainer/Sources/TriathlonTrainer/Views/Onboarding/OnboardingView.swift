import SwiftUI
import SwiftData

struct OnboardingView: View {
    @StateObject private var viewModel = OnboardingViewModel()
    @EnvironmentObject var calendarService: CalendarService
    @EnvironmentObject var healthKitService: HealthKitService
    @Environment(\.modelContext) private var context

    @State private var generatedProfile: AthleteProfile?

    var body: some View {
        if let profile = generatedProfile {
            MainTabView(profile: profile)
        } else {
            NavigationStack {
                TabView(selection: $viewModel.step) {
                    welcomeStep.tag(OnboardingStep.welcome)
                    profileStep.tag(OnboardingStep.profile)
                    raceStep.tag(OnboardingStep.raceSetup)
                    scheduleStep.tag(OnboardingStep.schedule)
                    permissionsStep.tag(OnboardingStep.permissions)
                    generatingStep.tag(OnboardingStep.generating)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: viewModel.step)
            }
        }
    }

    // MARK: - Welcome

    private var welcomeStep: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "figure.pool.swim")
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(colors: [.blue, .cyan], startPoint: .top, endPoint: .bottom)
                    )
                Text("TriTrainer")
                    .font(.largeTitle).bold()
                Text("Your adaptive triathlon coach")
                    .font(.title3).foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(icon: "brain.head.profile", color: .purple, title: "Adapts to You", subtitle: "Plan updates based on what you actually do, not just what you plan")
                FeatureRow(icon: "calendar", color: .blue, title: "Calendar Smart", subtitle: "Works around your schedule automatically")
                FeatureRow(icon: "cloud.sun.fill", color: .orange, title: "Weather Aware", subtitle: "Indoor alternatives when conditions are unsafe")
                FeatureRow(icon: "book.closed.fill", color: .green, title: "Full Coaching", subtitle: "Every session includes technique tips and guidance")
            }
            .padding(.horizontal, 32)

            Spacer()

            Button {
                withAnimation { viewModel.step = .profile }
            } label: {
                Text("Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 24)
            }
            .padding(.bottom, 32)
        }
    }

    // MARK: - Profile

    private var profileStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                OnboardingHeader(step: 1, title: "About You", subtitle: "We'll personalise your training plan")

                VStack(alignment: .leading, spacing: 8) {
                    Text("Your Name")
                        .font(.subheadline).bold()
                    TextField("First name", text: $viewModel.name)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Experience Level")
                        .font(.subheadline).bold()
                    ForEach(ExperienceLevel.allCases, id: \.self) { level in
                        SelectionRow(
                            title: level.rawValue,
                            subtitle: levelDescription(level),
                            isSelected: viewModel.experienceLevel == level
                        ) {
                            viewModel.experienceLevel = level
                        }
                    }
                }

                nextButton { viewModel.step = .raceSetup }
            }
            .padding(24)
        }
    }

    // MARK: - Race Setup

    private var raceStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                OnboardingHeader(step: 2, title: "Your Race", subtitle: "Tell us what you're training for")

                VStack(alignment: .leading, spacing: 8) {
                    Text("Race Distance")
                        .font(.subheadline).bold()
                    ForEach(RaceDistance.allCases, id: \.self) { dist in
                        SelectionRow(
                            title: dist.rawValue,
                            subtitle: raceDistanceSubtitle(dist),
                            isSelected: viewModel.raceDistance == dist
                        ) {
                            viewModel.raceDistance = dist
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Race Date")
                        .font(.subheadline).bold()
                    DatePicker("", selection: $viewModel.raceDate, in: Date()..., displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()

                    if let warning = viewModel.minimumWeeksWarning {
                        Label(warning, systemImage: "exclamationmark.triangle")
                            .font(.caption).foregroundStyle(.orange)
                    }
                }

                nextButton { viewModel.step = .schedule }
            }
            .padding(24)
        }
    }

    // MARK: - Schedule

    private var scheduleStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                OnboardingHeader(step: 3, title: "Your Schedule", subtitle: "When can you train each week?")

                VStack(alignment: .leading, spacing: 8) {
                    Text("Available Training Days")
                        .font(.subheadline).bold()
                    Text("Select all days you can train (minimum 3)")
                        .font(.caption).foregroundStyle(.secondary)

                    let days: [(name: String, value: Int)] = [
                        ("Monday", 2), ("Tuesday", 3), ("Wednesday", 4),
                        ("Thursday", 5), ("Friday", 6), ("Saturday", 7), ("Sunday", 1)
                    ]

                    ForEach(days, id: \.value) { day in
                        Toggle(day.name, isOn: Binding(
                            get: { viewModel.preferredDays.contains(day.value) },
                            set: { isOn in
                                if isOn {
                                    viewModel.preferredDays.insert(day.value)
                                } else {
                                    viewModel.preferredDays.remove(day.value)
                                }
                            }
                        ))
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Weekly Hours Available")
                            .font(.subheadline).bold()
                        Spacer()
                        Text(String(format: "%.0f hours", viewModel.weeklyAvailableHours))
                            .font(.subheadline).foregroundStyle(.blue)
                    }
                    Slider(value: $viewModel.weeklyAvailableHours, in: 3...20, step: 0.5)
                    HStack {
                        Text("3h (minimum)").font(.caption2).foregroundStyle(.secondary)
                        Spacer()
                        Text("20h").font(.caption2).foregroundStyle(.secondary)
                    }
                }

                nextButton { viewModel.step = .permissions }
            }
            .padding(24)
        }
    }

    // MARK: - Permissions

    private var permissionsStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                OnboardingHeader(step: 4, title: "Connections", subtitle: "Connect your devices and apps")

                PermissionRow(
                    icon: "calendar",
                    title: "Apple Calendar",
                    subtitle: "Schedule workouts and read your availability",
                    isConnected: calendarService.isAuthorized,
                    action: { Task { await calendarService.requestAccess() } }
                )

                PermissionRow(
                    icon: "heart.fill",
                    title: "Apple Health",
                    subtitle: "Import workouts from Garmin & Apple Watch",
                    isConnected: healthKitService.isAuthorized,
                    action: { Task { await healthKitService.requestAuthorization() } }
                )

                Text("Strava can be connected in Settings after setup.")
                    .font(.caption).foregroundStyle(.secondary)

                nextButton(label: "Build My Plan") {
                    viewModel.step = .generating
                    Task {
                        generatedProfile = await viewModel.generatePlan(in: context)
                    }
                }
            }
            .padding(24)
        }
    }

    // MARK: - Generating

    private var generatingStep: some View {
        VStack(spacing: 32) {
            Spacer()

            if viewModel.isGeneratingPlan {
                ProgressView()
                    .scaleEffect(1.5)
                VStack(spacing: 8) {
                    Text("Building Your Training Plan")
                        .font(.title3).bold()
                    Text("Calculating your periodized plan across all phases...")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            } else if let error = viewModel.planGenerationError {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 48)).foregroundStyle(.orange)
                Text(error)
                    .font(.subheadline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding(32)
    }

    // MARK: - Helpers

    private func nextButton(label: String = "Continue", action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(viewModel.isFormValid ? Color.blue : Color.gray)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .disabled(!viewModel.isFormValid)
        .padding(.top, 8)
    }

    private func levelDescription(_ level: ExperienceLevel) -> String {
        switch level {
        case .beginner: return "New to triathlon or structured training"
        case .intermediate: return "1-2 years training, completed a sprint/olympic"
        case .advanced: return "3+ years, consistent high training volume"
        }
    }

    private func raceDistanceSubtitle(_ dist: RaceDistance) -> String {
        "\(String(format: "%.0f", dist.swimKm * 1000))m swim · \(Int(dist.bikeKm))km bike · \(dist.runKm < 10 ? String(format: "%.0f", dist.runKm) : String(format: "%.1f", dist.runKm))km run"
    }
}

// MARK: - Onboarding Components

struct OnboardingHeader: View {
    var step: Int
    var title: String
    var subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Step \(step) of 4")
                .font(.caption).foregroundStyle(.blue)
            Text(title)
                .font(.largeTitle).bold()
            Text(subtitle)
                .font(.subheadline).foregroundStyle(.secondary)
        }
    }
}

struct SelectionRow: View {
    var title: String
    var subtitle: String
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.subheadline).bold().foregroundStyle(.primary)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .blue : .secondary)
            }
            .padding(12)
            .background(isSelected ? Color.blue.opacity(0.08) : Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                isSelected ? RoundedRectangle(cornerRadius: 12).stroke(Color.blue.opacity(0.4), lineWidth: 1) : nil
            )
        }
        .buttonStyle(.plain)
    }
}

struct FeatureRow: View {
    var icon: String
    var color: Color
    var title: String
    var subtitle: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline).bold()
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

struct PermissionRow: View {
    var icon: String
    var title: String
    var subtitle: String
    var isConnected: Bool
    var action: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3).foregroundStyle(.blue)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline).bold()
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if isConnected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Button("Allow") { action() }
                    .font(.caption).bold()
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Color.blue).foregroundStyle(.white)
                    .clipShape(Capsule())
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
