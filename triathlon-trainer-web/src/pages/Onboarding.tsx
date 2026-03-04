import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { v4 as uuid } from 'uuid'
import { format, differenceInWeeks } from 'date-fns'
import { db } from '../store/db'
import { useAppStore } from '../store/useAppStore'
import { generatePlan } from '../utils/planGenerator'
import type { AthleteProfile, RaceDistance, ExperienceLevel } from '../types'
import { RACE_DISTANCES } from '../types'

type Step = 'welcome' | 'name' | 'race' | 'schedule' | 'generating'

const DAY_NAMES = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']

export function Onboarding() {
  const navigate = useNavigate()
  const setProfile = useAppStore(s => s.setProfile)

  const [step, setStep] = useState<Step>('welcome')
  const [name, setName] = useState('')
  const [raceDistance, setRaceDistance] = useState<RaceDistance>('Olympic')
  const [raceDate, setRaceDate] = useState(() => {
    const d = new Date()
    d.setMonth(d.getMonth() + 6)
    return format(d, 'yyyy-MM-dd')
  })
  const [experience, setExperience] = useState<ExperienceLevel>('Beginner')
  const [selectedDays, setSelectedDays] = useState<number[]>([0, 1, 2, 4, 5]) // Mon–Wed, Fri–Sat
  const [weeklyHours, setWeeklyHours] = useState(8)

  const weeksToRace = differenceInWeeks(new Date(raceDate), new Date())
  const recommended = RACE_DISTANCES[raceDistance].totalWeeks

  function toggleDay(d: number) {
    setSelectedDays(prev =>
      prev.includes(d) ? prev.filter(x => x !== d) : [...prev, d]
    )
  }

  async function generate() {
    setStep('generating')
    const profile: AthleteProfile = {
      id: uuid(),
      name: name.trim(),
      raceDate,
      raceDistance,
      experienceLevel: experience,
      weeklyAvailableHours: weeklyHours,
      preferredDays: selectedDays.sort(),
      createdAt: new Date().toISOString(),
    }

    await db.athletes.put(profile)
    const workouts = generatePlan(profile)
    await db.workouts.bulkPut(workouts)
    setProfile(profile)
    navigate('/')
  }

  return (
    <div className="min-h-screen bg-white flex flex-col">
      {/* Progress dots */}
      {step !== 'welcome' && step !== 'generating' && (
        <div className="flex justify-center gap-2 pt-safe pt-4">
          {['name', 'race', 'schedule'].map((s, i) => (
            <div key={i} className={`w-2 h-2 rounded-full transition-colors ${
              ['name', 'race', 'schedule'].indexOf(step) >= i ? 'bg-blue-600' : 'bg-gray-200'
            }`} />
          ))}
        </div>
      )}

      <div className="flex-1 flex flex-col px-6 py-8">

        {/* ── Welcome ── */}
        {step === 'welcome' && (
          <div className="flex flex-col items-center justify-center flex-1 text-center">
            <div className="text-7xl mb-6">🏊🚴🏃</div>
            <h1 className="text-3xl font-bold text-gray-900 mb-2">TriTrainer</h1>
            <p className="text-gray-500 mb-8">Your adaptive triathlon coach</p>

            <div className="text-left space-y-4 mb-10 w-full max-w-xs">
              {[
                ['🧠', 'Adapts to You', 'Plan updates based on what you actually do'],
                ['📅', 'Calendar Smart', 'Exports sessions to Apple Calendar with one tap'],
                ['🌤️', 'Weather Aware', 'Indoor alternatives when it\'s unsafe outside'],
                ['💡', 'Full Coaching', 'Technique, drills, and tips on every session'],
              ].map(([icon, title, desc]) => (
                <div key={title} className="flex items-start gap-3">
                  <span className="text-2xl">{icon}</span>
                  <div>
                    <p className="font-semibold text-gray-900">{title}</p>
                    <p className="text-sm text-gray-500">{desc}</p>
                  </div>
                </div>
              ))}
            </div>

            <button
              onClick={() => setStep('name')}
              className="w-full max-w-xs py-4 bg-blue-600 text-white rounded-2xl font-bold text-lg shadow-lg shadow-blue-200"
            >
              Get Started
            </button>
          </div>
        )}

        {/* ── Name & Level ── */}
        {step === 'name' && (
          <div className="flex flex-col flex-1">
            <h2 className="text-2xl font-bold text-gray-900 mb-1">About You</h2>
            <p className="text-gray-500 mb-6">We'll personalise your training plan</p>

            <label className="block mb-4">
              <span className="text-sm font-semibold text-gray-700 mb-2 block">Your name</span>
              <input
                type="text"
                value={name}
                onChange={e => setName(e.target.value)}
                placeholder="First name"
                className="w-full border border-gray-200 rounded-xl px-4 py-3 text-lg outline-none focus:border-blue-400"
                autoFocus
              />
            </label>

            <label className="block mb-6">
              <span className="text-sm font-semibold text-gray-700 mb-2 block">Experience level</span>
              <div className="space-y-2">
                {([
                  ['Beginner', 'New to triathlon or structured training'],
                  ['Intermediate', '1–2 years training, completed a sprint/olympic'],
                  ['Advanced', '3+ years, consistent high training volume'],
                ] as [ExperienceLevel, string][]).map(([level, desc]) => (
                  <button
                    key={level}
                    onClick={() => setExperience(level)}
                    className={`w-full text-left px-4 py-3 rounded-xl border-2 transition-colors ${
                      experience === level ? 'border-blue-500 bg-blue-50' : 'border-gray-200 bg-white'
                    }`}
                  >
                    <p className="font-semibold text-gray-900">{level}</p>
                    <p className="text-sm text-gray-500">{desc}</p>
                  </button>
                ))}
              </div>
            </label>

            <div className="mt-auto">
              <button
                onClick={() => setStep('race')}
                disabled={!name.trim()}
                className="w-full py-4 bg-blue-600 text-white rounded-2xl font-bold disabled:opacity-40"
              >
                Continue
              </button>
            </div>
          </div>
        )}

        {/* ── Race ── */}
        {step === 'race' && (
          <div className="flex flex-col flex-1">
            <h2 className="text-2xl font-bold text-gray-900 mb-1">Your Race</h2>
            <p className="text-gray-500 mb-6">What are you training for?</p>

            <div className="space-y-2 mb-5">
              {(Object.entries(RACE_DISTANCES) as [RaceDistance, typeof RACE_DISTANCES[RaceDistance]][]).map(([dist, meta]) => (
                <button
                  key={dist}
                  onClick={() => setRaceDistance(dist)}
                  className={`w-full text-left px-4 py-3 rounded-xl border-2 transition-colors ${
                    raceDistance === dist ? 'border-blue-500 bg-blue-50' : 'border-gray-200 bg-white'
                  }`}
                >
                  <p className="font-semibold text-gray-900">{dist}</p>
                  <p className="text-sm text-gray-500">
                    {Math.round(meta.swimKm * 1000)}m swim · {meta.bikeKm}km bike · {meta.runKm}km run
                  </p>
                </button>
              ))}
            </div>

            <label className="block mb-2">
              <span className="text-sm font-semibold text-gray-700 mb-2 block">Race date</span>
              <input
                type="date"
                value={raceDate}
                min={format(new Date(), 'yyyy-MM-dd')}
                onChange={e => setRaceDate(e.target.value)}
                className="w-full border border-gray-200 rounded-xl px-4 py-3 text-lg outline-none focus:border-blue-400"
              />
            </label>

            {weeksToRace < recommended && (
              <div className="bg-orange-50 border border-orange-200 rounded-xl p-3 mt-2">
                <p className="text-sm text-orange-700">
                  ⚠️ {weeksToRace} weeks available — ideally {recommended}+ for a {raceDistance}. We'll build the best plan possible.
                </p>
              </div>
            )}

            <div className="mt-auto pt-4">
              <button
                onClick={() => setStep('schedule')}
                className="w-full py-4 bg-blue-600 text-white rounded-2xl font-bold"
              >
                Continue
              </button>
            </div>
          </div>
        )}

        {/* ── Schedule ── */}
        {step === 'schedule' && (
          <div className="flex flex-col flex-1">
            <h2 className="text-2xl font-bold text-gray-900 mb-1">Your Schedule</h2>
            <p className="text-gray-500 mb-6">When can you train each week?</p>

            <div className="mb-5">
              <p className="text-sm font-semibold text-gray-700 mb-2">Training days (minimum 3)</p>
              <div className="grid grid-cols-4 gap-2">
                {DAY_NAMES.map((day, i) => (
                  <button
                    key={i}
                    onClick={() => toggleDay(i)}
                    className={`py-3 rounded-xl font-medium text-sm transition-colors ${
                      selectedDays.includes(i)
                        ? 'bg-blue-600 text-white'
                        : 'bg-gray-100 text-gray-600'
                    }`}
                  >
                    {day}
                  </button>
                ))}
              </div>
            </div>

            <div className="mb-6">
              <div className="flex justify-between items-center mb-2">
                <p className="text-sm font-semibold text-gray-700">Weekly hours available</p>
                <p className="text-blue-600 font-bold">{weeklyHours}h</p>
              </div>
              <input
                type="range"
                min={3} max={20} step={0.5}
                value={weeklyHours}
                onChange={e => setWeeklyHours(Number(e.target.value))}
                className="w-full accent-blue-600"
              />
              <div className="flex justify-between text-xs text-gray-400 mt-1">
                <span>3h</span>
                <span>20h</span>
              </div>
            </div>

            <div className="mt-auto">
              <button
                onClick={generate}
                disabled={selectedDays.length < 3}
                className="w-full py-4 bg-blue-600 text-white rounded-2xl font-bold disabled:opacity-40"
              >
                Build My Plan 🚀
              </button>
            </div>
          </div>
        )}

        {/* ── Generating ── */}
        {step === 'generating' && (
          <div className="flex flex-col items-center justify-center flex-1 text-center">
            <div className="text-6xl mb-6 animate-bounce">🏊🚴🏃</div>
            <h2 className="text-2xl font-bold text-gray-900 mb-2">Building Your Plan</h2>
            <p className="text-gray-500">Calculating your personalised training schedule…</p>
          </div>
        )}
      </div>
    </div>
  )
}
