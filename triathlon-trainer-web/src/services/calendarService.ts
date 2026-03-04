import { parseISO, format, addSeconds } from 'date-fns'
import type { Workout } from '../types'

// ─── .ics Generator ────────────────────────────────────────────────────────
// Generates an iCal file that opens directly in Apple Calendar on iPhone.
// The user taps "Add to Calendar" and it's imported in one step.

function icsDate(date: Date): string {
  return date.toISOString().replace(/[-:]/g, '').replace(/\.\d{3}/, '')
}

function icsEscape(str: string): string {
  return str
    .replace(/\\/g, '\\\\')
    .replace(/;/g, '\\;')
    .replace(/,/g, '\\,')
    .replace(/\n/g, '\\n')
    .replace(/\r/g, '')
}

function foldLine(line: string): string {
  // RFC 5545: lines > 75 octets must be folded
  const chunks: string[] = []
  while (line.length > 75) {
    chunks.push(line.substring(0, 75))
    line = ' ' + line.substring(75)
  }
  chunks.push(line)
  return chunks.join('\r\n')
}

export function workoutToICS(workout: Workout): string {
  const start = parseISO(workout.scheduledDate + 'T07:00:00')
  const end = addSeconds(start, workout.plannedDurationSec)

  const description = [
    `🎯 ${workout.goal}`,
    '',
    `📋 WARM-UP`,
    workout.warmup,
    '',
    `⚡ MAIN SET`,
    workout.mainSet,
    '',
    `🔽 COOL-DOWN`,
    workout.cooldown,
    '',
    workout.tips.slice(0, 3).map(t => `💡 ${t.title}: ${t.detail}`).join('\n'),
  ].join('\n')

  const lines = [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//TriTrainer//EN',
    'CALSCALE:GREGORIAN',
    'METHOD:PUBLISH',
    'BEGIN:VEVENT',
    `UID:${workout.id}@tritrainer`,
    `DTSTART:${icsDate(start)}`,
    `DTEND:${icsDate(end)}`,
    `SUMMARY:${icsEscape(`${workout.sport}: ${workout.title}`)}`,
    foldLine(`DESCRIPTION:${icsEscape(description)}`),
    `CATEGORIES:${workout.sport.toUpperCase()},TRIATHLON`,
    `STATUS:CONFIRMED`,
    'END:VEVENT',
    'END:VCALENDAR',
  ]

  return lines.join('\r\n')
}

export function weekToICS(workouts: Workout[]): string {
  const events = workouts.map(w => {
    const start = parseISO(w.scheduledDate + 'T07:00:00')
    const end = addSeconds(start, w.plannedDurationSec)
    const desc = [
      `🎯 ${w.goal}`,
      '',
      `WARM-UP: ${w.warmup}`,
      '',
      `MAIN SET: ${w.mainSet}`,
      '',
      `COOL-DOWN: ${w.cooldown}`,
    ].join('\n')

    return [
      'BEGIN:VEVENT',
      `UID:${w.id}@tritrainer`,
      `DTSTART:${icsDate(start)}`,
      `DTEND:${icsDate(end)}`,
      `SUMMARY:${icsEscape(`${w.sport}: ${w.title}`)}`,
      foldLine(`DESCRIPTION:${icsEscape(desc)}`),
      `CATEGORIES:${w.sport.toUpperCase()}`,
      'END:VEVENT',
    ].join('\r\n')
  })

  return [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//TriTrainer//EN',
    'CALSCALE:GREGORIAN',
    'METHOD:PUBLISH',
    ...events,
    'END:VCALENDAR',
  ].join('\r\n')
}

// ─── Download helpers ─────────────────────────────────────────────────────

export function downloadICS(content: string, filename: string) {
  const blob = new Blob([content], { type: 'text/calendar;charset=utf-8' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = filename
  a.click()
  URL.revokeObjectURL(url)
}

export function openICSInCalendar(content: string) {
  // On iPhone, opening the .ics blob directly prompts "Add to Calendar"
  const blob = new Blob([content], { type: 'text/calendar;charset=utf-8' })
  const url = URL.createObjectURL(blob)
  window.open(url, '_blank')
  setTimeout(() => URL.revokeObjectURL(url), 3000)
}
