import { addDays, startOfWeek, differenceInWeeks, format } from 'date-fns'
import { v4 as uuid } from 'uuid'
import type {
  AthleteProfile, Workout, TrainingPhase, Sport, WorkoutIntensity, ZoneBlock
} from '../types'
import { RACE_DISTANCES, EXPERIENCE_MULTIPLIER } from '../types'
import { getWorkoutContent } from './workoutContent'

// ─── Phase Distribution ────────────────────────────────────────────────────

function phaseWeeks(total: number): { phase: TrainingPhase; weeks: number }[] {
  if (total < 10) return [{ phase: 'Base', weeks: Math.max(4, total - 2) }, { phase: 'Taper', weeks: 2 }]
  if (total < 16) return [{ phase: 'Base', weeks: 5 }, { phase: 'Build', weeks: total - 7 }, { phase: 'Peak', weeks: 2 }, { phase: 'Taper', weeks: 2 }]
  if (total < 24) return [{ phase: 'Base', weeks: 8 }, { phase: 'Build', weeks: total - 12 }, { phase: 'Peak', weeks: 2 }, { phase: 'Taper', weeks: 2 }]
  return [{ phase: 'Base', weeks: 10 }, { phase: 'Build', weeks: total - 16 }, { phase: 'Peak', weeks: 3 }, { phase: 'Taper', weeks: 3 }]
}

// ─── Weekly Volume ─────────────────────────────────────────────────────────

function weeklyHours(
  phase: TrainingPhase,
  weekInPhase: number,
  experience: AthleteProfile['experienceLevel'],
  distance: AthleteProfile['raceDistance'],
  cap: number
): number {
  const base: Record<AthleteProfile['raceDistance'], number> = {
    Sprint: 5, Olympic: 8, 'Half Ironman': 11, 'Full Ironman': 16
  }
  const phaseM: Record<TrainingPhase, number> = {
    Base: 0.7, Build: 1.0, Peak: 1.15, Taper: 0.55, Race: 0.3
  }
  const cycle = ((weekInPhase - 1) % 4) + 1
  const loadM = cycle === 1 ? 0.85 : cycle === 2 ? 1.0 : cycle === 3 ? 1.1 : 0.65

  return Math.min(base[distance] * phaseM[phase] * loadM * EXPERIENCE_MULTIPLIER[experience], cap)
}

// ─── Sport Split ───────────────────────────────────────────────────────────

function sportSplit(distance: AthleteProfile['raceDistance']): { swim: number; bike: number; run: number } {
  if (distance === 'Sprint' || distance === 'Olympic') return { swim: 0.15, bike: 0.50, run: 0.35 }
  if (distance === 'Half Ironman') return { swim: 0.12, bike: 0.55, run: 0.33 }
  return { swim: 0.10, bike: 0.58, run: 0.32 }
}

// ─── Main Generator ────────────────────────────────────────────────────────

export function generatePlan(profile: AthleteProfile): Workout[] {
  const today = new Date()
  const raceDate = new Date(profile.raceDate)
  const weeksUntilRace = Math.max(4, differenceInWeeks(raceDate, today))
  const totalWeeks = Math.min(weeksUntilRace, RACE_DISTANCES[profile.raceDistance].totalWeeks)
  const phases = phaseWeeks(totalWeeks)

  const workouts: Workout[] = []
  let globalWeek = 1

  for (const { phase, weeks } of phases) {
    for (let w = 1; w <= weeks; w++) {
      const weekStart = addDays(startOfWeek(today, { weekStartsOn: 1 }), (globalWeek - 1) * 7)
      const hours = weeklyHours(phase, w, profile.experienceLevel, profile.raceDistance, profile.weeklyAvailableHours)
      const split = sportSplit(profile.raceDistance)
      const isRecovery = ((w - 1) % 4) === 3

      const weekWorkouts = buildWeekWorkouts(
        weekStart,
        globalWeek,
        phase,
        hours,
        split,
        profile.preferredDays,
        isRecovery,
        profile.raceDistance,
        profile.experienceLevel
      )

      workouts.push(...weekWorkouts)
      globalWeek++
    }
  }

  return workouts
}

// ─── Week Builder ──────────────────────────────────────────────────────────

type SessionSlot = { sport: Sport; type: string; hours: number }

function buildWeekWorkouts(
  weekStart: Date,
  weekNumber: number,
  phase: TrainingPhase,
  totalHours: number,
  split: { swim: number; bike: number; run: number },
  preferredDays: number[],
  isRecovery: boolean,
  distance: AthleteProfile['raceDistance'],
  experience: AthleteProfile['experienceLevel']
): Workout[] {
  const days = [...preferredDays].sort()
  if (days.length < 3) return []

  const swimH = totalHours * split.swim
  const bikeH = totalHours * split.bike
  const runH = totalHours * split.run

  const sessions: SessionSlot[] = []

  // Weekend = last 2 days (indexes 5,6 = Sat/Sun)
  const weekendDays = days.filter(d => d >= 5)
  const weekDays = days.filter(d => d < 5)

  // Long sessions on weekends
  if (weekendDays.length > 0) sessions.push({ sport: 'Bike', type: 'long', hours: bikeH * 0.45 })
  if (weekendDays.length > 1) sessions.push({ sport: 'Run', type: 'long', hours: runH * 0.40 })

  if (isRecovery) {
    sessions.push({ sport: 'Swim', type: 'easy', hours: swimH })
    sessions.push({ sport: 'Run', type: 'easy', hours: runH * 0.6 })
  } else {
    sessions.push({ sport: 'Swim', type: 'technique', hours: swimH * 0.5 })
    if (swimH > 1.5) sessions.push({ sport: 'Swim', type: 'intervals', hours: swimH * 0.5 })
    sessions.push({ sport: 'Bike', type: 'intervals', hours: bikeH * 0.25 })
    sessions.push({ sport: 'Run', type: phase === 'Base' ? 'easy' : 'tempo', hours: runH * 0.35 })
    if (!isRecovery && phase !== 'Base' && days.length >= 5) {
      sessions.push({ sport: 'Brick', type: 'brick', hours: bikeH * 0.2 + runH * 0.15 })
    }
  }

  const allDays = [...weekendDays, ...weekDays].sort()
  const result: Workout[] = []

  sessions.slice(0, allDays.length).forEach((slot, i) => {
    const dayOffset = allDays[i]
    const date = addDays(weekStart, dayOffset)
    const content = getWorkoutContent(slot.sport, slot.type, phase, experience, slot.hours)

    result.push({
      id: uuid(),
      scheduledDate: format(date, 'yyyy-MM-dd'),
      sport: slot.sport,
      workoutType: slot.type,
      plannedDurationSec: Math.round(slot.hours * 3600),
      plannedDistanceKm: content.distanceKm,
      intensity: content.intensity,
      zones: content.zones,
      title: content.title,
      goal: content.goal,
      warmup: content.warmup,
      mainSet: content.mainSet,
      cooldown: content.cooldown,
      tips: content.tips,
      techniqueCues: content.techniqueCues,
      postWorkoutGuidance: content.postWorkoutGuidance,
      phase,
      weekNumber,
      status: 'Scheduled',
    })
  })

  return result
}
