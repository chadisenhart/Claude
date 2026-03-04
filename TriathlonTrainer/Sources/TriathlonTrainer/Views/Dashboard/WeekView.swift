import SwiftUI
import SwiftData

struct WeekView: View {
    var profile: AthleteProfile

    @Query(sort: \Workout.scheduledDate) private var allWorkouts: [Workout]
    @EnvironmentObject var weatherService: WeatherService
    @State private var selectedWorkout: Workout?
    @State private var selectedWeekOffset: Int = 0

    private let calendar = Calendar.current

    private var currentWeekStart: Date {
        let today = calendar.date(byAdding: .weekOfYear, value: selectedWeekOffset, to: Date())!
        return calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))!
    }

    private var weekWorkouts: [Workout] {
        let end = calendar.date(byAdding: .day, value: 7, to: currentWeekStart)!
        return allWorkouts.filter { $0.scheduledDate >= currentWeekStart && $0.scheduledDate < end }
    }

    private var weekStats: (planned: Int, completed: Int, hours: Double) {
        let planned = weekWorkouts.filter { $0.sport != .rest }.count
        let completed = weekWorkouts.filter { $0.status == .completed }.count
        let hours = weekWorkouts.compactMap { $0.result?.actualDuration }.reduce(0, +) / 3600
        return (planned, completed, hours)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Week navigator
                weekNavigator

                ScrollView {
                    VStack(spacing: 12) {
                        // Week summary
                        weekSummaryCard

                        // Day-by-day workouts
                        ForEach(0..<7, id: \.self) { dayOffset in
                            let date = calendar.date(byAdding: .day, value: dayOffset, to: currentWeekStart)!
                            let workout = weekWorkouts.first(where: { calendar.isDate($0.scheduledDate, inSameDayAs: date) })
                            DayWorkoutRow(date: date, workout: workout, weatherService: weatherService)
                                .onTapGesture {
                                    if let w = workout { selectedWorkout = w }
                                }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Week")
            .sheet(item: $selectedWorkout) { workout in
                WorkoutDetailView(workout: workout)
            }
        }
    }

    private var weekNavigator: some View {
        HStack {
            Button {
                withAnimation { selectedWeekOffset -= 1 }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
            }

            Spacer()

            VStack(spacing: 2) {
                Text(weekRangeText)
                    .font(.headline)
                if selectedWeekOffset == 0 {
                    Text("This Week")
                        .font(.caption).foregroundStyle(.blue)
                } else if selectedWeekOffset > 0 {
                    if let week = weekWorkouts.first {
                        Text("Week \(week.weekNumber) · \(week.trainingPhase.rawValue)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            Button {
                withAnimation { selectedWeekOffset += 1 }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        Divider()
    }

    private var weekRangeText: String {
        let end = calendar.date(byAdding: .day, value: 6, to: currentWeekStart)!
        let startStr = currentWeekStart.formatted(.dateTime.month(.abbreviated).day())
        let endStr = end.formatted(.dateTime.month(.abbreviated).day())
        return "\(startStr) – \(endStr)"
    }

    private var weekSummaryCard: some View {
        HStack(spacing: 0) {
            StatPill(label: "Planned", value: "\(weekStats.planned)", color: .blue)
            StatPill(label: "Done", value: "\(weekStats.completed)", color: .green)
            StatPill(
                label: "Hours",
                value: weekStats.hours > 0 ? String(format: "%.1f", weekStats.hours) : "-",
                color: .orange
            )
        }
        .padding(4)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 4)
    }
}

// MARK: - Day Row

struct DayWorkoutRow: View {
    var date: Date
    var workout: Workout?
    var weatherService: WeatherService

    private let calendar = Calendar.current

    var body: some View {
        HStack(spacing: 12) {
            // Date column
            VStack(spacing: 2) {
                Text(date.formatted(.dateTime.weekday(.abbreviated)))
                    .font(.caption2)
                    .foregroundStyle(isToday ? .blue : .secondary)
                Text(date.formatted(.dateTime.day()))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(isToday ? .blue : .primary)
            }
            .frame(width: 36)

            if let w = workout {
                workoutContent(w)
            } else {
                restDayContent
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 4)
        .overlay(
            isToday ? RoundedRectangle(cornerRadius: 14).stroke(Color.blue.opacity(0.4), lineWidth: 1.5) : nil
        )
    }

    private func workoutContent(_ w: Workout) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(sportColor(w.sport).opacity(0.15))
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: w.sport.systemImage)
                        .foregroundStyle(sportColor(w.sport))
                        .font(.system(size: 16))
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(w.sessionTitle)
                    .font(.subheadline).bold()
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text(durationFormatted(w.plannedDuration))
                        .font(.caption).foregroundStyle(.secondary)
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text(w.plannedIntensity.rawValue)
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                statusIcon(w.status)

                // Weather indicator
                let assessment = weatherService.assess(sport: w.sport, on: w.scheduledDate)
                if assessment.riskLevel >= .moderate {
                    Image(systemName: "cloud.rain")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private var restDayContent: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Rest Day")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Recovery")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "bed.double")
                .foregroundStyle(.gray.opacity(0.5))
        }
    }

    @ViewBuilder
    private func statusIcon(_ status: WorkoutStatus) -> some View {
        switch status {
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green).font(.subheadline)
        case .skipped:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red).font(.subheadline)
        case .partiallyCompleted:
            Image(systemName: "circle.lefthalf.filled")
                .foregroundStyle(.orange).font(.subheadline)
        case .indoorSubstituted:
            Image(systemName: "house.fill")
                .foregroundStyle(.purple).font(.subheadline)
        default:
            Image(systemName: "circle")
                .foregroundStyle(.gray).font(.subheadline)
        }
    }

    private var isToday: Bool { calendar.isDateInToday(date) }

    private func sportColor(_ sport: Sport) -> Color {
        switch sport {
        case .swim: return .blue
        case .bike: return .orange
        case .run: return .green
        case .brick: return .purple
        default: return .gray
        }
    }

    private func durationFormatted(_ seconds: TimeInterval) -> String {
        let m = Int(seconds / 60)
        let h = m / 60
        let rem = m % 60
        return h > 0 ? "\(h)h \(rem)m" : "\(m)m"
    }
}
