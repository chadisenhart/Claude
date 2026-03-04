import type { HourlyForecast, WeatherAssessment, WeatherWarning, RiskLevel, Sport } from '../types'

const API_KEY = import.meta.env.VITE_OPENWEATHER_API_KEY || ''
const BASE = 'https://api.openweathermap.org/data/3.0'

// ─── Fetch ────────────────────────────────────────────────────────────────

export async function fetchForecast(lat: number, lon: number): Promise<HourlyForecast[]> {
  if (!API_KEY) return []

  const res = await fetch(
    `${BASE}/onecall?lat=${lat}&lon=${lon}&exclude=minutely,daily,alerts&units=metric&appid=${API_KEY}`
  )
  if (!res.ok) return []

  const data = await res.json()
  return (data.hourly ?? []).slice(0, 48).map((h: any): HourlyForecast => ({
    dt: h.dt * 1000,
    temp: h.temp,
    feelsLike: h.feels_like,
    description: h.weather?.[0]?.description ?? '',
    windKmh: (h.wind_speed ?? 0) * 3.6,
    precipChance: h.pop ?? 0,
    precipMm: (h.rain?.['1h'] ?? h.snow?.['1h'] ?? 0),
    icon: h.weather?.[0]?.icon ?? '',
  }))
}

export async function getCurrentLocation(): Promise<{ lat: number; lon: number } | null> {
  return new Promise((resolve) => {
    if (!navigator.geolocation) { resolve(null); return }
    navigator.geolocation.getCurrentPosition(
      (pos) => resolve({ lat: pos.coords.latitude, lon: pos.coords.longitude }),
      () => resolve(null),
      { timeout: 8000 }
    )
  })
}

// ─── Assessment ───────────────────────────────────────────────────────────

export function assessWeather(
  forecast: HourlyForecast[],
  sport: Sport,
  workoutDate: string
): WeatherAssessment {
  const target = new Date(workoutDate).getTime()
  const conditions = forecast.reduce((best, h) =>
    Math.abs(h.dt - target) < Math.abs(best.dt - target) ? h : best,
    forecast[0]
  )

  if (!conditions) {
    return { isSuitable: true, riskLevel: 'unknown', warnings: [], indoorRecommended: false, summary: 'Weather data unavailable — check before heading out.' }
  }

  const warnings: WeatherWarning[] = []
  let risk: RiskLevel = 'low'

  const maxRisk = (r: RiskLevel) => {
    const order: RiskLevel[] = ['unknown', 'low', 'moderate', 'high', 'extreme']
    if (order.indexOf(r) > order.indexOf(risk)) risk = r
  }

  // Temperature
  if (conditions.feelsLike < -10) {
    warnings.push({ icon: '🥶', message: `Extreme cold (${Math.round(conditions.feelsLike)}°C). High hypothermia risk.` })
    maxRisk('extreme')
  } else if (conditions.feelsLike < 0) {
    warnings.push({ icon: '❄️', message: `Very cold (${Math.round(conditions.feelsLike)}°C). Dress in layers, protect extremities.` })
    maxRisk('high')
  } else if (conditions.feelsLike > 35) {
    warnings.push({ icon: '🌡️', message: `Extreme heat (${Math.round(conditions.feelsLike)}°C). High heat stroke risk.` })
    maxRisk('extreme')
  } else if (conditions.feelsLike > 30) {
    warnings.push({ icon: '☀️', message: `Very hot (${Math.round(conditions.feelsLike)}°C). Reduce intensity, carry extra fluids.` })
    maxRisk('high')
  } else if (conditions.feelsLike > 27) {
    warnings.push({ icon: '🌤️', message: `Hot (${Math.round(conditions.feelsLike)}°C). Slow down 10–15%, double hydration.` })
    maxRisk('moderate')
  }

  // Wind
  if (conditions.windKmh > 60) {
    warnings.push({ icon: '💨', message: `Dangerous wind (${Math.round(conditions.windKmh)} km/h). Debris risk — stay indoors.` })
    maxRisk('extreme')
  } else if (conditions.windKmh > 40) {
    warnings.push({ icon: '💨', message: `Strong wind (${Math.round(conditions.windKmh)} km/h). Outdoor cycling not recommended.` })
    if (sport === 'Bike') maxRisk('high')
    else maxRisk('moderate')
  } else if (conditions.windKmh > 25 && sport === 'Bike') {
    warnings.push({ icon: '🌬️', message: `Gusty (${Math.round(conditions.windKmh)} km/h). Plan route with wind at back on return.` })
  }

  // Rain
  if (conditions.precipChance > 0.7) {
    warnings.push({ icon: '🌧️', message: `High rain chance (${Math.round(conditions.precipChance * 100)}%). Wet roads — reduce bike speed in corners.` })
    if (sport === 'Bike') maxRisk('moderate')
  }
  if (conditions.precipMm > 10) {
    warnings.push({ icon: '⛈️', message: `Heavy rain (${Math.round(conditions.precipMm)}mm). Roads may flood.` })
    maxRisk('high')
  }

  // Storm
  if (conditions.description.toLowerCase().includes('thunder') || conditions.description.toLowerCase().includes('storm')) {
    warnings.push({ icon: '⚡', message: 'Thunderstorm forecast. No open water swimming. Avoid high ground on bike.' })
    maxRisk('extreme')
  }

  const finalRisk = risk as RiskLevel
  const indoorRecommended = finalRisk === 'extreme' || finalRisk === 'high'
  const intensityAdjustment = conditions.feelsLike > 27 ? 'Reduce target pace/power by 10–15% for the heat' : undefined

  const summary = {
    unknown: 'Weather data unavailable.',
    low: `Good conditions for your ${sport.toLowerCase()}.`,
    moderate: 'Manageable — take precautions and adjust effort as needed.',
    high: 'Challenging conditions. Consider the indoor alternative or reschedule.',
    extreme: 'Dangerous conditions. Indoor training strongly recommended.',
  }[finalRisk]

  return { isSuitable: finalRisk !== 'extreme', riskLevel: finalRisk, warnings, indoorRecommended, intensityAdjustment, summary }
}

// ─── Indoor Alternatives ──────────────────────────────────────────────────

export function getIndoorAlternative(sport: Sport) {
  switch (sport) {
    case 'Bike':
    case 'Brick':
      return {
        instructions: 'Complete on your indoor trainer (turbo / smart trainer). Same duration and effort zones as planned. Use structured ERG mode if available.\n\nFor Zwift/TrainerRoad: load a workout matching today\'s intensity zones.\nFor unstructured riding: use perceived effort, maintain cadence 85–95 rpm.',
        equipment: ['Indoor trainer / turbo', 'Fan (mandatory — no wind indoors)', 'Towel', '2× water bottles', 'Chamois cream'],
      }
    case 'Run':
      return {
        instructions: 'Treadmill alternative — same session indoors. Set treadmill incline to 0.5–1% to simulate outdoor air resistance.\n\nFor intervals: pre-set your interval speed and step on/off the belt for rest intervals.',
        equipment: ['Treadmill'],
      }
    default:
      return {
        instructions: 'Home bodyweight strength and core session. 3×15 of: plank, glute bridge, single-leg deadlift, press-up, mountain climber.',
        equipment: ['Exercise mat'],
      }
  }
}
