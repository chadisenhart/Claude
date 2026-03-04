import Foundation
import WeatherKit
import CoreLocation

/// Fetches weather forecasts via Apple WeatherKit and evaluates outdoor training suitability.
@MainActor
class WeatherService: ObservableObject {

    private let weatherService = WeatherService.shared
    // Note: WeatherKit.WeatherService is used above — alias to avoid name conflict
    private let wkService = WeatherKit.WeatherService()

    @Published var currentConditions: CurrentConditions?
    @Published var hourlyForecast: [HourlyConditions] = []
    @Published var isLoading = false
    @Published var error: String?

    // MARK: - Fetch Forecast

    func fetchForecast(for location: CLLocation) async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let weather = try await wkService.weather(for: location)

            currentConditions = CurrentConditions(
                temperature: weather.currentWeather.temperature.converted(to: .celsius).value,
                feelsLike: weather.currentWeather.apparentTemperature.converted(to: .celsius).value,
                condition: weather.currentWeather.condition.description,
                windSpeedKmh: weather.currentWeather.wind.speed.converted(to: .kilometersPerHour).value,
                humidity: weather.currentWeather.humidity,
                uvIndex: Int(weather.currentWeather.uvIndex.value),
                isDaylight: weather.currentWeather.isDaylight
            )

            hourlyForecast = weather.hourlyForecast.forecast.prefix(48).map { hour in
                HourlyConditions(
                    date: hour.date,
                    temperature: hour.temperature.converted(to: .celsius).value,
                    feelsLike: hour.apparentTemperature.converted(to: .celsius).value,
                    condition: hour.condition.description,
                    windSpeedKmh: hour.wind.speed.converted(to: .kilometersPerHour).value,
                    precipitationChance: hour.precipitationChance,
                    precipitationAmount: hour.precipitationAmount.converted(to: .millimeters).value
                )
            }
        } catch {
            self.error = "Unable to fetch weather: \(error.localizedDescription)"
        }
    }

    // MARK: - Workout Weather Assessment

    /// Evaluates whether conditions are suitable for an outdoor workout of a given sport.
    func assess(sport: Sport, on date: Date) -> WeatherAssessment {
        guard let conditions = hourlyConditions(for: date) else {
            return WeatherAssessment(
                isSuitable: true,
                riskLevel: .unknown,
                warnings: [],
                indoorRecommended: false,
                adjustedIntensity: nil,
                summary: "Weather data unavailable — check before heading out."
            )
        }

        var warnings: [WeatherWarning] = []
        var riskLevel: RiskLevel = .low

        // --- Temperature checks ---
        switch conditions.feelsLike {
        case ..<(-10):
            warnings.append(WeatherWarning(icon: "thermometer.snowflake", message: "Extreme cold (\(Int(conditions.feelsLike))°C). High hypothermia risk outdoors."))
            riskLevel = .extreme
        case -10..<0:
            warnings.append(WeatherWarning(icon: "thermometer.snowflake", message: "Very cold (\(Int(conditions.feelsLike))°C). Dress in layers, protect extremities."))
            riskLevel = max(riskLevel, .high)
        case 35...:
            warnings.append(WeatherWarning(icon: "thermometer.sun", message: "Extreme heat (\(Int(conditions.feelsLike))°C). High heat stroke risk."))
            riskLevel = .extreme
        case 30..<35:
            warnings.append(WeatherWarning(icon: "thermometer.sun", message: "Very hot (\(Int(conditions.feelsLike))°C). Reduce intensity, carry extra fluids."))
            riskLevel = max(riskLevel, .high)
        case 27..<30:
            warnings.append(WeatherWarning(icon: "thermometer", message: "Hot conditions (\(Int(conditions.feelsLike))°C). Slow down 10-15%, double hydration."))
            riskLevel = max(riskLevel, .moderate)
        default:
            break
        }

        // --- Wind checks ---
        if conditions.windSpeedKmh > 60 {
            warnings.append(WeatherWarning(icon: "wind", message: "Dangerous wind (\(Int(conditions.windSpeedKmh)) km/h). Risk of being knocked over or debris."))
            riskLevel = max(riskLevel, .extreme)
        } else if conditions.windSpeedKmh > 40 {
            warnings.append(WeatherWarning(icon: "wind", message: "Strong wind (\(Int(conditions.windSpeedKmh)) km/h). Bike outdoors not recommended."))
            if sport == .bike { riskLevel = max(riskLevel, .high) }
            else { riskLevel = max(riskLevel, .moderate) }
        } else if conditions.windSpeedKmh > 25 && sport == .bike {
            warnings.append(WeatherWarning(icon: "wind", message: "Gusty (\(Int(conditions.windSpeedKmh)) km/h). Plan route to have wind at back on return leg."))
            riskLevel = max(riskLevel, .low)
        }

        // --- Precipitation checks ---
        if conditions.precipitationChance > 0.7 {
            let icon = sport == .bike ? "cloud.rain" : "cloud.drizzle"
            warnings.append(WeatherWarning(icon: icon, message: "High rain chance (\(Int(conditions.precipitationChance * 100))%). Wet roads — reduce bike speed, especially corners."))
            if sport == .bike { riskLevel = max(riskLevel, .moderate) }
        }

        if conditions.precipitationAmount > 10 {
            warnings.append(WeatherWarning(icon: "cloud.heavyrain", message: "Heavy rain forecast (\(Int(conditions.precipitationAmount))mm). Roads may flood, visibility poor."))
            riskLevel = max(riskLevel, .high)
        }

        // --- Lightning/Thunder ---
        if conditions.condition.lowercased().contains("thunder") || conditions.condition.lowercased().contains("storm") {
            warnings.append(WeatherWarning(icon: "bolt.fill", message: "Thunderstorm in forecast. Do not swim in open water, avoid high ground on bike."))
            riskLevel = .extreme
        }

        // --- UV checks ---
        if let current = currentConditions, current.uvIndex >= 8 {
            warnings.append(WeatherWarning(icon: "sun.max", message: "Very high UV (index \(current.uvIndex)). Apply SPF 50+, wear a cap, consider morning training instead."))
            riskLevel = max(riskLevel, .moderate)
        }

        // --- Build assessment ---
        let indoorRecommended = riskLevel == .extreme || riskLevel == .high
        let adjustedIntensity: String? = conditions.feelsLike > 27 ? "Reduce target pace/power by 10-15% for heat" : nil

        let summary: String
        switch riskLevel {
        case .low, .unknown:
            summary = "Conditions look good for your \(sport.rawValue.lowercased()) session."
        case .moderate:
            summary = "Manageable conditions — take precautions and adjust effort as needed."
        case .high:
            summary = "Challenging conditions. Consider the indoor alternative or reschedule."
        case .extreme:
            summary = "Dangerous conditions. Indoor training strongly recommended today."
        }

        return WeatherAssessment(
            isSuitable: riskLevel != .extreme,
            riskLevel: riskLevel,
            warnings: warnings,
            indoorRecommended: indoorRecommended,
            adjustedIntensity: adjustedIntensity,
            summary: summary
        )
    }

    // MARK: - Helpers

    func hourlyConditions(for date: Date) -> HourlyConditions? {
        hourlyForecast.min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) })
    }

    func snapshotForWorkout(sport: Sport, on date: Date) -> WeatherSnapshot {
        guard let conditions = hourlyConditions(for: date) else {
            return WeatherSnapshot(
                temperature: 20, feelsLike: 20, condition: "Unknown",
                windSpeedKmh: 0, precipitationProbability: 0, isOutdoorSafe: true
            )
        }

        let assessment = assess(sport: sport, on: date)

        return WeatherSnapshot(
            temperature: conditions.temperature,
            feelsLike: conditions.feelsLike,
            condition: conditions.condition,
            windSpeedKmh: conditions.windSpeedKmh,
            precipitationProbability: conditions.precipitationChance,
            isOutdoorSafe: assessment.isSuitable,
            warningMessage: assessment.warnings.first?.message
        )
    }
}

