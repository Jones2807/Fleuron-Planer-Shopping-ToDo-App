import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'package:icalendar_parser/icalendar_parser.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/calendar_event.dart';
import '../models/employee.dart';
import '../models/todo_task.dart';
import 'group_colors.dart';
import 'secure_vault.dart';
import 'offline_queue_service.dart';

/// A CalDAV collection URL an event can be written to, paired with
/// the account it belongs to.
class TargetCalendar {
  final CalDavAccount account;
  final String href;
  TargetCalendar(this.account, this.href);
}

/// A CalDAV collection that has been mapped to a specific combination
/// of employees (see `calendar_mapping_screen.dart`), identified by
/// [participantNames] - a comma-joined, sorted list of employee names.
class MappedCalendar {
  final CalDavAccount account;
  final String href;
  final String participantNames;
  MappedCalendar(this.account, this.href, this.participantNames);
}

/// Talks to one or more CalDAV servers: discovers calendars, fetches
/// and parses events/to-dos, and pushes local changes back (falling
/// back to [OfflineQueueService] when the network is unavailable).
class CalDavService {
  static final Map<String, String> _calendarMap = {};
  static final List<Map<String, String>> discoveredRawCalendars = [];

  /// Participant-name keys (e.g. `"Alice,Bob"`) that map to more than
  /// one employee, i.e. shared/group calendars.
  static List<String> get activeGroups {
    return _calendarMap.keys.where((k) => k.contains(',')).toList();
  }

  /// Resolves a possibly-relative calendar [href] to an absolute,
  /// trailing-slash-terminated URL for [account].
  static String _buildFullUrl(CalDavAccount account, String href) {
    if (href.startsWith('http')) return href.endsWith('/') ? href : "$href/";
    String baseUrl = account.url;
    if (baseUrl.endsWith('/')) {
      baseUrl = baseUrl.substring(0, baseUrl.length - 1);
    }
    Uri uri = Uri.parse(baseUrl);
    String origin = "${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}";
    String fullUrl = href.startsWith('/') ? "$origin$href" : "$baseUrl/$href";
    return fullUrl.endsWith('/') ? fullUrl : "$fullUrl/";
  }

  /// Discovers all calendars on the currently-configured CalDAV
  /// server ([CalDavConfig]) via principal/calendar-home discovery,
  /// falling back to a handful of common server-specific paths if
  /// that fails. Results land in [discoveredRawCalendars].
  static Future<void> discoverCalendars(List<Employee> allEmployees) async {
    discoveredRawCalendars.clear();
    final activeAccs = (await SecureVault.getAllAccounts()).where((a) => a.isActive).toList();
    await _getMappedCalendars(activeAccs);

    final basicAuth = 'Basic ${base64Encode(utf8.encode('${CalDavConfig.username}:${CalDavConfig.password}'))}';
    String base = CalDavConfig.serverUrl;
    if (base.endsWith('/')) base = base.substring(0, base.length - 1);
    String origin = Uri.parse(base).origin;

    String principalUrl = "";
    List<String> principalTargets = [base, "$base/remote.php/dav/", "$base/.well-known/caldav"];

    for (String target in principalTargets) {
      if (principalUrl.isNotEmpty) break;
      try {
        final req = http.Request('PROPFIND', Uri.parse(target))
          ..headers['Authorization'] = basicAuth
          ..headers['Depth'] = '0'
          ..headers['Content-Type'] = 'application/xml; charset=utf-8';
        req.body = '''<d:propfind xmlns:d="DAV:"><d:prop><d:current-user-principal /></d:prop></d:propfind>''';
        final res = await http.Response.fromStream(await req.send().timeout(const Duration(seconds: 8)));
        if (res.statusCode == 207 || res.statusCode == 200) {
          final doc = XmlDocument.parse(res.body);
          final principalNodes = doc.findAllElements('current-user-principal', namespace: '*');
          if (principalNodes.isNotEmpty) {
            final hrefs = principalNodes.first.findAllElements('href', namespace: '*');
            if (hrefs.isNotEmpty) principalUrl = hrefs.first.innerText;
          }
        }
      } catch (_) {}
    }

    String calendarHomeUrl = "";
    if (principalUrl.isNotEmpty) {
      try {
        final String target = principalUrl.startsWith('http') ? principalUrl : "$origin$principalUrl";
        final reqHome = http.Request('PROPFIND', Uri.parse(target))
          ..headers['Authorization'] = basicAuth
          ..headers['Depth'] = '0'
          ..headers['Content-Type'] = 'application/xml; charset=utf-8';
        reqHome.body = '''<d:propfind xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav"><d:prop><c:calendar-home-set /></d:prop></d:propfind>''';
        final resHome = await http.Response.fromStream(await reqHome.send().timeout(const Duration(seconds: 8)));
        if (resHome.statusCode == 207 || resHome.statusCode == 200) {
          final homeNodes = XmlDocument.parse(resHome.body).findAllElements('calendar-home-set', namespace: '*');
          if (homeNodes.isNotEmpty) {
            final hrefs = homeNodes.first.findAllElements('href', namespace: '*');
            if (hrefs.isNotEmpty) calendarHomeUrl = hrefs.first.innerText;
          }
        }
      } catch (_) {}
    }

    List<String> pathsToTest = [];
    if (calendarHomeUrl.isNotEmpty) pathsToTest.add(calendarHomeUrl.startsWith('http') ? calendarHomeUrl : "$origin$calendarHomeUrl");
    pathsToTest.addAll([
      base,
      "$base/remote.php/dav/calendars/${CalDavConfig.username}/",
      "$base/remote.php/caldav/",
      "$base/caldav/",
      "$base/caldav.php/${CalDavConfig.username}/"
    ]);

    bool foundCalendars = false;
    for (var url in pathsToTest) {
      if (foundCalendars) break;
      try {
        String finalUrl = url.endsWith('/') ? url : "$url/";
        final request = http.Request('PROPFIND', Uri.parse(finalUrl))
          ..headers['Authorization'] = basicAuth
          ..headers['Depth'] = '1'
          ..headers['Content-Type'] = 'application/xml; charset=utf-8';
        request.body = '''<d:propfind xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav"><d:prop><d:displayname /><c:supported-calendar-component-set /></d:prop></d:propfind>''';
        final response = await http.Response.fromStream(await request.send().timeout(const Duration(seconds: 8)));
        if (response.statusCode == 207 || response.statusCode == 200) {
          final document = XmlDocument.parse(response.body);
          for (var resp in document.findAllElements('response', namespace: '*')) {
            bool isCalendar = resp.findAllElements('comp', namespace: '*').any((c) => c.getAttribute('name') == 'VEVENT') ||
                resp.findAllElements('calendar', namespace: '*').isNotEmpty;
            if (isCalendar) {
              final hrefNodes = resp.findAllElements('href', namespace: '*');
              final nameNodes = resp.findAllElements('displayname', namespace: '*');
              if (hrefNodes.isNotEmpty && nameNodes.isNotEmpty) {
                String href = hrefNodes.first.innerText;
                String displayName = nameNodes.first.innerText.trim();
                if (!href.endsWith('principals/') && !href.endsWith('calendars/') && displayName.isNotEmpty) {
                  discoveredRawCalendars.add({'name': displayName, 'href': href});
                  foundCalendars = true;
                }
              }
            }
          }
        }
      } catch (e) {}
    }
  }

