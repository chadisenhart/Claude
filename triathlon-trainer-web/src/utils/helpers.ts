import { format, parseISO, isToday, isTomorrow } from 'date-fns'

export function formatDuration(seconds: number): string {
  const h = Math.floor(seconds / 3600)
  const m = Math.floor((seconds % 3600) / 60)
  if (h > 0) return `${h}h ${m}m`
  return `${m} min`
}

export function formatDistance(km: number): string {
  if (km < 1) return `${Math.round(km * 1000)}m`
  return `${km.toFixed(1)}km`
}

export function formatDate(dateStr: string): string {
  const d = parseISO(dateStr)
  if (isToday(d)) return 'Today'
  if (isTomorrow(d)) return 'Tomorrow'
  return format(d, 'EEE d MMM')
}

export function formatShortDate(dateStr: string): string {
  return format(parseISO(dateStr), 'EEE d')
}

export function cn(...classes: (string | undefined | false | null)[]): string {
  return classes.filter(Boolean).join(' ')
}

export function sportBg(sport: string): string {
  switch (sport) {
    case 'Swim':   return 'bg-blue-100 text-blue-700'
    case 'Bike':   return 'bg-orange-100 text-orange-700'
    case 'Run':    return 'bg-green-100 text-green-700'
    case 'Brick':  return 'bg-purple-100 text-purple-700'
    default:       return 'bg-gray-100 text-gray-600'
  }
}

export function sportColor(sport: string): string {
  switch (sport) {
    case 'Swim':   return '#3b82f6'
    case 'Bike':   return '#f97316'
    case 'Run':    return '#22c55e'
    case 'Brick':  return '#a855f7'
    default:       return '#9ca3af'
  }
}

export function sportIcon(sport: string): string {
  switch (sport) {
    case 'Swim':   return '🏊'
    case 'Bike':   return '🚴'
    case 'Run':    return '🏃'
    case 'Brick':  return '⚡'
    case 'Rest':   return '😴'
    default:       return '💪'
  }
}

export function intensityColor(intensity: string): string {
  switch (intensity) {
    case 'Recovery': return 'text-gray-500'
    case 'Easy':     return 'text-blue-500'
    case 'Moderate': return 'text-green-500'
    case 'Threshold':return 'text-orange-500'
    case 'VO2 Max':  return 'text-red-500'
    case 'Sprint':   return 'text-red-700'
    default:         return 'text-gray-500'
  }
}

export function zoneColor(zone: number): string {
  const colors = ['', '#6b7280', '#3b82f6', '#22c55e', '#f97316', '#ef4444']
  return colors[Math.min(zone, 5)] || '#6b7280'
}

export function statusIcon(status: string): string {
  switch (status) {
    case 'Completed': return '✅'
    case 'Skipped':   return '❌'
    case 'Partial':   return '⚡'
    case 'Indoor':    return '🏠'
    default:          return '○'
  }
}
