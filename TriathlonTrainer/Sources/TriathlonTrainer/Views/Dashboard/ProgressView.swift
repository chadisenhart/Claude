import SwiftUI
import SwiftData
import Charts

struct ProgressView: View {
    var profile: AthleteProfile

    @Query(sort: \Workout.scheduledDate) private var allWorkouts: [Workout]
    @EnvironmentObject var adaptiveEngine: AdaptiveEngine
    @State private var selectedTimeRange: TimeRange = .lastFourWeeks

    enum TimeRange: String, CaseIterable {
        case lastTwoWeeks = "2W"
        case lastFourWeeks = "4W"
        case allTime = "All"
    }

    private var filteredWorkouts: [Workout] {
        let cutoff: Date
        switch selectedTimeRange {
        case .lastTwoWeeks:
            cutoff = Calendar.current.date(byAdding: .weekOfYear, value: -2, to: Date())!
        case .lastFourWeeks:
            cutoff = Calendar.current.date(byAdding: .weekOfYear, value: -4, to: Date())!
        case .allTime:
            cutoff = .distantPast
        }
        return allWorkouts.filter { $0.scheduledDate >= cutoff && $0.result != nil }
    }

    private var completedWorkouts: [Workout] { filteredWorkouts.filter { $0.status == .completed } }
    private var totalHours: Double { completedWorkouts.compactMap { $0.result?.actualDuration }.reduce(0, +) / 3600 }

    private var sportBreakdown: [(sport: Sport, hours: Double)] {
        let sports: [Sport] = [.swim, .bike, .run]
        return sports.map { sport in
            let h = completedWorkouts.filter { $0.sport == sport }
                .compactMap { $0.result?.actualDuration }
                .reduce(0, +) / 3600
            return (sport: sport, hours: h)
        }.filter { $0.hours > 0 }
    }