  /// Returns the CalDAV collections the current, active, non-read-only
  /// accounts are mapped to (see `calendar_mapping_screen.dart`).
  static Future<List<MappedCalendar>> getWritableCalendars() async {
    final allAccounts = await SecureVault.getAllAccounts();
    final activeAccounts = allAccounts.where((a) => a.isActive && !a.isReadOnly).toList();
    return await _getMappedCalendars(activeAccounts);
  }

  /// Loads the saved calendar-to-employee mappings for [activeAccounts]
  /// from local storage, migrating from the older single-account
  /// (`custom_calendar_mapping`) format if the newer per-account
  /// (`custom_calendar_mapping_v2`) format isn't present yet. Also
  /// rebuilds the in-memory [_calendarMap] lookup as a side effect.
  static Future<List<MappedCalendar>> _getMappedCalendars(List<CalDavAccount> activeAccounts) async {
    List<MappedCalendar> list = [];
    final prefs = await SharedPreferences.getInstance();
    final String? v2json = prefs.getString('custom_calendar_mapping_v2');
    Map<String, dynamic> v2Decoded = v2json != null ? jsonDecode(v2json) : {};
    _calendarMap.clear();

    for (var acc in activeAccounts) {
      if (v2Decoded.containsKey(acc.id)) {
        final hrefMap = v2Decoded[acc.id] as Map<String, dynamic>;
        hrefMap.forEach((href, namesStr) {
          if ((namesStr as String).isNotEmpty) {
            list.add(MappedCalendar(acc, href, namesStr));
            _calendarMap[namesStr] = href;
          }
        });
      } else if (acc.id == activeAccounts.first.id) {
        final String? v1json = prefs.getString('custom_calendar_mapping');
        if (v1json != null) {
          final Map<String, dynamic> decoded = jsonDecode(v1json);
          decoded.forEach((href, namesStr) {
            if ((namesStr as String).isNotEmpty) {
              list.add(MappedCalendar(acc, href, namesStr));
              _calendarMap[namesStr] = href;
            }
          });
        }
      }
    }
    return list;
  }

  /// Finds the mapped calendar that exactly matches [participants],
  /// falling back to a generic per-user home collection guess if no
  /// account is configured or no mapping matches.
  static Future<TargetCalendar?> _getTargetForParticipants(List<Employee> participants) async {
    final allAccounts = await SecureVault.getAllAccounts();
    final activeAccounts = allAccounts.where((a) => a.isActive && !a.isReadOnly).toList();
    if (activeAccounts.isEmpty) return null;
    final mappedCals = await _getMappedCalendars(activeAccounts);
    if (participants.isEmpty) return TargetCalendar(activeAccounts.first, "/caldav.php/${activeAccounts.first.username}/home/");

    final names = participants.map((e) => e.name).toList()..sort();
    final key = names.join(",");
    try {
      final match = mappedCals.firstWhere((m) => m.participantNames == key);
      return TargetCalendar(match.account, match.href);
    } catch (e) {
      return TargetCalendar(activeAccounts.first, "/caldav.php/${activeAccounts.first.username}/home/");
    }
  }

  /// Fetches every event across all configured accounts: read-only
  /// `.ics` subscriptions plus every mapped, writable calendar.
  /// [noTitleFallback] is shown for events with no summary - it's
  /// passed in rather than hardcoded, since this static service has
  /// no [BuildContext] to resolve the app's active language itself
  /// (see `calendar_screen.dart`, which passes the localized string).
  static Future<List<CalendarEvent>> fetchAllEvents(List<Employee> allEmployees, {required String noTitleFallback}) async {
    if (!kIsWeb) {
      try {
        await OfflineQueueService.processQueue();
      } catch (e) {
        debugPrint("Ignoring queue error: $e");
      }
    }

    List<CalendarEvent> allServerEvents = [];
    final allAccounts = await SecureVault.getAllAccounts();
    final activeAccounts = allAccounts.where((a) => a.isActive).toList();
    final mappedCals = await _getMappedCalendars(activeAccounts);

    for (var acc in activeAccounts.where((a) => a.isReadOnly)) {
      try {
        final response = await http.get(Uri.parse(acc.url)).timeout(const Duration(seconds: 15));
        if (response.statusCode == 200) {
          allServerEvents.addAll(_parseIcalData(response.body, acc.name, allEmployees, isAbo: true, noTitleFallback: noTitleFallback));
        }
      } catch (e) {
        debugPrint("❌ Subscription error: $e");
      }
    }

    for (var mapped in mappedCals) {
      final String calendarName = mapped.participantNames;
      final String targetCalendarUrl = _buildFullUrl(mapped.account, mapped.href);
      final basicAuth = 'Basic ${base64Encode(utf8.encode('${mapped.account.username}:${mapped.account.password}'))}';

      try {
        final request = http.Request('REPORT', Uri.parse(targetCalendarUrl))
          ..headers['Authorization'] = basicAuth
          ..headers['Depth'] = '1'
          ..headers['Content-Type'] = 'application/xml; charset=utf-8';
        request.body = '''<c:calendar-query xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav"><d:prop><d:getetag /><c:calendar-data /></d:prop><c:filter><c:comp-filter name="VCALENDAR"><c:comp-filter name="VEVENT" /></c:comp-filter></c:filter></c:calendar-query>''';

        final response = await http.Response.fromStream(await request.send().timeout(const Duration(seconds: 20)));
        if (response.statusCode == 207) {
          final document = XmlDocument.parse(response.body);
          for (var resp in document.findAllElements('response', namespace: '*')) {
            final hrefNodes = resp.findAllElements('href', namespace: '*');
            final calDataNodes = resp.findAllElements('calendar-data', namespace: '*');
            if (hrefNodes.isNotEmpty && calDataNodes.isNotEmpty) {
              String eventHref = hrefNodes.first.innerText;
              String fileName = eventHref.split('/').last;
              allServerEvents.addAll(_parseIcalData(calDataNodes.first.innerText, calendarName, allEmployees, fileName: fileName, noTitleFallback: noTitleFallback));
            }
          }
        }
      } catch (e) {
        debugPrint("❌ Network Error: $e");
      }
    }

    allServerEvents.sort((a, b) {
      int dateCompare = a.start.compareTo(b.start);
      if (dateCompare != 0) return dateCompare;
      if (a.isAllDay && !b.isAllDay) return -1;
      if (!a.isAllDay && b.isAllDay) return 1;
      return 0;
    });

    return allServerEvents;
  }

