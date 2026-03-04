# TriTrainer — Adaptive Triathlon Training App

An iOS app (SwiftUI) that connects to your calendar and weather, builds a periodized triathlon training plan, and adapts it in real time based on what you actually do.

## Features

### Adaptive Training Plan
- **Periodization**: Base → Build → Peak → Taper phases automatically calculated from your race date
- **3:1 Loading**: 3 weeks progressive load, 1 recovery week — proven training structure
- **Live Adaptation**: Plan adjusts weekly based on compliance rate, perceived effort, and performance trends
- Automatically detects fatigue, low compliance, or performance breakthroughs and adjusts accordingly

### Calendar Integration (Apple EventKit)
- Reads your Apple Calendar to find your available time windows
- Avoids scheduling workouts during busy periods
- Writes all planned workouts to a dedicated "Triathlon Training" calendar
- Suggests optimal workout times (morning for hard sessions, evening for easy)

### Weather Awareness (Apple WeatherKit)
- Checks hourly forecasts for each planned outdoor session
- Flags unsafe conditions: extreme heat/cold, high winds, thunderstorms, heavy rain
- Generates sport-specific risk assessments (wind matters more for cycling than running)
- Provides detailed indoor alternatives with equipment lists when outdoor training isn't safe
- Adjusts intensity guidance for heat (slow down 10-15% when >27°C)

### Activity Sync
- **Apple HealthKit**: Reads completed workouts from any source (Garmin Connect, Apple Watch, third-party apps) — covers Garmin natively since Garmin syncs to Apple Health
- **Strava OAuth2**: Direct integration for richer data (laps, power curves, segment data)
- Auto-matches completed activities to planned workouts by date and duration

### Coaching Content (per workout)
Every session includes:
- **Session Goal**: What you're trying to achieve physiologically
- **Warm-Up Instructions**: Detailed, sport-specific warm-up protocol
- **Main Set**: Structured workout with specific intervals, distances, and effort targets
- **Cool-Down**: Recovery protocol
- **Coaching Tips**: 3-5 expert tips timed to before/during/after the session
- **Technique Cues**: Specific form focus points with drills and common mistakes to avoid
- **Nutrition Guidance**: Fueling strategy for the session
- **Post-Workout Guidance**: Recovery instructions and what to track

### Triathlon-Specific Content
- **Swim**: Technique drills (catch-up, fingertip drag), open water preparation, CSS intervals
- **Bike**: FTP work, cadence training, aero position, hill and descent technique
- **Run**: Zone 2 easy running, tempo, VO2 max intervals, run-off-bike brick running
- **Brick Sessions**: Dedicated bike-to-run transitions with T2 practice guidance

## Architecture

```
TriathlonTrainer/
├── App/
│   └── TriathlonTrainerApp.swift          # App entry + service injection
├── Models/
│   ├── AthleteProfile.swift               # SwiftData model: athlete & race info
│   ├── Workout.swift                      # SwiftData model: planned session + coaching
│   └── WorkoutResult.swift                # SwiftData model: actual performance + plan
├── Services/
│   ├── CalendarService.swift              # EventKit integration
│   ├── WeatherService.swift               # WeatherKit integration
│   ├── HealthKitService.swift             # HKWorkout reads (Garmin, Watch)
│   ├── StravaService.swift                # OAuth2 + REST API
│   └── AdaptiveEngine.swift               # Plan adaptation logic
├── ViewModels/
│   ├── DashboardViewModel.swift
│   ├── OnboardingViewModel.swift
│   └── WorkoutViewModel.swift
├── Views/
│   ├── Onboarding/OnboardingView.swift    # 4-step setup flow
│   ├── Dashboard/
│   │   ├── DashboardView.swift            # Today + weekly overview
│   │   ├── WeekView.swift                 # Full week calendar view
│   │   ├── ProgressView.swift             # Charts + fitness metrics
│   │   └── MainTabView.swift
│   ├── Workout/
│   │   ├── WorkoutDetailView.swift        # Full session detail + coaching
│   │   └── WorkoutLogView.swift           # Log actual performance
│   └── Settings/SettingsView.swift
└── Utilities/
    ├── TrainingPlanGenerator.swift         # Periodization engine
    └── WorkoutContentLibrary.swift         # All coaching content
```

## Setup

### Requirements
- iOS 17.0+
- Xcode 15+
- Apple Developer account (for WeatherKit entitlement)

### Xcode Configuration
1. Open/create project in Xcode targeting iOS 17+
2. Add all Swift files from `Sources/TriathlonTrainer/`
3. Enable capabilities:
   - **WeatherKit** (requires Apple Developer account)
   - **HealthKit** (Background processing optional)
   - **Calendar** (via Info.plist usage description)
4. Add to `Info.plist`:
   ```xml
   <key>NSCalendarsUsageDescription</key>
   <string>TriTrainer reads your availability to schedule workouts and adds sessions to your calendar.</string>
   <key>NSHealthShareUsageDescription</key>
   <string>TriTrainer reads your workouts to track training completion and adapt your plan.</string>
   <key>NSLocationWhenInUseUsageDescription</key>
   <string>Used to fetch local weather forecasts for your training location.</string>
   ```
5. Add URL scheme `triathlontrainer` for Strava OAuth callback
6. Replace `YOUR_STRAVA_CLIENT_ID` and `YOUR_STRAVA_CLIENT_SECRET` in `StravaService.swift`

### Strava API Setup
1. Create app at https://www.strava.com/settings/api
2. Set Authorization Callback Domain to `triathlontrainer`
3. Add credentials to `StravaService.swift`

## Adaptive Engine Logic

The app tracks weekly compliance and adjusts upcoming training:

| Compliance | Action |
|-----------|--------|
| ≥90% + low RPE | +8% volume on easy sessions |
| 75–90% | No change |
| 60–75% | −10% volume next week |
| <60% | −20% volume next week |
| 2+ easy sessions with RPE >8 | Unplanned recovery week |
| 3+ consecutive skips | Soft-load re-entry week |

Weather adaptation:
- Wind >60 km/h → indoor substitution (all sports)
- Wind >40 km/h → indoor substitution (bike only)
- Temp >35°C or feels-like < -10°C → indoor substitution
- Thunderstorm → indoor substitution + open water warning
