import SwiftUI
import SwiftData

struct WorkoutDetailView: View {
    var workout: Workout

    @EnvironmentObject var weatherService: WeatherService
    @EnvironmentObject var adaptiveEngine: AdaptiveEngine
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var selectedSection: WorkoutSection = .overview
    @State private var showLogSheet = false
    @State private var showSkipConfirm = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Sport header
                workoutHeader

                // Section picker
                Picker("Section", selection: $selectedSection) {
                    ForEach(WorkoutSection.allCases, id: \.self) { section in
                        Text(section.rawValue).tag(section)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                // Content
                ScrollView {
                    VStack(spacing: 20) {
                        switch selectedSection {
                        case .overview:
                            overviewSection
                        case .session:
                            sessionSection
                        case .coaching:
                            coachingSection
                        case .technique:
                            techniqueSection
                        case .log:
                            if workout.result != nil {
                                completedResultSection
                            } else {
                                logPromptSection
                            }
                        }
                    }
                    .padding()
                }

                // Bottom action bar
                if workout.status == .scheduled || workout.status == .rescheduled {
                    actionBar
                }
            }
            .navigationTitle(workout.sport.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showLogSheet) {
                WorkoutLogView(workout: workout)
            }
            .confirmationDialog("Skip this workout?", isPresented: $showSkipConfirm) {
                Button("Skip — I'll miss this one", role: .destructive) {
                    workout.status = .skipped
                    try? context.save()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Skipped workouts are tracked and the plan adapts accordingly.")
            }
        }
    }

    // MARK: - Header

