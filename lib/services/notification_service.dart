import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/calendar_event.dart';
import '../models/employee.dart';

/// Localized strings [NotificationService] needs to build an event
/// reminder notification (channel name/description, title, body).
///
/// Bundled into one object rather than passed as many individual
/// parameters, since this static service has no [BuildContext] to
/// resolve the app's active language itself - see
/// `calendar_screen.dart`, which builds this from [AppLocalizations]
/// right before scheduling a notification.
class NotificationLabels {
  final String channelName;
  final String channelDescription;
  final String title;
  final String Function(String eventTitle) osTitle;
  final String Function(int minutesBefore) osBody;
  final String Function(String eventTitle, int minutesBefore, String location) bigTextBody;
  final String locationNotSpecified;

  const NotificationLabels({
    required this.channelName,
    required this.channelDescription,
    required this.title,
    required this.osTitle,
    required this.osBody,
    required this.bigTextBody,
    required this.locationNotSpecified,
  });
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  static bool _isInitialized = false;

  /// Initializes the notification system at app startup.
  static Future<void> init() async {
    // Local notifications aren't supported on the web build - bail out early.
    if (kIsWeb) {
      debugPrint("Web mode: local notifications disabled.");
      return;
    }

    // Timezone data is essential for exact-time alarms to fire correctly.
    tz.initializeTimeZones();

    // Uses the app's default Android icon.
    const AndroidInitializationSettings androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosInit = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true
    );
    const InitializationSettings initSettings = InitializationSettings(android: androidInit, iOS: iosInit);

    await _notificationsPlugin.initialize(settings: initSettings);

    // Android 13+ requires these permissions to be requested explicitly.
    final androidImplementation = _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
      await androidImplementation.requestExactAlarmsPermission();
    }

    _isInitialized = true;
  }

  /// Schedules a reminder notification for [event], using [labels]
  /// for all localized text. No-op if [currentUser] isn't among the
  /// event's participants, notifications are disabled for the event,
  /// or the reminder time has already passed.
  static Future<void> scheduleEventNotification(
      CalendarEvent event,
      Employee? currentUser, {
        required NotificationLabels labels,
      }) async {
    if (kIsWeb || !_isInitialized) return;

    bool amIParticipating = event.participants.any((p) => p.name == currentUser?.name);
    if (!amIParticipating || !event.notificationsEnabled) return;

    final scheduledTime = event.start.subtract(Duration(minutes: event.minutesBefore));

    // Don't schedule alarms for a time that's already in the past.
    if (scheduledTime.isBefore(DateTime.now())) return;

    final androidDetails = AndroidNotificationDetails(
      'team_cal_channel',
      labels.channelName,
      channelDescription: labels.channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      color: const Color(0xFF4A73D1),
      styleInformation: BigTextStyleInformation(
        labels.bigTextBody(event.title, event.minutesBefore, event.location.isNotEmpty ? event.location : labels.locationNotSpecified),
        htmlFormatBigText: true,
        contentTitle: labels.title,
        htmlFormatContentTitle: true,
      ),
    );

    final notificationDetails = NotificationDetails(android: androidDetails, iOS: const DarwinNotificationDetails());

    await _notificationsPlugin.zonedSchedule(
      id: event.uid.hashCode,
      title: labels.osTitle(event.title),
      body: labels.osBody(event.minutesBefore),
      scheduledDate: tz.TZDateTime.from(scheduledTime, tz.local),
      notificationDetails: notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  /// Cancels the notification for [eventUid], e.g. when the event is
  /// deleted or rescheduled.
  static Future<void> cancelNotification(String eventUid) async {
    if (kIsWeb || !_isInitialized) return;
    await _notificationsPlugin.cancel(id: eventUid.hashCode);
  }
}