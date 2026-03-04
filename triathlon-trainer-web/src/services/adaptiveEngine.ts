import type { Workout, AdaptationEvent, WorkoutIntensity } from '../types'

// ─── Compliance Analysis ───────────────────────────────────────────────────

export interface WeeklyAnalysis {
  complianceRate: number
  volumeCompliance: number
  completed: number
  skipped: number
  plannedHours: number
  actualHours: number
  avgRPE: number
  trend: 'improving' | 'stable' | 'declining' | 'poor'
  recommendations: string[]
}

export function analyzeWeek(workouts: Workout[]): WeeklyAnalysis {
  const scheduled = workouts.filter(w => w.sport !== 'Rest')
  const completed = workouts.filter(w => w.status === 'Completed' || w.status === 'Partial')
  const skipped = workouts.filter(w => w.status === 'Skipped')

  const complianceRate = scheduled.length ? completed.length / scheduled.length : 1
  const plannedHours = workouts.reduce((s, w) => s + w.plannedDurationSec / 3600, 0)
  const actualHours = workouts
    .filter(w => w.result)
    .reduce((s, w) => s + (w.result!.actualDuration / 3600), 0)
  const volumeCompliance = plannedHours > 0 ? Math.min(actualHours / plannedHours, 1.5) : 1

  const rpeValues = workouts.filter(w => w.result).map(w => w.result!.perceivedEffort)
  const avgRPE = rpeValues.length ? rpeValues.reduce((a, b) => a + b, 0) / rpeValues.length : 0

  const trend: WeeklyAnalysis['trend'] =
    complianceRate >= 0.9 ? 'improving' :
    complianceRate >= 0.7 ? 'stable' :
    complianceRate >= 0.5 ? 'declining' : 'poor'

  const recommendations: string[] = []
  if (complianceRate < 0.7) recommendations.push(`Compliance was ${Math.round(complianceRate * 100)}%. Consider shortening sessions — consistency beats perfection.`)
  if (avgRPE > 8) recommendations.push('Average effort is very high. Slow down on easy days — zone 2 should feel almost embarrassingly easy.')
  if (volumeCompliance > 1.2) recommendations.push('You\'re doing more volume than planned. Great enthusiasm, but be careful of overuse injury.')
  if (complianceRate >= 0.9 && avgRPE < 7) recommendations.push('Excellent week! You\'re handling the load well — next week\'s volume can increase slightly.')

  return { complianceRate, volumeCompliance, completed: completed.length, skipped: skipped.length, plannedHours, actualHours, avgRPE, trend, recommendations }
}

// ─── Adaptation ───────────────────────────────────────────────────────────

export function adaptWorkouts(
  upcomingWorkouts: Workout[],
  lastWeekWorkouts: Workout[]
): { workouts: Workout[]; events: AdaptationEvent[] } {
  const analysis = analyzeWeek(lastWeekWorkouts)
  const events: AdaptationEvent[] = []
  let workouts = [...upcomingWorkouts]

  // Low compliance → reduce volume
  if (analysis.complianceRate < 0.6) {
    workouts = scaleVolume(workouts, 0.80)
    events.push({
      date: new Date().toISOString(),
      reason: 'Low Compliance',
      description: `Compliance was ${Math.round(analysis.complianceRate * 100)}% last week. Volume reduced 20% to help you build consistency. Hit 80%+ of this week's sessions.`,
      changeType: 'Volume Reduced',
    })
  } else if (analysis.complianceRate < 0.75) {
    workouts = scaleVolume(workouts, 0.90)
    events.push({
      date: new Date().toISOString(),
      reason: 'Low Compliance',
      description: `Compliance was ${Math.round(analysis.complianceRate * 100)}% last week. Volume reduced 10% — focus on consistency this week.`,
      changeType: 'Volume Reduced',
    })
  }

  // High compliance + low RPE → can push harder
  if (analysis.complianceRate >= 0.9 && analysis.avgRPE < 6) {
    workouts = scaleEasyVolume(workouts, 1.08)
    events.push({
      date: new Date().toISOString(),
      reason: 'High Compliance',
      description: 'Great compliance and effort last week! Easy session volume increased 8% to match your improving fitness.',
      changeType: 'Volume Increased',
    })
  }

  // High RPE on easy days → fatigue warning
  const overeasedWorkouts = lastWeekWorkouts.filter(w =>
    (w.intensity === 'Easy' || w.intensity === 'Recovery') &&
    (w.result?.perceivedEffort ?? 0) > 8
  )
  if (overeasedWorkouts.length >= 2) {
    workouts = insertRecoveryWeek(workouts)
    events.push({
      date: new Date().toISOString(),
      reason: 'Accumulated Fatigue',
      description: `Easy sessions felt very hard (RPE ${overeasedWorkouts.map(w => w.result!.perceivedEffort).join(', ')}). This is a fatigue signal. Unplanned recovery week: volume down 40%, intensity lowered. Your body needs this to adapt.`,
      changeType: 'Recovery Week Added',
    })
  }

  // 3+ consecutive skips → soft entry
  if (consecutiveSkips(lastWeekWorkouts) >= 3) {
    workouts = softLoad(workouts)
    events.push({
      date: new Date().toISOString(),
      reason: 'Low Compliance',
      description: '3+ consecutive skipped sessions. Check for illness or overtraining. This week is a soft re-entry: reduced volume and intensity.',
      changeType: 'Volume Reduced',
    })
  }

  return { workouts, events }
}