  /// Parses a raw iCal (`VCALENDAR`) string into [CalendarEvent]s,
  /// handling all-day detection, recurrence rules (`RRULE`), and
  /// per-occurrence exclusions (`EXDATE`).
  static List<CalendarEvent> _parseIcalData(String iCalString, String calendarName, List<Employee> allEmployees, {String? fileName, bool isAbo = false, required String noTitleFallback}) {
    List<CalendarEvent> events = [];
    try {
      final icalendar = ICalendar.fromString(iCalString);
      final data = icalendar.data;

      // WORKAROUND: icalendar_parser drops nested TRIGGER/VALARM data from the
      // VEVENT map (confirmed via debug logging), so the reminder is instead
      // read directly from the raw ICS text, keyed by UID.
      final Map<String, String> valarmBlocksByUid = {};
      for (var block in iCalString.split('BEGIN:VEVENT').skip(1)) {
        final uidMatch = RegExp(r'UID:([^\r\n]+)').firstMatch(block);
        if (uidMatch != null) {
          valarmBlocksByUid[uidMatch.group(1)!.trim()] = block;
        }
      }

      for (var component in data) {
        if (component['type'] == 'VEVENT') {
          String title = component['summary'] ?? noTitleFallback;
          if (isAbo) title = "[$calendarName] $title";

          String location = component['location'] ?? '';
          DateTime start = DateTime.now();
          DateTime end = DateTime.now().add(const Duration(hours: 1));
          bool isAllDay = false;

          if (component['dtstart'] != null) {
            final dt = component['dtstart'];
            if (dt is IcsDateTime) {
              start = dt.toDateTime()?.toLocal() ?? DateTime.now();
              if (dt.dt.length <= 8) isAllDay = true;
            } else if (dt is String) start = DateTime.parse(dt).toLocal();
          }

          if (component['dtend'] != null) {
            final dt = component['dtend'];
            if (dt is IcsDateTime) {
              end = dt.toDateTime()?.toLocal() ?? start.add(const Duration(hours: 1));
            } else if (dt is String) {
              end = DateTime.parse(dt).toLocal();
            }
          }

          if (isAllDay) {
            DateTime startTest = DateTime(start.year, start.month, start.day);
            DateTime endTest = DateTime(end.year, end.month, end.day);
            if (endTest.isAfter(startTest)) {
              end = end.subtract(const Duration(days: 1));
            }
          }

          Recurrence recurrence = Recurrence.none;
          List<int> recurrenceDays = [];
          DateTime? recurrenceEndDate;
          List<DateTime> excludeDates = [];

          if (component['exdate'] != null) {
            var exData = component['exdate'];
            List exList = exData is List ? exData : [exData];
            for (var item in exList) {
              if (item is IcsDateTime) {
                DateTime? dt = item.toDateTime()?.toLocal();
                if (dt != null) excludeDates.add(dt);
              } else if (item is String) {
                for (var str in item.split(',')) {
                  if (str.length >= 8) {
                    try {
                      excludeDates.add(DateTime(int.parse(str.substring(0, 4)), int.parse(str.substring(4, 6)), int.parse(str.substring(6, 8))));
                    } catch (_) {}
                  }
                }
              }
            }
          }

          if (component['rrule'] != null) {
            String rruleStr = component['rrule'].toString().toUpperCase();
            if (rruleStr.contains('FREQ=DAILY')) {
              recurrence = Recurrence.daily;
            } else if (rruleStr.contains('FREQ=WEEKLY')) {
              if (rruleStr.contains('INTERVAL=2')) {
                recurrence = Recurrence.biWeekly;
              } else if (rruleStr.contains('BYDAY=')) {
                recurrence = Recurrence.customDays;
                if (rruleStr.contains('MO')) recurrenceDays.add(1);
                if (rruleStr.contains('TU')) recurrenceDays.add(2);
                if (rruleStr.contains('WE')) recurrenceDays.add(3);
                if (rruleStr.contains('TH')) recurrenceDays.add(4);
                if (rruleStr.contains('FR')) recurrenceDays.add(5);
                if (rruleStr.contains('SA')) recurrenceDays.add(6);
                if (rruleStr.contains('SU')) recurrenceDays.add(7);
              } else {
                recurrence = Recurrence.weekly;
              }
            }
            else if (rruleStr.contains('FREQ=MONTHLY')) {
              recurrence = Recurrence.monthly;
            }

            if (component['rrule'] is Map && component['rrule']['UNTIL'] != null) {
              var untilVal = component['rrule']['UNTIL'];
              if (untilVal is IcsDateTime) {
                recurrenceEndDate = untilVal.toDateTime()?.toLocal();
              } else if (untilVal is String) {
                recurrenceEndDate = DateTime.parse(untilVal).toLocal();
              }
            } else if (rruleStr.contains('UNTIL=')) {
              final match = RegExp(r'UNTIL=([0-9T]+)').firstMatch(rruleStr);
              if (match != null && match.group(1)!.length >= 8) {
                String ds = match.group(1)!;
                recurrenceEndDate = DateTime(int.parse(ds.substring(0, 4)), int.parse(ds.substring(4, 6)), int.parse(ds.substring(6, 8)));
              }
            }
          }

          List<Employee> participants = [];
          if (isAbo) {
            participants = allEmployees;
          } else {
            // FIX: trim() prevents a leading space after a comma (e.g. "Anna, Bernd")
            // from breaking the exact-match comparison against employee names,
            // which previously caused participants to silently drop out of team events.
            List<String> namesInKey = calendarName.split(',').map((s) => s.trim()).toList();
            participants = allEmployees.where((emp) => namesInKey.contains(emp.name)).toList();
            if (participants.isEmpty && allEmployees.isNotEmpty) {
              participants = [allEmployees.first];
            }
          }

          // Read the reminder back from the raw ICS text via valarmBlocksByUid
          // (see above), since icalendar_parser discards nested VALARM data.
          bool notificationsEnabled = false;
          int minutesBefore = 15;
          final String? rawBlock = valarmBlocksByUid[component['uid']];
          if (rawBlock != null) {
            final match = RegExp(r'TRIGGER[^:\r\n]*:-PT(\d+)M').firstMatch(rawBlock);
            if (match != null) {
              notificationsEnabled = true;
              minutesBefore = int.parse(match.group(1)!);
            }
          }

          events.add(CalendarEvent(
            uid: component['uid'] ?? '${DateTime.now().millisecondsSinceEpoch}@team-planer',
            href: fileName,
            title: title,
            start: start,
            end: end,
            isAllDay: isAllDay,
            participants: participants,
            notificationsEnabled: notificationsEnabled,
            minutesBefore: minutesBefore,
            color: isAbo ? Colors.blueGrey : (participants.length == 1 ? participants.first.color : GroupColors.getColor(calendarName)),
            location: location,
            recurrence: recurrence,
            recurrenceDays: recurrenceDays,
            recurrenceEndDate: recurrenceEndDate,
            excludeDates: excludeDates,
          ));
        }
      }
    } catch (e) {
      debugPrint("Error parsing iCal data: $e");
    }
    return events;
  }

