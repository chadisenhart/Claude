// ─── Athlete ────────────────────────────────────────────────────────────────

export type RaceDistance = 'Sprint' | 'Olympic' | 'Half Ironman' | 'Full Ironman'
export type ExperienceLevel = 'Beginner' | 'Intermediate' | 'Advanced'
export type Sport = 'Swim' | 'Bike' | 'Run' | 'Brick' | 'Strength' | 'Rest'
export type TrainingPhase = 'Base' | 'Build' | 'Peak' | 'Taper' | 'Race'
export type WorkoutIntensity = 'Recovery' | 'Easy' | 'Moderate' | 'Threshold' | 'VO2 Max' | 'Sprint'
export type WorkoutStatus = 'Scheduled' | 'Completed' | 'Skipped' | 'Partial' | 'Rescheduled' | 'Indoor'

export interface AthleteProfile {
  id: string
  name: string
  raceDate: string        // ISO date string
  raceDistance: RaceDistance
  experienceLevel: ExperienceLevel
  weeklyAvailableHours: number
  preferredDays: number[] // 0=Mon … 6=Sun
  swimCSS?: number        // seconds per 100m
  bikeFTP?: number        // watts
  runThresholdPace?: number // seconds per km
  stravaAccessToken?: string
  stravaRefreshToken?: string
  stravaTokenExpiry?: number
  createdAt: string
}

// ─── Workout ─────────────────────────────────────────────────────────────────

export interface CoachingTip {
  id: string
  title: string
  detail: string
  timing: 'Before' | 'Warm-up' | 'Main Set' | 'Cool-down' | 'After' | 'Nutrition'
}

export interface TechniqueCue {
  id: string
  sport: Sport
  cue: string
  drillName?: string
  drillDescription?: string
  commonMistake?: string
}

export interface ZoneBlock {
  zone: number
  durationSeconds: number
  description: string
}

export interface IndoorAlternative {
  instructions: string
  equipment: string[]
}

export interface WeatherSnapshot {
  temp: number
  feelsLike: number
  condition: string
  windKmh: number
  precipChance: number
  isOutdoorSafe: boolean
  warning?: string
}

export interface WorkoutResult {
  completedAt: string
  actualDuration: number  // seconds
  actualDistanceKm?: number
  avgHeartRate?: number
  avgPower?: number
  avgPaceSecPerKm?: number
  perceivedEffort: number // 1–10
  notes: string
  complianceScore: number // 0–1
  stravaActivityId?: number
}

export interface Workout {
  id: string
  scheduledDate: string   // ISO date string
  sport: Sport
  workoutType: string
  plannedDurationSec: number
  plannedDistanceKm?: number
  intensity: WorkoutIntensity
  zones: ZoneBlock[]

  // Coaching content
  title: string
  goal: string
  warmup: string
  mainSet: string
  cooldown: string
  tips: CoachingTip[]
  techniqueCues: TechniqueCue[]
  postWorkoutGuidance: string

  // Context
  phase: TrainingPhase
  weekNumber: number
  status: WorkoutStatus
  calendarEventId?: string
  weatherSnapshot?: WeatherSnapshot
  indoorAlternative?: IndoorAlternative
  result?: WorkoutResult
}

// ─── Plan ────────────────────────────────────────────────────────────────────

export interface AdaptationEvent {
  date: string
  reason: string
  description: string
  changeType: string
}

export interface TrainingPlan {
  id: string
  athleteId: string
  createdAt: string
  lastAdaptedAt: string
  adaptationHistory: AdaptationEvent[]
}

// ─── Weather ─────────────────────────────────────────────────────────────────

export interface HourlyForecast {
  dt: number
  temp: number
  feelsLike: number
  description: string
  windKmh: number
  precipChance: number
  precipMm: number
  icon: string
}

export type RiskLevel = 'unknown' | 'low' | 'moderate' | 'high' | 'extreme'

export interface WeatherWarning {
  icon: string
  message: string
}

export interface WeatherAssessment {
  isSuitable: boolean
  riskLevel: RiskLevel
  warnings: WeatherWarning[]
  indoorRecommended: boolean
  intensityAdjustment?: string
  summary: string
}

// ─── Strava ──────────────────────────────────────────────────────────────────

export interface StravaActivity {
  id: number
  name: string
  type: string
  start_date: string
  moving_time: number
  elapsed_time: number
  distance: number
  total_elevation_gain: number
  average_speed: number
  average_heartrate?: number
  max_heartrate?: number
  average_watts?: number
  kilojoules?: number
  suffer_score?: number
}

// ─── Race Distance metadata ───────────────────────────────────────────────────

export const RACE_DISTANCES: Record<RaceDistance, {
  swimKm: number; bikeKm: number; runKm: number; totalWeeks: number
}> = {
  'Sprint':       { swimKm: 0.75, bikeKm: 20,  runKm: 5,    totalWeeks: 8  },
  'Olympic':      { swimKm: 1.5,  bikeKm: 40,  runKm: 10,   totalWeeks: 12 },
  'Half Ironman': { swimKm: 1.93, bikeKm: 90,  runKm: 21.1, totalWeeks: 20 },
  'Full Ironman': { swimKm: 3.86, bikeKm: 180, runKm: 42.2, totalWeeks: 30 },
}

export const EXPERIENCE_MULTIPLIER: Record<ExperienceLevel, number> = {
  Beginner: 0.7,
  Intermediate: 1.0,
  Advanced: 1.35,
}

export const SPORT_COLORS: Record<Sport, string> = {
  Swim: '#3b82f6',
  Bike: '#f97316',
  Run: '#22c55e',
  Brick: '#a855f7',
  Strength: '#ef4444',
  Rest: '#9ca3af',
}

export const SPORT_ICONS: Record<Sport, string> = {
  Swim: '🏊',
  Bike: '🚴',
  Run: '🏃',
  Brick: '⚡',
  Strength: '💪',
  Rest: '😴',
}
