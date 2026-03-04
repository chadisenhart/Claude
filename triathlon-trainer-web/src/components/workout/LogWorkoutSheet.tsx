import { useState } from 'react'
import type { Workout, WorkoutResult } from '../../types'
import { formatDuration } from '../../utils/helpers'
import { calcComplianceScore } from '../../services/adaptiveEngine'

interface Props {
  workout: Workout
  onClose: () => void
  onSave: (result: WorkoutResult) => void
}

const RPE_LABELS: Record<number, string> = {
  1: 'Very Easy', 2: 'Very Easy', 3: 'Easy', 4: 'Easy',
  5: 'Moderate', 6: 'Moderate', 7: 'Hard', 8: 'Hard',
  9: 'Very Hard', 10: 'Max Effort'
}

export function LogWorkoutSheet({ workout, onClose, onSave }: Props) {
  const plannedMin = Math.floor(workout.plannedDurationSec / 60)
  const [hours, setHours] = useState(Math.floor(plannedMin / 60))
  const [minutes, setMinutes] = useState(plannedMin % 60)
  const [rpe, setRpe] = useState(6)
  const [notes, setNotes] = useState('')
  const [completed, setCompleted] = useState(true)

  const actualSec = (hours * 60 + minutes) * 60

  function handleSave() {
    const result: WorkoutResult = {
      completedAt: new Date().toISOString(),
      actualDuration: actualSec,
      perceivedEffort: rpe,
      notes,
      complianceScore: calcComplianceScore({ ...workout, result: { completedAt: '', actualDuration: actualSec, perceivedEffort: rpe, notes, complianceScore: 0 } }),
    }
    onSave(result)
  }

  return (
    <div className="fixed inset-0 z-[60] flex flex-col bg-white">
      {/* Header */}
      <div className="flex items-center justify-between p-4 border-b border-gray-100 pt-safe">
        <button onClick={onClose} className="text-gray-400 text-lg">✕</button>
        <h2 className="font-bold text-gray-900">Log Session</h2>
        <button onClick={handleSave} className="text-blue-600 font-bold">Save</button>
      </div>

      <div className="flex-1 overflow-y-auto pb-8">
        {/* How did it go */}
        <section className="p-4 border-b border-gray-50">
          <p className="text-xs font-semibold text-gray-400 uppercase tracking-wide mb-3">How did it go?</p>
          <div className="flex gap-3">
            {[true, false].map(val => (
              <button
                key={String(val)}
                onClick={() => setCompleted(val)}
                className={`flex-1 py-2.5 rounded-xl font-medium text-sm transition-colors ${
                  completed === val ? 'bg-blue-600 text-white' : 'bg-gray-100 text-gray-600'
                }`}
              >
                {val ? '✅ Completed' : '⚡ Partially'}
              </button>
            ))}
          </div>
        </section>

        {/* Duration */}
        <section className="p-4 border-b border-gray-50">
          <p className="text-xs font-semibold text-gray-400 uppercase tracking-wide mb-3">
            Duration <span className="text-gray-300 ml-1 normal-case font-normal">(planned: {formatDuration(workout.plannedDurationSec)})</span>
          </p>
          <div className="flex gap-4 justify-center">
            <div className="text-center">
              <select
                value={hours}
                onChange={e => setHours(Number(e.target.value))}
                className="text-3xl font-bold text-center bg-gray-50 rounded-xl p-3 w-20 border-none outline-none"
              >
                {Array.from({ length: 7 }, (_, i) => (
                  <option key={i} value={i}>{i}h</option>
                ))}
              </select>
            </div>
            <div className="text-center">
              <select
                value={minutes}
                onChange={e => setMinutes(Number(e.target.value))}
                className="text-3xl font-bold text-center bg-gray-50 rounded-xl p-3 w-20 border-none outline-none"
              >
                {[0,5,10,15,20,25,30,35,40,45,50,55].map(m => (
                  <option key={m} value={m}>{m}m</option>
                ))}
              </select>
            </div>
          </div>
        </section>

        {/* RPE */}
        <section className="p-4 border-b border-gray-50">
          <p className="text-xs font-semibold text-gray-400 uppercase tracking-wide mb-3">
            Perceived Effort (RPE)
          </p>
          <div className="text-center mb-4">
            <span className="text-4xl font-bold" style={{ color: rpeColor(rpe) }}>{rpe}</span>
            <span className="text-gray-400 text-lg">/10</span>
            <p className="text-sm text-gray-500 mt-1">{RPE_LABELS[rpe]}</p>
          </div>
          <input
            type="range"
            min={1}
            max={10}
            value={rpe}
            onChange={e => setRpe(Number(e.target.value))}
            className="w-full accent-blue-600"
          />
          <div className="flex justify-between text-xs text-gray-400 mt-1">
            <span>Very Easy</span>
            <span>Max</span>
          </div>
          <p className="text-xs text-gray-400 mt-2 text-center">
            Target effort: RPE {targetRPE(workout.intensity)}
          </p>
        </section>

        {/* Notes */}
        <section className="p-4">
          <p className="text-xs font-semibold text-gray-400 uppercase tracking-wide mb-3">Notes (optional)</p>
          <textarea
            value={notes}
            onChange={e => setNotes(e.target.value)}
            placeholder="How did you feel? Any issues? Things that went well?"
            className="w-full bg-gray-50 rounded-xl p-3 text-sm text-gray-700 resize-none outline-none min-h-[80px]"
          />
        </section>

        {/* Post guidance */}
        <section className="px-4 pb-4">
          <div className="bg-blue-50 rounded-xl p-4">
            <p className="text-xs font-semibold text-blue-600 mb-1">Coach's Note</p>
            <p className="text-sm text-gray-600">{workout.postWorkoutGuidance}</p>
          </div>
        </section>
      </div>
    </div>
  )
}

function rpeColor(rpe: number): string {
  if (rpe <= 3) return '#22c55e'
  if (rpe <= 5) return '#eab308'
  if (rpe <= 7) return '#f97316'
  return '#ef4444'
}

function targetRPE(intensity: string): string {
  switch (intensity) {
    case 'Recovery': return '1–2'
    case 'Easy': return '3–5'
    case 'Moderate': return '5–6'
    case 'Threshold': return '7–8'
    case 'VO2 Max': return '8–9'
    case 'Sprint': return '9–10'
    default: return '5–6'
  }
}
