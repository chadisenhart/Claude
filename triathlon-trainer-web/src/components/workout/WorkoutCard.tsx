import type { Workout } from '../../types'
import { formatDuration, formatDistance, sportBg, sportIcon, statusIcon } from '../../utils/helpers'

interface WorkoutCardProps {
  workout: Workout
  onClick: () => void
  compact?: boolean
}

export function WorkoutCard({ workout, onClick, compact = false }: WorkoutCardProps) {
  const isRest = workout.sport === 'Rest'

  if (isRest) {
    return (
      <div className="bg-gray-50 rounded-xl p-3 flex items-center gap-3 text-gray-400">
        <span className="text-2xl">😴</span>
        <div>
          <p className="font-medium text-gray-500">Rest Day</p>
          <p className="text-xs">Recovery is training</p>
        </div>
      </div>
    )
  }

  return (
    <button
      onClick={onClick}
      className="w-full text-left bg-white rounded-2xl border border-gray-100 shadow-sm overflow-hidden active:scale-98 transition-transform"
    >
      {/* Sport bar */}
      <div
        className="h-1.5 w-full"
        style={{ backgroundColor: sportColor(workout.sport) }}
      />

      <div className="p-4">
        <div className="flex items-start justify-between gap-2">
          <div className="flex items-center gap-3">
            <div
              className="w-10 h-10 rounded-full flex items-center justify-center text-xl flex-shrink-0"
              style={{ backgroundColor: sportColor(workout.sport) + '20' }}
            >
              {sportIcon(workout.sport)}
            </div>
            <div>
              <p className="font-semibold text-gray-900 leading-tight">{workout.title}</p>
              <div className="flex items-center gap-2 mt-0.5">
                <span className={`text-xs px-1.5 py-0.5 rounded-full font-medium ${sportBg(workout.sport)}`}>
                  {workout.sport}
                </span>
                <span className="text-xs text-gray-400">{formatDuration(workout.plannedDurationSec)}</span>
                {workout.plannedDistanceKm && (
                  <span className="text-xs text-gray-400">{formatDistance(workout.plannedDistanceKm)}</span>
                )}
              </div>
            </div>
          </div>

          <div className="flex flex-col items-end gap-1">
            <span className="text-lg">{statusIcon(workout.status)}</span>
            {workout.result && (
              <span className="text-xs text-gray-400">RPE {workout.result.perceivedEffort}</span>
            )}
          </div>
        </div>

        {!compact && (
          <p className="mt-3 text-sm text-gray-500 leading-snug line-clamp-2">
            {workout.goal}
          </p>
        )}

        {!compact && workout.status === 'Scheduled' && (
          <div className="mt-3 flex items-center justify-between">
            <span className="text-xs text-blue-500 font-medium">{workout.phase} · Week {workout.weekNumber}</span>
            <span className="text-xs text-gray-400">Tap for full session →</span>
          </div>
        )}
      </div>
    </button>
  )
}

function sportColor(sport: string): string {
  switch (sport) {
    case 'Swim': return '#3b82f6'
    case 'Bike': return '#f97316'
    case 'Run':  return '#22c55e'
    case 'Brick': return '#a855f7'
    default: return '#9ca3af'
  }
}
