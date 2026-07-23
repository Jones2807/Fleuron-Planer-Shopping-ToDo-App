import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:flutter/scheduler.dart' show SchedulerBinding;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;

// Models & services
import '../models/employee.dart';
import '../models/calendar_event.dart';
import '../services/caldav_service.dart';
import '../services/database_service.dart';
import '../services/secure_vault.dart';
import '../services/group_colors.dart';
import '../widgets/app_drawer.dart';
import '../services/offline_queue_service.dart';
import '../widgets/calendar_dialogs.dart'; // Filters & search
import '../services/holiday_service.dart';
import '../services/notification_service.dart';
import '../l10n/app_localizations.dart';

// Other screens
import 'todo_screen.dart';
import 'shopping_list_screen.dart';
import 'event_editor_screen.dart'; // The event editor

/// Main screen of the app: calendar grid, day/week agenda, and the
/// entry points to the to-do list and shopping list.
class TeamCalendarScreen extends StatefulWidget {
  const TeamCalendarScreen({super.key});

  @override
  State<TeamCalendarScreen> createState() => _TeamCalendarScreenState();
}

/// State for [TeamCalendarScreen].
///
/// Owns the currently loaded events, the active user/filter selection,
/// and the calendar's view state (month/2-weeks/week). Data is
/// restored from the local cache first for a fast first paint, then
/// refreshed from the CalDAV server in the background.
class _TeamCalendarScreenState extends State<TeamCalendarScreen> {
  List<Employee> allEmployees = [];

  late Set<Employee> visibleEmployees;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  List<CalendarEvent> _allEvents = [];

  bool _isLoadingEvents = false;
  bool _isShowingDialog = false;

  bool _showWeekNumbers = false;
  bool _grayOutPastEvents = true;
  bool _showHolidays = true;

  Employee? _currentUser;
  final int _selectedIndex = 0;

  /// Locale tag understood by `intl`'s [DateFormat] and by
  /// `table_calendar`, derived from the app's active language. Falls
  /// back to English for any language other than German.
  String get _dateLocaleTag =>
      Localizations.localeOf(context).languageCode == 'de' ? 'de_DE' : 'en_US';

  @override
  void initState() {
    super.initState();
    HolidayService.loadHolidays(DateTime.now().year);
    visibleEmployees = {};
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await _loadSettings();
    await _initCalDav();
  }

  /// Loads the saved team, the active user, and display preferences
  /// (week numbers, gray-out past events, holidays) from local
  /// storage. Falls back to a single default employee if no team has
  /// been configured yet.
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    final allAccounts = await SecureVault.getAllAccounts();
    final activeAccounts = allAccounts.where((a) => a.isActive).toList();

    Map<String, Employee> uniqueEmployees = {};

    for (var acc in activeAccounts) {
      final String? teamJson = prefs.getString('saved_team_${acc.id}');
      if (teamJson != null) {
        final List<dynamic> decoded = jsonDecode(teamJson);
        for (var e in decoded) {
          final emp = Employee.fromJson(e);
          uniqueEmployees[emp.name] = emp;
        }
      }
    }

    if (uniqueEmployees.isEmpty) {
      final String? globalJson = prefs.getString('saved_team');
      if (globalJson != null) {
        final List<dynamic> decoded = jsonDecode(globalJson);
        for (var e in decoded) {
          final emp = Employee.fromJson(e);
          uniqueEmployees[emp.name] = emp;
        }
      } else {
        uniqueEmployees["Ich"] = const Employee("Ich", Color(0xFF4A73D1));
      }
    }

    allEmployees = uniqueEmployees.values.toList();

    await GroupColors.loadColors();