    private var weeklyVolume: [(week: String, hours: Double)] {
        let grouped = Dictionary(grouping: completedWorkouts) { workout -> String in
            let weekStart = Calendar.current.date(from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: workout.scheduledDate))!
            return weekStart.formatted(.dateTime.month(.abbreviated).day())
        }
        return grouped.map { week, workouts in
            let hours = workouts.compactMap { $0.result?.actualDuration }.reduce(0, +) / 3600
            return (week: week, hours: hours)
        }.sorted { $0.week < $1.week }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Range selector
                    Picker("Range", selection: $selectedTimeRange) {
                        ForEach(TimeRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // Summary cards
                    summarySection

                    // Weekly volume chart
                    if !weeklyVolume.isEmpty {
                        weeklyVolumeChart
                    }

                    // Sport breakdown
                    if !sportBreakdown.isEmpty {
                        sportBreakdownSection
                    }

                    // Fitness metrics
                    fitnessMetricsSection

                    // Compliance history
                    complianceSection
                }
                .padding()
            }
            .navigationTitle("Progress")
        }
    }

    private var summarySection: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            MetricCard(
                title: "Total Hours",
                value: String(format: "%.1fh", totalHours),
                icon: "clock.fill",
                color: .blue
            )
            MetricCard(
                title: "Sessions Done",
                value: "\(completedWorkouts.count)",
                icon: "checkmark.circle.fill",
                color: .green
            )
            MetricCard(
                title: "Compliance",
                value: complianceText,
                icon: "chart.bar.fill",
                color: .orange
            )
            MetricCard(
                title: "Weeks to Race",
                value: "\(weeksToRace)",
                icon: "flag.checkered",
                color: .red
            )
        }
    }

    private var weeklyVolumeChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Weekly Volume", systemImage: "chart.bar.fill")
                .font(.headline)

            Chart {
                ForEach(weeklyVolume, id: \.week) { entry in
                    BarMark(
                        x: .value("Week", entry.week),
                        y: .value("Hours", entry.hours)
                    )
                    .foregroundStyle(Color.blue.gradient)
                }
            }
            .frame(height: 180)
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisValueLabel().font(.caption2)
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisValueLabel { Text("\(value.as(Double.self).map { Int($0) } ?? 0)h").font(.caption2) }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 6)
    }

    private var sportBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Sport Breakdown", systemImage: "person.3.fill")
                .font(.headline)

            ForEach(sportBreakdown, id: \.sport) { entry in
                HStack {
                    Image(systemName: entry.sport.systemImage)
                        .frame(width: 24)
                        .foregroundStyle(sportColor(entry.sport))
                    Text(entry.sport.rawValue)
                        .font(.subheadline)
                    Spacer()
                    Text(String(format: "%.1fh", entry.hours))
                        .font(.subheadline).bold()

                    // Bar
                    GeometryReader { geo in
                        let maxH = sportBreakdown.map(\.hours).max() ?? 1
                        RoundedRectangle(cornerRadius: 4)
                            .fill(sportColor(entry.sport).opacity(0.3))
                            .frame(width: geo.size.width * CGFloat(entry.hours / maxH))
                    }
                    .frame(width: 80, height: 8)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 6)
    }

    private var fitnessMetricsSection: some View {
        let metrics = adaptiveEngine.fitnessMetrics

        return VStack(alignment: .leading, spacing: 12) {
            Label("Fitness Status", systemImage: "heart.fill")
                .font(.headline)

            HStack(spacing: 16) {
                FitnessMetricBadge(
                    title: "Fitness",
                    value: String(format: "%.0f", metrics.chronicTrainingLoad),
                    subtitle: metrics.fitnessLabel,
                    color: .blue
                )
                FitnessMetricBadge(
                    title: "Fatigue",
                    value: String(format: "%.0f", metrics.acuteTrainingLoad),
                    subtitle: "Acute load",
                    color: .orange
                )
                FitnessMetricBadge(
                    title: "Form",
                    value: String(format: "%+.0f", metrics.trainingStressBalance),
                    subtitle: metrics.formLabel,
                    color: metrics.trainingStressBalance > 0 ? .green : .red
                )
            }

            Text("Fitness (CTL) takes weeks to build. Form spikes up after rest and drops during heavy training. Race day: aim for form +5 to +20.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 6)
    }

    private var complianceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Recent Sessions", systemImage: "list.bullet.clipboard")
                .font(.headline)

            ForEach(allWorkouts.filter({ $0.result != nil }).suffix(10).reversed()) { workout in
                HStack(spacing: 10) {
                    Image(systemName: workout.sport.systemImage)
                        .frame(width: 20)
                        .foregroundStyle(sportColor(workout.sport))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(workout.sessionTitle)
                            .font(.caption).bold()
                            .lineLimit(1)
                        Text(workout.scheduledDate.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let result = workout.result {
                        Text("RPE \(result.perceivedEffort)")
                            .font(.caption2).foregroundStyle(.secondary)
                        Text("\(Int(result.complianceScore * 100))%")
                            .font(.caption).bold()
                            .foregroundStyle(result.complianceScore >= 0.8 ? .green : .orange)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 6)
    }

    // MARK: - Helpers

    private var complianceText: String {
        let total = filteredWorkouts.count
        let done = completedWorkouts.count
        guard total > 0 else { return "N/A" }
        return "\(Int(Double(done) / Double(total) * 100))%"
    }

    private var weeksToRace: Int {
        max(0, Calendar.current.dateComponents([.weekOfYear], from: Date(), to: profile.raceDate).weekOfYear ?? 0)
    }

    private func sportColor(_ sport: Sport) -> Color {
        switch sport {
        case .swim: return .blue
        case .bike: return .orange
        case .run: return .green
        default: return .purple
        }
    }
}

// MARK: - Metric Card

struct MetricCard: View {
    var title: String
    var value: String
    var icon: String
    var color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Spacer()
            }
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
            Text(title)
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 4)
    }
}

// MARK: - Fitness Metric Badge

struct FitnessMetricBadge: View {
    var title: String
    var value: String
    var subtitle: String
    var color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2).foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(subtitle)
                .font(.caption2).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
