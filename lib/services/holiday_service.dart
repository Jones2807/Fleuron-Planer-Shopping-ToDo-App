import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class HolidayService {
  // Defaults: Germany / Bavaria.
  static String countryCode = 'DE';
  static String? regionCode = 'DE-BY';

  static Map<DateTime, String> _cachedHolidays = {};

  /// Loads the saved country/region settings from SharedPreferences.
  static Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    countryCode = prefs.getString('holiday_country') ?? 'DE';

    // 'NONE' or unset means: load nationwide holidays only.
    final savedRegion = prefs.getString('holiday_region');
    if (savedRegion == null || savedRegion == 'NONE' || savedRegion.isEmpty) {
      regionCode = null;
    } else {
      regionCode = savedRegion;
    }
  }

  /// Loads the holidays for [year], honoring the current settings.
  static Future<void> loadHolidays(int year) async {
    await loadSettings(); // Refresh settings before loading.

    final prefs = await SharedPreferences.getInstance();
    // Cache key depends on country and region, so switching either
    // doesn't show stale data from a previous selection.
    final String cacheKey = 'holidays_${countryCode}_${regionCode ?? "ALL"}_$year';

    // 1. Load from cache first, for an immediate display.
    final cachedData = prefs.getString(cacheKey);
    if (cachedData != null) {
      _parseAndSetHolidays(cachedData);
    }

    // 2. Fetch fresh data from the free API in the background.
    try {
      final url = Uri.parse('https://date.nager.at/api/v3/PublicHolidays/$year/$countryCode');
      final response = await http.get(url).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        await prefs.setString(cacheKey, response.body);
        _parseAndSetHolidays(response.body);
      }
    } catch (e) {
      debugPrint("Couldn't fetch holidays live, using cache: $e");
    }
  }

  static void _parseAndSetHolidays(String jsonString) {
    try {
      final List<dynamic> data = jsonDecode(jsonString);
      Map<DateTime, String> newHolidays = {};

      for (var item in data) {
        final dateStr = item['date'] as String;
        final name = item['localName'] as String;
        final counties = item['counties'] as List<dynamic>?;

        // Relevant if it's a nationwide holiday (counties == null), or
        // a regional one that covers the selected state.
        bool isRelevant = counties == null || (regionCode != null && counties.contains(regionCode));

        if (isRelevant) {
          final parts = dateStr.split('-');
          if (parts.length == 3) {
            final dt = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
            newHolidays[dt] = name;
          }
        }
      }

      _cachedHolidays = newHolidays;
    } catch (e) {
      debugPrint("Error parsing holidays: $e");
    }
  }

  /// Returns the holiday name for [day], or `null` if it isn't one.
  static String? getHolidayName(DateTime day) {
    final dateOnly = DateTime(day.year, day.month, day.day);
    return _cachedHolidays[dateOnly];
  }
}