    setState(() {
      visibleEmployees = allEmployees.toSet();
      _showWeekNumbers = prefs.getBool('showWeekNumbers') ?? false;
      _grayOutPastEvents = prefs.getBool('grayOutPastEvents') ?? true;
      _showHolidays = prefs.getBool('showHolidays') ?? true;

      final savedUser = prefs.getString('currentUser');
      if (savedUser != null) {
        _currentUser = allEmployees.firstWhere((e) => e.name == savedUser, orElse: () => allEmployees.first);
      } else {
        _currentUser = allEmployees.first;
      }

      final savedFilters = prefs.getStringList('visibleEmployees');
      if (savedFilters != null) {
        visibleEmployees = allEmployees.where((e) => savedFilters.contains(e.name)).toSet();
      }
    });
  }

  /// Shows a dialog to pick which team member is currently using this
  /// device (used to attribute new events/todos to the right person).
  void _showUserSwitchDialog() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.userSwitchDialogTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: allEmployees.map((emp) => ListTile(
            leading: CircleAvatar(
              backgroundColor: emp.color,
              child: Text(emp.initials, style: const TextStyle(color: Colors.white)),
            ),
            title: Text(emp.name),
            trailing: _currentUser?.name == emp.name ? const Icon(Icons.check, color: Colors.green) : null,
            onTap: () {
              _saveUser(emp);
              Navigator.pop(context);
            },
          )).toList(),
        ),
      ),
    );
  }

  Future<void> _saveUser(Employee emp) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _currentUser = emp);
    await prefs.setString('currentUser', emp.name);
  }

  Future<void> _saveFilters(Set<Employee> newSet) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => visibleEmployees = newSet);
    await prefs.setStringList('visibleEmployees', newSet.map((e) => e.name).toList());
  }

  /// Shows the dialog for choosing the holiday country/region, used
  /// to decide which public holidays get highlighted in the calendar.
  void _showLocalizationSettingsDialog() async {
    final prefs = await SharedPreferences.getInstance();

    String selectedCountry = prefs.getString('holiday_country') ?? 'DE';
    String selectedRegion = prefs.getString('holiday_region') ?? 'DE-BY';

    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;

    final Map<String, String> countries = {
      'DE': l10n.countryGermany,
      'AT': l10n.countryAustria,
      'CH': l10n.countrySwitzerland,
    };

    // German state names are intentionally kept in their native form -
    // they're official designations, not everyday vocabulary that
    // should be translated.
    final Map<String, String> germanRegions = {
      'NONE': l10n.regionNone,
      'DE-BW': 'Baden-Württemberg',
      'DE-BY': 'Bayern',
      'DE-BE': 'Berlin',
      'DE-BB': 'Brandenburg',
      'DE-HB': 'Bremen',
      'DE-HH': 'Hamburg',
      'DE-HE': 'Hessen',
      'DE-MV': 'Mecklenburg-Vorpommern',
      'DE-NI': 'Niedersachsen',
      'DE-NW': 'Nordrhein-Westfalen',
      'DE-RP': 'Rheinland-Pfalz',
      'DE-SL': 'Saarland',
      'DE-SN': 'Sachsen',
      'DE-ST': 'Sachsen-Anhalt',
      'DE-SH': 'Schleswig-Holstein',
      'DE-TH': 'Thüringen',
    };

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(l10n.holidaySettingsTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.holidaySettingsDescription, style: const TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 24),

              DropdownButtonFormField<String>(
                initialValue: selectedCountry,
                decoration: InputDecoration(labelText: l10n.countryLabel, border: const OutlineInputBorder(), contentPadding: const EdgeInsets.symmetric(horizontal: 12)),
                items: countries.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                onChanged: (val) {
                  setDialogState(() {
                    selectedCountry = val!;
                    if (selectedCountry != 'DE') selectedRegion = 'NONE';
                  });
                },
              ),
              const SizedBox(height: 16),

              if (selectedCountry == 'DE')
                DropdownButtonFormField<String>(
                  initialValue: germanRegions.containsKey(selectedRegion) ? selectedRegion : 'NONE',
                  decoration: InputDecoration(labelText: l10n.regionLabel, border: const OutlineInputBorder(), contentPadding: const EdgeInsets.symmetric(horizontal: 12)),
                  items: germanRegions.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                  onChanged: (val) => setDialogState(() => selectedRegion = val!),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A73D1), foregroundColor: Colors.white),
              onPressed: () async {
                await prefs.setString('holiday_country', selectedCountry);
                await prefs.setString('holiday_region', selectedRegion);

                // Re-fetch holidays for the newly selected country/region.
                await HolidayService.loadHolidays(DateTime.now().year);

                if (mounted) {
                  Navigator.pop(context);
                  setState(() {}); // Force the calendar to redraw with the new holidays.
                }
              },
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }

  /// Restores cached events immediately, then re-syncs against the
  /// CalDAV server if credentials are configured and the device is
  /// online.
  Future<void> _initCalDav() async {
    bool hasCredentials = await CalDavConfig.loadFromVault();

    if (!hasCredentials) {
      debugPrint("No credentials found.");
      setState(() => _isLoadingEvents = false);
      return;
    }

    List<CalendarEvent> cachedEvents = kIsWeb
        ? await WebEventCache.loadEvents(allEmployees)
        : await LocalDatabase.instance.getCachedEvents(allEmployees);

    if (mounted && cachedEvents.isNotEmpty) {
      setState(() => _allEvents = cachedEvents);
    }

    setState(() => _isLoadingEvents = true);

    bool isOnline = await CalDavService.checkConnection();

    if (!isOnline) {
      if (mounted) setState(() => _isLoadingEvents = false);
      return;
    }

    await CalDavService.discoverCalendars(allEmployees);
    await _loadEventsFromServer();
  }

  /// Fetches all events from the CalDAV server and refreshes both the
  /// in-memory state and the local cache (SQLite on mobile, an
  /// in-memory/web cache on the web build).
  ///
  /// Bails out early if the device is offline, rather than calling
  /// the server. Without this check, a network failure would make
  /// [CalDavService.fetchAllEvents] quietly return an empty list
  /// (it swallows per-account errors internally), which would then
  /// get written straight into the cache - wiping out perfectly
  /// good cached events just because there was no connection.
  Future<void> _loadEventsFromServer() async {
    setState(() => _isLoadingEvents = true);

    final isOnline = await CalDavService.checkConnection();
    if (!isOnline) {
      if (mounted) setState(() => _isLoadingEvents = false);
      return;
    }

    try {
      final l10n = AppLocalizations.of(context)!;
      final events = await CalDavService.fetchAllEvents(allEmployees, noTitleFallback: l10n.untitledEventFallback);

      // The native SQLite cache is only available on mobile builds.
      if (!kIsWeb) {
        await LocalDatabase.instance.updateCache(events);
      }

      await WebEventCache.saveEvents(events);

      if (mounted) {
        setState(() {
          _allEvents = events;
          _isLoadingEvents = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading events from server: $e");
      if (mounted) setState(() => _isLoadingEvents = false);
    }
  }

  /// Returns all events that occur on [day], expanding recurrence
  /// rules and applying exclusions and the current employee filter.
  /// Sorted so all-day events come first, then by start time, then by
  /// duration (longer events first for equal start times).
  List<CalendarEvent> _getEventsForDay(DateTime day) {
    final filteredEvents = _allEvents.where((event) {
      DateTime checkDateOnly = DateTime(day.year, day.month, day.day);
      DateTime startOnly = DateTime(event.start.year, event.start.month, event.start.day);
      DateTime endOnly = DateTime(event.end.year, event.end.month, event.end.day);

      bool isExcluded = event.excludeDates.any((ex) =>
      ex.year == checkDateOnly.year &&
          ex.month == checkDateOnly.month &&
          ex.day == checkDateOnly.day);
      if (isExcluded) return false;

      bool isOccurring = false;

      if (!checkDateOnly.isBefore(startOnly) && !checkDateOnly.isAfter(endOnly)) {
        isOccurring = true;
      } else if (event.recurrence != Recurrence.none && !checkDateOnly.isBefore(startOnly)) {
        if (event.recurrenceEndDate != null && checkDateOnly.isAfter(event.recurrenceEndDate!)) {
          isOccurring = false;
        } else {
          int diffDays = checkDateOnly.difference(startOnly).inDays;
          if (event.recurrence == Recurrence.daily) {
            isOccurring = true;
          } else if (event.recurrence == Recurrence.weekly) isOccurring = diffDays % 7 == 0;
          else if (event.recurrence == Recurrence.biWeekly) isOccurring = diffDays % 14 == 0;
          else if (event.recurrence == Recurrence.monthly) isOccurring = startOnly.day == checkDateOnly.day;
          else if (event.recurrence == Recurrence.customDays) isOccurring = event.recurrenceDays.contains(checkDateOnly.weekday);
        }
      }

      final visibleNames = visibleEmployees.map((e) => e.name).toSet();
      return isOccurring && event.participants.any((p) => visibleNames.contains(p.name));
    }).toList();

    filteredEvents.sort((a, b) {
      // All-day events always come first.
      if (a.isAllDay != b.isAllDay) {
        return a.isAllDay ? -1 : 1;
      }

      // Sort by time of day only - a recurring event's `start` still
      // carries the date of its very first occurrence, not today's
      // date, so comparing full DateTimes here would sort it wrong.
      int minutesA = (a.start.hour * 60) + a.start.minute;
      int minutesB = (b.start.hour * 60) + b.start.minute;

      int timeCompare = minutesA.compareTo(minutesB);
      if (timeCompare != 0) {
        return timeCompare;
      }

      // Equal start time: longer events first.
      int durationA = a.end.difference(a.start).inMinutes;
      int durationB = b.end.difference(b.start).inMinutes;
      return durationB.compareTo(durationA);
    });

    return filteredEvents;
  }

  /// Builds a list of previously used event titles for the title-field
  /// autocomplete, ranked by usage frequency and recency (most relevant first).
  List<String> _buildTitleSuggestions() {
    final Map<String, int> frequency = {};
    final Map<String, DateTime> lastUsed = {};

    for (final event in _allEvents) {
      final title = event.title.trim();
      if (title.isEmpty) continue;
      frequency[title] = (frequency[title] ?? 0) + 1;
      if (lastUsed[title] == null || event.start.isAfter(lastUsed[title]!)) {
        lastUsed[title] = event.start;
      }
    }

    final titles = frequency.keys.toList();
    titles.sort((a, b) {
      final freqCompare = frequency[b]!.compareTo(frequency[a]!);
      if (freqCompare != 0) return freqCompare;
      return lastUsed[b]!.compareTo(lastUsed[a]!);
    });
    return titles;
  }

  /// Opens the full-page event editor to create a new event on
  /// [targetDay] (or the currently selected day if omitted).
  /// Builds the localized [NotificationLabels] bundle that
  /// [NotificationService] needs to construct an event reminder.
  NotificationLabels _buildNotificationLabels(AppLocalizations l10n) {
    return NotificationLabels(
      channelName: l10n.notificationChannelName,
      channelDescription: l10n.notificationChannelDescription,
      title: l10n.notificationTitleLabel,
      osTitle: (title) => l10n.notificationEventTitle(title),
      osBody: (minutes) => l10n.notificationBodyMinutes(minutes),
      bigTextBody: (title, minutes, location) => l10n.notificationBigTextBody(title, minutes, location),
      locationNotSpecified: l10n.notificationLocationNotSpecified,
    );
  }

  void _showAddEventDialog({DateTime? targetDay}) {
    if (_isShowingDialog || !mounted) return;
    setState(() => _isShowingDialog = true);
    final l10n = AppLocalizations.of(context)!;

    final dayToUse = targetDay ?? _selectedDay;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => AddEventFullPage(
        targetDay: dayToUse,
        allEmployees: allEmployees,
        titleSuggestions: _buildTitleSuggestions(),
        onSave: (newEvent, targetCal) {
          setState(() {
            _allEvents = List.from(_allEvents)..add(newEvent);
          });

          WebEventCache.saveEvents(_allEvents);
          if (!kIsWeb) LocalDatabase.instance.updateCache(_allEvents);

          CalDavService.syncEvent(newEvent, explicitCalendar: targetCal).then((_) {
            OfflineQueueService.processQueue();
          });
          NotificationService.scheduleEventNotification(newEvent, _currentUser, labels: _buildNotificationLabels(l10n));
        },
      ),
    )).then((_) {
      if (mounted) setState(() => _isShowingDialog = false);
    });
  }

  /// Shows a bottom sheet listing all events on [day], with a shortcut
  /// to add a new one and a holiday banner if [day] is a public
  /// holiday.
  void _showDayEventsOverview(DateTime day, List<CalendarEvent> events) {
    if (_isShowingDialog || !mounted) return;
    setState(() => _isShowingDialog = true);

    String? holidayName = HolidayService.getHolidayName(day);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(DateFormat('EEEE, d. MMMM', _dateLocaleTag).format(day),
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.add, color: Colors.blue, size: 32),
                    onPressed: () {
                      Navigator.pop(context);
                      Future.delayed(const Duration(milliseconds: 200), () {
                        if (mounted) _showAddEventDialog(targetDay: day);
                      });
                    },
                  ),
                ],
              ),

              // Holiday banner, shown only if `day` is a public holiday.
              if (holidayName != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade200)
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.celebration, color: Colors.orange, size: 20),
                        const SizedBox(width: 8),
                        Text(holidayName, style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 8),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: events.length,
                  itemBuilder: (context, index) {
                    final event = events[index];

                    bool showNoonDivider = false;
                    if (!event.isAllDay && event.start.hour >= 12) {
                      if (index > 0) {
                        final prevEvent = events[index - 1];
                        if (prevEvent.isAllDay || prevEvent.start.hour < 12) {
                          showNoonDivider = true;
                        }
                      }
                    }

                    final occurrenceEnd = DateTime(day.year, day.month, day.day, event.end.hour, event.end.minute);
                    final isPast = occurrenceEnd.isBefore(DateTime.now());
                    final applyGray = _grayOutPastEvents && isPast;

                    return Column(
                      children: [
                        if (showNoonDivider)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12.0),
                            child: Row(
                              children: [
                                Text("12:00", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                                Expanded(child: Divider(indent: 8, endIndent: 0, thickness: 1, color: Colors.grey)),
                              ],
                            ),
                          ),

                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: InkWell(
                            onTap: () {
                              Navigator.pop(context);
                              _showEventDetails(event);
                            },
                            child: Opacity(
                              opacity: applyGray ? 0.6 : 1.0,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(width: 65, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    if (!event.isAllDay) ...[
                                      Text(DateFormat('HH:mm').format(event.start), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: applyGray ? Colors.grey : Colors.black)),
                                      Text(DateFormat('HH:mm').format(event.end), style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                                    ] else
                                      Text(AppLocalizations.of(context)!.allDay, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: applyGray ? Colors.grey : Colors.black)),
                                  ])),
                                  const SizedBox(width: 12),
                                  Expanded(child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(color: applyGray ? Colors.grey.shade400 : event.color, borderRadius: BorderRadius.circular(16)),
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text(event.title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 6),
                                      Row(children: [
                                        const Icon(Icons.person, color: Colors.white, size: 16),
                                        const SizedBox(width: 6),
                                        Expanded(child: Text(event.participants.map((p) => p.name).join(', '), style: const TextStyle(color: Colors.white, fontSize: 15), overflow: TextOverflow.ellipsis)),
                                      ]),
                                    ]),
                                  )),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    ).then((_) { if (mounted) setState(() => _isShowingDialog = false); });
  }

  /// Opens the full-page event editor pre-filled with [event] for
  /// viewing/editing, and wires up save/delete handling - including
  /// the "this occurrence vs. entire series" choice for recurring
  /// events.
  void _showEventDetails(CalendarEvent event) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => AddEventFullPage(
        targetDay: event.start,
        allEmployees: allEmployees,
        titleSuggestions: _buildTitleSuggestions(),
        existingEvent: event,
        onSave: (updatedEvent, targetCal) {
          setState(() {
            _allEvents = List.from(_allEvents)..removeWhere((e) => e.uid == event.uid)..add(updatedEvent);
          });

          WebEventCache.saveEvents(_allEvents);
          if (!kIsWeb) LocalDatabase.instance.updateCache(_allEvents);

          final oldNames = event.participants.map((e) => e.name).toList()..sort();
          final newNames = updatedEvent.participants.map((e) => e.name).toList()..sort();
          bool participantsChanged = oldNames.join(',') != newNames.join(',');

          if (participantsChanged) {
            CalDavService.deleteEvent(event);
          }
          CalDavService.syncEvent(updatedEvent, explicitCalendar: targetCal).then((_) {
            OfflineQueueService.processQueue();
          });
        },
        onDelete: (targetCal) {
          if (event.recurrence != Recurrence.none) {
            final l10n = AppLocalizations.of(context)!;
            showDialog(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: Text(l10n.deleteRecurringEventTitle),
                content: Text(l10n.deleteRecurringEventMessage),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      Navigator.pop(context);
                      setState(() {
                        final updatedEvent = CalendarEvent(
                          uid: event.uid, href: event.href, title: event.title, start: event.start, end: event.end, isAllDay: event.isAllDay,
                          participants: event.participants, notificationsEnabled: event.notificationsEnabled, minutesBefore: event.minutesBefore, color: event.color,
                          recurrence: event.recurrence, recurrenceDays: event.recurrenceDays, recurrenceEndDate: event.recurrenceEndDate, location: event.location,
                          excludeDates: [...event.excludeDates, _selectedDay],
                        );
                        _allEvents = List.from(_allEvents)..removeWhere((e) => e.uid == event.uid)..add(updatedEvent);
                      });
                      WebEventCache.saveEvents(_allEvents);
                      if (!kIsWeb) LocalDatabase.instance.updateCache(_allEvents);
                      CalDavService.deleteEvent(event, excludeDate: _selectedDay, explicitCalendar: targetCal);
                    },
                    child: Text(l10n.deleteThisOccurrence),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      Navigator.pop(context);
                      NotificationService.cancelNotification(event.uid);
                      setState(() => _allEvents = List.from(_allEvents)..removeWhere((e) => e.uid == event.uid));
                      WebEventCache.saveEvents(_allEvents);
                      if (!kIsWeb) LocalDatabase.instance.updateCache(_allEvents);
                      CalDavService.deleteEvent(event, explicitCalendar: targetCal);
                    },
                    child: Text(l10n.deleteEntireSeries, style: const TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            );
          } else {
            Navigator.pop(context);
            setState(() => _allEvents = List.from(_allEvents)..removeWhere((e) => e.uid == event.uid));
            WebEventCache.saveEvents(_allEvents);
            if (!kIsWeb) LocalDatabase.instance.updateCache(_allEvents);
            CalDavService.deleteEvent(event, explicitCalendar: targetCal);
          }
        },
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      drawer: AppDrawer(
        currentUser: _currentUser,
        allEmployees: allEmployees,
        grayOutPastEvents: _grayOutPastEvents,
        showWeekNumbers: _showWeekNumbers,
        showHolidays: _showHolidays,
        onUserSwitch: _showUserSwitchDialog,
        onLocalizationTap: _showLocalizationSettingsDialog,
        onGrayOutPastEventsChanged: (value) {
          setState(() => _grayOutPastEvents = value);
        },
        onShowWeekNumbersChanged: (value) {
          setState(() => _showWeekNumbers = value);
        },
        onShowHolidaysChanged: (value) {
          setState(() => _showHolidays = value);
        },
        onSettingsSaved: () {
          _initCalDav();
        },
        onTeamChanged: () {
          _loadSettings();
        },
        onColorsChanged: () {
          setState(() {});
        },
        oninitializeApp: _initCalDav,
      ),

      appBar: _selectedIndex == 0 ? AppBar(
        title: Text(
          DateFormat('MMMM', _dateLocaleTag).format(_focusedDay).replaceFirst(
              RegExp(r'^.'), DateFormat('MMMM', _dateLocaleTag).format(_focusedDay)[0].toUpperCase()),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
        ),
        centerTitle: false,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black87),
            tooltip: l10n.searchTooltip,
            onPressed: () {
              showSearch(
                context: context,
                delegate: EventSearchDelegate(
                  allEvents: _allEvents,
                  searchFieldLabel: l10n.searchEventsHint,
                  onEventSelected: (event) {
                    _showEventDetails(event);
                  },
                ),
              );
            },
          ),
          if (_isLoadingEvents)
            const Padding(padding: EdgeInsets.symmetric(horizontal: 16.0), child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))))
          else
            IconButton(icon: const Icon(Icons.refresh, color: Colors.black87), onPressed: _loadEventsFromServer),

          IconButton(
            icon: const Icon(Icons.filter_alt_outlined, color: Colors.black87),
            onPressed: () {
              showModalBottomSheet(
                  context: context,
                  builder: (context) => FilterDialogContent(
                      allEmployees: allEmployees,
                      initialVisible: visibleEmployees,
                      onChanged: (newSet) => _saveFilters(newSet)
                  )
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ) : null,

      body: _selectedIndex == 0 ? Column(
        children: [
          _calendarFormat == CalendarFormat.month
              ? Expanded(child: _buildTableCalendar())
              : _buildTableCalendar(),

          if (_calendarFormat != CalendarFormat.month)
            Expanded(
              child: Container(
                color: Colors.white,
                width: double.infinity,
                child: _buildInlineDayEvents(),
              ),
            ),
        ],
      ) : const ShoppingListScreen(),

      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: SpeedDial(
        icon: Icons.add,
        activeIcon: Icons.close,
        backgroundColor: const Color(0xFF4A73D1),
        foregroundColor: Colors.white,
        overlayColor: Colors.black,
        overlayOpacity: 0.5,
        spacing: 12,
        spaceBetweenChildren: 8,
        elevation: 8.0,
        children: [
          SpeedDialChild(
            child: const Icon(Icons.event),
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF4A73D1),
            label: l10n.newEvent,
            onTap: () {
              _showAddEventDialog(targetDay: _selectedDay);
            },
          ),
          SpeedDialChild(
            child: const Icon(Icons.checklist),
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF4A73D1),
            label: l10n.todos,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CalDavTodoScreen()),
              );
            },
          ),
          SpeedDialChild(
            child: const Icon(Icons.shopping_cart_outlined),
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF4A73D1),
            label: l10n.shoppingList,
            onTap: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ShoppingListScreen())
              );
            },
          ),
        ],
      ),

      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        color: Colors.white,
        child: SizedBox(
          height: 60.0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              IconButton(
                icon: const Icon(Icons.today, size: 28),
                color: Colors.grey[700],
                tooltip: l10n.todayTooltip,
                onPressed: () {
                  setState(() {
                    _focusedDay = DateTime.now();
                    _selectedDay = DateTime.now();
                    _calendarFormat = CalendarFormat.month;
                  });
                },
              ),
              const SizedBox(width: 48),
              PopupMenuButton<CalendarFormat>(
                icon: Icon(Icons.view_agenda_outlined, size: 28, color: Colors.grey[700]),
                tooltip: l10n.viewSelectorTooltip,
                offset: const Offset(0, -170),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 6,
                onSelected: (CalendarFormat format) {
                  setState(() {
                    _calendarFormat = format;
                  });
                },
                itemBuilder: (BuildContext context) => [
                  PopupMenuItem(
                    value: CalendarFormat.month,
                    child: Row(
                      children: [
                        Icon(Icons.calendar_view_month, color: _calendarFormat == CalendarFormat.month ? const Color(0xFF4A73D1) : Colors.grey),
                        const SizedBox(width: 12),
                        Text(l10n.viewMonth, style: TextStyle(fontWeight: _calendarFormat == CalendarFormat.month ? FontWeight.bold : FontWeight.normal)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: CalendarFormat.twoWeeks,
                    child: Row(
                      children: [
                        Icon(Icons.view_day_outlined, color: _calendarFormat == CalendarFormat.twoWeeks ? const Color(0xFF4A73D1) : Colors.grey),
                        const SizedBox(width: 12),
                        Text(l10n.viewTwoWeeks, style: TextStyle(fontWeight: _calendarFormat == CalendarFormat.twoWeeks ? FontWeight.bold : FontWeight.normal)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: CalendarFormat.week,
                    child: Row(
                      children: [
                        Icon(Icons.calendar_view_week, color: _calendarFormat == CalendarFormat.week ? const Color(0xFF4A73D1) : Colors.grey),
                        const SizedBox(width: 12),
                        Text(l10n.viewWeek, style: TextStyle(fontWeight: _calendarFormat == CalendarFormat.week ? FontWeight.bold : FontWeight.normal)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds a single day cell for the month grid: date number, an
  /// optional holiday name, and up to two stacked event lists (before
  /// and after noon).
  Widget _buildCustomCell(BuildContext context, DateTime day, {bool isToday = false, bool isSelected = false, bool isOutsideMonth = false}) {
    final events = _getEventsForDay(day);
    final eventsBeforeNoon = events.where((e) => e.start.hour < 12 || e.isAllDay).toList();
    final eventsAfterNoon = events.where((e) => e.start.hour >= 12 && !e.isAllDay).toList();

    bool isWeekend = day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;

    String? holidayName = HolidayService.getHolidayName(day);
    bool isHoliday = _showHolidays && holidayName != null;

    Widget cell = Container(
      margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 1),
      decoration: BoxDecoration(
          color: isToday
              ? Colors.green.withValues(alpha: 0.1)
              : (isHoliday
              ? Colors.orange.withValues(alpha: 0.1)
              : (isWeekend ? Colors.grey.shade100 : Colors.grey.shade50)),
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(
            color: isSelected ? const Color(0xFF4A73D1) : (isHoliday ? Colors.orange.shade200 : Colors.grey.shade300),
            width: isSelected ? 2.0 : 0.5,
          )
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cell header: day number and, if applicable, the holiday name.
          Padding(
            padding: const EdgeInsets.only(top: 4.0, left: 4.0, right: 4.0, bottom: 2.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    "${day.day}",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                      color: isOutsideMonth ? Colors.grey.shade400 : (isToday ? Colors.green.shade700 : (isWeekend || isHoliday ? Colors.red.shade400 : Colors.black87)),
                    )
                ),
                if (isHoliday)
                  Expanded(
                    child: Text(
                      holidayName,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(child: _buildEventList(eventsBeforeNoon, day)),
          if (eventsAfterNoon.isNotEmpty) ...[
            Container(height: 1.5, color: Colors.grey.shade300, margin: const EdgeInsets.symmetric(horizontal: 4)),
            Expanded(child: _buildEventList(eventsAfterNoon, day)),
          ]
        ],
      ),
    );

    if (isOutsideMonth) {
      return Opacity(
        opacity: 0.35,
        child: cell,
      );
    }

    return cell;
  }

  /// Renders the compact, colored event chips shown inside a month
  /// cell, handling the multi-day-event case where only the first day
  /// shows the title and the start/end days get rounded corners.
  Widget _buildEventList(List<CalendarEvent> events, DateTime currentDay) {
    return ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 1),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: events.length,
        separatorBuilder: (context, index) {
          return Container(height: 1.0, color: Colors.grey.shade400, margin: const EdgeInsets.symmetric(horizontal: 4));
        },
        itemBuilder: (context, index) {
          final event = events[index];

          final occurrenceEnd = DateTime(currentDay.year, currentDay.month, currentDay.day, event.end.hour, event.end.minute);
          final isPast = occurrenceEnd.isBefore(DateTime.now());
          final applyGray = _grayOutPastEvents && isPast;

          bool isFirstDay = currentDay.year == event.start.year && currentDay.month == event.start.month && currentDay.day == event.start.day;
          bool isLastDay = currentDay.year == event.end.year && currentDay.month == event.end.month && currentDay.day == event.end.day;

          if (event.recurrence != Recurrence.none) {
            isFirstDay = true;
            isLastDay = true;
          }

          return Container(
              margin: EdgeInsets.only(
                bottom: 2,
                left: isFirstDay ? 2 : 0,
                right: isLastDay ? 2 : 0,
              ),
              padding: EdgeInsets.symmetric(
                  horizontal: isFirstDay ? 4 : 2,
                  vertical: 1.5
              ),
              decoration: BoxDecoration(
                  color: applyGray ? Colors.grey.shade400 : event.color,
                  borderRadius: BorderRadius.horizontal(
                    left: isFirstDay ? const Radius.circular(4) : Radius.zero,
                    right: isLastDay ? const Radius.circular(4) : Radius.zero,
                  )
              ),
              child: Text(
                  isFirstDay ? event.title : " ",
                  style: TextStyle(
                      color: applyGray ? Colors.grey.shade200 : Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1
              )
          );
        }
    );
  }

  /// Builds the `table_calendar` grid itself (month/2-weeks/week
  /// format), wiring in the custom cell builders and the day-selection
  /// behaviour (tap an empty day to add an event, tap a day with
  /// events to see its agenda).
  Widget _buildTableCalendar() {
    return TableCalendar(
      locale: _dateLocaleTag,
      firstDay: DateTime.utc(2023, 1, 1),
      lastDay: DateTime.utc(2030, 12, 31),
      focusedDay: _focusedDay,
      calendarFormat: _calendarFormat,

      shouldFillViewport: _calendarFormat == CalendarFormat.month,
      rowHeight: _calendarFormat == CalendarFormat.month ? 52 : 120,

      daysOfWeekHeight: 30,
      headerVisible: false,
      weekNumbersVisible: _showWeekNumbers,
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      startingDayOfWeek: StartingDayOfWeek.monday,
      calendarBuilders: CalendarBuilders(
        defaultBuilder: (context, day, focusedDay) => _buildCustomCell(context, day),
        todayBuilder: (context, day, focusedDay) => _buildCustomCell(context, day, isToday: true),
        selectedBuilder: (context, day, focusedDay) => _buildCustomCell(context, day, isSelected: true),
        outsideBuilder: (context, day, focusedDay) => _buildCustomCell(context, day, isOutsideMonth: true),
        dowBuilder: (context, day) => Center(child: Text(DateFormat.E(_dateLocaleTag).format(day).substring(0, 2), style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.bold))),
        weekNumberBuilder: (context, weekNumber) => Center(
          child: Text("$weekNumber", style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic, fontWeight: FontWeight.w500)),
        ),
      ),
      onDaySelected: (selectedDay, focusedDay) {
        setState(() { _selectedDay = selectedDay; _focusedDay = focusedDay; });

        if (_calendarFormat == CalendarFormat.month) {
          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final events = _getEventsForDay(selectedDay);
            if (events.isEmpty) {
              _showAddEventDialog(targetDay: selectedDay);
            } else {
              _showDayEventsOverview(selectedDay, events);
            }
          });
        }
      },
      onPageChanged: (focusedDay) => setState(() => _focusedDay = focusedDay),
    );
  }

  /// Builds the agenda list shown below the calendar in 2-weeks/week
  /// view: the selected day's header, an optional holiday banner, and
  /// the day's events (or an empty-state message).
  Widget _buildInlineDayEvents() {
    final events = _getEventsForDay(_selectedDay);
    final l10n = AppLocalizations.of(context)!;
    String? holidayName = HolidayService.getHolidayName(_selectedDay);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Text(
              DateFormat('EEEE, d. MMMM', _dateLocaleTag).format(_selectedDay),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF4A73D1))
          ),
        ),

        if (holidayName != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text("✨ $holidayName", style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ),

        Expanded(
          child: events.isEmpty
              ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_available, size: 48, color: Colors.grey.shade300),
                  const SizedBox(height: 8),
                  Text(l10n.noEvents, style: TextStyle(color: Colors.grey.shade500, fontStyle: FontStyle.italic)),
                ],
              )
          )
              : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: events.length,
            itemBuilder: (context, index) {
              final event = events[index];

              bool showNoonDivider = false;
              if (!event.isAllDay && event.start.hour >= 12) {
                if (index > 0) {
                  final prevEvent = events[index - 1];
                  if (prevEvent.isAllDay || prevEvent.start.hour < 12) {
                    showNoonDivider = true;
                  }
                }
              }

              final occurrenceEnd = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day, event.end.hour, event.end.minute);
              final applyGray = _grayOutPastEvents && occurrenceEnd.isBefore(DateTime.now());

              return Column(
                children: [
                  if (showNoonDivider)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12.0),
                      child: Row(
                        children: [
                          Text("12:00", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                          Expanded(child: Divider(indent: 8, endIndent: 0, thickness: 1, color: Colors.grey)),
                        ],
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: () => _showEventDetails(event),
                      child: Opacity(
                        opacity: applyGray ? 0.6 : 1.0,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                                width: 55,
                                child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (!event.isAllDay) ...[
                                        Text(DateFormat('HH:mm').format(event.start), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: applyGray ? Colors.grey : Colors.black)),
                                        Text(DateFormat('HH:mm').format(event.end), style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                      ] else
                                        Text(l10n.allDayShort, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    ]
                                )
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(color: applyGray ? Colors.grey.shade400 : event.color, borderRadius: BorderRadius.circular(12)),
                                  child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(event.title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 4),
                                        Text(event.participants.map((p) => p.name).join(', '), style: const TextStyle(color: Colors.white, fontSize: 12)),
                                      ]
                                  ),
                                )
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}