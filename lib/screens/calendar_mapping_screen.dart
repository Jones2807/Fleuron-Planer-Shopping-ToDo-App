import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../models/employee.dart';
import '../services/caldav_service.dart';
import '../services/secure_vault.dart';
import '../l10n/app_localizations.dart';

/// A configuration screen that allows users to map discovered CalDAV calendars
/// (folders) to specific [Employee] profiles within a selected workspace.
class CalendarMappingScreen extends StatefulWidget {
  /// The global list of employees, used as a fallback or initial value.
  final List<Employee> allEmployees;

  /// Callback triggered whenever the calendar mappings are updated.
  final VoidCallback onMappingChanged;

  /// Creates a new [CalendarMappingScreen] instance.
  const CalendarMappingScreen({
    super.key,
    required this.allEmployees,
    required this.onMappingChanged,
  });

  @override
  State<CalendarMappingScreen> createState() => _CalendarMappingScreenState();
}

class _CalendarMappingScreenState extends State<CalendarMappingScreen> {
  // --- Storage keys & constants ---
  static const String _storageKeyMapping = 'custom_calendar_mapping_v2';
  static const String _storageKeyTeamPrefix = 'saved_team_';
  static const String _storageKeyGlobalTeam = 'saved_team';

  /// Default employee name used as a fallback on fresh installs, before
  /// any team has been configured. Intentionally a literal value (not
  /// localized) - the same convention is used for the equivalent
  /// fallback in `team_manager_screen.dart`.
  static const String _defaultFallbackName = 'Ich';

  /// List of available, writable CalDAV accounts.
  List<CalDavAccount> _accounts = [];

  /// The currently selected CalDAV account.
  CalDavAccount? _selectedAccount;

  /// Indicates whether the initial data is still loading.
  bool _isLoading = true;

  /// Indicates whether the app is currently fetching calendars from the server.
  bool _isScanning = false;

  /// Holds the raw calendar data discovered from the server.
  List<Map<String, String>> _localRawCalendars = [];

  /// Holds the employees for the CURRENTLY SELECTED workspace.
  List<Employee> _currentWorkspaceTeam = [];

  /// Stores the mapping relationship: AccountID -> { Href -> List of Employee Names }
  final Map<String, Map<String, List<String>>> _accountMappings = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// Initializes the screen by loading saved accounts, existing mappings,
  /// and automatically triggering a server scan for the selected account.
  Future<void> _loadData() async {
    final allAccounts = await SecureVault.getAllAccounts();
    final writableAccounts = allAccounts.where((a) => !a.isReadOnly && a.isActive).toList();

    final prefs = await SharedPreferences.getInstance();
    final String? savedJson = prefs.getString(_storageKeyMapping);

    // Restore previously saved calendar mappings
    if (savedJson != null) {
      final Map<String, dynamic> decoded = jsonDecode(savedJson);
      decoded.forEach((accountId, hrefMap) {
        _accountMappings[accountId] = {};
        (hrefMap as Map<String, dynamic>).forEach((href, namesStr) {
          _accountMappings[accountId]![href] = (namesStr as String).split(',');
        });
      });
    }

    setState(() {
      _accounts = writableAccounts;
      if (_accounts.isNotEmpty) {
        _selectedAccount = _accounts.first;
      }
    });

    if (_selectedAccount != null) {
      await _scanSelectedAccount();
    } else {
      setState(() => _isLoading = false);
    }
  }

  /// Loads the specific team members assigned to the currently selected account.
  Future<void> _loadTeamForSelectedAccount() async {
    if (_selectedAccount == null) return;

    final prefs = await SharedPreferences.getInstance();
    final accountId = _selectedAccount!.id;
    final String? teamJson = prefs.getString('$_storageKeyTeamPrefix$accountId');

    List<Employee> loadedTeam = [];

    if (teamJson != null) {
      final List<dynamic> decoded = jsonDecode(teamJson);
      loadedTeam = decoded.map((e) => Employee.fromJson(e)).toList();
    } else {
      // Migration fallback (similar to TeamManager):
      // If empty, check the primary global account for existing data.
      if (_accounts.isNotEmpty && accountId == _accounts.first.id) {
        final String? globalJson = prefs.getString(_storageKeyGlobalTeam);
        if (globalJson != null) {
          final List<dynamic> decoded = jsonDecode(globalJson);
          loadedTeam = decoded.map((e) => Employee.fromJson(e)).toList();
        } else {
          // Absolute fallback for fresh installs
          loadedTeam = [const Employee(_defaultFallbackName, Color(0xFF4A73D1))];
        }
      } else {
        loadedTeam = [];
      }
    }

    setState(() {
      _currentWorkspaceTeam = loadedTeam;
    });
  }

