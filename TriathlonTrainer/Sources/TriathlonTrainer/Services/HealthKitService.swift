import Foundation
import HealthKit

/// Reads actual workout data from Apple Health (covers both Garmin and Strava synced activities).
@MainActor
class HealthKitService: ObservableObject {

    private let healthStore = HKHealthStore()
    @Published var isAuthorized = false
    @Published var authorizationError: String?

    // Types we want to read
    private let readTypes: Set<HKObjectType> = {
        var types: Set<HKObjectType> = [
            HKObjectType.workoutType()
        ]
        let quantityTypes: [HKQuantityTypeIdentifier] = [
            .heartRate,
            .activeEnergyBurned,
            .distanceWalkingRunning,
            .distanceCycling,
            .distanceSwimming,
            .swimmingStrokeCount,
            .runningPower,
            .cyclingPower,
            .cyclingSpeed,
            .runningSpeed,
            .vo2Max
        ]
        quantityTypes.compactMap { HKObjectType.quantityType(forIdentifier: $0) }
            .forEach { types.insert($0) }
        return types
    }()

    // MARK: - Authorization

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            authorizationError = "HealthKit is not available on this device."
            return
        }

        do {
            try await healthStore.requestAuthorization(toShare: [], read: readTypes)
            isAuthorized = true
        } catch {
            authorizationError = "HealthKit access denied: \(error.localizedDescription)"
        }
    }

    // MARK: - Workout Fetching

    /// Fetches all workouts of the given activity type within the date range.
    func fetchWorkouts(type: HKWorkoutActivityType, from start: Date, to end: Date) async -> [HKWorkout] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let typePredicate = HKQuery.predicateForWorkouts(with: type)
        let compound = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, typePredicate])
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: .workoutType(),
                predicate: compound,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, _ in
                continuation.resume(returning: (samples as? [HKWorkout]) ?? [])
            }
            healthStore.execute(query)
        }
    }

    /// Fetches all triathlon-relevant workouts from the past N days.
    func fetchRecentTriathlonWorkouts(days: Int = 30) async -> [HealthKitWorkoutRecord] {
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: endDate)!

        let swimWorkouts = await fetchWorkouts(type: .swimming, from: startDate, to: endDate)
        let bikeWorkouts = await fetchWorkouts(type: .cycling, from: startDate, to: endDate)
        let runWorkouts = await fetchWorkouts(type: .running, from: startDate, to: endDate)

        let allWorkouts = (swimWorkouts + bikeWorkouts + runWorkouts)
            .sorted { $0.startDate > $1.startDate }

        return await withTaskGroup(of: HealthKitWorkoutRecord?.self) { group in
            for workout in allWorkouts {
                group.addTask {
                    await self.buildRecord(from: workout)
                }
            }

            var records: [HealthKitWorkoutRecord] = []
            for await record in group {
                if let r = record { records.append(r) }
            }
            return records.sorted { $0.startDate > $1.startDate }
        }
    }

    // MARK: - Detailed Workout Metrics

    private func buildRecord(from workout: HKWorkout) async -> HealthKitWorkoutRecord {
        let heartRates = await fetchHeartRateData(for: workout)
        let avgHR = heartRates.isEmpty ? nil : heartRates.reduce(0, +) / Double(heartRates.count)
        let maxHR = heartRates.max()

        let sport: Sport
        switch workout.workoutActivityType {
        case .swimming: sport = .swim
        case .cycling: sport = .bike
        case .running: sport = .run
        default: sport = .run
        }

        let distanceMeters: Double?
        if let total = workout.totalDistance {
            distanceMeters = total.doubleValue(for: .meter())
        } else {
            distanceMeters = nil
        }

        let calories = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie())

        return HealthKitWorkoutRecord(
            id: workout.uuid,
            sport: sport,
            startDate: workout.startDate,
            endDate: workout.endDate,
            duration: workout.duration,
            distanceMeters: distanceMeters,
            averageHeartRate: avgHR,
            maxHeartRate: maxHR,
            calories: calories,
            sourceName: workout.sourceRevision.source.name
        )
    }

    private func fetchHeartRateData(for workout: HKWorkout) async -> [Double] {
        guard let hrType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return [] }

        let predicate = HKQuery.predicateForSamples(
            withStart: workout.startDate,
            end: workout.endDate,
            options: .strictStartDate
        )

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: hrType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                let rates = (samples as? [HKQuantitySample])?.map {
                    $0.quantity.doubleValue(for: HKUnit(from: "count/min"))
                } ?? []
                continuation.resume(returning: rates)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - VO2 Max

    func fetchLatestVO2Max() async -> Double? {
        guard let vo2Type = HKObjectType.quantityType(forIdentifier: .vo2Max) else { return nil }

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: vo2Type,
                predicate: nil,
                limit: 1,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, samples, _ in
                let value = (samples?.first as? HKQuantitySample)?
                    .quantity
                    .doubleValue(for: HKUnit(from: "ml/kg*min"))
                continuation.resume(returning: value)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Match to Planned Workout

    /// Finds a HealthKit workout that likely corresponds to a planned workout.
    func matchRecord(_ records: [HealthKitWorkoutRecord], toPlanned workout: Workout) -> HealthKitWorkoutRecord? {
        let planDate = workout.scheduledDate
        let windowStart = Calendar.current.date(byAdding: .hour, value: -6, to: planDate)!
        let windowEnd = Calendar.current.date(byAdding: .day, value: 1, to: planDate)!

        let sameSport = records.filter { r in
            r.sport == workout.sport &&
            r.startDate >= windowStart &&
            r.startDate <= windowEnd
        }

        // Best match: closest duration to planned
        return sameSport.min(by: {
            abs($0.duration - workout.plannedDuration) < abs($1.duration - workout.plannedDuration)
        })
    }
}

// MARK: - Supporting Types

struct HealthKitWorkoutRecord: Identifiable {
    var id: UUID
    var sport: Sport
    var startDate: Date
    var endDate: Date
    var duration: TimeInterval
    var distanceMeters: Double?
    var averageHeartRate: Double?
    var maxHeartRate: Double?
    var calories: Double?
    var sourceName: String

    var distanceKm: Double? { distanceMeters.map { $0 / 1000 } }
    var durationFormatted: String {
        let h = Int(duration) / 3600
        let m = (Int(duration) % 3600) / 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }
}
