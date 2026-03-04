import Foundation

/// Generates a periodized triathlon training plan based on athlete profile.
/// Uses a classic Base → Build → Peak → Taper model with 3:1 loading weeks.
struct TrainingPlanGenerator {

    // MARK: - Phase Distribution

    static func phaseWeeks(totalWeeks: Int) -> [(phase: TrainingPhase, weeks: Int)] {
        switch totalWeeks {
        case ..<10:
            return [(.base, 4), (.taper, totalWeeks - 4)]
        case 10..<16:
            return [(.base, 5), (.build, totalWeeks - 7), (.peak, 2), (.taper, 2)]
        case 16..<24:
            return [(.base, 8), (.build, totalWeeks - 12), (.peak, 2), (.taper, 2)]
        default: // 24+ weeks
            return [(.base, 10), (.build, totalWeeks - 16), (.peak, 3), (.taper, 3)]
        }
    }

    // MARK: - Weekly Volume Targets (in hours)

    static func weeklyHours(
        phase: TrainingPhase,
        weekInPhase: Int,
        experience: ExperienceLevel,
        distance: RaceDistance
    ) -> Double {
        let base: Double
        switch distance {
        case .sprint:   base = 5
        case .olympic:  base = 8
        case .halfIronman: base = 11
        case .fullIronman: base = 16
        }

        let phaseMultiplier: Double
        switch phase {
        case .base:   phaseMultiplier = 0.7
        case .build:  phaseMultiplier = 1.0
        case .peak:   phaseMultiplier = 1.15
        case .taper:  phaseMultiplier = 0.55
        case .race:   phaseMultiplier = 0.3
        }

        // 3:1 loading: weeks 1-3 build, week 4 recover
        let loadingMultiplier: Double
        let cycleWeek = ((weekInPhase - 1) % 4) + 1
        switch cycleWeek {
        case 1: loadingMultiplier = 0.85
        case 2: loadingMultiplier = 1.0
        case 3: loadingMultiplier = 1.1
        case 4: loadingMultiplier = 0.65 // recovery week
        default: loadingMultiplier = 1.0
        }

        return base * phaseMultiplier * loadingMultiplier * experience.weeklyVolumeMultiplier
    }

    // MARK: - Volume Split by Sport

    static func volumeSplit(phase: TrainingPhase, distance: RaceDistance) -> (swim: Double, bike: Double, run: Double) {
        switch distance {
        case .sprint, .olympic:
            return (swim: 0.15, bike: 0.50, run: 0.35)
        case .halfIronman:
            return (swim: 0.12, bike: 0.55, run: 0.33)
        case .fullIronman:
            return (swim: 0.10, bike: 0.58, run: 0.32)
        }
    }

    // MARK: - Plan Generation

    static func generatePlan(for profile: AthleteProfile) -> [PlannedWeek] {
        let calendar = Calendar.current
        let today = Date()
        let weeksUntilRace = max(4, calendar.dateComponents([.weekOfYear], from: today, to: profile.raceDate).weekOfYear ?? profile.raceDistance.totalWeeksNeeded)
        let totalWeeks = min(weeksUntilRace, profile.raceDistance.totalWeeksNeeded)
        let phases = phaseWeeks(totalWeeks: totalWeeks)

        var plannedWeeks: [PlannedWeek] = []
        var globalWeekNumber = 1

        for (phase, weekCount) in phases {
            for weekInPhase in 1...weekCount {
                let weekStart = calendar.date(byAdding: .weekOfYear, value: globalWeekNumber - 1, to: today)!
                let hours = weeklyHours(
                    phase: phase,
                    weekInPhase: weekInPhase,
                    experience: profile.experienceLevel,
                    distance: profile.raceDistance
                )
                let split = volumeSplit(phase: phase, distance: profile.raceDistance)
                let isRecoveryWeek = ((weekInPhase - 1) % 4) == 3

                let workouts = generateWeekWorkouts(
                    weekStart: weekStart,
                    weekNumber: globalWeekNumber,
                    totalHours: min(hours, profile.weeklyAvailableHours),
                    split: split,
                    phase: phase,
                    distance: profile.raceDistance,
                    experience: profile.experienceLevel,
                    availableDays: profile.preferredWorkoutDays,
                    isRecoveryWeek: isRecoveryWeek
                )

                plannedWeeks.append(PlannedWeek(
                    weekNumber: globalWeekNumber,
                    weekStart: weekStart,
                    phase: phase,
                    isRecoveryWeek: isRecoveryWeek,
                    targetHours: hours,
                    workouts: workouts
                ))

                globalWeekNumber += 1
            }
        }

        return plannedWeeks
    }

    // MARK: - Weekly Workout Assignment

    static func generateWeekWorkouts(
        weekStart: Date,
        weekNumber: Int,
        totalHours: Double,
        split: (swim: Double, bike: Double, run: Double),
        phase: TrainingPhase,
        distance: RaceDistance,
        experience: ExperienceLevel,
        availableDays: [Int],
        isRecoveryWeek: Bool
    ) -> [Workout] {
        var workouts: [Workout] = []
        let calendar = Calendar.current
        let sortedDays = availableDays.sorted()
        let swimHours = totalHours * split.swim
        let bikeHours = totalHours * split.bike
        let runHours = totalHours * split.run

        guard sortedDays.count >= 3 else { return [] }

        // Assign workout slots based on available days
        // Typical pattern: Mon=Rest, Tue=Swim/Run, Wed=Bike, Thu=Swim/Run, Fri=Rest/Easy, Sat=Long Bike, Sun=Long Run
        let workoutAssignments = buildWorkoutSchedule(
            days: sortedDays,
            phase: phase,
            distance: distance,
            swimHours: swimHours,
            bikeHours: bikeHours,
            runHours: runHours,
            isRecoveryWeek: isRecoveryWeek
        )

        for assignment in workoutAssignments {
            guard let date = calendar.date(byAdding: .day, value: assignment.dayOffset, to: weekStart) else { continue }
            let workout = buildWorkout(
                date: date,
                assignment: assignment,
                phase: phase,
                weekNumber: weekNumber,
                experience: experience,
                distance: distance
            )
            workouts.append(workout)
        }

        return workouts
    }

