import Dexie, { type Table } from 'dexie'
import type { AthleteProfile, Workout, TrainingPlan } from '../types'

class TriathlonDB extends Dexie {
  athletes!: Table<AthleteProfile>
  workouts!: Table<Workout>
  plans!: Table<TrainingPlan>

  constructor() {
    super('TriathlonTrainer')
    this.version(1).stores({
      athletes: 'id, createdAt',
      workouts: 'id, scheduledDate, sport, phase, weekNumber, status, [sport+status]',
      plans: 'id, athleteId',
    })
  }
}

export const db = new TriathlonDB()
