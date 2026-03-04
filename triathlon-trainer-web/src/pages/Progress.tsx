import { useState } from 'react'
import { useLiveQuery } from 'dexie-react-hooks'
import { subWeeks, format, startOfWeek, addDays, parseISO } from 'date-fns'
import { BarChart, Bar, XAxis, YAxis, ResponsiveContainer, Cell } from 'recharts'
import { db } from '../store/db'
import { useAppStore } from '../store/useAppStore'
import { Card, SectionHeader } from '../components/ui/Card'
import { analyzeWeek } from '../services/adaptiveEngine'
import { formatDuration, sportIcon } from '../utils/helpers'

type Range = '2W' | '4W' | 'All'

export function Progress() {
  const [range, setRange] = useState<Range>('4W')
  const profile = useAppStore(s => s.profile)

  const cutoff = range === '2W' ? subWeeks(new Date(), 2)
    : range === '4W' ? subWeeks(new Date(), 4)
    : new Date(0)

  const cutoffStr = format(cutoff, 'yyyy-MM-dd')
  const allWorkouts = useLiveQuery(() => db.workouts.toArray()) ?? []
  const filtered = allWorkouts.filter(w => w.scheduledDate >= cutoffStr && w.result)
  const completed = filtered.filter(w => w.status === 'Completed' || w.status === 'Partial')

  const totalHours = completed.reduce((s, w) => s + w.result!.actualDuration / 3600, 0)
  const totalSessions = completed.length
  const totalScheduled = filtered.filter(w => w.sport !== 'Rest').length
  const compliance = totalScheduled ? Math.round(totalSessions / totalScheduled * 100) : 0

  const weeksToRace = profile
    ? Math.max(0, Math.ceil((new Date(profile.raceDate).getTime() - Date.now()) / (7 * 24 * 3600 * 1000)))
    : 0

  // Weekly volume chart
  const weeklyData = buildWeeklyData(completed, range)

  // Sport breakdown
  const sportBreakdown = ['Swim', 'Bike', 'Run'].map(sport => ({
    sport,
    hours: completed.filter(w => w.sport === sport).reduce((s, w) => s + w.result!.actualDuration / 3600, 0),
    sessions: completed.filter(w => w.sport === sport).length,
  })).filter(s => s.hours > 0)

  // Last week analysis
  const lastWeekStart = format(startOfWeek(subWeeks(new Date(), 1), { weekStartsOn: 1 }), 'yyyy-MM-dd')
  const lastWeekEnd   = format(addDays(startOfWeek(new Date(), { weekStartsOn: 1 }), -1), 'yyyy-MM-dd')
  const lastWeekWorkouts = allWorkouts.filter(w => w.scheduledDate >= lastWeekStart && w.scheduledDate <= lastWeekEnd)
  const lastWeekAnalysis = lastWeekWorkouts.length ? analyzeWeek(lastWeekWorkouts) : null

  return (
    <div className="pt-safe pb-20 min-h-screen bg-gray-50">
      <div className="p-4 space-y-4">
        <h1 className="text-2xl font-bold text-gray-900">Progress</h1>

        {/* Range selector */}
        <div className="flex bg-gray-100 rounded-xl p-1 gap-1">
          {(['2W', '4W', 'All'] as Range[]).map(r => (
            <button
              key={r}
              onClick={() => setRange(r)}
              className={`flex-1 py-2 rounded-lg text-sm font-medium transition-colors ${
                range === r ? 'bg-white text-gray-900 shadow-sm' : 'text-gray-500'
              }`}
            >
              {r}
            </button>
          ))}
        </div>

        {/* Summary stats */}
        <div className="grid grid-cols-2 gap-3">
          <Card>
            <p className="text-2xl font-bold text-blue-600">{totalHours.toFixed(1)}h</p>
            <p className="text-xs text-gray-400 mt-1">Total Hours</p>
          </Card>
          <Card>
            <p className="text-2xl font-bold text-green-600">{totalSessions}</p>
            <p className="text-xs text-gray-400 mt-1">Sessions Done</p>
          </Card>
          <Card>
            <p className={`text-2xl font-bold ${compliance >= 80 ? 'text-green-600' : compliance >= 60 ? 'text-orange-500' : 'text-red-500'}`}>
              {compliance}%
            </p>
            <p className="text-xs text-gray-400 mt-1">Compliance</p>
          </Card>
          <Card>
            <p className="text-2xl font-bold text-red-500">{weeksToRace}</p>
            <p className="text-xs text-gray-400 mt-1">Weeks to Race</p>
          </Card>
        </div>

        {/* Weekly volume chart */}
        {weeklyData.length > 0 && (
          <Card>
            <SectionHeader icon="📊" title="Weekly Volume (hours)" />
            <ResponsiveContainer width="100%" height={160}>
              <BarChart data={weeklyData} margin={{ top: 0, right: 0, bottom: 0, left: -20 }}>
                <XAxis dataKey="week" tick={{ fontSize: 10 }} />
                <YAxis tick={{ fontSize: 10 }} />
                <Bar dataKey="hours" radius={[4, 4, 0, 0]}>
                  {weeklyData.map((_, i) => (
                    <Cell key={i} fill="#3b82f6" fillOpacity={0.8} />
                  ))}
                </Bar>
              </BarChart>
            </ResponsiveContainer>
          </Card>
        )}

        {/* Sport breakdown */}
        {sportBreakdown.length > 0 && (
          <Card>
            <SectionHeader icon="🏅" title="Sport Breakdown" />
            <div className="space-y-3">
              {sportBreakdown.map(({ sport, hours, sessions }) => {
                const maxH = Math.max(...sportBreakdown.map(s => s.hours))
                return (
                  <div key={sport} className="flex items-center gap-3">
                    <span className="text-xl w-7">{sportIcon(sport)}</span>
                    <div className="flex-1">
                      <div className="flex justify-between text-sm mb-1">
                        <span className="font-medium text-gray-700">{sport}</span>
                        <span className="text-gray-400">{hours.toFixed(1)}h · {sessions} sessions</span>
                      </div>
                      <div className="h-2 bg-gray-100 rounded-full overflow-hidden">
                        <div
                          className="h-full rounded-full"
                          style={{
                            width: `${maxH > 0 ? (hours / maxH * 100) : 0}%`,
                            backgroundColor: sportColor(sport),
                          }}
                        />
                      </div>
                    </div>
                  </div>
                )
              })}
            </div>
          </Card>
        )}

        {/* Last week analysis */}
        {lastWeekAnalysis && (
          <Card>
            <SectionHeader icon="🧠" title="Last Week's Analysis" />
            <div className="flex justify-between mb-3">
              <div>
                <p className="text-2xl font-bold" style={{ color: complianceColor(lastWeekAnalysis.complianceRate) }}>
                  {Math.round(lastWeekAnalysis.complianceRate * 100)}%
                </p>
                <p className="text-xs text-gray-400">Compliance</p>
              </div>
              <div className="text-center">
                <p className="text-2xl font-bold text-gray-800">
                  {lastWeekAnalysis.actualHours.toFixed(1)}<span className="text-sm text-gray-400">/{lastWeekAnalysis.plannedHours.toFixed(1)}h</span>
                </p>
                <p className="text-xs text-gray-400">Hours</p>
              </div>
              <div className="text-right">
                <p className="text-2xl font-bold text-gray-800">{lastWeekAnalysis.avgRPE.toFixed(1)}</p>
                <p className="text-xs text-gray-400">Avg RPE</p>
              </div>
            </div>
            {lastWeekAnalysis.recommendations.length > 0 && (
              <div className="space-y-2">
                {lastWeekAnalysis.recommendations.map((rec, i) => (
                  <p key={i} className="text-sm text-gray-600 bg-blue-50 rounded-xl p-3">
                    → {rec}
                  </p>
                ))}
              </div>
            )}
          </Card>
        )}

        {/* Recent sessions */}
        {completed.length > 0 && (
          <Card>
            <SectionHeader icon="📋" title="Recent Sessions" />
            <div className="space-y-2">
              {[...completed].sort((a, b) => b.scheduledDate.localeCompare(a.scheduledDate)).slice(0, 10).map(w => (
                <div key={w.id} className="flex items-center gap-3 py-1">
                  <span className="text-lg">{sportIcon(w.sport)}</span>
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-medium truncate">{w.title}</p>
                    <p className="text-xs text-gray-400">
                      {format(parseISO(w.scheduledDate), 'EEE d MMM')}
                    </p>
                  </div>
                  {w.result && (
                    <div className="text-right">
                      <p className="text-xs text-gray-400">RPE {w.result.perceivedEffort}</p>
                      <p className={`text-xs font-semibold ${w.result.complianceScore >= 0.8 ? 'text-green-600' : 'text-orange-500'}`}>
                        {Math.round(w.result.complianceScore * 100)}%
                      </p>
                    </div>
                  )}
                </div>
              ))}
            </div>
          </Card>
        )}

        {completed.length === 0 && (
          <Card className="text-center py-8">
            <p className="text-4xl mb-3">🏊🚴🏃</p>
            <p className="font-semibold text-gray-700">No logged sessions yet</p>
            <p className="text-sm text-gray-400 mt-1">Complete your first workout to see progress here</p>
          </Card>
        )}
      </div>
    </div>
  )
}

function buildWeeklyData(workouts: any[], range: Range) {
  const weeks = range === '2W' ? 2 : range === '4W' ? 4 : 8
  return Array.from({ length: weeks }, (_, i) => {
    const wStart = startOfWeek(subWeeks(new Date(), weeks - 1 - i), { weekStartsOn: 1 })
    const wEnd = addDays(wStart, 7)
    const wStartStr = format(wStart, 'yyyy-MM-dd')
    const wEndStr   = format(wEnd,   'yyyy-MM-dd')
    const hours = workouts
      .filter(w => w.scheduledDate >= wStartStr && w.scheduledDate < wEndStr)
      .reduce((s: number, w: any) => s + w.result!.actualDuration / 3600, 0)
    return { week: format(wStart, 'M/d'), hours: Math.round(hours * 10) / 10 }
  })
}

function complianceColor(rate: number): string {
  if (rate >= 0.85) return '#22c55e'
  if (rate >= 0.65) return '#f97316'
  return '#ef4444'
}

function sportColor(sport: string): string {
  switch (sport) {
    case 'Swim': return '#3b82f6'
    case 'Bike': return '#f97316'
    case 'Run':  return '#22c55e'
    default: return '#9ca3af'
  }
}
