import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'caldav_service.dart';
import 'secure_vault.dart';
import '../models/todo_task.dart';

/// Which of the three per-device sync filters a diff entry belongs
/// to. Mirrors the three toggles in `sync_settings_screen.dart`
/// (team & calendar colors, store names, route sort order).
enum SyncCategory { team, stores, routes }

/// A single human-readable line describing one detected change,
/// tagged with the [SyncCategory] it belongs to - so the UI can
/// group it by, and gray it out according to, the matching
/// per-device filter toggle.
class SyncDiffEntry {
  final SyncCategory category;
  final String description;
  const SyncDiffEntry({required this.category, required this.description});
}

/// The difference between the locally stored settings and whatever
/// is currently on the sync server, ready to show the user before
/// anything gets overwritten.
class SyncDiff {
  final List<SyncDiffEntry> entries;
  final Map<String, dynamic> rawData;

  SyncDiff({required this.entries, required this.rawData});

  bool get hasChanges => entries.isNotEmpty;

  /// All entries belonging to [category], e.g. to render them
  /// grouped under that category's heading in the diff dialog.
  List<SyncDiffEntry> forCategory(SyncCategory category) =>
      entries.where((e) => e.category == category).toList();
}

/// Localized strings [SyncService] needs to describe diffs and errors
/// to the user (e.g. "New store: {name}", "Network error: {error}").
///
/// Bundled into one object rather than passed as many individual
/// parameters, since this static service has no [BuildContext] to
/// resolve the app's active language itself - see
/// `sync_settings_screen.dart`, which builds this from
/// [AppLocalizations] once per action.
class SyncLabels {
  final String Function(String name) storeAdded;
  final String Function(String name) storeRemoved;
  final String routesChanged;
  final String teamOrColorsChanged;
  final String Function(int code) serverError;
  final String Function(String error) networkError;
  final String noActiveAccount;
  final String noTaskListFound;
  final String Function(String error) caldavError;
  final String unnamedTaskFallback;

  const SyncLabels({
    required this.storeAdded,
    required this.storeRemoved,
    required this.routesChanged,
    required this.teamOrColorsChanged,
    required this.serverError,
    required this.networkError,
    required this.noActiveAccount,
    required this.noTaskListFound,
    required this.caldavError,
    required this.unnamedTaskFallback,
  });
}

class SyncService {
  // --- Shared helpers for gathering data and diffing ---

  /// Gathers all locally stored settings into a clean JSON tree
  /// (values already stored as JSON strings are decoded first, so
  /// nothing ends up double-escaped).
  static Future<Map<String, dynamic>> _gatherLocalData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    dynamic parseIfJson(String? value) {
      if (value == null) return null;
      try { return jsonDecode(value); } catch (_) { return value; }
    }