    // MARK: - Workout Schedule Builder

    static func buildWorkoutSchedule(
        days: [Int],
        phase: TrainingPhase,
        distance: RaceDistance,
        swimHours: Double,
        bikeHours: Double,
        runHours: Double,
        isRecoveryWeek: Bool
    ) -> [WorkoutAssignment] {
        var assignments: [WorkoutAssignment] = []
        let dayCount = days.count

        // Map available days to workout types
        // We want: swim 2-3x, bike 2-3x, run 2-3x per week, possibly 1 brick
        var swimSessions = isRecoveryWeek ? 1 : (swimHours > 2 ? 2 : 1)
        var bikeSessions = isRecoveryWeek ? 1 : (bikeHours > 3 ? 2 : (bikeHours > 5 ? 3 : 2))
        var runSessions = isRecoveryWeek ? 1 : (runHours > 2 ? 2 : 1)
        var brickSession = !isRecoveryWeek && phase != .base && dayCount >= 5 ? 1 : 0

        // Ensure we don't exceed available days
        let totalSessions = swimSessions + bikeSessions + runSessions + brickSession
        if totalSessions > dayCount {
            if brickSession > 0 { brickSession = 0 }
            if swimSessions > 1 { swimSessions = 1 }
            if runSessions > 1 { runSessions = 1 }
        }

        // Assign sports to days (spread hard sessions, put long sessions on weekends)
        let weekendDays: Set<Int> = [1, 7] // Sunday, Saturday
        let availableWeekendDays = days.filter { weekendDays.contains($0) }
        let availableWeekDays = days.filter { !weekendDays.contains($0) }

        var sessionQueue: [(sport: Sport, type: WorkoutAssignmentType, durationHours: Double)] = []

        // Long sessions on weekends
        if !availableWeekendDays.isEmpty {
            sessionQueue.append((.bike, .longEndurance, bikeHours * 0.45))
            if availableWeekendDays.count >= 2 {
                sessionQueue.append((.run, .longEndurance, runHours * 0.4))
            }
        }

        // Quality sessions mid-week
        if phase != .base || !isRecoveryWeek {
            if swimSessions >= 1 { sessionQueue.append((.swim, .technique, swimHours * 0.5)) }
            if swimSessions >= 2 { sessionQueue.append((.swim, .intervals, swimHours * 0.5)) }
            if bikeSessions >= 2 { sessionQueue.append((.bike, .intervals, bikeHours * 0.25)) }
            if runSessions >= 1 { sessionQueue.append((.run, .tempo, runHours * 0.3)) }
        } else {
            if swimSessions >= 1 { sessionQueue.append((.swim, .easy, swimHours)) }
            if runSessions >= 1 { sessionQueue.append((.run, .easy, runHours)) }
        }

        if brickSession > 0 {
            sessionQueue.append((.brick, .brick, bikeHours * 0.2 + runHours * 0.15))
        }

        // Map to actual day offsets (0=Mon if week starts Monday)
        let allDays = (availableWeekendDays + availableWeekDays).sorted()
        for (index, session) in sessionQueue.prefix(allDays.count).enumerated() {
            let dayOfWeek = allDays[index]
            let dayOffset = dayOfWeek == 1 ? 6 : dayOfWeek - 2 // Convert to 0-6 offset from Monday
            assignments.append(WorkoutAssignment(
                dayOffset: dayOffset,
                sport: session.sport,
                type: session.type,
                targetDurationHours: session.durationHours
            ))
        }

        return assignments
    }

    // MARK: - Individual Workout Builder

    static func buildWorkout(
        date: Date,
        assignment: WorkoutAssignment,
        phase: TrainingPhase,
        weekNumber: Int,
        experience: ExperienceLevel,
        distance: RaceDistance
    ) -> Workout {
        let content = WorkoutContentLibrary.content(
            for: assignment.sport,
            type: assignment.type,
            phase: phase,
            experience: experience,
            durationHours: assignment.targetDurationHours
        )

        return Workout(
            scheduledDate: date,
            sport: assignment.sport,
            workoutType: content.workoutType,
            plannedDuration: assignment.targetDurationHours * 3600,
            plannedDistance: content.distanceKm,
            plannedIntensity: content.intensity,
            trainingZones: content.zones,
            sessionTitle: content.title,
            sessionGoal: content.goal,
            warmupInstructions: content.warmup,
            mainSetInstructions: content.mainSet,
            cooldownInstructions: content.cooldown,
            coachingTips: content.tips,
            techniqueFocus: content.techniqueCues,
            postWorkoutGuidance: content.postWorkoutGuidance,
            trainingPhase: phase,
            weekNumber: weekNumber
        )
    }
}

// MARK: - Supporting Types

struct PlannedWeek {
    var weekNumber: Int
    var weekStart: Date
    var phase: TrainingPhase
    var isRecoveryWeek: Bool
    var targetHours: Double
    var workouts: [Workout]
}

struct WorkoutAssignment {
    var dayOffset: Int
    var sport: Sport
    var type: WorkoutAssignmentType
    var targetDurationHours: Double
}

enum WorkoutAssignmentType {
    case easy
    case technique
    case tempo
    case intervals
    case longEndurance
    case brick
    case recovery
}
