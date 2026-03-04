import { useState, useEffect } from 'react'
import { useLiveQuery } from 'dexie-react-hooks'
import { isToday, parseISO, startOfWeek, endOfWeek, format, addDays } from 'date-fns'
import { db } from '../store/db'
import { useAppStore } from '../store/useAppStore'
import { WorkoutCard } from '../components/workout/WorkoutCard'
import { WorkoutDetailSheet } from '../components/workout/WorkoutDetailSheet'
import { Card, SectionHeader } from '../components/ui/Card'
import { fetchForecast, getCurrentLocation, assessWeather } from '../services/weatherService'
import { adaptWorkouts } from '../services/adaptiveEngine'
import { formatDuration, sportIcon, statusIcon } from '../utils/helpers'
import type { Workout, WeatherAssessment, HourlyForecast } from '../types'

export function Dashboard() {
  const profile = useAppStore(s => s.profile)
  const adaptationAlerts = useAppStore(s => s.adaptationAlerts)
  const clearAlerts = useAppStore(s => s.clearAlerts)

  const [selectedWorkout, setSelectedWorkout] = useState<Workout | null>(null)
  const [forecast, setForecast] = useState<HourlyForecast[]>([])
  const [todayAssessment, setTodayAssessment] = useState<WeatherAssessment | null>(null)

  const today = format(new Date(), 'yyyy-MM-dd')
  const weekStart = format(startOfWeek(new Date(), { weekStartsOn: 1 }), 'yyyy-MM-dd')
  const weekEnd   = format(endOfWeek(new Date(),   { weekStartsOn: 1 }), 'yyyy-MM-dd')

  const allWorkouts = useLiveQuery(() =>
    db.workouts.where('scheduledDate').aboveOrEqual(weekStart).toArray()
  ) ?? []

  const todayWorkout = allWorkouts.find(w => w.scheduledDate === today)
  const weekWorkouts = allWorkouts.filter(w => w.scheduledDate >= weekStart && w.scheduledDate <= weekEnd)
    .sort((a, b) => a.scheduledDate.localeCompare(b.scheduledDate))

  const upcomingWorkouts = allWorkouts
    .filter(w => w.scheduledDate > today && w.status === 'Scheduled')
    .sort((a, b) => a.scheduledDate.localeCompare(b.scheduledDate))
    .slice(0, 5)

  const weeksToRace = profile
    ? Math.max(0, Math.ceil((new Date(profile.raceDate).getTime() - Date.now()) / (7 * 24 * 3600 * 1000)))
    : 0

  const completedThisWeek = weekWorkouts.filter(w => w.status === 'Completed').length
  const scheduledThisWeek = weekWorkouts.filter(w => w.sport !== 'Rest').length

  // Load weather
  useEffect(() => {
    async function load() {
      const loc = await getCurrentLocation()
      if (!loc) return
      const f = await fetchForecast(loc.lat, loc.lon)
      setForecast(f)
      if (todayWorkout) {
        setTodayAssessment(assessWeather(f, todayWorkout.sport, todayWorkout.scheduledDate))
      }
    }
    load()
  }, [todayWorkout?.id])

  async function handleUpdate(id: string, updates: Partial<Workout>) {
    await db.workouts.update(id, updates)
  }

  const firstName = profile?.name.split(' ')[0] ?? 'Athlete'

  return (
    <div className="pt-safe pb-20 min-h-screen bg-gray-50">
      <div className="p-4 space-y-4">

        {/* Header */}
        <div className="flex items-start justify-between">
          <div>
            <h1 className="text-2xl font-bold text-gray-900">Hey, {firstName}!</h1>
            {profile && (
              <p className="text-sm text-gray-500 mt-0.5">
                {weeksToRace} weeks to your {profile.raceDistance}
              </p>
            )}
          </div>
          <div className="bg-blue-600 text-white rounded-2xl px-3 py-2 text-center">
            <p className="text-2xl font-bold leading-none">{weeksToRace}</p>
            <p className="text-xs opacity-80">weeks</p>
          </div>
        </div>

        {/* Adaptation alerts */}
        {adaptationAlerts.length > 0 && (
          <Card className="border-purple-100 bg-purple-50">
            <div className="flex items-start justify-between mb-2">
              <SectionHeader icon="🧠" title="Plan Updated" color="text-purple-700" />
              <button onClick={clearAlerts} className="text-purple-400 text-sm">✕</button>
            </div>
            <div className="space-y-2">
              {adaptationAlerts.map((alert, i) => (
                <div key={i} className="text-sm">
                  <p className="font-semibold text-purple-700">{alert.reason}</p>
                  <p className="text-gray-600 text-xs mt-0.5">{alert.description}</p>
                </div>
              ))}
            </div>
          </Card>
        )}

        {/* Today's workout */}
        <div>
          <SectionHeader icon="☀️" title="Today" />
          {todayWorkout ? (
            <WorkoutCard
              workout={todayWorkout}
              onClick={() => setSelectedWorkout(todayWorkout)}
            />
          ) : (
            <Card className="text-center py-6 text-gray-400">
              <p className="text-3xl mb-2">😴</p>
              <p className="font-medium text-gray-500">Rest day</p>
              <p className="text-sm">Recovery is training too</p>
            </Card>
          )}
        </div>

        {/* Week strip */}
        <Card>
          <SectionHeader
            title="This Week"
            right={
              <span className="text-sm text-gray-400">
                {completedThisWeek}/{scheduledThisWeek} done
              </span>
            }
          />
          <WeekStrip workouts={weekWorkouts} onSelect={setSelectedWorkout} />
          <div className="flex gap-2 mt-3">
            <StatChip label="Completed" value={String(completedThisWeek)} color="green" />
            <StatChip
              label="Hours"
              value={formatDuration(weekWorkouts.filter(w => w.result).reduce((s, w) => s + (w.result?.actualDuration ?? 0), 0))}
              color="blue"
            />
            <StatChip
              label="Phase"
              value={weekWorkouts[0]?.phase ?? '—'}
              color="purple"
            />
          </div>
        </Card>

        {/* Upcoming */}
        {upcomingWorkouts.length > 0 && (
          <div>
            <SectionHeader icon="📅" title="Coming Up" />
            <div className="space-y-2">
              {upcomingWorkouts.map(w => (
                <button
                  key={w.id}
                  onClick={() => setSelectedWorkout(w)}
                  className="w-full flex items-center gap-3 bg-white rounded-xl p-3 border border-gray-100 shadow-sm text-left"
                >
                  <span className="text-xl">{sportIcon(w.sport)}</span>
                  <div className="flex-1 min-w-0">
                    <p className="font-medium text-sm text-gray-900 truncate">{w.title}</p>
                    <p className="text-xs text-gray-400">
                      {format(parseISO(w.scheduledDate), 'EEE d MMM')} · {formatDuration(w.plannedDurationSec)}
                    </p>
                  </div>
                  <span className="text-gray-300">›</span>
                </button>
              ))}
            </div>
          </div>
        )}

      </div>

      {selectedWorkout && (
        <WorkoutDetailSheet
          workout={selectedWorkout}
          weather={selectedWorkout.scheduledDate === today ? todayAssessment ?? undefined : undefined}
          onClose={() => setSelectedWorkout(null)}
          onUpdate={handleUpdate}
        />
      )}
    </div>
  )
}

