import type { StravaActivity } from '../types'

const CLIENT_ID = import.meta.env.VITE_STRAVA_CLIENT_ID || ''
const CLIENT_SECRET = import.meta.env.VITE_STRAVA_CLIENT_SECRET || ''
const REDIRECT_URI = `${window.location.origin}/strava/callback`
const BASE = 'https://www.strava.com/api/v3'

// ─── Token Management ─────────────────────────────────────────────────────

interface TokenData {
  accessToken: string
  refreshToken: string
  expiresAt: number
  athleteId: number
  athleteName: string
}

function saveTokens(data: TokenData) {
  localStorage.setItem('strava_tokens', JSON.stringify(data))
}

function loadTokens(): TokenData | null {
  try {
    const raw = localStorage.getItem('strava_tokens')
    return raw ? JSON.parse(raw) : null
  } catch { return null }
}

function clearTokens() {
  localStorage.removeItem('strava_tokens')
}

export function isAuthenticated(): boolean {
  return loadTokens() !== null
}

export function getAthleteName(): string {
  return loadTokens()?.athleteName ?? ''
}

export function disconnect() {
  clearTokens()
}

// ─── OAuth Flow ───────────────────────────────────────────────────────────

export function getAuthUrl(): string {
  const params = new URLSearchParams({
    client_id: CLIENT_ID,
    redirect_uri: REDIRECT_URI,
    response_type: 'code',
    approval_prompt: 'auto',
    scope: 'read,activity:read_all',
  })
  return `https://www.strava.com/oauth/authorize?${params}`
}

export async function handleCallback(code: string): Promise<boolean> {
  try {
    const res = await fetch('https://www.strava.com/oauth/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        client_id: CLIENT_ID,
        client_secret: CLIENT_SECRET,
        code,
        grant_type: 'authorization_code',
      }),
    })
    if (!res.ok) return false

    const data = await res.json()
    saveTokens({
      accessToken: data.access_token,
      refreshToken: data.refresh_token,
      expiresAt: data.expires_at,
      athleteId: data.athlete?.id,
      athleteName: `${data.athlete?.firstname ?? ''} ${data.athlete?.lastname ?? ''}`.trim(),
    })
    return true
  } catch { return false }
}

async function ensureValidToken(): Promise<string | null> {
  const tokens = loadTokens()
  if (!tokens) return null

  if (Date.now() / 1000 < tokens.expiresAt - 300) {
    return tokens.accessToken
  }

  // Refresh
  try {
    const res = await fetch('https://www.strava.com/oauth/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        client_id: CLIENT_ID,
        client_secret: CLIENT_SECRET,
        grant_type: 'refresh_token',
        refresh_token: tokens.refreshToken,
      }),
    })
    if (!res.ok) { clearTokens(); return null }
    const data = await res.json()
    saveTokens({ ...tokens, accessToken: data.access_token, refreshToken: data.refresh_token, expiresAt: data.expires_at })
    return data.access_token
  } catch { return null }
}

// ─── Activities ───────────────────────────────────────────────────────────

export async function fetchRecentActivities(perPage = 30): Promise<StravaActivity[]> {
  const token = await ensureValidToken()
  if (!token) return []

  try {
    const res = await fetch(`${BASE}/athlete/activities?per_page=${perPage}&page=1`, {
      headers: { Authorization: `Bearer ${token}` },
    })
    if (!res.ok) return []
    const data: StravaActivity[] = await res.json()
    return data.filter(a => ['Swim', 'Ride', 'Run'].includes(a.type))
  } catch { return [] }
}

export function matchActivityToWorkout(
  activities: StravaActivity[],
  workoutDate: string,
  sport: string,
  plannedDurationSec: number
): StravaActivity | null {
  const date = new Date(workoutDate)
  const windowStart = new Date(date.getTime() - 8 * 3600 * 1000)
  const windowEnd = new Date(date.getTime() + 24 * 3600 * 1000)

  const sportMap: Record<string, string> = { Swim: 'Swim', Bike: 'Ride', Run: 'Run', Brick: 'Ride' }
  const targetType = sportMap[sport]

  const candidates = activities.filter(a => {
    const start = new Date(a.start_date)
    return a.type === targetType && start >= windowStart && start <= windowEnd
  })

  return candidates.sort((a, b) =>
    Math.abs(a.moving_time - plannedDurationSec) - Math.abs(b.moving_time - plannedDurationSec)
  )[0] ?? null
}
