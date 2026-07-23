import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Represents a saved filter configuration for the calendar view.
///
/// This model allows users to store specific combinations of active calendars
/// as a preset, which can be quickly selected from the UI.
class FilterPreset {
  // --- Serialization Keys (Clean Architecture) ---
  static const String keyId = 'id';
  static const String keyName = 'name';
  static const String keyIconCodePoint = 'iconCodePoint';
  static const String keyActiveCalendars = 'activeCalendars';

  /// The unique identifier of the preset.
  final String id;

  /// The display name of the filter preset.
  final String name;

  /// The numeric code point representing the Flutter [IconData].
  final int iconCodePoint;

  /// A list of calendar IDs or names that should be visible when this preset is active.
  /// An empty list typically implies that all calendars are shown.
  final List<String> activeCalendars;

  /// Creates a new instance of [FilterPreset].
  FilterPreset({
    required this.id,
    required this.name,
    required this.iconCodePoint,
    required this.activeCalendars,
  });

  /// Converts the [FilterPreset] instance into a JSON-compatible Map.
  Map<String, dynamic> toJson() => {
    keyId: id,
    keyName: name,
    keyIconCodePoint: iconCodePoint,
    keyActiveCalendars: activeCalendars,
  };

  /// Creates a [FilterPreset] instance from a JSON map.
  ///
  /// If the `iconCodePoint` or `activeCalendars` are missing in the JSON,
  /// it provides safe default fallback values.
  factory FilterPreset.fromJson(Map<String, dynamic> json) => FilterPreset(
    id: json[keyId],
    name: json[keyName],
    iconCodePoint: json[keyIconCodePoint] ?? Icons.filter_alt.codePoint,
    activeCalendars: List<String>.from(json[keyActiveCalendars] ?? []),
  );
}

/// A service class for managing [FilterPreset] data.
///
/// Handles the persistent storage and retrieval of custom filter presets
/// using [SharedPreferences], making it compatible with PWA and mobile platforms.
class PresetService {
  /// The key used to store the presets in [SharedPreferences].
  static const String _storageKey = 'custom_filter_presets';

  /// Loads all locally stored presets.
  ///
  /// If no presets are found in the local storage, it generates and returns
  /// a default "show all" preset, named [defaultPresetName]. That name is
  /// supplied by the caller rather than hardcoded here, since this service
  /// has no [BuildContext] to resolve the app's active language itself
  /// (see `calendar_dialogs.dart`, which passes the localized string).
  static Future<List<FilterPreset>> loadPresets({required String defaultPresetName}) async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonStr = prefs.getString(_storageKey);

    if (jsonStr != null && jsonStr.isNotEmpty) {
      final List<dynamic> decoded = jsonDecode(jsonStr);
      return decoded.map((e) => FilterPreset.fromJson(e)).toList();
    }

    // Generate default preset if none exist
    return [
      FilterPreset(
        id: 'preset_all',
        name: defaultPresetName,
        iconCodePoint: Icons.all_inclusive.codePoint,
        activeCalendars: [], // Empty usually means "Show all" in the filter logic
      ),
    ];
  }

  /// Saves the provided list of [presets] to the local storage.
  static Future<void> savePresets(List<FilterPreset> presets) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = presets.map((p) => p.toJson()).toList();
    await prefs.setString(_storageKey, jsonEncode(jsonList));
  }
}