    return {
      'group_colors': parseIfJson(prefs.getString('group_colors')),
      'saved_team': parseIfJson(prefs.getString('saved_team')),
      'storeProfileNames': prefs.getStringList('storeProfileNames'),
      'storeProfiles': parseIfJson(prefs.getString('storeProfiles')),
      'last_updated': DateTime.now().toIso8601String(),
    };
  }

  /// Compares [serverData] against the current local settings and
  /// builds the human-readable [SyncDiff] describing what would
  /// change, using [labels] for the localized description text.
  static Future<SyncDiff> _generateDiff(Map<String, dynamic> serverData, SyncLabels labels) async {
    final prefs = await SharedPreferences.getInstance();
    List<SyncDiffEntry> entries = [];

    // Compares the clean server-side JSON against the locally stored JSON string.
    bool isDifferent(String key, dynamic serverValue) {
      if (serverValue == null) return false;
      final localString = prefs.getString(key);
      final serverString = serverValue is String ? serverValue : jsonEncode(serverValue);
      return localString != serverString;
    }

    // 1. Compare store profiles.
    final List<String> localStores = prefs.getStringList('storeProfileNames') ?? [];
    final List<String> serverStores = List<String>.from(serverData['storeProfileNames'] ?? []);

    for (var s in serverStores) {
      if (!localStores.contains(s)) entries.add(SyncDiffEntry(category: SyncCategory.stores, description: labels.storeAdded(s)));
    }
    for (var l in localStores) {
      if (!serverStores.contains(l)) entries.add(SyncDiffEntry(category: SyncCategory.stores, description: labels.storeRemoved(l)));
    }

    // 2. Compare store route sort orders.
    if (isDifferent('storeProfiles', serverData['storeProfiles'])) {
      entries.add(SyncDiffEntry(category: SyncCategory.routes, description: labels.routesChanged));
    }

    // 3. Compare team members and calendar color assignments.
    if (isDifferent('saved_team', serverData['saved_team']) || isDifferent('group_colors', serverData['group_colors'])) {
      entries.add(SyncDiffEntry(category: SyncCategory.team, description: labels.teamOrColorsChanged));
    }

    return SyncDiff(entries: entries, rawData: serverData);
  }

  // --- WebDAV sync ---

  /// Uploads the current local settings as a JSON file to a WebDAV
  /// server. Returns `null` on success, or a localized error message
  /// on failure.
  static Future<String?> uploadSettings({required String url, required String user, required String pass, required SyncLabels labels}) async {
    try {
      final exportData = await _gatherLocalData();
      final auth = 'Basic ${base64Encode(utf8.encode('$user:$pass'))}';

      final response = await http.put(
        Uri.parse(url),
        headers: {'Authorization': auth, 'Content-Type': 'application/json'},
        body: jsonEncode(exportData),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return null;
      } else {
        return labels.serverError(response.statusCode);
      }
    } catch (e) {
      return labels.networkError(e.toString());
    }
  }

  /// Fetches the WebDAV settings file and diffs it against the local
  /// state. Returns `null` if the file couldn't be fetched/parsed.
  static Future<SyncDiff?> compareSettings({required String url, required String user, required String pass, required SyncLabels labels}) async {
    try {
      final auth = 'Basic ${base64Encode(utf8.encode('$user:$pass'))}';
      final response = await http.get(Uri.parse(url), headers: {'Authorization': auth});

      if (response.statusCode != 200) return null;

      final Map<String, dynamic> serverData = jsonDecode(response.body);
      return await _generateDiff(serverData, labels);
    } catch (e) {
      debugPrint("WebDAV Compare Exception: $e");
      return null;
    }
  }

  // --- CalDAV piggyback sync ---

  /// Uploads the current local settings as a hidden `VTODO` task
  /// (named `APP_CONFIG_$fileName`) in the account's first to-do
  /// list, instead of needing a separate WebDAV server. Returns
  /// `null` on success, or a localized error message on failure.
  static Future<String?> uploadSettingsCaldav({required String fileName, required SyncLabels labels}) async {
    try {
      final accounts = await SecureVault.getAllAccounts();
      final activeAccount = accounts.where((a) => a.isActive).firstOrNull;
      if (activeAccount == null) return labels.noActiveAccount;

      final exportData = await _gatherLocalData();
      final jsonString = jsonEncode(exportData); // Plain JSON, no nested-escaping issues.
      final taskTitle = "APP_CONFIG_$fileName";

      final lists = await CalDavService.fetchTodoLists(account: activeAccount);
      if (lists.isEmpty) return labels.noTaskListFound;

      String targetListPath = lists.values.first;

      final tasks = await CalDavService.fetchTasks(targetListPath, account: activeAccount, unnamedFallback: labels.unnamedTaskFallback);
      TodoTask? configTask;
      for (var t in tasks) {
        if (t.title == taskTitle) configTask = t;
      }

      if (configTask == null) {
        await CalDavService.addTask(targetListPath, taskTitle, description: jsonString, account: activeAccount);
      } else {
        final updatedTask = TodoTask(
          uid: configTask.uid,
          title: configTask.title,
          isDone: configTask.isDone,
          description: jsonString,
          dueDate: configTask.dueDate,
        );
        await CalDavService.updateTask(targetListPath, updatedTask, account: activeAccount);
      }

      return null;
    } catch (e) {
      return labels.caldavError(e.toString());
    }
  }

  /// Finds the `APP_CONFIG_$fileName` task across all of the
  /// account's to-do lists and diffs its stored settings JSON
  /// against the local state. Returns `null` if no such task exists
  /// yet or it has no data.
  static Future<SyncDiff?> compareSettingsCaldav({required String fileName, required SyncLabels labels}) async {
    try {
      final accounts = await SecureVault.getAllAccounts();
      final activeAccount = accounts.where((a) => a.isActive).firstOrNull;
      if (activeAccount == null) return null;

      final taskTitle = "APP_CONFIG_$fileName";
      final lists = await CalDavService.fetchTodoLists(account: activeAccount);

      TodoTask? configTask;
      for (var listPath in lists.values) {
        final tasks = await CalDavService.fetchTasks(listPath, account: activeAccount, unnamedFallback: labels.unnamedTaskFallback);
        for (var t in tasks) {
          if (t.title == taskTitle) { configTask = t; break; }
        }
        if (configTask != null) break;
      }

      if (configTask == null || configTask.description == null || configTask.description!.isEmpty) {
        return null;
      }

      final Map<String, dynamic> serverData = jsonDecode(configTask.description!);
      return await _generateDiff(serverData, labels);

    } catch (e) {
      debugPrint("CalDAV Compare Exception: $e");
      return null;
    }
  }

  // --- Applying settings ---

  /// Writes [importData] back into local storage, honoring the
  /// per-device filter toggles (team/colors, stores, routes) so a
  /// device can adopt some data packages while keeping its own
  /// values for others. The toggles are read per workspace (see
  /// `sync_settings_screen.dart`, which saves them under
  /// `sync_toggle_*_$accountId`) - [accountId] must match the
  /// workspace the toggles were configured for, or they'll silently
  /// fall back to their defaults.
  static Future<void> applySettings(Map<String, dynamic> importData, {required String accountId}) async {
    final prefs = await SharedPreferences.getInstance();

    final bool syncTeam = prefs.getBool('sync_toggle_team_$accountId') ?? true;
    final bool syncStores = prefs.getBool('sync_toggle_stores_$accountId') ?? true;
    final bool syncRoutes = prefs.getBool('sync_toggle_routes_$accountId') ?? false;

    // Re-encodes values back into strings for SharedPreferences.
    String encodeIfNeeded(dynamic data) {
      return data is String ? data : jsonEncode(data);
    }

    if (syncTeam) {
      if (importData['group_colors'] != null) await prefs.setString('group_colors', encodeIfNeeded(importData['group_colors']));
      if (importData['saved_team'] != null) await prefs.setString('saved_team', encodeIfNeeded(importData['saved_team']));
    }

    if (syncStores && importData['storeProfileNames'] != null) {
      await prefs.setStringList('storeProfileNames', List<String>.from(importData['storeProfileNames']));
    }

    if (syncRoutes && importData['storeProfiles'] != null) {
      await prefs.setString('storeProfiles', encodeIfNeeded(importData['storeProfiles']));
    }
  }
}