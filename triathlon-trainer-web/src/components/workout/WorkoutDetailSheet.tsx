import { useState } from 'react'
import type { Workout, WeatherAssessment } from '../../types'
import { formatDuration, formatDistance, zoneColor, sportIcon } from '../../utils/helpers'
import { workoutToICS, openICSInCalendar } from '../../services/calendarService'
import { getIndoorAlternative } from '../../services/weatherService'
import { LogWorkoutSheet } from './LogWorkoutSheet'

interface Props {
  workout: Workout
  weather?: WeatherAssessment
  onClose: () => void
  onUpdate: (id: string, updates: Partial<Workout>) => void
}

type Tab = 'overview' | 'session' | 'coaching' | 'technique'

export function WorkoutDetailSheet({ workout, weather, onClose, onUpdate }: Props) {
  const [tab, setTab] = useState<Tab>('overview')
  const [showLog, setShowLog] = useState(false)
  const [showSkipConfirm, setShowSkipConfirm] = useState(false)

  const isActionable = workout.status === 'Scheduled' || workout.status === 'Rescheduled'
  const indoorAlt = weather?.indoorRecommended ? getIndoorAlternative(workout.sport) : workout.indoorAlternative

  function handleAddToCalendar() {
    openICSInCalendar(workoutToICS(workout))
  }

  function handleSkip() {
    onUpdate(workout.id, { status: 'Skipped', result: undefined })
    onClose()
  }

  return (
    <>
      <div className="fixed inset-0 z-50 flex flex-col bg-white">
        {/* Sport header */}
        <div
          className="relative flex-shrink-0 pt-safe"
          style={{ background: `linear-gradient(135deg, ${sportColor(workout.sport)}cc, ${sportColor(workout.sport)}88)` }}
        >
          <div className="flex items-center justify-between p-4">
            <button onClick={onClose} className="text-white text-2xl w-8 h-8 flex items-center justify-center">←</button>
            <button
              onClick={handleAddToCalendar}
              className="text-white text-sm bg-white/20 px-3 py-1 rounded-full"
            >
              📅 Add to Calendar
            </button>
          </div>

          <div className="px-4 pb-5 text-white text-center">
            <div className="text-4xl mb-2">{sportIcon(workout.sport)}</div>
            <h1 className="text-xl font-bold">{workout.title}</h1>
            <div className="flex items-center justify-center gap-4 mt-2 text-sm text-white/80">
              <span>⏱ {formatDuration(workout.plannedDurationSec)}</span>
              {workout.plannedDistanceKm && <span>📏 {formatDistance(workout.plannedDistanceKm)}</span>}
              <span>💪 {workout.intensity}</span>
            </div>
          </div>

          {/* Weather alert */}
          {weather && weather.warnings.length > 0 && (
            <div className={`mx-4 mb-4 px-3 py-2 rounded-xl text-sm ${
              weather.riskLevel === 'extreme' ? 'bg-red-500/90 text-white' : 'bg-orange-400/90 text-white'
            }`}>
              <span className="font-medium">{weather.warnings[0].icon} </span>
              {weather.summary}
            </div>
          )}
        </div>

        {/* Tab bar */}
        <div className="flex border-b border-gray-100 bg-white flex-shrink-0 overflow-x-auto">
          {(['overview', 'session', 'coaching', 'technique'] as Tab[]).map(t => (
            <button
              key={t}
              onClick={() => setTab(t)}
              className={`flex-1 py-3 text-sm font-medium capitalize whitespace-nowrap px-2 transition-colors border-b-2 ${
                tab === t ? 'text-blue-600 border-blue-600' : 'text-gray-400 border-transparent'
              }`}
            >
              {t}
            </button>
          ))}
        </div>

        {/* Content */}
        <div className="flex-1 overflow-y-auto pb-32">
          <div className="p-4 space-y-4">
            {tab === 'overview' && <OverviewTab workout={workout} weather={weather} indoorAlt={indoorAlt} />}
            {tab === 'session' && <SessionTab workout={workout} />}
            {tab === 'coaching' && <CoachingTab workout={workout} />}
            {tab === 'technique' && <TechniqueTab workout={workout} />}
          </div>
        </div>

        {/* Action bar */}
        {isActionable && (
          <div className="fixed bottom-0 left-0 right-0 bg-white border-t border-gray-100 p-4 pb-safe flex gap-3">
            <button
              onClick={() => setShowSkipConfirm(true)}
              className="flex-1 py-3 rounded-xl border-2 border-red-200 text-red-500 font-semibold"
            >
              Skip
            </button>
            <button
              onClick={() => setShowLog(true)}
              className="flex-2 py-3 px-6 rounded-xl font-semibold text-white flex-grow"
              style={{ background: sportColor(workout.sport) }}
            >
              ✓ Log Workout
            </button>
          </div>
        )}

        {workout.result && (
          <div className="fixed bottom-0 left-0 right-0 bg-white border-t border-gray-100 p-4 pb-safe">
            <div className="bg-green-50 rounded-xl p-3 flex items-center gap-3">
              <span className="text-2xl">✅</span>
              <div>
                <p className="font-semibold text-green-700">Completed</p>
                <p className="text-sm text-green-600">
                  {formatDuration(workout.result.actualDuration)} · RPE {workout.result.perceivedEffort}/10 · {Math.round(workout.result.complianceScore * 100)}% compliance
                </p>
              </div>
            </div>
          </div>
        )}
      </div>

      {showLog && (
        <LogWorkoutSheet
          workout={workout}
          onClose={() => setShowLog(false)}
          onSave={(result) => {
            onUpdate(workout.id, {
              result,
              status: result.actualDuration < workout.plannedDurationSec * 0.5 ? 'Partial' : 'Completed'
            })
            setShowLog(false)
            onClose()
          }}
        />
      )}

      {showSkipConfirm && (
        <div className="fixed inset-0 z-[60] bg-black/50 flex items-end">
          <div className="bg-white w-full rounded-t-3xl p-6">
            <h3 className="text-lg font-bold mb-2">Skip this workout?</h3>
            <p className="text-gray-500 text-sm mb-6">Skipped workouts are tracked and the plan adapts accordingly. Missing one session is fine — consistency over perfection.</p>
            <button onClick={handleSkip} className="w-full py-3 bg-red-500 text-white rounded-xl font-semibold mb-3">
              Skip — I'll miss this one
            </button>
            <button onClick={() => setShowSkipConfirm(false)} className="w-full py-3 text-gray-500">
              Cancel
            </button>
          </div>
        </div>
      )}
    </>
  )
}