// ─── Compliance Score ─────────────────────────────────────────────────────

export function calcComplianceScore(workout: Workout): number {
  if (!workout.result) return 0

  const durationScore = Math.min(workout.result.actualDuration / workout.plannedDurationSec, 1.0)

  const expectedRPE: Record<WorkoutIntensity, number> = {
    Recovery: 2, Easy: 4, Moderate: 6, Threshold: 7.5, 'VO2 Max': 9, Sprint: 10
  }
  const rpeDiff = Math.abs(workout.result.perceivedEffort - (expectedRPE[workout.intensity] ?? 6))
  const rpeScore = Math.max(0, 1 - rpeDiff / 5)

  return durationScore * 0.7 + rpeScore * 0.3
}

// ─── Helpers ──────────────────────────────────────────────────────────────

function scaleVolume(workouts: Workout[], factor: number): Workout[] {
  return workouts.map(w => ({
    ...w,
    plannedDurationSec: Math.round(w.plannedDurationSec * factor),
    plannedDistanceKm: w.plannedDistanceKm ? w.plannedDistanceKm * factor : undefined,
  }))
}

function scaleEasyVolume(workouts: Workout[], factor: number): Workout[] {
  return workouts.map(w =>
    (w.intensity === 'Easy' || w.intensity === 'Recovery')
      ? { ...w, plannedDurationSec: Math.round(w.plannedDurationSec * factor) }
      : w
  )
}

function insertRecoveryWeek(workouts: Workout[]): Workout[] {
  return workouts.map(w => ({
    ...w,
    plannedDurationSec: Math.round(w.plannedDurationSec * 0.6),
    intensity: (w.intensity === 'Threshold' || w.intensity === 'VO2 Max' || w.intensity === 'Sprint')
      ? 'Easy' as WorkoutIntensity
      : w.intensity,
    title: w.intensity === 'Threshold' || w.intensity === 'VO2 Max' ? `Recovery: ${w.title}` : w.title,
    goal: w.intensity === 'Threshold' || w.intensity === 'VO2 Max'
      ? 'Recovery week — keep effort very easy. Let your body absorb recent training load.'
      : w.goal,
  }))
}

function softLoad(workouts: Workout[]): Workout[] {
  return workouts.map(w => ({
    ...w,
    plannedDurationSec: Math.round(w.plannedDurationSec * 0.7),
    intensity: w.intensity !== 'Recovery' ? 'Easy' as WorkoutIntensity : w.intensity,
  }))
}

function consecutiveSkips(workouts: Workout[]): number {
  let max = 0, cur = 0
  for (const w of workouts.sort((a, b) => a.scheduledDate.localeCompare(b.scheduledDate))) {
    if (w.status === 'Skipped') { cur++; max = Math.max(max, cur) }
    else cur = 0
  }
  return max
}
