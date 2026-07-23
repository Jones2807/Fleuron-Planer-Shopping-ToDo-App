import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/employee.dart';
import '../models/calendar_event.dart';
import '../models/filter_preset.dart';
import '../l10n/app_localizations.dart';

/// Bottom-sheet content for the calendar's employee filter: manual
/// per-person toggles plus save/apply-able named presets.
class FilterDialogContent extends StatefulWidget {
  final List<Employee> allEmployees;
  final Set<Employee> initialVisible;
  final Function(Set<Employee>) onChanged;

  const FilterDialogContent({super.key, required this.allEmployees, required this.initialVisible, required this.onChanged});

  @override
  State<FilterDialogContent> createState() => _FilterDialogContentState();
}

class _FilterDialogContentState extends State<FilterDialogContent> {
  late Set<Employee> _tempVisible;
  List<FilterPreset> _presets = [];
  bool _isLoadingPresets = true;
  bool _hasLoadedPresets = false;

  @override
  void initState() {
    super.initState();
    _tempVisible = Set.from(widget.initialVisible);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // AppLocalizations.of(context) needs a fully attached widget tree,
    // which isn't guaranteed yet in initState() - didChangeDependencies()
    // is the safe place for this kind of context-dependent lookup.
    if (!_hasLoadedPresets) {
      _hasLoadedPresets = true;
      _loadPresets();
    }
  }

  Future<void> _loadPresets() async {
    final l10n = AppLocalizations.of(context)!;
    final loaded = await PresetService.loadPresets(defaultPresetName: l10n.showAllPresetName);
    setState(() {
      _presets = loaded;
      _isLoadingPresets = false;
    });
  }

  void _createNewPreset() {
    final l10n = AppLocalizations.of(context)!;
    final TextEditingController nameCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.newPresetTitle),
        content: TextField(
          controller: nameCtrl,
          decoration: InputDecoration(hintText: l10n.presetNameHint),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A73D1), foregroundColor: Colors.white),
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;

              final activeNames = _tempVisible.map((e) => e.name).toList();

              final newPreset = FilterPreset(
                id: 'preset_${DateTime.now().millisecondsSinceEpoch}',
                name: nameCtrl.text.trim(),
                iconCodePoint: Icons.filter_list.codePoint, // Kept on the model in case it's needed later.
                activeCalendars: activeNames,
              );

              _presets.add(newPreset);
              await PresetService.savePresets(_presets);

              if (mounted) {
                setState(() {});
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.presetSavedMessage)));
              }
            },
            child: Text(l10n.save),
          )
        ],
      ),
    );
  }

  void _applyPreset(FilterPreset preset) {
    setState(() {
      if (preset.activeCalendars.isEmpty) {
        _tempVisible = Set.from(widget.allEmployees);
      } else {
        _tempVisible = widget.allEmployees
            .where((emp) => preset.activeCalendars.contains(emp.name))
            .toSet();
      }
    });
    widget.onChanged(_tempVisible);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(16),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.filterViewTitle, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              TextButton.icon(
                icon: const Icon(Icons.save, size: 18),
                label: Text(l10n.saveAsPreset),
                onPressed: _createNewPreset,
              )
            ],
          ),
          const SizedBox(height: 12),

          if (_isLoadingPresets)
            const Center(child: LinearProgressIndicator())
          else if (_presets.isNotEmpty) ...[
            Text(l10n.quickSelect, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _presets.map((preset) {
                  bool isExactlyMatch = false;
                  if (preset.activeCalendars.isEmpty && _tempVisible.length == widget.allEmployees.length) {
                    isExactlyMatch = true;
                  } else if (preset.activeCalendars.length == _tempVisible.length &&
                      preset.activeCalendars.every((name) => _tempVisible.any((e) => e.name == name))) {
                    isExactlyMatch = true;
                  }

                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ActionChip(
                      // Fixed icon constant rather than a dynamic IconData
                      // (dynamic IconData values break with tree-shaken icons).
                      avatar: Icon(Icons.filter_list, size: 16, color: isExactlyMatch ? Colors.white : const Color(0xFF4A73D1)),
                      label: Text(preset.name, style: TextStyle(color: isExactlyMatch ? Colors.white : Colors.black87, fontWeight: isExactlyMatch ? FontWeight.bold : FontWeight.normal)),
                      backgroundColor: isExactlyMatch ? const Color(0xFF4A73D1) : Colors.blue.shade50,
                      side: BorderSide(color: isExactlyMatch ? const Color(0xFF4A73D1) : Colors.blue.shade200),
                      onPressed: () => _applyPreset(preset),
                    ),
                  );
                }).toList(),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12.0),
              child: Divider(height: 1),
            ),
          ],

          Text(l10n.manualSelection, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Flexible(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 8,
                children: widget.allEmployees.map((emp) {
                  bool isSelected = _tempVisible.contains(emp);
                  return FilterChip(
                    label: Text(emp.name, style: TextStyle(color: isSelected ? Colors.white : Colors.black)),
                    selected: isSelected,
                    selectedColor: emp.color,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _tempVisible.add(emp);
                        } else {
                          _tempVisible.remove(emp);
                        }
                      });
                      widget.onChanged(_tempVisible);
                    },
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

/// Full-text search over all loaded events (title and location).
///
/// The search field's placeholder is passed in by the caller (see
/// `calendar_screen.dart`) since it needs to be localized at the
/// point where the app's active locale is known.
class EventSearchDelegate extends SearchDelegate<CalendarEvent?> {
  final List<CalendarEvent> allEvents;
  final Function(CalendarEvent) onEventSelected;

  EventSearchDelegate({required this.allEvents, required this.onEventSelected, required String searchFieldLabel})
      : super(searchFieldLabel: searchFieldLabel);

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          if (query.isEmpty) {
            close(context, null);
          } else {
            query = '';
          }
        },
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _buildSearchResults(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildSearchResults(context);

  Widget _buildSearchResults(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dateLocaleTag = Localizations.localeOf(context).languageCode == 'de' ? 'de_DE' : 'en_US';

    if (query.trim().isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(l10n.enterTitleOrLocationHint, style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
          ],
        ),
      );
    }

    final suggestions = allEvents.where((event) {
      final titleMatch = event.title.toLowerCase().contains(query.toLowerCase());
      final locMatch = event.location.toLowerCase().contains(query.toLowerCase());
      return titleMatch || locMatch;
    }).toList();

    suggestions.sort((a, b) => a.start.compareTo(b.start));

    if (suggestions.isEmpty) {
      return Center(child: Text(l10n.noEventsFoundForQuery(query), style: TextStyle(color: Colors.grey.shade600)));
    }

    return ListView.builder(
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        final event = suggestions[index];
        final isPast = event.start.isBefore(DateTime.now());

        return ListTile(
          leading: Container(
            width: 12,
            height: double.infinity,
            decoration: BoxDecoration(color: isPast ? Colors.grey : event.color, borderRadius: BorderRadius.circular(6)),
          ),
          title: Text(event.title, style: TextStyle(fontWeight: FontWeight.bold, color: isPast ? Colors.grey : Colors.black)),
          subtitle: Text(
            "${DateFormat('EEEE, dd.MM.yyyy', dateLocaleTag).format(event.start)} • ${event.isAllDay ? l10n.allDay : DateFormat('HH:mm').format(event.start)}",
            style: TextStyle(color: isPast ? Colors.grey : Colors.grey.shade700),
          ),
          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
          onTap: () {
            close(context, event);
            onEventSelected(event);
          },
        );
      },
    );
  }
}