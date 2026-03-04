import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useAppStore } from '../store/useAppStore'
import { db } from '../store/db'
import { Card, SectionHeader } from '../components/ui/Card'
import { isAuthenticated, getAthleteName, getAuthUrl, disconnect } from '../services/stravaService'
import { format, parseISO } from 'date-fns'

export function Settings() {
  const profile = useAppStore(s => s.profile)
  const clearProfile = useAppStore(s => s.clearProfile)
  const navigate = useNavigate()
  const [showResetConfirm, setShowResetConfirm] = useState(false)
  const stravaAuthed = isAuthenticated()
  const stravaName = getAthleteName()

  async function handleReset() {
    await db.workouts.clear()
    await db.plans.clear()
    await db.athletes.clear()
    clearProfile()
    disconnect()
    navigate('/onboarding')
  }

  if (!profile) return null

  const weeksToRace = Math.max(0, Math.ceil((new Date(profile.raceDate).getTime() - Date.now()) / (7 * 24 * 3600 * 1000)))

  return (
    <div className="pt-safe pb-20 min-h-screen bg-gray-50">
      <div className="p-4 space-y-4">
        <h1 className="text-2xl font-bold text-gray-900">Settings</h1>

        {/* Athlete */}
        <Card>
          <SectionHeader icon="👤" title="Athlete" />
          <div className="space-y-3">
            <Row label="Name" value={profile.name} />
            <Row label="Race" value={profile.raceDistance} />
            <Row label="Race Date" value={format(parseISO(profile.raceDate), 'd MMM yyyy')} />
            <Row label="Weeks to Race" value={String(weeksToRace)} />
            <Row label="Experience" value={profile.experienceLevel} />
            <Row label="Weekly Hours" value={`${profile.weeklyAvailableHours}h target`} />
          </div>
        </Card>

        {/* Calendar */}
        <Card>
          <SectionHeader icon="📅" title="Apple Calendar" />
          <p className="text-sm text-gray-600 mb-3">
            On any workout, tap <strong>"Add to Calendar"</strong> to export it directly to Apple Calendar. The session includes your warm-up, main set, cool-down, and coaching tips in the event notes.
          </p>
          <p className="text-sm text-gray-400">
            You can also export an entire week at once from the Week view.
          </p>
        </Card>

        {/* Strava */}
        <Card>
          <SectionHeader icon="🟠" title="Strava" />
          {stravaAuthed ? (
            <div className="space-y-3">
              <div className="flex items-center justify-between">
                <div>
                  <p className="font-medium text-green-600">✅ Connected</p>
                  {stravaName && <p className="text-sm text-gray-500">{stravaName}</p>}
                </div>
                <button
                  onClick={() => { disconnect(); window.location.reload() }}
                  className="text-sm text-red-500 border border-red-200 px-3 py-1.5 rounded-lg"
                >
                  Disconnect
                </button>
              </div>
              <p className="text-xs text-gray-400">Activities are matched to planned workouts by date and duration.</p>
            </div>
          ) : (
            <div className="space-y-3">
              <p className="text-sm text-gray-600">Connect Strava to auto-import completed run, ride and swim activities.</p>
              <a
                href={getAuthUrl()}
                className="block w-full py-3 bg-orange-500 text-white text-center rounded-xl font-semibold"
              >
                Connect with Strava
              </a>
              <p className="text-xs text-gray-400 text-center">Read-only access. We never post on your behalf.</p>
            </div>
          )}
        </Card>

        {/* Weather */}
        <Card>
          <SectionHeader icon="🌤️" title="Weather" />
          <p className="text-sm text-gray-600">
            Weather forecasts use your device's location to assess each session. No API key needed — just allow location access when prompted.
          </p>
          {!import.meta.env.VITE_OPENWEATHER_API_KEY && (
            <div className="mt-3 bg-yellow-50 rounded-xl p-3">
              <p className="text-xs text-yellow-700">
                <strong>Setup needed:</strong> Add your free OpenWeatherMap API key as <code>VITE_OPENWEATHER_API_KEY</code> in your <code>.env</code> file.{' '}
                Get one free at openweathermap.org
              </p>
            </div>
          )}
        </Card>

        {/* About */}
        <Card>
          <SectionHeader icon="ℹ️" title="About" />
          <div className="space-y-2">
            <Row label="App" value="TriTrainer v1.0" />
            <Row label="Data" value="Stored locally on your device" />
            <Row label="Sync" value="No account required" />
          </div>
          <div className="mt-3 bg-blue-50 rounded-xl p-3">
            <p className="text-xs text-blue-700">
              <strong>Add to Home Screen:</strong> In Safari, tap the Share button then "Add to Home Screen" to install the app on your iPhone.
            </p>
          </div>
        </Card>

        {/* Reset */}
        <Card className="border-red-100">
          <SectionHeader icon="⚠️" title="Danger Zone" color="text-red-500" />
          <button
            onClick={() => setShowResetConfirm(true)}
            className="w-full py-3 text-red-500 border border-red-200 rounded-xl font-medium"
          >
            Reset All Training Data
          </button>
        </Card>
      </div>

      {showResetConfirm && (
        <div className="fixed inset-0 z-50 bg-black/50 flex items-end">
          <div className="bg-white w-full rounded-t-3xl p-6">
            <h3 className="text-lg font-bold mb-2">Reset everything?</h3>
            <p className="text-gray-500 text-sm mb-6">
              This deletes your training plan, all workouts, and all logged results. This cannot be undone.
            </p>
            <button onClick={handleReset} className="w-full py-3 bg-red-500 text-white rounded-xl font-semibold mb-3">
              Yes, reset everything
            </button>
            <button onClick={() => setShowResetConfirm(false)} className="w-full py-3 text-gray-500">
              Cancel
            </button>
          </div>
        </div>
      )}
    </div>
  )
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex justify-between">
      <span className="text-sm text-gray-500">{label}</span>
      <span className="text-sm font-medium text-gray-800">{value}</span>
    </div>
  )
}
