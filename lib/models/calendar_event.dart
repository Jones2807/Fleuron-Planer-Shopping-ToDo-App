import 'package:flutter/material.dart';
import 'employee.dart';

/// Defines the possible recurrence intervals for a [CalendarEvent].
enum Recurrence {
  /// No recurrence (single event)
  none,
  /// Daily recurrence
  daily,
  /// Weekly recurrence
  weekly,
  /// Bi-weekly recurrence
  biWeekly,
  /// Monthly recurrence
  monthly,
  /// Recurrence on custom days of the week (see [CalendarEvent.recurrenceDays])
  customDays
}

/// Represents a calendar event in the application.
///
/// This class stores all relevant information about an event,
/// including recurrence rules, participants, and notifications.
class CalendarEvent {
  // --- Serialization Keys (Clean Architecture) ---
  static const String keyUid = 'uid';
  static const String keyHref = 'href';
  static const String keyTitle = 'title';
  static const String keyStartTime = 'startTime';
  static const String keyEndTime = 'endTime';
  static const String keyIsAllDay = 'isAllDay';
  static const String keyParticipants = 'participants';
  static const String keyLocation = 'location';
  static const String keyColorValue = 'colorValue';
  static const String keyNotificationsEnabled = 'notificationsEnabled';
  static const String keyMinutesBefore = 'minutesBefore';
  static const String keyRecurrence = 'recurrence';
  static const String keyRecurrenceDays = 'recurrenceDays';
  static const String keyRecurrenceEndDate = 'recurrenceEndDate';
  static const String keyExcludeDates = 'excludeDates';

  /// Unique ID of the event (e.g., UUID).
  final String uid;

  /// Optional reference link (e.g., the URL for CalDAV synchronization).
  final String? href;

  /// The title or subject of the event.
  final String title;

  /// The start time of the event.
  final DateTime start;

  /// The end time of the event.
  final DateTime end;

  /// Indicates whether this is an all-day event.
  final bool isAllDay;

  /// List of participants ([Employee]) assigned to this event.
  final List<Employee> participants;

  /// Indicates whether notifications are enabled for this event.
  final bool notificationsEnabled;

  /// Number of minutes before the start time to trigger the notification.
  final int minutesBefore;

  /// The display color of the event in the calendar.
  final Color color;

  /// The type of recurrence (e.g., daily, weekly).
  final Recurrence recurrence;

  /// List of weekdays (e.g., 1 = Monday, 7 = Sunday) for custom recurrences.
  final List<int> recurrenceDays;

  /// Optional end date when the recurrence series stops.
  /// If this value is `null`, the series repeats indefinitely.
  final DateTime? recurrenceEndDate;

  /// The location where the event takes place.
  final String location;

  /// Stores specific dates (exceptions) where a recurring event was deleted or skipped.
  final List<DateTime> excludeDates;

  /// Creates a new instance of [CalendarEvent].
  const CalendarEvent({
    required this.uid,
    this.href,
    required this.title,
    required this.start,
    required this.end,
    required this.isAllDay,
    required this.participants,
    this.notificationsEnabled = false,
    this.minutesBefore = 15,
    required this.color,
    this.recurrence = Recurrence.none,
    this.recurrenceDays = const [],
    this.recurrenceEndDate,
    this.location = "",
    this.excludeDates = const [],
  });

  /// Converts the [CalendarEvent] into a Map.
  ///
  /// This is useful for serialization, e.g., for storing in an
  /// SQLite database or transmitting as JSON data.
  Map<String, dynamic> toMap() {
    return {
      keyUid: uid,
      keyHref: href,
      keyTitle: title,
      keyStartTime: start.toUtc().toIso8601String(),
      keyEndTime: end.toUtc().toIso8601String(),
      keyIsAllDay: isAllDay ? 1 : 0,
      keyParticipants: participants.map((e) => e.name).join(','),
      keyLocation: location,
      keyColorValue: color.toARGB32(),
      keyNotificationsEnabled: notificationsEnabled ? 1 : 0,
      keyMinutesBefore: minutesBefore,
      keyRecurrence: recurrence.name,
      keyRecurrenceDays: recurrenceDays.join(','),
      keyRecurrenceEndDate: recurrenceEndDate?.toUtc().toIso8601String(),
      keyExcludeDates: excludeDates.map((d) => d.toIso8601String()).join(','),
    };
  }
}
