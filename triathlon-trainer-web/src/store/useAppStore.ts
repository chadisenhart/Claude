import { create } from 'zustand'
import { persist } from 'zustand/middleware'
import type { AthleteProfile, Workout, AdaptationEvent } from '../types'
import { db } from './db'

interface AppState {
  profile: AthleteProfile | null
  adaptationAlerts: AdaptationEvent[]
  stravaActivities: any[]

  setProfile: (profile: AthleteProfile) => void
  clearProfile: () => void
  addAdaptationAlert: (event: AdaptationEvent) => void
  clearAlerts: () => void
  setStravaActivities: (activities: any[]) => void

  // Workout helpers
  updateWorkout: (id: string, updates: Partial<Workout>) => Promise<void>
}

export const useAppStore = create<AppState>()(
  persist(
    (set) => ({
      profile: null,
      adaptationAlerts: [],
      stravaActivities: [],

      setProfile: (profile) => set({ profile }),
      clearProfile: () => set({ profile: null }),
      addAdaptationAlert: (event) =>
        set((s) => ({ adaptationAlerts: [event, ...s.adaptationAlerts].slice(0, 5) })),
      clearAlerts: () => set({ adaptationAlerts: [] }),
      setStravaActivities: (activities) => set({ stravaActivities: activities }),

      updateWorkout: async (id, updates) => {
        await db.workouts.update(id, updates)
      },
    }),
    {
      name: 'triathlon-app',
      partialize: (state) => ({ profile: state.profile }),
    }
  )
)