// MARK: - Supporting Types

struct CurrentConditions {
    var temperature: Double
    var feelsLike: Double
    var condition: String
    var windSpeedKmh: Double
    var humidity: Double
    var uvIndex: Int
    var isDaylight: Bool
}

struct HourlyConditions {
    var date: Date
    var temperature: Double
    var feelsLike: Double
    var condition: String
    var windSpeedKmh: Double
    var precipitationChance: Double
    var precipitationAmount: Double
}

struct WeatherAssessment {
    var isSuitable: Bool
    var riskLevel: RiskLevel
    var warnings: [WeatherWarning]
    var indoorRecommended: Bool
    var adjustedIntensity: String?
    var summary: String
}

struct WeatherWarning {
    var icon: String
    var message: String
}

enum RiskLevel: Int, Comparable {
    case unknown = 0, low = 1, moderate = 2, high = 3, extreme = 4

    static func < (lhs: RiskLevel, rhs: RiskLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    static func max(_ lhs: RiskLevel, _ rhs: RiskLevel) -> RiskLevel {
        lhs > rhs ? lhs : rhs
    }
}

// MARK: - Indoor Alternatives

extension WeatherService {
    /// Returns an indoor alternative workout for when conditions are poor.
    static func indoorAlternative(for workout: Workout) -> IndoorAlternative {
        switch workout.sport {
        case .bike, .brick:
            return IndoorAlternative(
                workoutType: .bikeIndoorTrainer,
                instructions: """
                    Complete this session on your indoor trainer (turbo trainer / smart trainer). \
                    Same duration and effort zones as planned. Use structured ERG mode if available. \
                    \n\nFor Zwift/TrainerRoad users: load a workout matching today's intensity zones. \
                    \nFor unstructured riding: use perceived effort and maintain cadence 85-95 rpm.
                    """,
                equipmentNeeded: ["Indoor trainer / turbo", "Fan (mandatory — no wind indoors)", "Towel", "Water bottles x2", "Chamois cream"]
            )
        case .run:
            return IndoorAlternative(
                workoutType: .runEasy,
                instructions: """
                    Treadmill alternative — same session indoors. \
                    Set treadmill incline to 0.5-1% to simulate outdoor air resistance. \
                    \n\nFor intervals: treadmill speed is slower to change than outdoor pace — \
                    pre-set your interval speed and jump on/off the belt for rest intervals.
                    """,
                equipmentNeeded: ["Treadmill"]
            )
        case .swim:
            return IndoorAlternative(
                workoutType: .swimTechnique,
                instructions: "Pool swimming is always indoor — proceed with the planned session.",
                equipmentNeeded: ["Pool access", "Goggles", "Swim cap"]
            )
        default:
            return IndoorAlternative(
                workoutType: .strengthCore,
                instructions: "Home bodyweight strength and core session instead. 3×15 of: plank, glute bridge, single-leg deadlift, press-up, mountain climber.",
                equipmentNeeded: ["Exercise mat"]
            )
        }
    }
}
