import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/employee.dart';
import '../models/calendar_event.dart';
import '../services/caldav_service.dart';
import '../services/group_colors.dart';
import '../services/secure_vault.dart';
import '../l10n/app_localizations.dart';

/// Full-page event editor, with the "smart account logic": as soon as
/// the guest selection changes, it looks up whether a CalDAV folder
/// exists for exactly that combination of people in the selected
/// account, and only allows saving when a match is found.
class AddEventFullPage extends StatefulWidget {
  final DateTime targetDay;
  final List<Employee> allEmployees;
  final Function(CalendarEvent, MappedCalendar?) onSave;
  final CalendarEvent? existingEvent;
  final Function(MappedCalendar?)? onDelete;
  final List<String> titleSuggestions;

  const AddEventFullPage({
    super.key,
    required this.targetDay,
    required this.allEmployees,
    required this.onSave,
    this.existingEvent,
    this.onDelete,
    this.titleSuggestions = const [],
  });

  @override
  State<AddEventFullPage> createState() => _AddEventFullPageState();
}

class _AddEventFullPageState extends State<AddEventFullPage> {
  late TextEditingController _titleController;
  late TextEditingController _locationController;
  final FocusNode _titleFocusNode = FocusNode();
  final Set<Employee> _selectedEmployees = {};
  bool _isAllDay = false;
  late DateTime _startDate;
  late DateTime _endDate;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;

  bool _notificationsEnabled = true;
  int _minutesBefore = 30;

  Color _eventColor = Colors.blue;
  Recurrence _recurrence = Recurrence.none;
  final List<int> _recurrenceDays = [];
  DateTime? _recurrenceEndDate;

  List<CalDavAccount> _accounts = [];
  CalDavAccount? _selectedAccount;
  List<MappedCalendar> _allMappings = [];
  List<MappedCalendar> _currentAccountMappings = [];
  MappedCalendar? _exactMatch;

  List<Employee> _currentWorkspaceTeam = [];

  /// Locale tag understood by `intl`'s [DateFormat], derived from the
  /// app's active language. Falls back to English for any language
  /// other than German.
  String get _dateLocaleTag =>
      Localizations.localeOf(context).languageCode == 'de' ? 'de_DE' : 'en_US';

  /// [Locale] to pass to `showDatePicker`, matching [_dateLocaleTag].
  Locale get _pickerLocale =>
      Localizations.localeOf(context).languageCode == 'de' ? const Locale('de', 'DE') : const Locale('en', 'US');

  /// Localized display name for a [Recurrence] value, used both in
  /// the picker dialog and in the summary row.
  String _recurrenceLabel(Recurrence r, AppLocalizations l10n) {
    switch (r) {
      case Recurrence.none:
        return l10n.recurrenceNone;
      case Recurrence.daily:
        return l10n.recurrenceDaily;
      case Recurrence.weekly:
        return l10n.recurrenceWeekly;
      case Recurrence.biWeekly:
        return l10n.recurrenceBiWeekly;
      case Recurrence.monthly:
        return l10n.recurrenceMonthly;
      case Recurrence.customDays:
        return l10n.recurrenceCustomDays;
    }
  }

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _locationController = TextEditingController();

    if (widget.existingEvent != null) {
      final e = widget.existingEvent!;
      _titleController.text = e.title;
      _locationController.text = e.location;
      _isAllDay = e.isAllDay;
      _startDate = e.start;
      _endDate = e.end;
      _startTime = TimeOfDay.fromDateTime(e.start);
      _endTime = TimeOfDay.fromDateTime(e.end);
      _notificationsEnabled = e.notificationsEnabled;
      _minutesBefore = e.minutesBefore;
      _eventColor = e.color;
      _recurrence = e.recurrence;
      _recurrenceDays.addAll(e.recurrenceDays);
      _selectedEmployees.addAll(e.participants);
      _recurrenceEndDate = e.recurrenceEndDate;
    } else {
      _startDate = widget.targetDay;
      _endDate = widget.targetDay;
      _startTime = const TimeOfDay(hour: 22, minute: 30);
      _endTime = const TimeOfDay(hour: 23, minute: 30);

      // Intentionally no automatic guest pre-selection here.

      _updateColorBasedOnSelection();
    }

