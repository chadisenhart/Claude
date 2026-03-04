import Foundation
import EventKit

/// Manages Apple Calendar integration via EventKit.
/// Reads busy times to avoid scheduling conflicts, writes workouts as calendar events.
@MainActor
class CalendarService: ObservableObject {

    private let eventStore = EKEventStore()
    @Published var isAuthorized = false
    @Published var authorizationError: String?

    // MARK: - Authorization

    func requestAccess() async {
        do {
            if #available(iOS 17.0, *) {
                let granted = try await eventStore.requestFullAccessToEvents()
                isAuthorized = granted
                if !granted {
                    authorizationError = "Calendar access denied. Please enable it in Settings > Privacy > Calendars."
                }
            } else {
                let granted = try await eventStore.requestAccess(to: .event)
                isAuthorized = granted
            }
        } catch {
            isAuthorized = false
            authorizationError = error.localizedDescription
        }
    }

    var authorizationStatus: EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .event)
    }

    // MARK: - Busy Time Detection

    /// Returns time windows that are busy in the user's calendar for a given date range.
    func busyWindows(from startDate: Date, to endDate: Date) -> [BusyWindow] {
        guard isAuthorized else { return [] }

        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: nil
        )
        let events = eventStore.events(matching: predicate)

        return events
            .filter { !$0.isAllDay }
            .map { BusyWindow(start: $0.startDate, end: $0.endDate, title: $0.title ?? "Busy") }
            .sorted { $0.start < $1.start }
    }

    /// Finds open time slots on a given date for a workout of specified duration.
    func availableSlots(on date: Date, durationMinutes: Int) -> [TimeSlot] {
        let calendar = Calendar.current

        // Define workout-friendly window: 5:30am - 9:30pm
        guard let dayStart = calendar.date(bySettingHour: 5, minute: 30, second: 0, of: date),
              let dayEnd = calendar.date(bySettingHour: 21, minute: 30, second: 0, of: date) else {
            return []
        }

        let busyTimes = busyWindows(from: dayStart, to: dayEnd)
        var slots: [TimeSlot] = []
        var cursor = dayStart

        for busy in busyTimes {
            let gapDuration = busy.start.timeIntervalSince(cursor)
            if gapDuration >= Double(durationMinutes * 60) {
                slots.append(TimeSlot(start: cursor, end: busy.start))
            }
            if busy.end > cursor {
                cursor = busy.end
            }
        }

        // Check gap after last busy event
        let finalGap = dayEnd.timeIntervalSince(cursor)
        if finalGap >= Double(durationMinutes * 60) {
            slots.append(TimeSlot(start: cursor, end: dayEnd))
        }

        return slots
    }

    /// Checks if a specific time window is free on the user's calendar.
    func isTimeFree(start: Date, end: Date) -> Bool {
        let busy = busyWindows(from: start, to: end)
        return busy.isEmpty
    }

    // MARK: - Writing Workouts to Calendar

    /// Creates a calendar event for a planned workout. Returns the event identifier.
    @discardableResult
    func createWorkoutEvent(for workout: Workout, calendarName: String = "Triathlon Training") -> String? {
        guard isAuthorized else { return nil }

        let calendar = findOrCreateCalendar(named: calendarName)

        let event = EKEvent(eventStore: eventStore)
        event.title = "\(workout.sport.rawValue): \(workout.sessionTitle)"
        event.startDate = workout.scheduledDate
        event.endDate = workout.scheduledDate.addingTimeInterval(workout.plannedDuration)
        event.calendar = calendar
        event.notes = buildEventNotes(for: workout)

        // Color-code by sport using calendar color (best effort)
        let structuredLocation = EKStructuredLocation(title: workout.sport == .swim ? "Pool / Open Water" : "Outdoor")
        event.structuredLocation = structuredLocation

        do {
            try eventStore.save(event, span: .thisEvent)
            return event.eventIdentifier
        } catch {
            print("CalendarService: Failed to save event: \(error)")
            return nil
        }
    }

    /// Updates an existing calendar event (e.g., after rescheduling).
    func updateWorkoutEvent(eventId: String, workout: Workout) {
        guard isAuthorized,
              let event = eventStore.event(withIdentifier: eventId) else { return }

        event.title = "\(workout.sport.rawValue): \(workout.sessionTitle)"
        event.startDate = workout.scheduledDate
        event.endDate = workout.scheduledDate.addingTimeInterval(workout.plannedDuration)
        event.notes = buildEventNotes(for: workout)

        try? eventStore.save(event, span: .thisEvent)
    }

    /// Removes a workout event from the calendar.
    func deleteWorkoutEvent(eventId: String) {
        guard isAuthorized,
              let event = eventStore.event(withIdentifier: eventId) else { return }
        try? eventStore.remove(event, span: .thisEvent)
    }

    // MARK: - Week Planning

    /// Finds best workout times for a week, avoiding calendar conflicts.
    func suggestWorkoutTimes(for workouts: [Workout]) -> [UUID: Date] {
        var suggestions: [UUID: Date] = [:]

        for workout in workouts {
            let durationMinutes = Int(workout.plannedDuration / 60)
            let slots = availableSlots(on: workout.scheduledDate, durationMinutes: durationMinutes)

            // Prefer morning slots for key sessions, evening for easy sessions
            let preferred: Date
            if workout.plannedIntensity == .easy || workout.plannedIntensity == .recovery {
                // Evening preferred for easy sessions
                preferred = slots.first(where: { isEveningSlot($0) })?.start
                    ?? slots.first?.start
                    ?? workout.scheduledDate
            } else {
                // Morning preferred for hard sessions
                preferred = slots.first(where: { isMorningSlot($0) })?.start
                    ?? slots.first?.start
                    ?? workout.scheduledDate
            }

            suggestions[workout.id] = preferred
        }

        return suggestions
    }

    // MARK: - Helpers

    private func findOrCreateCalendar(named name: String) -> EKCalendar {
        if let existing = eventStore.calendars(for: .event).first(where: { $0.title == name }) {
            return existing
        }

        let newCalendar = EKCalendar(for: .event, eventStore: eventStore)
        newCalendar.title = name
        newCalendar.cgColor = CGColor(red: 0.2, green: 0.6, blue: 1.0, alpha: 1.0) // Tri blue
        newCalendar.source = eventStore.defaultCalendarForNewEvents?.source
            ?? eventStore.sources.first(where: { $0.sourceType == .local })

        try? eventStore.saveCalendar(newCalendar, commit: true)
        return newCalendar
    }

    private func buildEventNotes(for workout: Workout) -> String {
        var notes = "🎯 \(workout.sessionGoal)\n\n"
        notes += "📋 WARM-UP\n\(workout.warmupInstructions)\n\n"
        notes += "⚡ MAIN SET\n\(workout.mainSetInstructions)\n\n"
        notes += "🔽 COOL-DOWN\n\(workout.cooldownInstructions)\n\n"

        if !workout.coachingTips.isEmpty {
            notes += "💡 COACH'S TIPS\n"
            for tip in workout.coachingTips.prefix(3) {
                notes += "• \(tip.title): \(tip.detail)\n"
            }
        }

        return notes
    }

    private func isMorningSlot(_ slot: TimeSlot) -> Bool {
        let hour = Calendar.current.component(.hour, from: slot.start)
        return hour >= 5 && hour <= 10
    }

    private func isEveningSlot(_ slot: TimeSlot) -> Bool {
        let hour = Calendar.current.component(.hour, from: slot.start)
        return hour >= 17 && hour <= 20
    }
}

// MARK: - Supporting Types

struct BusyWindow {
    var start: Date
    var end: Date
    var title: String
}

struct TimeSlot {
    var start: Date
    var end: Date

    var durationMinutes: Int {
        Int(end.timeIntervalSince(start) / 60)
    }
}