  /// Checks connectivity against a real CalDAV account only. Read-only ICS
  /// subscriptions don't support PROPFIND, so they must never be picked as
  /// the connection-check target — otherwise a single active ICS subscription
  /// would falsely report the whole app as offline and block sync for every
  /// other account.
  static Future<bool> checkConnection() async {
    try {
      final accounts = await SecureVault.getAllAccounts();
      final active = accounts.where((a) => a.isActive && !a.isReadOnly).toList();

      // Only read-only ICS subscriptions are active: nothing to PROPFIND
      // against. Let the sync flow continue so the abo(s) can still be
      // fetched via their own GET-based path in fetchAllEvents().
      if (active.isEmpty) return true;

      final acc = active.first;
      final basicAuth = 'Basic ${base64Encode(utf8.encode('${acc.username}:${acc.password}'))}';

      final request = http.Request('PROPFIND', Uri.parse(acc.url))
        ..headers['Authorization'] = basicAuth
        ..headers['Depth'] = '0'
        ..headers['Content-Type'] = 'application/xml; charset=utf-8';

      final res = await http.Response.fromStream(await request.send().timeout(const Duration(seconds: 3)));
      return res.statusCode > 0;
    } catch (e) {
      debugPrint("Online-Check Error: $e");
      return false;
    }
  }