  /// Connects to the CalDAV server of the selected account, retrieves available
  /// calendars, and attempts to auto-map them based on employee names.
  Future<void> _scanSelectedAccount() async {
    if (_selectedAccount == null) return;

    setState(() {
      _isScanning = true;
      _localRawCalendars.clear();
    });

    // 1. Load the team for this workspace first
    await _loadTeamForSelectedAccount();

    // 2. Scan the server folders using CalDavService
    CalDavConfig.serverUrl = _selectedAccount!.url;
    CalDavConfig.username = _selectedAccount!.username;
    CalDavConfig.password = _selectedAccount!.password;

    await CalDavService.discoverCalendars(_currentWorkspaceTeam);

    bool dataChanged = false;

    // Self-healing: Remove ghost paths that no longer exist on the server
    if (_accountMappings.containsKey(_selectedAccount!.id)) {
      final validHrefs = CalDavService.discoveredRawCalendars.map((c) => c['href']!).toSet();
      final currentMap = _accountMappings[_selectedAccount!.id]!;
      int beforeCount = currentMap.length;
      currentMap.removeWhere((href, names) => !validHrefs.contains(href));
      if (currentMap.length != beforeCount) dataChanged = true;
    }

    // Auto-save: Attempt to auto-map new folders based on employee names
    for (var cal in CalDavService.discoveredRawCalendars) {
      final href = cal['href']!;
      final name = cal['name']!;
      List<String> currentMapped = _accountMappings[_selectedAccount!.id]?[href] ?? [];

      if (currentMapped.isEmpty) {
        List<String> newSelection = [];
        for (var emp in _currentWorkspaceTeam) {
          if (name.toLowerCase().contains(emp.name.toLowerCase())) {
            newSelection.add(emp.name);
          }
        }
        newSelection.sort();
        if (newSelection.isNotEmpty) {
          if (!_accountMappings.containsKey(_selectedAccount!.id)) {
            _accountMappings[_selectedAccount!.id] = {};
          }
          _accountMappings[_selectedAccount!.id]![href] = newSelection;
          dataChanged = true;
        }
      }
    }

    if (dataChanged) {
      _persistMappings();
    }

    setState(() {
      _localRawCalendars = List.from(CalDavService.discoveredRawCalendars);
      _isScanning = false;
      _isLoading = false;
    });
  }

  /// Serializes the current `_accountMappings` to JSON and saves them locally.
  Future<void> _persistMappings() async {
    Map<String, dynamic> jsonMap = {};
    _accountMappings.forEach((accountId, hrefMap) {
      jsonMap[accountId] = {};
      hrefMap.forEach((h, names) {
        if (names.isNotEmpty) jsonMap[accountId][h] = names.join(',');
      });
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKeyMapping, jsonEncode(jsonMap));

    // Notify parent widget about the update
    widget.onMappingChanged();
  }

  /// Updates and saves the mapped employees for a specific calendar folder (href).
  Future<void> _saveMapping(String href, List<String> selectedNames) async {
    if (_selectedAccount == null) return;
    selectedNames.sort();

    setState(() {
      if (!_accountMappings.containsKey(_selectedAccount!.id)) {
        _accountMappings[_selectedAccount!.id] = {};
      }
      _accountMappings[_selectedAccount!.id]![href] = selectedNames;
    });

    await _persistMappings();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: Text(l10n.mapCalendarsTitle),
        backgroundColor: const Color(0xFF4A73D1),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _accounts.isEmpty
          ? Center(child: Text(l10n.noActiveAccountsFound))
          : Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Colors.grey.shade300))),
            child: Row(
              children: [
                const Icon(Icons.cloud_sync, color: Color(0xFF4A73D1)),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<CalDavAccount>(
                      value: _selectedAccount,
                      isExpanded: true,
                      items: _accounts.map((acc) => DropdownMenuItem(value: acc, child: Text(acc.name, style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
                      onChanged: (newAccount) {
                        if (newAccount != null && newAccount.id != _selectedAccount?.id) {
                          setState(() => _selectedAccount = newAccount);
                          _scanSelectedAccount();
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isScanning
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const CircularProgressIndicator(), const SizedBox(height: 16), Text(l10n.loadingFoldersAndPeople)] ))
                : _localRawCalendars.isEmpty
                ? Center(child: Text(l10n.noCalendarsFound))
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _localRawCalendars.length,
              itemBuilder: (context, index) {
                final cal = _localRawCalendars[index];
                final href = cal['href']!;
                final name = cal['name']!;
                List<String> selectedNames = _accountMappings[_selectedAccount?.id]?[href] ?? [];

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.folderLabel(name), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Text(l10n.assignedPeopleLabel, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                        const SizedBox(height: 8),
                        if (_currentWorkspaceTeam.isEmpty)
                          Text(l10n.noPeopleAssignedYet, style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.orange, fontSize: 12))
                        else
                          Wrap(
                            spacing: 8,
                            children: _currentWorkspaceTeam.map((emp) {
                              final isSelected = selectedNames.contains(emp.name);
                              return FilterChip(
                                label: Text(emp.name),
                                selected: isSelected,
                                selectedColor: emp.color.withValues(alpha: 0.3),
                                onSelected: (bool selected) {
                                  List<String> newSelection = List.from(selectedNames);
                                  if (selected) {
                                    newSelection.add(emp.name);
                                  } else {
                                    newSelection.remove(emp.name);
                                  }
                                  _saveMapping(href, newSelection);
                                },
                              );
                            }).toList(),
                          )
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}