// ─── Overview Tab ─────────────────────────────────────────────────────────

function OverviewTab({ workout, weather, indoorAlt }: { workout: Workout; weather?: WeatherAssessment; indoorAlt?: { instructions: string; equipment: string[] } | null }) {
  return (
    <>
      <InfoSection title="🎯 Session Goal">
        <p className="text-gray-700">{workout.goal}</p>
      </InfoSection>

      {workout.zones.length > 0 && (
        <InfoSection title="📊 Training Zones">
          <div className="space-y-2">
            {workout.zones.map((block, i) => (
              <div key={i} className="flex items-center gap-3">
                <div
                  className="w-3 h-3 rounded-full flex-shrink-0"
                  style={{ backgroundColor: zoneColor(block.zone) }}
                />
                <span className="text-sm font-medium w-14">Zone {block.zone}</span>
                <span className="text-sm text-gray-500 flex-1">{block.description}</span>
                <span className="text-sm text-gray-400">{formatDuration(block.durationSeconds)}</span>
              </div>
            ))}
          </div>
        </InfoSection>
      )}

      <InfoSection title={`📅 ${workout.phase} Phase`}>
        <p className="text-sm text-gray-500">{phaseDesc(workout.phase)}</p>
      </InfoSection>

      {weather && weather.warnings.length > 0 && (
        <InfoSection title="🌤️ Weather Check">
          <p className="text-sm mb-3">{weather.summary}</p>
          {weather.warnings.map((w, i) => (
            <div key={i} className="flex items-start gap-2 text-sm text-gray-600 mb-1">
              <span>{w.icon}</span>
              <span>{w.message}</span>
            </div>
          ))}
          {weather.intensityAdjustment && (
            <p className="text-sm font-medium text-orange-600 mt-2">⚠️ {weather.intensityAdjustment}</p>
          )}
        </InfoSection>
      )}

      {indoorAlt && weather?.indoorRecommended && (
        <InfoSection title="🏠 Indoor Alternative">
          <p className="text-sm text-gray-700 mb-3">{indoorAlt.instructions}</p>
          {indoorAlt.equipment.length > 0 && (
            <div className="flex flex-wrap gap-2">
              {indoorAlt.equipment.map((e, i) => (
                <span key={i} className="text-xs bg-gray-100 text-gray-600 px-2 py-1 rounded-full">{e}</span>
              ))}
            </div>
          )}
        </InfoSection>
      )}
    </>
  )
}

// ─── Session Tab ──────────────────────────────────────────────────────────

