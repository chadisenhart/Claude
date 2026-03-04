import { useState } from 'react'
import { useLiveQuery } from 'dexie-react-hooks'
import { format, addWeeks, subWeeks, startOfWeek, endOfWeek, addDays, parseISO } from 'date-fns'
import { db } from '../store/db'
import { WorkoutDetailSheet } from '../components/workout/WorkoutDetailSheet'
import { weekToICS, openICSInCalendar } from '../services/calendarService'
import { formatDuration, sportIcon, statusIcon } from '../utils/helpers'
import type { Workout } from '../types'

export function Week() {
  const [baseDate, setBaseDate] = useState(new Date())
  const [selectedWorkout, setSelectedWorkout] = useState<Workout | null>(null)

  const weekStart = startOfWeek(baseDate, { weekStartsOn: 1 })
  const weekEnd   = endOfWeek(baseDate,   { weekStartsOn: 1 })

  const weekStartStr = format(weekStart, 'yyyy-MM-dd')
  const weekEndStr   = format(weekEnd,   'yyyy-MM-dd')

  const weekWorkouts = useLiveQuery(() =>
    db.workouts.where('scheduledDate').between(weekStartStr, weekEndStr, true, true).toArray()
  ) ?? []

  const isCurrentWeek = format(new Date(), 'yyyy-MM-dd') >= weekStartStr &&
                        format(new Date(), 'yyyy-MM-dd') <= weekEndStr

  const weekRange = `${format(weekStart, 'd MMM')} – ${format(weekEnd, 'd MMM')}`

  const planned = weekWorkouts.filter(w => w.sport !== 'Rest').length
  const completed = weekWorkouts.filter(w => w.status === 'Completed').length
  const actualHours = weekWorkouts
    .filter(w => w.result)
    .reduce((s, w) => s + w.result!.actualDuration / 3600, 0)

  async function handleUpdate(id: string, updates: Partial<Workout>) {
    await db.workouts.update(id, updates)
  }

  function handleExportWeek() {
    openICSInCalendar(weekToICS(weekWorkouts))
  }

  return (
    <div className="pt-safe pb-20 min-h-screen bg-gray-50">
      {/* Week navigator */}
      <div className="bg-white border-b border-gray-100 px-4 py-3">
        <div className="flex items-center justify-between">
          <button
            onClick={() => setBaseDate(subWeeks(baseDate, 1))}
            className="w-9 h-9 rounded-full bg-gray-100 flex items-center justify-center text-gray-600"
          >
            ‹
          </button>
          <div className="text-center">
            <p className="font-semibold text-gray-900">{weekRange}</p>
            {isCurrentWeek && <p className="text-xs text-blue-600">This week</p>}
            {weekWorkouts[0] && !isCurrentWeek && (
              <p className="text-xs text-gray-400">{weekWorkouts[0].phase} · Week {weekWorkouts[0].weekNumber}</p>
            )}
          </div>
          <button
            onClick={() => setBaseDate(addWeeks(baseDate, 1))}
            className="w-9 h-9 rounded-full bg-gray-100 flex items-center justify-center text-gray-600"
          >
            ›
          </button>
        </div>

        {/* Week stats */}
        <div className="flex gap-3 mt-3">
          <div className="flex-1 bg-gray-50 rounded-xl p-2 text-center">
            <p className="font-bold text-blue-600">{completed}/{planned}</p>
            <p className="text-xs text-gray-400">Sessions</p>
          </div>
          <div className="flex-1 bg-gray-50 rounded-xl p-2 text-center">
            <p className="font-bold text-orange-600">{actualHours.toFixed(1)}h</p>
            <p className="text-xs text-gray-400">Logged</p>
          </div>
          <button
            onClick={handleExportWeek}
            className="flex-1 bg-blue-50 rounded-xl p-2 text-center text-blue-600"
          >
            <p className="font-bold text-sm">📅</p>
            <p className="text-xs">Calendar</p>
          </button>
        </div>
      </div>

      {/* Day rows */}
      <div className="p-4 space-y-3">
        {Array.from({ length: 7 }, (_, i) => {
          const date = format(addDays(weekStart, i), 'yyyy-MM-dd')
          const workout = weekWorkouts.find(w => w.scheduledDate === date)
          const isToday = date === format(new Date(), 'yyyy-MM-dd')

          return (
            <div
              key={i}
              className={`bg-white rounded-2xl border ${isToday ? 'border-blue-300' : 'border-gray-100'} shadow-sm overflow-hidden`}
            >
              {isToday && <div className="h-1 bg-blue-500" />}
              <div
                className="flex items-center gap-3 p-3 cursor-pointer"
                onClick={() => workout && setSelectedWorkout(workout)}
              >
                {/* Day */}
                <div className={`w-12 text-center flex-shrink-0 ${isToday ? 'text-blue-600' : 'text-gray-500'}`}>
                  <p className="text-xs font-medium">{format(parseISO(date), 'EEE')}</p>
                  <p className={`text-xl font-bold ${isToday ? 'text-blue-600' : 'text-gray-800'}`}>
                    {format(parseISO(date), 'd')}
                  </p>
                </div>

                {/* Workout */}
                {workout ? (
                  <div className="flex items-center gap-3 flex-1 min-w-0">
                    <div
                      className="w-10 h-10 rounded-full flex items-center justify-center text-xl flex-shrink-0"
                      style={{ backgroundColor: sportColorLight(workout.sport) }}
                    >
                      {sportIcon(workout.sport)}
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="font-semibold text-sm text-gray-900 truncate">{workout.title}</p>
                      <div className="flex items-center gap-2">
                        <span className="text-xs text-gray-400">{formatDuration(workout.plannedDurationSec)}</span>
                        <span className="text-xs text-gray-300">·</span>
                        <span className="text-xs text-gray-400">{workout.intensity}</span>
                      </div>
                    </div>
                    <span className="text-lg flex-shrink-0">{statusIcon(workout.status)}</span>
                  </div>
                ) : (
                  <div className="flex items-center gap-3 flex-1 text-gray-400">
                    <div className="w-10 h-10 rounded-full border-2 border-dashed border-gray-200 flex items-center justify-center">
                      <span className="text-gray-300 text-lg">😴</span>
                    </div>
                    <span className="text-sm">Rest day</span>
                  </div>
                )}
              </div>
            </div>
          )
        })}
      </div>

      {selectedWorkout && (
        <WorkoutDetailSheet
          workout={selectedWorkout}
          onClose={() => setSelectedWorkout(null)}
          onUpdate={handleUpdate}
        />
      )}
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
