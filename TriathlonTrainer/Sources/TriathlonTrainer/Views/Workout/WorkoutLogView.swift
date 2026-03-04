import SwiftUI
import SwiftData

struct WorkoutLogView: View {
    var workout: Workout

    @EnvironmentObject var adaptiveEngine: AdaptiveEngine
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var actualHours: Int = 0
    @State private var actualMinutes: Int = 30
    @State private var rpe: Int = 6
    @State private var notes: String = ""
    @State private var didComplete: Bool = true

    private var plannedMinutes: Int { Int(workout.plannedDuration / 60) }

    var body: some View {
        NavigationStack {
            Form {
                Section("How did it go?") {
                    Picker("Result", selection: $didComplete) {
                        Text("Completed ✓").tag(true)
                        Text("Partially completed").tag(false)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Actual Duration") {
                    HStack {
                        Picker("Hours", selection: $actualHours) {
                            ForEach(0..<6) { Text("\($0)h").tag($0) }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)

                        Picker("Minutes", selection: $actualMinutes) {
                            ForEach([0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55], id: \.self) {
                                Text("\($0)m").tag($0)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                    }
                    .frame(height: 120)

                    let plannedH = plannedMinutes / 60
                    let plannedM = plannedMinutes % 60
                    Text("Planned: \(plannedH > 0 ? "\(plannedH)h " : "")\(plannedM)m")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Perceived Effort")
                                .font(.subheadline)
                            Spacer()
                            Text("\(rpe)/10 — \(rpeLabel)")
                                .font(.subheadline).bold()
                                .foregroundStyle(rpeColor)
                        }

                        Slider(value: Binding(
                            get: { Double(rpe) },
                            set: { rpe = Int($0) }
                        ), in: 1...10, step: 1)
                        .tint(rpeColor)

                        HStack {
                            Text("Very Easy").font(.caption2).foregroundStyle(.secondary)
                            Spacer()
                            Text("Max Effort").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Effort (RPE)")
                } footer: {
                    Text(rpeGuidance)
                        .font(.caption)
                }

                Section("Notes (Optional)") {
                    TextEditor(text: $notes)
                        .frame(height: 80)
                        .placeholder(when: notes.isEmpty) {
                            Text("How did you feel? Any issues? Things that went well?")
                                .foregroundStyle(.secondary)
                                .padding(.top, 8)
                        }
                }

                Section("Post-Workout Guidance") {
                    Text(workout.postWorkoutGuidance)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Log Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { saveLog() }
                        .bold()
                }
            }
            .onAppear {
                actualHours = plannedMinutes / 60
                actualMinutes = plannedMinutes % 60
            }
        }
    }

    private var actualDuration: TimeInterval {
        TimeInterval((actualHours * 60 + actualMinutes) * 60)
    }

    private var rpeLabel: String {
        switch rpe {
        case 1...2: return "Very Easy"
        case 3...4: return "Easy"
        case 5...6: return "Moderate"
        case 7...8: return "Hard"
        case 9: return "Very Hard"
        default: return "Max"
        }
    }

    private var rpeColor: Color {
        switch rpe {
        case 1...3: return .green
        case 4...6: return .yellow
        case 7...8: return .orange
        default: return .red
        }
    }

    private var rpeGuidance: String {
        let plannedRPE: String
        switch workout.plannedIntensity {
        case .recovery: plannedRPE = "2-3"
        case .easy: plannedRPE = "3-5"
        case .moderate: plannedRPE = "5-6"
        case .threshold: plannedRPE = "7-8"
        case .vo2max: plannedRPE = "8-9"
        case .sprint: plannedRPE = "9-10"
        }
        return "Today's target effort: RPE \(plannedRPE). Your logged RPE affects how your plan adapts."
    }

    private func saveLog() {
        let result = WorkoutResult(
            workoutId: workout.id,
            actualDuration: actualDuration,
            perceivedEffort: rpe,
            athleteNotes: notes
        )
        result.complianceScore = adaptiveEngine.complianceScore(for: workout)

        workout.result = result
        workout.status = didComplete ? .completed : .partiallyCompleted

        try? context.save()
        dismiss()
    }
}

// MARK: - Placeholder Modifier

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {
        ZStack(alignment: .topLeading) {
            if shouldShow { placeholder() }
            self
        }
    }
}
