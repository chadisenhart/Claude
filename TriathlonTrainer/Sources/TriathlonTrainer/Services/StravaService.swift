import Foundation

/// Manages Strava OAuth2 authentication and activity syncing.
/// Provides richer activity data than HealthKit (segments, heart rate zones, power curves).
@MainActor
class StravaService: ObservableObject {

    @Published var isAuthenticated = false
    @Published var athlete: StravaAthlete?
    @Published var recentActivities: [StravaActivity] = []
    @Published var isSyncing = false
    @Published var error: String?

    private let clientId = "YOUR_STRAVA_CLIENT_ID"        // Replace with actual client ID
    private let clientSecret = "YOUR_STRAVA_CLIENT_SECRET" // Replace with actual secret
    private let redirectUri = "triathlontrainer://strava/callback"

    private var accessToken: String?
    private var refreshToken: String?
    private var tokenExpiry: Date?

    private let baseURL = "https://www.strava.com/api/v3"

    // MARK: - OAuth2 Authorization

    var authorizationURL: URL? {
        var components = URLComponents(string: "https://www.strava.com/oauth/authorize")
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectUri),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "approval_prompt", value: "auto"),
            URLQueryItem(name: "scope", value: "read,activity:read_all")
        ]
        return components?.url
    }

    func handleCallback(url: URL) async {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            error = "Invalid callback URL"
            return
        }

        await exchangeCodeForToken(code: code)
    }

    private func exchangeCodeForToken(code: String) async {
        let body: [String: String] = [
            "client_id": clientId,
            "client_secret": clientSecret,
            "code": code,
            "grant_type": "authorization_code"
        ]

        do {
            let response: TokenResponse = try await post(path: "/oauth/token", body: body, useBaseURL: "https://www.strava.com")
            saveTokens(response)
            await fetchAthlete()
        } catch {
            self.error = "Authentication failed: \(error.localizedDescription)"
        }
    }

    func refreshAccessToken() async {
        guard let refresh = refreshToken else { return }

        let body: [String: String] = [
            "client_id": clientId,
            "client_secret": clientSecret,
            "grant_type": "refresh_token",
            "refresh_token": refresh
        ]

        do {
            let response: TokenResponse = try await post(path: "/oauth/token", body: body, useBaseURL: "https://www.strava.com")
            saveTokens(response)
        } catch {
            self.error = "Token refresh failed — please re-authenticate with Strava."
            isAuthenticated = false
        }
    }

    private func saveTokens(_ response: TokenResponse) {
        accessToken = response.accessToken
        refreshToken = response.refreshToken
        tokenExpiry = Date(timeIntervalSince1970: TimeInterval(response.expiresAt))
        isAuthenticated = true

        // Persist to Keychain in production
        UserDefaults.standard.set(response.accessToken, forKey: "strava_access_token")
        UserDefaults.standard.set(response.refreshToken, forKey: "strava_refresh_token")
        UserDefaults.standard.set(response.expiresAt, forKey: "strava_token_expiry")
    }

    func loadStoredTokens() {
        accessToken = UserDefaults.standard.string(forKey: "strava_access_token")
        refreshToken = UserDefaults.standard.string(forKey: "strava_refresh_token")
        let expiry = UserDefaults.standard.integer(forKey: "strava_token_expiry")
        if expiry > 0 { tokenExpiry = Date(timeIntervalSince1970: TimeInterval(expiry)) }
        isAuthenticated = accessToken != nil
    }

    func disconnect() {
        accessToken = nil
        refreshToken = nil
        tokenExpiry = nil
        isAuthenticated = false
        athlete = nil
        recentActivities = []
        UserDefaults.standard.removeObject(forKey: "strava_access_token")
        UserDefaults.standard.removeObject(forKey: "strava_refresh_token")
        UserDefaults.standard.removeObject(forKey: "strava_token_expiry")
    }

    // MARK: - Athlete

    func fetchAthlete() async {
        do {
            athlete = try await get(path: "/athlete")
        } catch {
            self.error = "Failed to fetch athlete profile: \(error.localizedDescription)"
        }
    }

    // MARK: - Activities

    func fetchRecentActivities(perPage: Int = 30) async {
        guard isAuthenticated else { return }
        isSyncing = true
        defer { isSyncing = false }

        await ensureValidToken()

        do {
            let activities: [StravaActivity] = try await get(
                path: "/athlete/activities",
                params: ["per_page": "\(perPage)", "page": "1"]
            )
            recentActivities = activities.filter {
                $0.type == "Swim" || $0.type == "Ride" || $0.type == "Run"
            }
        } catch {
            self.error = "Activity sync failed: \(error.localizedDescription)"
        }
    }

    func fetchActivityDetail(id: Int) async -> StravaDetailedActivity? {
        await ensureValidToken()
        return try? await get(path: "/activities/\(id)")
    }

    // MARK: - Match to Planned Workout

    func matchActivity(_ activities: [StravaActivity], toPlanned workout: Workout) -> StravaActivity? {
        let planDate = workout.scheduledDate
        let windowStart = Calendar.current.date(byAdding: .hour, value: -8, to: planDate)!
        let windowEnd = Calendar.current.date(byAdding: .day, value: 1, to: planDate)!

        let sportFilter: String
        switch workout.sport {
        case .swim: sportFilter = "Swim"
        case .bike, .brick: sportFilter = "Ride"
        case .run: sportFilter = "Run"
        default: return nil
        }

        return activities
            .filter { $0.type == sportFilter && $0.startDate >= windowStart && $0.startDate <= windowEnd }
            .min(by: { abs($0.movingTime - Int(workout.plannedDuration)) < abs($1.movingTime - Int(workout.plannedDuration)) })
    }

    // MARK: - HTTP Helpers

    private func ensureValidToken() async {
        if let expiry = tokenExpiry, expiry < Date().addingTimeInterval(300) {
            await refreshAccessToken()
        }
    }

    private func get<T: Decodable>(path: String, params: [String: String] = [:]) async throws -> T {
        var components = URLComponents(string: baseURL + path)!
        if !params.isEmpty {
            components.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        }

        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw StravaError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        return try JSONDecoder.stravaDecoder.decode(T.self, from: data)
    }

    private func post<T: Decodable>(path: String, body: [String: String], useBaseURL: String? = nil) async throws -> T {
        let urlString = (useBaseURL ?? baseURL) + path
        var request = URLRequest(url: URL(string: urlString)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = body.map { "\($0.key)=\($0.value)" }.joined(separator: "&").data(using: .utf8)

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder.stravaDecoder.decode(T.self, from: data)
    }
}