  /// Uploads (creates/updates) [event] via `PUT`, either to
  /// [explicitCalendar] or to whichever mapped calendar matches the
  /// event's participants. On network failure (mobile only - the web
  /// build has no persistent queue), the request is queued for later
  /// via [OfflineQueueService].
  static Future<void> syncEvent(CalendarEvent event, {MappedCalendar? explicitCalendar}) async {
    MappedCalendar? target = explicitCalendar;
    if (target == null) {
      final allAccounts = await SecureVault.getAllAccounts();
      final activeAccounts = allAccounts.where((a) => a.isActive && !a.isReadOnly).toList();
      if (activeAccounts.isEmpty) return;
      final mappedCals = await _getMappedCalendars(activeAccounts);
      final names = event.participants.map((e) => e.name).toList()..sort();
      final key = names.join(",");
      try {
        target = mappedCals.firstWhere((m) => m.participantNames == key);
      } catch (_) {
        if (mappedCals.isNotEmpty) target = mappedCals.first;
      }
    }
    if (target == null) return;

    final String targetCalendarUrl = _buildFullUrl(target.account, target.href);
    final Map<String, String> headers = {
      'Authorization': 'Basic ${base64Encode(utf8.encode('${target.account.username}:${target.account.password}'))}',
      'Content-Type': 'text/calendar; charset=utf-8'
    };

    String fileName = event.href ?? '${event.uid.replaceAll(RegExp(r'[^a-zA-Z0-9-@]'), '_')}.ics';
    final eventUrl = "$targetCalendarUrl$fileName";
    final iCalData = generateICalEvent(event, event.uid);

    try {
      final response = await http.put(Uri.parse(eventUrl), headers: headers, body: utf8.encode(iCalData)).timeout(const Duration(seconds: 4));
      if (response.statusCode == 201 || response.statusCode == 204) {
        debugPrint("✅ Event synced directly.");
      } else {
        throw Exception("Server Error ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("📡 Network error. Queuing PUT request...");
      if (!kIsWeb) {
        await OfflineQueueService.enqueue(QueuedRequest(id: event.uid, method: 'PUT', url: eventUrl, headers: headers, body: iCalData));
      }
    }
  }

  /// Deletes [event] from the server. If [excludeDate] is given for a
  /// recurring event, only that single occurrence is excluded (via an
  /// updated `EXDATE`) rather than deleting the whole series. Falls
  /// back to the offline queue on network failure, same as [syncEvent].
  static Future<void> deleteEvent(CalendarEvent event, {DateTime? excludeDate, MappedCalendar? explicitCalendar}) async {
    MappedCalendar? target = explicitCalendar;
    if (target == null) {
      final allAccounts = await SecureVault.getAllAccounts();
      final activeAccounts = allAccounts.where((a) => a.isActive && !a.isReadOnly).toList();
      if (activeAccounts.isEmpty) return;
      final mappedCals = await _getMappedCalendars(activeAccounts);
      final names = event.participants.map((e) => e.name).toList()..sort();
      final key = names.join(",");
      try {
        target = mappedCals.firstWhere((m) => m.participantNames == key);
      } catch (_) {
        if (mappedCals.isNotEmpty) target = mappedCals.first;
      }
    }
    if (target == null) return;

    final String targetCalendarUrl = _buildFullUrl(target.account, target.href);
    final Map<String, String> headers = {
      'Authorization': 'Basic ${base64Encode(utf8.encode('${target.account.username}:${target.account.password}'))}',
      'Content-Type': 'text/calendar; charset=utf-8'
    };
    String fileName = event.href ?? '${event.uid.replaceAll(RegExp(r'[^a-zA-Z0-9-@]'), '_')}.ics';
    final eventUrl = "$targetCalendarUrl$fileName";

    try {
      if (excludeDate != null && event.recurrence != Recurrence.none) {
        String iCalData = generateICalEvent(event, event.uid, excludeDate: excludeDate);
        await http.put(Uri.parse(eventUrl), headers: headers, body: utf8.encode(iCalData)).timeout(const Duration(seconds: 4));
      } else {
        await http.delete(Uri.parse(eventUrl), headers: headers).timeout(const Duration(seconds: 4));
      }
    } catch (e) {
      debugPrint("📡 Network error. Queuing DELETE/EXCLUDE request...");
      if (!kIsWeb) {
        if (excludeDate != null && event.recurrence != Recurrence.none) {
          String iCalData = generateICalEvent(event, event.uid, excludeDate: excludeDate);
          await OfflineQueueService.enqueue(QueuedRequest(id: event.uid, method: 'PUT', url: eventUrl, headers: headers, body: iCalData));
        } else {
          await OfflineQueueService.enqueue(QueuedRequest(id: event.uid, method: 'DELETE', url: eventUrl, headers: headers));
        }
      }
    }
  }

  /// Builds the raw `VCALENDAR`/`VEVENT` iCal payload for [event],
  /// including `RRULE` for recurring events and `EXDATE` for
  /// exclusions (optionally adding [excludeDate] to the existing list,
  /// used when deleting a single occurrence of a series).
  static String generateICalEvent(CalendarEvent event, String uid, {DateTime? excludeDate}) {
    final String dtStamp = DateFormat("yyyyMMdd'T'HHmmss'Z'").format(DateTime.now().toUtc());
    String ds, de;
    if (event.isAllDay) {
      ds = "DTSTART;VALUE=DATE:${DateFormat("yyyyMMdd").format(event.start.toLocal())}";
      de = "DTEND;VALUE=DATE:${DateFormat("yyyyMMdd").format(event.end.toLocal().add(const Duration(days: 1)))}";
    } else {
      ds = "DTSTART:${DateFormat("yyyyMMdd'T'HHmmss'Z'").format(event.start.toUtc())}";
      de = "DTEND:${DateFormat("yyyyMMdd'T'HHmmss'Z'").format(event.end.toUtc())}";
    }
    String r = "";
    if (event.recurrence != Recurrence.none) {
      r = "RRULE:FREQ=";
      if (event.recurrence == Recurrence.daily) {
        r += "DAILY";
      } else if (event.recurrence == Recurrence.weekly) r += "WEEKLY";
      else if (event.recurrence == Recurrence.biWeekly) r += "WEEKLY;INTERVAL=2";
      else if (event.recurrence == Recurrence.monthly) r += "MONTHLY";
      else if (event.recurrence == Recurrence.customDays) r += "WEEKLY;BYDAY=${event.recurrenceDays.map((d) => ["MO", "TU", "WE", "TH", "FR", "SA", "SU"][d - 1]).join(",")}";

      if (event.recurrenceEndDate != null) {
        r += ";UNTIL=${DateFormat("yyyyMMdd'T'235959'Z'").format(event.recurrenceEndDate!.toUtc())}";
      }
      r += "\n";
    }
    String ex = "";
    List<DateTime> allEx = List.from(event.excludeDates);
    if (excludeDate != null && !allEx.any((d) => d.year == excludeDate.year && d.month == excludeDate.month && d.day == excludeDate.day)) {
      allEx.add(excludeDate);
    }
    if (allEx.isNotEmpty) {
      ex = "EXDATE;VALUE=DATE:${allEx.map((d) => DateFormat("yyyyMMdd").format(d.toLocal())).join(",")}\n";
    }

    // Persist the reminder as a standard VALARM component so it survives
    // every CalDAV sync/re-fetch and works across all devices, instead of
    // living only in local app state.
    String va = "";
    if (event.notificationsEnabled) {
      va = "BEGIN:VALARM\nACTION:DISPLAY\nDESCRIPTION:Reminder\nTRIGGER:-PT${event.minutesBefore}M\nEND:VALARM\n";
    }

    return '''BEGIN:VCALENDAR\nVERSION:2.0\nPRODID:-//Team Planer App//DE\nBEGIN:VEVENT\nUID:$uid\nDTSTAMP:$dtStamp\n$ds\n$de\nSUMMARY:${event.title}\nDESCRIPTION:Teilnehmer: ${event.participants.map((p) => p.name).join(', ')}\nLOCATION:${event.location}\n$r$ex${va}END:VEVENT\nEND:VCALENDAR''';
  }

  // --- To-do functions ---

  /// Accounts that have the to-do module enabled (see the workspace
  /// editor in `settings_screen.dart`).
  static Future<List<CalDavAccount>> getTodoAccounts() async {
    final all = await SecureVault.getAllAccounts();
    return all.where((a) => a.isActive && a.syncTodos && !a.isReadOnly).toList();
  }

  /// Resolves [acc]'s calendar-home collection URL via
  /// principal/calendar-home discovery, falling back to a common
  /// Nextcloud/ownCloud-style path if discovery doesn't find one.
  static Future<String> _getCalendarHome(CalDavAccount acc) async {
    final basicAuth = 'Basic ${base64Encode(utf8.encode('${acc.username}:${acc.password}'))}';
    String base = acc.url;
    if (base.endsWith('/')) base = base.substring(0, base.length - 1);

    String principalUrl = "";
    List<String> principalTargets = [base, "$base/remote.php/dav/", "$base/.well-known/caldav"];

    for (String target in principalTargets) {
      if (principalUrl.isNotEmpty) break;
      try {
        final req = http.Request('PROPFIND', Uri.parse(target))
          ..headers['Authorization'] = basicAuth
          ..headers['Depth'] = '0'
          ..headers['Content-Type'] = 'application/xml; charset=utf-8';
        req.body = '''<d:propfind xmlns:d="DAV:"><d:prop><d:current-user-principal /></d:prop></d:propfind>''';

        final res = await http.Response.fromStream(await req.send().timeout(const Duration(seconds: 5)));
        if (res.statusCode == 207 || res.statusCode == 200) {
          final doc = XmlDocument.parse(res.body);
          final principalNodes = doc.findAllElements('current-user-principal', namespace: '*');
          if (principalNodes.isNotEmpty) {
            final hrefs = principalNodes.first.findAllElements('href', namespace: '*');
            if (hrefs.isNotEmpty) principalUrl = hrefs.first.innerText;
          }
        }
      } catch (_) {}
    }

    String calendarHomeUrl = "";
    if (principalUrl.isNotEmpty) {
      try {
        String origin = Uri.parse(base).origin;
        final String target = principalUrl.startsWith('http') ? principalUrl : "$origin$principalUrl";

        final reqHome = http.Request('PROPFIND', Uri.parse(target))
          ..headers['Authorization'] = basicAuth
          ..headers['Depth'] = '0'
          ..headers['Content-Type'] = 'application/xml; charset=utf-8';
        reqHome.body = '''<d:propfind xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav"><d:prop><c:calendar-home-set /></d:prop></d:propfind>''';

        final resHome = await http.Response.fromStream(await reqHome.send().timeout(const Duration(seconds: 5)));
        if (resHome.statusCode == 207 || resHome.statusCode == 200) {
          final homeNodes = XmlDocument.parse(resHome.body).findAllElements('calendar-home-set', namespace: '*');
          if (homeNodes.isNotEmpty) {
            final hrefs = homeNodes.first.findAllElements('href', namespace: '*');
            if (hrefs.isNotEmpty) calendarHomeUrl = hrefs.first.innerText;
          }
        }
      } catch (_) {}
    }

    if (calendarHomeUrl.isNotEmpty) {
      String origin = Uri.parse(base).origin;
      return calendarHomeUrl.startsWith('http') ? calendarHomeUrl : "$origin$calendarHomeUrl";
    }

    return "$base/remote.php/dav/calendars/${acc.username}/";
  }

  /// Determines whether a CalDAV collection path represents a private list.
  /// Privacy is encoded directly in the server path so that every device
  /// can derive it from a plain PROPFIND, without relying on local device state.
  static bool isPrivatePath(String path) {
    return path.toLowerCase().contains('/list_private_');
  }

  static Future<String?> createNewList(String listName, {bool isPrivate = false, CalDavAccount? account}) async {
    final acc = account ?? (await getTodoAccounts()).firstOrNull;
    if (acc == null) return null;

    final String homeUrl = await _getCalendarHome(acc);
    final String uid = DateTime.now().millisecondsSinceEpoch.toString();
    final String marker = isPrivate ? 'list_private_' : 'list_shared_';
    final String calendarUrl = "$homeUrl$marker$uid/";

    try {
      final res = await http.Response.fromStream(
          await (http.Request('MKCOL', Uri.parse(calendarUrl))
            ..headers['Authorization'] = 'Basic ${base64Encode(utf8.encode('${acc.username}:${acc.password}'))}'
            ..headers['Content-Type'] = 'application/xml; charset=utf-8'
            ..body = '''<?xml version="1.0" encoding="utf-8" ?><mkcol xmlns="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav"><set><prop><resourcetype><collection/><C:calendar/></resourcetype><C:supported-calendar-component-set><C:comp name="VTODO"/></C:supported-calendar-component-set><displayname>$listName</displayname></prop></set></mkcol>''')
              .send());
      if (res.statusCode == 201) return Uri.parse(calendarUrl).path;
    } catch (_) {}
    return null;
  }

  /// Moves a list from [oldPath] to [newPath] on the server via WebDAV MOVE.
  /// Used to migrate legacy, locally-flagged private lists to the new
  /// path-based scheme. Some servers (e.g. Synology) reject MOVE for security
  /// reasons - callers must handle a `false` return gracefully, not assume success.
  static Future<bool> moveList(String oldPath, String newPath, {CalDavAccount? account}) async {
    final acc = account ?? (await getTodoAccounts()).firstOrNull;
    if (acc == null) return false;

    final String oldUrl = _buildFullUrl(acc, oldPath);
    final String newUrl = _buildFullUrl(acc, newPath);

    try {
      final res = await http.Response.fromStream(
          await (http.Request('MOVE', Uri.parse(oldUrl))
            ..headers['Authorization'] = 'Basic ${base64Encode(utf8.encode('${acc.username}:${acc.password}'))}'
            ..headers['Destination'] = newUrl
            ..headers['Overwrite'] = 'F')
              .send());
      return res.statusCode == 201 || res.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, String>> fetchTodoLists({CalDavAccount? account}) async {
    final acc = account ?? (await getTodoAccounts()).firstOrNull;
    if (acc == null) return {};

    Map<String, String> lists = {};
    final String targetUrl = await _getCalendarHome(acc);
    final basicAuth = 'Basic ${base64Encode(utf8.encode('${acc.username}:${acc.password}'))}';

    try {
      final request = http.Request('PROPFIND', Uri.parse(targetUrl))
        ..headers['Authorization'] = basicAuth
        ..headers['Depth'] = '1'
        ..headers['Content-Type'] = 'application/xml; charset=utf-8';

      request.body = '''<d:propfind xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav"><d:prop><d:displayname /><d:resourcetype /><c:supported-calendar-component-set /></d:prop></d:propfind>''';

      final response = await http.Response.fromStream(await request.send().timeout(const Duration(seconds: 4)));
      if (response.statusCode == 207) {
        final responseString = utf8.decode(response.bodyBytes, allowMalformed: true);
        final doc = XmlDocument.parse(responseString);

        for (var resp in doc.findAllElements('response', namespace: '*')) {
          bool isTodo = false;

          final compElements = resp.findAllElements('comp', namespace: '*');
          for (var c in compElements) {
            if (c.getAttribute('name')?.toUpperCase() == 'VTODO') {
              isTodo = true;
              break;
            }
          }

          if (!isTodo) {
            final hNodes = resp.findAllElements('href', namespace: '*');
            final nNodes = resp.findAllElements('displayname', namespace: '*');

            if (hNodes.isNotEmpty && nNodes.isNotEmpty) {
              final hrefLower = hNodes.first.innerText.toLowerCase();
              final nameLower = nNodes.first.innerText.toLowerCase();

              bool createdByOurApp = hrefLower.contains('/list_');
              bool hasTodoName = nameLower.contains('todo') ||
                  nameLower.contains('list') ||
                  nameLower.contains('aufgabe') ||
                  nameLower.contains('einkauf') ||
                  nameLower.contains('käufe') ||
                  nameLower.contains('task');

              if (createdByOurApp || hasTodoName) {
                final resType = resp.findAllElements('resourcetype', namespace: '*');
                if (resType.isNotEmpty && resType.first.findAllElements('collection', namespace: '*').isNotEmpty) {
                  isTodo = true;
                }
              }
            }
          }

          if (isTodo) {
            final h = resp.findAllElements('href', namespace: '*');
            final n = resp.findAllElements('displayname', namespace: '*');
            if (h.isNotEmpty && n.isNotEmpty) {
              if (!h.first.innerText.endsWith('calendars/${acc.username}/')) {
                lists[n.first.innerText] = h.first.innerText;
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint("FetchTodoLists Error: $e");
    }
    return lists;
  }

  /// Fetches all `VTODO` tasks in the collection at [path].
  /// [unnamedFallback] is shown for tasks with no summary - passed in
  /// for the same reason as [fetchAllEvents]'s `noTitleFallback` (see
  /// there): this static service has no [BuildContext] of its own.
  static Future<List<TodoTask>> fetchTasks(String path, {CalDavAccount? account, required String unnamedFallback}) async {
    final acc = account ?? (await getTodoAccounts()).firstOrNull;
    if (acc == null) return [];

    List<TodoTask> tasks = [];
    try {
      final res = await http.Response.fromStream(await (http.Request('REPORT', Uri.parse(_buildFullUrl(acc, path)))
        ..headers['Authorization'] = 'Basic ${base64Encode(utf8.encode('${acc.username}:${acc.password}'))}'
        ..headers['Depth'] = '1'
        ..headers['Content-Type'] = 'application/xml; charset=utf-8'
        ..body = '''<c:calendar-query xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav"><d:prop><c:calendar-data /></d:prop><c:filter><c:comp-filter name="VCALENDAR"><c:comp-filter name="VTODO" /></c:comp-filter></c:filter></c:calendar-query>''')
          .send());

      if (res.statusCode == 207) {
        final doc = XmlDocument.parse(res.body);
        for (var resp in doc.findAllElements('response', namespace: '*')) {
          final calData = resp.findAllElements('calendar-data', namespace: '*');
          if (calData.isNotEmpty) {
            final ical = ICalendar.fromString(calData.first.innerText);
            for (var comp in ical.data) {
              if (comp['type'] == 'VTODO') {
                debugPrint("🔍 Task '${comp['summary']}': Status=${comp['status']}, Percent=${comp['percent-complete']}, HasCompleted=${comp.containsKey('completed')}");

                // Smarter parsing of the completed/done status: some
                // servers (e.g. Synology) leave a stale COMPLETED
                // timestamp on a task that's since been reopened, so
                // an explicit "still open" status always wins over
                // just checking for a `completed` timestamp.
                String statusStr = (comp['status'] ?? '').toString().toUpperCase();
                String percentStr = (comp['percent-complete'] ?? '').toString();

                bool isDone = false;

                // 1. An explicit "not done yet" status always means open,
                //    regardless of any stale completion data present.
                if (statusStr.contains('NEEDS-ACTION') || statusStr.contains('IN-PROCESS') || percentStr == '0') {
                  isDone = false;
                }
                // 2. Otherwise, check for an explicit "done" signal.
                else if (statusStr.contains('COMPLETED') || percentStr == '100' || comp.containsKey('completed')) {
                  isDone = true;
                }

                tasks.add(TodoTask(
                    uid: comp['uid']?.toString() ?? '',
                    title: comp['summary']?.toString() ?? unnamedFallback,
                    isDone: isDone,
                    description: comp['description']?.toString(),
                    dueDate: comp['due'] != null ? DateTime.tryParse(comp['due'].toString()) : null));
              }
            }
          }
        }
      }
    } catch (_) {}
    return tasks;
  }

  /// Creates a new `VTODO` task named [title] in the collection at
  /// [path].
  static Future<bool> addTask(String path, String title, {String? description, DateTime? dueDate, CalDavAccount? account}) async {
    final acc = account ?? (await getTodoAccounts()).firstOrNull;
    if (acc == null) return false;

    final uid = DateTime.now().millisecondsSinceEpoch.toString();
    final nowZ = "${DateTime.now().toUtc().toIso8601String().replaceAll(RegExp(r'[:-]'), '').split('.')[0]}Z";
    String dLine = description != null ? "DESCRIPTION:${description.replaceAll('\n', '\\n')}\r\n" : "";
    String duLine = dueDate != null ? "DUE:${dueDate.toUtc().toIso8601String().replaceAll(RegExp(r'[:-]'), '').split('.')[0]}Z\r\n" : "";

    try {
      final res = await http.put(
          Uri.parse("${_buildFullUrl(acc, path)}$uid.ics"),
          headers: {
            'Authorization': 'Basic ${base64Encode(utf8.encode('${acc.username}:${acc.password}'))}',
            'Content-Type': 'text/calendar; charset=utf-8'
          },
          body: utf8.encode('BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//FamilyApp//DE\r\nBEGIN:VTODO\r\nUID:$uid\r\nDTSTAMP:$nowZ\r\nSUMMARY:$title\r\n$dLine$duLine' 'STATUS:NEEDS-ACTION\r\nEND:VTODO\r\nEND:VCALENDAR'));
      return (res.statusCode == 201 || res.statusCode == 204);
    } catch (_) {
      return false;
    }
  }

  /// Overwrites the `VTODO` at [path]/`{task.uid}.ics` with [task]'s
  /// current state (including its done/not-done status).
  static Future<bool> updateTask(String path, TodoTask task, {CalDavAccount? account}) async {
    final acc = account ?? (await getTodoAccounts()).firstOrNull;
    if (acc == null) return false;

    final nowZ = "${DateTime.now().toUtc().toIso8601String().replaceAll(RegExp(r'[:-]'), '').split('.')[0]}Z";
    String dLine = task.description != null ? "DESCRIPTION:${task.description!.replaceAll('\n', '\\n')}\r\n" : "";
    String duLine = task.dueDate != null ? "DUE:${task.dueDate!.toUtc().toIso8601String().replaceAll(RegExp(r'[:-]'), '').split('.')[0]}Z\r\n" : "";
    String s = task.isDone ? "COMPLETED" : "NEEDS-ACTION";
    String c = task.isDone ? "COMPLETED:$nowZ\r\nPERCENT-COMPLETE:100\r\n" : "PERCENT-COMPLETE:0\r\n";

    try {
      final res = await http.put(
          Uri.parse("${_buildFullUrl(acc, path)}${task.uid}.ics"),
          headers: {
            'Authorization': 'Basic ${base64Encode(utf8.encode('${acc.username}:${acc.password}'))}',
            'Content-Type': 'text/calendar; charset=utf-8'
          },
          body: utf8.encode('BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//FamilyApp//DE\r\nBEGIN:VTODO\r\nUID:${task.uid}\r\nDTSTAMP:$nowZ\r\nSUMMARY:${task.title}\r\n$dLine$duLine' 'STATUS:$s\r\n$c' 'END:VTODO\r\nEND:VCALENDAR'));
      return (res.statusCode >= 200 && res.statusCode < 300);
    } catch (_) {
      return false;
    }
  }

  /// Deletes the whole collection at [path] via `DELETE`. Note that
  /// some servers (Synology in particular) reject this for
  /// third-party apps - callers should show the user an explanation
  /// when this returns `false` (see `todo_screen.dart`'s
  /// "blocked by server" dialog).
  static Future<bool> deleteList(String path, {required CalDavAccount account}) async {
    try {
      String targetUrl = _buildFullUrl(account, path);
      if (!targetUrl.endsWith('/')) targetUrl += '/';
      final basicAuth = 'Basic ${base64Encode(utf8.encode('${account.username}:${account.password}'))}';

      debugPrint("🗑️ Sending DELETE request to $targetUrl");

      final response = await http.delete(
          Uri.parse(targetUrl),
          headers: {'Authorization': basicAuth}
      ).timeout(const Duration(seconds: 15)); // Generous timeout for slower NAS devices.

      debugPrint("🗑️ Delete list status: ${response.statusCode}");
      if (response.statusCode >= 400) {
        debugPrint("🗑️ Delete list error response: ${response.body}");
      }

      return (response.statusCode >= 200 && response.statusCode < 300);
    } catch (e) {
      debugPrint("❌ Delete list exception: $e");
      return false;
    }
  }

  /// Renames the collection at [path] to [newName] via `PROPPATCH`.
  /// Same server-support caveat as [deleteList] applies.
  static Future<bool> renameList(String path, String newName, {required CalDavAccount account}) async {
    try {
      String targetUrl = _buildFullUrl(account, path);
      if (!targetUrl.endsWith('/')) targetUrl += '/';
      final basicAuth = 'Basic ${base64Encode(utf8.encode('${account.username}:${account.password}'))}';

      final body = '''<?xml version="1.0" encoding="utf-8" ?>
        <d:propertyupdate xmlns:d="DAV:">
          <d:set><d:prop><d:displayname>$newName</d:displayname></d:prop></d:set>
        </d:propertyupdate>''';

      debugPrint("✏️ Sending PROPPATCH request to $targetUrl");

      final req = http.Request('PROPPATCH', Uri.parse(targetUrl))
        ..headers['Authorization'] = basicAuth
        ..headers['Content-Type'] = 'application/xml; charset=utf-8'
        ..body = body;

      final response = await http.Response.fromStream(await req.send().timeout(const Duration(seconds: 15)));

      debugPrint("✏️ Rename list status: ${response.statusCode}");
      if (response.statusCode >= 400) {
        debugPrint("✏️ Rename list error response: ${response.body}");
      }

      return (response.statusCode >= 200 && response.statusCode < 300);
    } catch (e) {
      debugPrint("❌ Rename list exception: $e");
      return false;
    }
  }

  /// Deletes the `VTODO` at [path]/`$uid.ics`.
  static Future<bool> deleteTask(String path, String uid, {CalDavAccount? account}) async {
    final acc = account ?? (await getTodoAccounts()).firstOrNull;
    if (acc == null) return false;

    try {
      final url = "${_buildFullUrl(acc, path)}$uid.ics";
      final basicAuth = 'Basic ${base64Encode(utf8.encode('${acc.username}:${acc.password}'))}';

      final res = await http.delete(Uri.parse(url), headers: {'Authorization': basicAuth});
      return (res.statusCode >= 200 && res.statusCode < 300);
    } catch (_) {
      return false;
    }
  }
}