    _loadAccountsAndMappings();
  }

  Future<void> _loadAccountsAndMappings() async {
    final cals = await CalDavService.getWritableCalendars();
    if (!mounted) return;

    final Map<String, CalDavAccount> accMap = {};
    for (var c in cals) {
      accMap[c.account.id] = c.account;
    }
    final accounts = accMap.values.toList();

    CalDavAccount? initialAcc;
    if (widget.existingEvent != null) {
      final names = widget.existingEvent!.participants.map((e)=>e.name).toList()..sort();
      final key = names.join(',');
      try {
        final match = cals.firstWhere((c) => c.participantNames == key);
        initialAcc = match.account;
      } catch (_) {}
    }
    if (initialAcc == null && accounts.isNotEmpty) {
      initialAcc = accounts.first;
    }

    setState(() {
      _allMappings = cals;
      _accounts = accounts;
      _selectedAccount = initialAcc;
      _updateAccountState();
    });

    _loadTeamForSelectedAccount();
  }

  Future<void> _loadTeamForSelectedAccount() async {
    if (_selectedAccount == null) return;

    final prefs = await SharedPreferences.getInstance();
    final accountId = _selectedAccount!.id;
    final String? teamJson = prefs.getString('saved_team_$accountId');

    List<Employee> loadedTeam = [];

    if (teamJson != null) {
      final List<dynamic> decoded = jsonDecode(teamJson);
      loadedTeam = decoded.map((e) => Employee.fromJson(e)).toList();
    } else {
      if (_accounts.isNotEmpty && accountId == _accounts.first.id) {
        final String? globalJson = prefs.getString('saved_team');
        if (globalJson != null) {
          final List<dynamic> decoded = jsonDecode(globalJson);
          loadedTeam = decoded.map((e) => Employee.fromJson(e)).toList();
        } else {
          loadedTeam = [const Employee("Ich", Color(0xFF4A73D1))];
        }
      } else {
        loadedTeam = [];
      }
    }

    setState(() {
      _currentWorkspaceTeam = loadedTeam;

      _selectedEmployees.removeWhere((p) => !loadedTeam.any((emp) => emp.name == p.name));

      _validateCombination();
      _updateColorBasedOnSelection();
    });
  }

  void _updateAccountState() {
    if (_selectedAccount == null) {
      _currentAccountMappings = [];
      return;
    }
    _currentAccountMappings = _allMappings.where((m) => m.account.id == _selectedAccount!.id).toList();
    _validateCombination();
  }

  void _validateCombination() {
    if (_selectedEmployees.isEmpty) {
      _exactMatch = null;
      return;
    }
    final names = _selectedEmployees.map((e) => e.name).toList()..sort();
    final key = names.join(",");

    try {
      _exactMatch = _currentAccountMappings.firstWhere((m) => m.participantNames == key);
    } catch (_) {
      _exactMatch = null;
    }
  }

  void _updateColorBasedOnSelection() {
    if (_selectedEmployees.length == 1) {
      _eventColor = _selectedEmployees.first.color;
    } else if (_selectedEmployees.isNotEmpty) {
      final names = _selectedEmployees.map((e) => e.name).toList()..sort();
      final key = names.join(",");
      _eventColor = GroupColors.getColor(key);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _titleFocusNode.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isStart) async {
    final DateTime? picked = await showDatePicker(context: context, initialDate: isStart ? _startDate : _endDate, firstDate: DateTime(2023), lastDate: DateTime(2030), locale: _pickerLocale);
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate.isBefore(_startDate)) _endDate = _startDate;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _pickTime(bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(context: context, initialTime: isStart ? _startTime : _endTime, builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true), child: child!));
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
          final startDateTime = DateTime(_startDate.year, _startDate.month, _startDate.day, _startTime.hour, _startTime.minute);
          final endDateTime = startDateTime.add(const Duration(minutes: 15));
          _endTime = TimeOfDay.fromDateTime(endDateTime);
          _endDate = DateTime(endDateTime.year, endDateTime.month, endDateTime.day);
        } else {
          _endTime = picked;
        }
      });
    }
  }

  String _formatTime(TimeOfDay time) => '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  void _showColorPicker() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.chooseColorTitle),
        content: SingleChildScrollView(child: Wrap(spacing: 10, runSpacing: 10, children: [
          Colors.red, Colors.pink, Colors.purple, Colors.deepPurple, Colors.indigo, Colors.blue, Colors.lightBlue, Colors.cyan,
          Colors.teal, Colors.green, Colors.lightGreen, Colors.lime, Colors.yellow, Colors.amber, Colors.orange, Colors.deepOrange,
          Colors.brown, Colors.grey, Colors.blueGrey, Colors.black,
        ].map((color) => GestureDetector(
          onTap: () { setState(() => _eventColor = color); Navigator.pop(context); },
          child: Container(width: 40, height: 40, decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: _eventColor == color ? Border.all(width: 3, color: Colors.white) : null)),
        )).toList())),
      ),
    );
  }

  void _showRecurrencePicker() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.recurrenceTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _recurrenceOption(l10n.recurrenceNone, Recurrence.none),
            _recurrenceOption(l10n.recurrenceDaily, Recurrence.daily),
            _recurrenceOption(l10n.recurrenceWeekly, Recurrence.weekly),
            _recurrenceOption(l10n.recurrenceBiWeekly, Recurrence.biWeekly),
            _recurrenceOption(l10n.recurrenceMonthly, Recurrence.monthly),
            _recurrenceOption(l10n.recurrenceCustomDays, Recurrence.customDays),
          ],
        ),
      ),
    );
  }

  Widget _recurrenceOption(String label, Recurrence value) {
    final isSelected = _recurrence == value;
    return ListTile(
      title: Text(label),
      leading: Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: isSelected ? const Color(0xFF4A73D1) : Colors.grey),
      onTap: () {
        setState(() => _recurrence = value);
        Navigator.pop(context);
        if (value == Recurrence.customDays) _showCustomDaysPicker();
      },
    );
  }

  void _showCustomDaysPicker() {
    final l10n = AppLocalizations.of(context)!;
    final List<String> weekdays = [l10n.weekdayMon, l10n.weekdayTue, l10n.weekdayWed, l10n.weekdayThu, l10n.weekdayFri, l10n.weekdaySat, l10n.weekdaySun];
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text(l10n.chooseWeekdaysTitle),
          content: Wrap(spacing: 8, children: List.generate(7, (index) {
            final day = index + 1;
            final isSelected = _recurrenceDays.contains(day);
            return FilterChip(
              label: Text(weekdays[index]),
              selected: isSelected,
              onSelected: (selected) {
                setModalState(() { if (selected) {
                  _recurrenceDays.add(day);
                } else {
                  _recurrenceDays.remove(day);
                } });
                setState(() {});
              },
            );
          })),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.done))],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: const Color(0xFF4A73D1),
          elevation: 0,
          leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
          title: Text(widget.existingEvent != null ? l10n.editEventTitle : l10n.eventTitle, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          actions: [
            if (widget.existingEvent != null && widget.onDelete != null)
              IconButton(icon: const Icon(Icons.delete, color: Colors.white), onPressed: () => widget.onDelete!(_exactMatch)),

            IconButton(
                icon: Icon(Icons.check, color: _exactMatch != null ? Colors.white : Colors.white38),
                onPressed: _exactMatch != null ? () {
                  if (_titleController.text.isNotEmpty) {
                    final start = DateTime(_startDate.year, _startDate.month, _startDate.day, _startTime.hour, _startTime.minute);
                    final end = DateTime(_endDate.year, _endDate.month, _endDate.day, _endTime.hour, _endTime.minute);
                    String generatedUid = widget.existingEvent?.uid ?? '${_titleController.text.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}-${DateTime.now().millisecondsSinceEpoch}@team-planer';

                    widget.onSave(CalendarEvent(
                      uid: generatedUid,
                      title: _titleController.text, start: start, end: end, isAllDay: _isAllDay,
                      participants: _selectedEmployees.toList(), notificationsEnabled: _notificationsEnabled,
                      minutesBefore: _minutesBefore, color: _eventColor, recurrence: _recurrence,
                      recurrenceDays: _recurrenceDays, recurrenceEndDate: _recurrenceEndDate, location: _locationController.text,
                      excludeDates: widget.existingEvent?.excludeDates ?? [],
                    ), _exactMatch);
                    Navigator.pop(context);
                  }
                } : null
            ),
          ],
        ),
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                // Live suggestion list populated from previously used event titles,
                // filtered as the user types.
                child: Autocomplete<String>(
                  textEditingController: _titleController,
                  focusNode: _titleFocusNode,
                  optionsBuilder: (TextEditingValue value) {
                    if (value.text.isEmpty) return const Iterable<String>.empty();
                    final query = value.text.toLowerCase();
                    final matches = widget.titleSuggestions
                        .where((t) => t.toLowerCase().contains(query))
                        .toList();
                    matches.sort((a, b) {
                      final aStarts = a.toLowerCase().startsWith(query);
                      final bStarts = b.toLowerCase().startsWith(query);
                      if (aStarts != bStarts) return aStarts ? -1 : 1;
                      return 0;
                    });
                    return matches.take(6);
                  },
                  fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                    return TextFormField(
                      controller: controller,
                      focusNode: focusNode,
                      textCapitalization: TextCapitalization.sentences,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      onTapOutside: (event) => FocusManager.instance.primaryFocus?.unfocus(),
                      decoration: const InputDecoration(hintText: "Titel", border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 12.0, horizontal: 4.0), hintStyle: TextStyle(color: Colors.grey, fontWeight: FontWeight.normal)),
                    );
                  },
                  optionsViewBuilder: (context, onSelected, options) {
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(8),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 240, maxWidth: 400),
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: options.length,
                            itemBuilder: (context, index) {
                              final option = options.elementAt(index);
                              return ListTile(
                                dense: true,
                                leading: const Icon(Icons.history, size: 18, color: Colors.grey),
                                title: Text(option),
                                onTap: () => onSelected(option),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const Divider(height: 1),

              if (_accounts.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.cloud_sync, color: Colors.grey),
                  title: Text(l10n.saveToAccountLabel, style: const TextStyle(fontSize: 16)),
                  trailing: DropdownButtonHideUnderline(
                    child: DropdownButton<CalDavAccount>(
                      value: _selectedAccount,
                      items: _accounts.map((acc) => DropdownMenuItem(value: acc, child: Text(acc.name, style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
                      onChanged: (newAccount) {
                        if (newAccount != null) {
                          setState(() {
                            _selectedAccount = newAccount;
                            _updateAccountState();
                          });
                          _loadTeamForSelectedAccount();
                        }
                      },
                    ),
                  ),
                ),

              Container(height: 12, color: const Color(0xFFF2F2F7)),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.update, color: Colors.grey),
                    const SizedBox(width: 16),
                    Text(l10n.allDay, style: const TextStyle(fontSize: 16)),
                    const Spacer(),
                    Switch(value: _isAllDay, onChanged: (v) => setState(() => _isAllDay = v), activeThumbColor: const Color(0xFF4A73D1)),
                  ],
                ),
              ),
              _buildCustomDateTimeRow(icon: Icons.calendar_today_outlined, date: _startDate, time: _startTime, isStart: true, showTime: !_isAllDay),
              _buildCustomDateTimeRow(icon: Icons.event_available, date: _endDate, time: _endTime, isStart: false, showTime: !_isAllDay),
              const Padding(padding: EdgeInsets.symmetric(vertical: 8.0), child: Icon(Icons.expand_more, color: Colors.grey)),
              Container(height: 12, color: const Color(0xFFF2F2F7)),

              // --- Guests & validation ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(children: [const Icon(Icons.people_outline, color: Colors.grey), const SizedBox(width: 16), Text(l10n.selectGuestsLabel, style: const TextStyle(fontSize: 16))]),
                          if (_currentWorkspaceTeam.isNotEmpty)
                            TextButton(
                              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 30), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                              onPressed: () {
                                setState(() {
                                  if (_selectedEmployees.length == _currentWorkspaceTeam.length) {
                                    _selectedEmployees.clear();
                                  } else {
                                    _selectedEmployees.clear();
                                    _selectedEmployees.addAll(_currentWorkspaceTeam);
                                  }
                                  _validateCombination();
                                  _updateColorBasedOnSelection();
                                });
                              },
                              child: Text(
                                  _selectedEmployees.length == _currentWorkspaceTeam.length ? l10n.deselectAll : l10n.selectAll,
                                  style: const TextStyle(fontWeight: FontWeight.bold)
                              ),
                            )
                        ]
                    ),
                    const SizedBox(height: 12),

                    if (_currentWorkspaceTeam.isEmpty)
                      Text(l10n.noPeopleAssignedYet, style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.orange, fontSize: 13))
                    else
                      SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                              children: _currentWorkspaceTeam.map((emp) {
                                bool isAvailableInAccount = _currentAccountMappings.any((m) => m.participantNames.split(',').contains(emp.name));
                                bool isSelected = _selectedEmployees.contains(emp);

                                return Padding(
                                  padding: const EdgeInsets.only(right: 12),
                                  child: GestureDetector(
                                    onTap: isAvailableInAccount ? () {
                                      setState(() {
                                        if (isSelected) {
                                          _selectedEmployees.remove(emp);
                                        } else {
                                          _selectedEmployees.add(emp);
                                        }
                                        _validateCombination();
                                        _updateColorBasedOnSelection();
                                      });
                                    } : null,
                                    child: Opacity(
                                      opacity: isAvailableInAccount ? 1.0 : 0.3,
                                      child: CircleAvatar(
                                          radius: 22,
                                          backgroundColor: isSelected ? emp.color : emp.color.withValues(alpha: 0.2),
                                          child: Text(emp.initials, style: TextStyle(color: isSelected ? Colors.white : emp.color, fontWeight: FontWeight.bold))
                                      ),
                                    ),
                                  ),
                                );
                              }).toList()
                          )
                      ),

                    const SizedBox(height: 16),

                    Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: _exactMatch != null ? Colors.green.shade50 : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _exactMatch != null ? Colors.green.shade200 : Colors.red.shade200)
                        ),
                        child: Row(
                            children: [
                              Icon(_exactMatch != null ? Icons.check_circle : Icons.warning_amber_rounded, color: _exactMatch != null ? Colors.green : Colors.red, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Text(
                                      _exactMatch != null
                                          ? l10n.combinationValidMessage
                                          : _currentAccountMappings.isEmpty
                                          ? l10n.noFolderAssignedMessage
                                          : l10n.noSharedFolderMessage,
                                      style: TextStyle(color: _exactMatch != null ? Colors.green.shade800 : Colors.red.shade800, fontSize: 13)
                                  )
                              )
                            ]
                        )
                    )

                  ],
                ),
              ),
              const Divider(height: 1, indent: 56),

              _buildRow(icon: Icons.circle, iconColor: _eventColor, label: l10n.changeColorLabel, onTap: _showColorPicker),
              _buildRow(icon: Icons.sync, label: l10n.repeatSummary(_recurrenceLabel(_recurrence, l10n)), onTap: _showRecurrencePicker),
              if (_recurrence != Recurrence.none)
                _buildRow(
                  icon: Icons.event_busy,
                  label: _recurrenceEndDate == null ? l10n.neverEnds : l10n.endsOn(DateFormat('dd.MM.yyyy', _dateLocaleTag).format(_recurrenceEndDate!)),
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(context: context, initialDate: _recurrenceEndDate ?? _endDate.add(const Duration(days: 30)), firstDate: _startDate, lastDate: DateTime(2035), locale: _pickerLocale);
                    if (picked != null) setState(() => _recurrenceEndDate = picked);
                  },
                  trailing: _recurrenceEndDate != null ? IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => setState(() => _recurrenceEndDate = null)) : null,
                ),
              Container(height: 12, color: const Color(0xFFF2F2F7)),

              ListTile(
                leading: Icon(Icons.alarm, color: _notificationsEnabled ? Colors.grey.shade600 : Colors.grey.shade400),
                title: Text(_notificationsEnabled ? l10n.minutesBeforeLabel(_minutesBefore) : l10n.noReminderLabel, style: TextStyle(fontSize: 16, color: _notificationsEnabled ? Colors.black : Colors.grey)),
                trailing: IconButton(icon: const Icon(Icons.close, size: 20, color: Colors.grey), onPressed: () => setState(() => _notificationsEnabled = false)),
                onTap: () {
                  setState(() => _notificationsEnabled = true);
                  showDialog(context: context, builder: (context) => AlertDialog(title: Text(l10n.reminderTitle), content: DropdownButton<int>(value: _minutesBefore, isExpanded: true, items: [5, 15, 30, 60, 1440].map((m) => DropdownMenuItem(value: m, child: Text(l10n.minutesBeforeLabel(m)))).toList(), onChanged: (v) { if (v != null) { setState(() => _minutesBefore = v); Navigator.pop(context); }})));
                },
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),

              Container(height: 12, color: const Color(0xFFF2F2F7)),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.location_on_outlined, color: Colors.grey),
                    const SizedBox(width: 16),
                    Expanded(child: TextField(controller: _locationController, decoration: InputDecoration(hintText: l10n.addLocationHint, border: InputBorder.none))),
                  ],
                ),
              ),
            ],
          ),
        ));
  }

  Widget _buildCustomDateTimeRow({required IconData icon, required DateTime date, required TimeOfDay time, required bool isStart, required bool showTime}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey.shade600),
          const SizedBox(width: 16),
          GestureDetector(onTap: () => _pickDate(isStart), child: Text(DateFormat('E., d. MMM. yyyy', _dateLocaleTag).format(date), style: const TextStyle(fontSize: 16))),
          const Spacer(),
          if (showTime) GestureDetector(onTap: () => _pickTime(isStart), child: Text(_formatTime(time), style: const TextStyle(fontSize: 16))),
        ],
      ),
    );
  }

  Widget _buildRow({required IconData icon, Color? iconColor, required String label, Widget? trailing, VoidCallback? onTap}) {
    return ListTile(leading: Icon(icon, color: iconColor ?? Colors.grey.shade600), title: Text(label, style: const TextStyle(fontSize: 16)), trailing: trailing, onTap: onTap, contentPadding: const EdgeInsets.symmetric(horizontal: 16));
  }
}