function SessionTab({ workout }: { workout: Workout }) {
  return (
    <>
      <InfoSection title="🔥 Warm-Up">
        <p className="text-sm text-gray-700 whitespace-pre-line">{workout.warmup}</p>
      </InfoSection>
      <InfoSection title="⚡ Main Set">
        <p className="text-sm text-gray-700 whitespace-pre-line">{workout.mainSet}</p>
      </InfoSection>
      <InfoSection title="❄️ Cool-Down">
        <p className="text-sm text-gray-700 whitespace-pre-line">{workout.cooldown}</p>
      </InfoSection>
      <InfoSection title="✅ After This Session">
        <p className="text-sm text-gray-500">{workout.postWorkoutGuidance}</p>
      </InfoSection>
    </>
  )
}

// ─── Coaching Tab ─────────────────────────────────────────────────────────

function CoachingTab({ workout }: { workout: Workout }) {
  const order: Array<{ key: string; icon: string; label: string }> = [
    { key: 'Before', icon: '📋', label: 'Before You Start' },
    { key: 'Nutrition', icon: '🍌', label: 'Nutrition' },
    { key: 'Warm-up', icon: '🔥', label: 'Warm-Up Tips' },
    { key: 'Main Set', icon: '⚡', label: 'Main Set Tips' },
    { key: 'Cool-down', icon: '❄️', label: 'Cool-Down' },
    { key: 'After', icon: '🔄', label: 'After the Session' },
  ]

  const grouped = workout.tips.reduce((acc, tip) => {
    ;(acc[tip.timing] = acc[tip.timing] || []).push(tip)
    return acc
  }, {} as Record<string, typeof workout.tips>)

  return (
    <>
      {order.map(({ key, icon, label }) =>
        grouped[key]?.length ? (
          <InfoSection key={key} title={`${icon} ${label}`}>
            <div className="space-y-3">
              {grouped[key].map(tip => (
                <div key={tip.id} className="bg-blue-50 rounded-xl p-3">
                  <p className="font-semibold text-sm text-gray-900 mb-1">💡 {tip.title}</p>
                  <p className="text-sm text-gray-600">{tip.detail}</p>
                </div>
              ))}
            </div>
          </InfoSection>
        ) : null
      )}
    </>
  )
}

// ─── Technique Tab ────────────────────────────────────────────────────────

function TechniqueTab({ workout }: { workout: Workout }) {
  const [expanded, setExpanded] = useState<string | null>(null)

  if (!workout.techniqueCues.length) {
    return <p className="text-center text-gray-400 py-8">No specific technique cues for this session.</p>
  }

  return (
    <div className="space-y-3">
      {workout.techniqueCues.map(cue => (
        <div key={cue.id} className="bg-white rounded-2xl border border-gray-100 shadow-sm overflow-hidden">
          <button
            onClick={() => setExpanded(expanded === cue.id ? null : cue.id)}
            className="w-full text-left p-4"
          >
            <div className="flex items-start gap-3">
              <span className="text-xl mt-0.5">{sportIcon(cue.sport)}</span>
              <div className="flex-1">
                <p className="font-medium text-sm text-gray-900">{cue.cue}</p>
                {cue.commonMistake && (
                  <p className="text-xs text-red-500 mt-1">⚠️ Common mistake: {cue.commonMistake}</p>
                )}
              </div>
              <span className="text-gray-400 ml-2">{expanded === cue.id ? '▲' : '▼'}</span>
            </div>
          </button>

          {expanded === cue.id && cue.drillName && (
            <div className="px-4 pb-4">
              <div className="bg-blue-50 rounded-xl p-3">
                <p className="font-semibold text-sm text-blue-700 mb-1">🏋️ Drill: {cue.drillName}</p>
                {cue.drillDescription && (
                  <p className="text-sm text-gray-600">{cue.drillDescription}</p>
                )}
              </div>
            </div>
          )}
        </div>
      ))}
    </div>
  )
}

// ─── Helpers ──────────────────────────────────────────────────────────────

function InfoSection({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-4">
      <h3 className="font-semibold text-sm text-gray-700 mb-3">{title}</h3>
      {children}
    </div>
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

function phaseDesc(phase: string): string {
  switch (phase) {
    case 'Base': return 'Building aerobic foundation and technique'
    case 'Build': return 'Increasing intensity and race-specific fitness'
    case 'Peak': return 'Highest training load, race simulation'
    case 'Taper': return 'Reducing volume, maintaining sharpness'
    default: return 'Race preparation'
  }
}
