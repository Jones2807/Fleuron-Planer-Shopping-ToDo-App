import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Manages custom colors for group calendars (calendars shared by
/// more than one person).
class GroupColors {
  static final Map<String, Color> _customColors = {};

  static Future<void> loadColors() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonStr = prefs.getString('group_colors');
    if (jsonStr != null) {
      final Map<String, dynamic> decoded = jsonDecode(jsonStr);
      _customColors.clear(); // Clear first, so stale entries don't linger.
      decoded.forEach((key, value) {
        _customColors[key] = Color(value as int);
      });
    }
  }

  static Future<void> saveColor(String groupKey, Color color) async {
    _customColors[groupKey] = color;
    final prefs = await SharedPreferences.getInstance();
    final Map<String, int> toSave = {};
    _customColors.forEach((key, value) {
      // Serialize each stored color as a 32-bit ARGB integer.
      toSave[key] = value.toARGB32();
    });
    await prefs.setString('group_colors', jsonEncode(toSave));
  }

  static Color getColor(String groupKey) {
    return _customColors[groupKey] ?? const Color(0xFF4A90E2);
  }
}