    private var workoutHeader: some View {
        ZStack {
            LinearGradient(
                colors: [sportColor.opacity(0.7), sportColor.opacity(0.4)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 8) {
                Image(systemName: workout.sport.systemImage)
                    .font(.system(size: 36))
                    .foregroundStyle(.white)

                Text(workout.sessionTitle)
                    .font(.title3).bold()
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                HStack(spacing: 16) {
                    Label(durationFormatted, systemImage: "clock")
                    if let dist = distanceFormatted {
                        Label(dist, systemImage: "arrow.left.and.right")
                    }
                    Label(workout.plannedIntensity.rpeRange, systemImage: "gauge.with.dots.needle.67percent")
                }
                .font(.caption)
                .foregroundStyle(.white.opacity(0.9))

                // Weather badge
                let assessment = weatherService.assess(sport: workout.sport, on: workout.scheduledDate)
                if !assessment.warnings.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: assessment.riskLevel == .extreme ? "exclamationmark.triangle.fill" : "exclamationmark.circle")
                        Text(assessment.summary)
                            .lineLimit(1)
                    }
                    .font(.caption)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.2))
                    .clipShape(Capsule())
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity)
        .frame(height: 180)
    }

    // MARK: - Overview Section

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Goal
            InfoCard(title: "Session Goal", icon: "target", iconColor: .blue) {
                Text(workout.sessionGoal)
                    .font(.body)
            }

            // Training zones
            if !workout.trainingZones.isEmpty {
                InfoCard(title: "Training Zones", icon: "waveform.path.ecg", iconColor: .purple) {
                    ForEach(workout.trainingZones, id: \.description) { block in
                        HStack {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(zoneColor(block.zone))
                                .frame(width: 12, height: 12)
                            Text("Zone \(block.zone)")
                                .font(.subheadline)
                            Spacer()
                            Text(block.description)
                                .font(.caption).foregroundStyle(.secondary)
                            Text(formatDuration(block.durationSeconds))
                                .font(.caption).bold().foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // Phase context
            InfoCard(title: "Training Phase: \(workout.trainingPhase.rawValue)", icon: "calendar.badge.exclamationmark", iconColor: .orange) {
                Text(workout.trainingPhase.description)
                    .font(.subheadline).foregroundStyle(.secondary)
            }

            // Weather
            let assessment = weatherService.assess(sport: workout.sport, on: workout.scheduledDate)
            if !assessment.warnings.isEmpty || assessment.indoorRecommended {
                weatherCard(assessment)
            }

            // Indoor alternative
            if let indoor = workout.indoorAlternative {
                InfoCard(title: "Indoor Alternative Available", icon: "house.fill", iconColor: .indigo) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(indoor.instructions)
                            .font(.subheadline)
                        if !indoor.equipmentNeeded.isEmpty {
                            Label("Equipment: " + indoor.equipmentNeeded.joined(separator: ", "), systemImage: "wrench")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Session Section

    private var sessionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            InfoCard(title: "Warm-Up", icon: "thermometer.medium", iconColor: .yellow) {
                Text(workout.warmupInstructions)
                    .font(.subheadline)
            }

            InfoCard(title: "Main Set", icon: "bolt.fill", iconColor: sportColor) {
                Text(workout.mainSetInstructions)
                    .font(.subheadline)
            }

            InfoCard(title: "Cool-Down", icon: "snowflake", iconColor: .teal) {
                Text(workout.cooldownInstructions)
                    .font(.subheadline)
            }

            InfoCard(title: "After This Session", icon: "checkmark.seal.fill", iconColor: .green) {
                Text(workout.postWorkoutGuidance)
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Coaching Section

    private var coachingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            let grouped = Dictionary(grouping: workout.coachingTips) { $0.timing }
            let order: [CoachingTip.TipTiming] = [.preWorkout, .nutrition, .duringWarmup, .duringMainSet, .duringCooldown, .postWorkout]

            ForEach(order, id: \.self) { timing in
                if let tips = grouped[timing], !tips.isEmpty {
                    InfoCard(
                        title: timingTitle(timing),
                        icon: timingIcon(timing),
                        iconColor: timingColor(timing)
                    ) {
                        VStack(spacing: 12) {
                            ForEach(tips) { tip in
                                CoachingTipCard(tip: tip)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Technique Section

    private var techniqueSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if workout.techniqueFocus.isEmpty {
                Text("No specific technique cues for this session.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(workout.techniqueFocus) { cue in
                    TechniqueCueCard(cue: cue)
                }
            }
        }
    }

    // MARK: - Log Section

    private var logPromptSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "pencil.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.blue)
            Text("Log this session after completing it")
                .font(.headline)
            Text("Record your actual duration, perceived effort, and notes. This data helps adapt your future training.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Log Workout") {
                showLogSheet = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity)
    }

    private var completedResultSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let result = workout.result {
                InfoCard(title: "Completed", icon: "checkmark.circle.fill", iconColor: .green) {
                    HStack(spacing: 20) {
                        VStack {
                            Text(formatDuration(result.actualDuration))
                                .font(.title3).bold()
                            Text("Duration").font(.caption).foregroundStyle(.secondary)
                        }
                        VStack {
                            Text("\(result.perceivedEffort)/10")
                                .font(.title3).bold()
                            Text("RPE").font(.caption).foregroundStyle(.secondary)
                        }
                        VStack {
                            Text("\(Int(result.complianceScore * 100))%")
                                .font(.title3).bold()
                            Text("Compliance").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    if !result.athleteNotes.isEmpty {
                        Text(result.athleteNotes)
                            .font(.subheadline).foregroundStyle(.secondary)
                            .padding(.top, 4)
                    }
                }
            }
        }
    }

    // MARK: - Weather Card

    private func weatherCard(_ assessment: WeatherAssessment) -> some View {
        InfoCard(
            title: "Weather Check",
            icon: "cloud.sun.fill",
            iconColor: assessment.riskLevel == .extreme ? .red : .orange
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Text(assessment.summary)
                    .font(.subheadline)
                ForEach(assessment.warnings, id: \.message) { warning in
                    HStack(spacing: 8) {
                        Image(systemName: warning.icon)
                            .foregroundStyle(.orange)
                        Text(warning.message)
                            .font(.caption)
                    }
                }
                if let adjusted = assessment.adjustedIntensity {
                    Text(adjusted)
                        .font(.caption).bold().foregroundStyle(.orange)
                }
                if assessment.indoorRecommended {
                    Label("Indoor training recommended", systemImage: "house.fill")
                        .font(.caption).foregroundStyle(.purple)
                }
            }
        }
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) {
                Button {
                    showSkipConfirm = true
                } label: {
                    Label("Skip", systemImage: "xmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)

                Button {
                    showLogSheet = true
                } label: {
                    Label("Log Workout", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(sportColor)
            }
            .padding()
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Helpers

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

    private var distanceFormatted: String? {
        guard let km = workout.plannedDistance else { return nil }
        return km < 1 ? "\(Int(km * 1000))m" : String(format: "%.1fkm", km)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let m = Int(seconds / 60)
        let h = m / 60
        let rem = m % 60
        return h > 0 ? "\(h)h\(rem)m" : "\(m)m"
    }

    private func zoneColor(_ zone: Int) -> Color {
        [.gray, .blue, .green, .yellow, .orange, .red][min(zone, 5)]
    }

    private func timingTitle(_ timing: CoachingTip.TipTiming) -> String {
        switch timing {
        case .preWorkout: return "Before You Start"
        case .nutrition: return "Nutrition"
        case .duringWarmup: return "During Warm-Up"
        case .duringMainSet: return "During Main Set"
        case .duringCooldown: return "Cool-Down Tips"
        case .postWorkout: return "After the Session"
        }
    }

    private func timingIcon(_ timing: CoachingTip.TipTiming) -> String {
        switch timing {
        case .preWorkout: return "checkmark.circle"
        case .nutrition: return "fork.knife"
        case .duringWarmup: return "thermometer.medium"
        case .duringMainSet: return "bolt"
        case .duringCooldown: return "snowflake"
        case .postWorkout: return "arrow.triangle.2.circlepath"
        }
    }

    private func timingColor(_ timing: CoachingTip.TipTiming) -> Color {
        switch timing {
        case .preWorkout: return .blue
        case .nutrition: return .green
        case .duringWarmup: return .yellow
        case .duringMainSet: return .orange
        case .duringCooldown: return .teal
        case .postWorkout: return .purple
        }
    }
}

// MARK: - Coaching Tip Card

struct CoachingTipCard: View {
    var tip: CoachingTip

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(Color.blue.opacity(0.15))
                .frame(width: 36, height: 36)
                .overlay {
                    Text("💡")
                }
            VStack(alignment: .leading, spacing: 4) {
                Text(tip.title)
                    .font(.subheadline).bold()
                Text(tip.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Technique Cue Card

struct TechniqueCueCard: View {
    var cue: TechniqueCue
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: cue.sport.systemImage)
                        .foregroundStyle(.blue)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(cue.cue)
                            .font(.subheadline).bold()
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                        if let mistake = cue.commonMistake {
                            Label("Common mistake: \(mistake)", systemImage: "exclamationmark.circle")
                                .font(.caption)
                                .foregroundStyle(.red.opacity(0.8))
                        }
                    }
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded, let drill = cue.drillName {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Drill: \(drill)", systemImage: "figure.run.circle")
                        .font(.subheadline).bold().foregroundStyle(.blue)
                    if let desc = cue.drillDescription {
                        Text(desc)
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(10)
                .background(Color.blue.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4)
    }
}

// MARK: - Info Card

struct InfoCard<Content: View>: View {
    var title: String
    var icon: String
    var iconColor: Color
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.subheadline).bold()
                .foregroundStyle(iconColor)

            content
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 6)
    }
}