// MARK: - Supporting Types

struct StravaAthlete: Codable, Identifiable {
    var id: Int
    var firstname: String
    var lastname: String
    var profileMedium: String?
    var city: String?
    var country: String?

    enum CodingKeys: String, CodingKey {
        case id, firstname, lastname, city, country
        case profileMedium = "profile_medium"
    }
}

struct StravaActivity: Codable, Identifiable {
    var id: Int
    var name: String
    var type: String
    var startDate: Date
    var movingTime: Int
    var elapsedTime: Int
    var distance: Double
    var totalElevationGain: Double
    var averageSpeed: Double
    var maxSpeed: Double
    var averageHeartrate: Double?
    var maxHeartrate: Double?
    var averageWatts: Double?
    var kilojoules: Double?
    var sufferScore: Int?

    enum CodingKeys: String, CodingKey {
        case id, name, type, distance
        case startDate = "start_date"
        case movingTime = "moving_time"
        case elapsedTime = "elapsed_time"
        case totalElevationGain = "total_elevation_gain"
        case averageSpeed = "average_speed"
        case maxSpeed = "max_speed"
        case averageHeartrate = "average_heartrate"
        case maxHeartrate = "max_heartrate"
        case averageWatts = "average_watts"
        case kilojoules
        case sufferScore = "suffer_score"
    }
}

struct StravaDetailedActivity: Codable {
    var id: Int
    var description: String?
    var calories: Double?
    var deviceName: String?
    var laps: [StravaLap]?

    enum CodingKeys: String, CodingKey {
        case id, description, calories
        case deviceName = "device_name"
        case laps
    }
}

struct StravaLap: Codable {
    var lapIndex: Int
    var elapsedTime: Int
    var distance: Double
    var averageSpeed: Double
    var averageHeartrate: Double?
    var averageWatts: Double?

    enum CodingKeys: String, CodingKey {
        case lapIndex = "lap_index"
        case elapsedTime = "elapsed_time"
        case distance
        case averageSpeed = "average_speed"
        case averageHeartrate = "average_heartrate"
        case averageWatts = "average_watts"
    }
}

struct TokenResponse: Codable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Int
    var athlete: StravaAthlete?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresAt = "expires_at"
        case athlete
    }
}

enum StravaError: Error {
    case httpError(Int)
    case notAuthenticated
}

extension JSONDecoder {
    static var stravaDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        let formatter = ISO8601DateFormatter()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)
            if let date = formatter.date(from: str) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(str)")
        }
        return decoder
    }
}