// ─── Week Strip ───────────────────────────────────────────────────────────

function WeekStrip({ workouts, onSelect }: { workouts: Workout[]; onSelect: (w: Workout) => void }) {
  const dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S']
  const weekStart = startOfWeek(new Date(), { weekStartsOn: 1 })

  return (
    <div className="flex gap-1">
      {dayLabels.map((label, i) => {
        const date = format(addDays(weekStart, i), 'yyyy-MM-dd')
        const workout = workouts.find(w => w.scheduledDate === date)
        const isTodayDay = date === format(new Date(), 'yyyy-MM-dd')

        return (
          <div key={i} className="flex-1 flex flex-col items-center gap-1">
            <span className={`text-xs ${isTodayDay ? 'text-blue-600 font-bold' : 'text-gray-400'}`}>{label}</span>
            {workout ? (
              <button
                onClick={() => onSelect(workout)}
                className="w-8 h-8 rounded-full flex items-center justify-center text-sm"
                style={{ backgroundColor: sportColorLight(workout.sport) }}
              >
                {workout.result ? '✅' : sportIcon(workout.sport)}
              </button>
            ) : (
              <div className="w-8 h-8 rounded-full border border-gray-200 flex items-center justify-center">
                {isTodayDay && <div className="w-2 h-2 rounded-full bg-blue-400" />}
              </div>
            )}
          </div>
        )
      })}
    </div>
  )
}

function sportColorLight(sport: string): string {
  switch (sport) {
    case 'Swim': return '#dbeafe'
    case 'Bike': return '#ffedd5'
    case 'Run':  return '#dcfce7'
    case 'Brick': return '#f3e8ff'
    default: return '#f3f4f6'
  }
}

function StatChip({ label, value, color }: { label: string; value: string; color: string }) {
  const colors: Record<string, string> = {
    green: 'bg-green-50 text-green-700',
    blue: 'bg-blue-50 text-blue-700',
    purple: 'bg-purple-50 text-purple-700',
    orange: 'bg-orange-50 text-orange-700',
  }
  return (
    <div className={`flex-1 rounded-xl py-2 text-center ${colors[color] ?? colors.blue}`}>
      <p className="font-bold text-sm">{value}</p>
      <p className="text-xs opacity-70">{label}</p>
    </div>
  )
}
