import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:flutter/material.dart';

import '../models/calendar_event.dart';
import '../models/employee.dart';

/// Local SQLite database used to cache events (mobile platforms only).
class LocalDatabase {
  static final LocalDatabase instance = LocalDatabase._init();
  static Database? _database;
  LocalDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('calendar_events.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, filePath);
    return await openDatabase(path, version: 2, // Bumped to 2 for the excludeDates migration below.
        onCreate: _createDB,
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            // Migrates existing databases in place, without losing any data.
            await db.execute('ALTER TABLE events ADD COLUMN excludeDates TEXT DEFAULT ""');
          }
        }
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE events (
        uid TEXT PRIMARY KEY, href TEXT, title TEXT NOT NULL,
        startTime TEXT NOT NULL, endTime TEXT NOT NULL, isAllDay INTEGER NOT NULL,
        participants TEXT NOT NULL, location TEXT, colorValue INTEGER NOT NULL,
        notificationsEnabled INTEGER NOT NULL, minutesBefore INTEGER NOT NULL,
        recurrence TEXT, recurrenceDays TEXT, recurrenceEndDate TEXT, excludeDates TEXT
      )
    ''');
  }

  Future<List<CalendarEvent>> getCachedEvents(List<Employee> allEmployees) async {
    if (kIsWeb) return [];
    final db = await instance.database;
    final result = await db.query('events');

    return result.map((json) {
      List<String> names = (json['participants'] as String).split(',');
      List<Employee> parts = allEmployees.where((emp) => names.contains(emp.name)).toList();

      Recurrence rec = Recurrence.values.firstWhere((e) => e.name == (json['recurrence'] as String?), orElse: () => Recurrence.none);
      List<int> recDays = [];
      if (json['recurrenceDays'] != null && json['recurrenceDays'].toString().isNotEmpty) {
        recDays = json['recurrenceDays'].toString().split(',').map((e) => int.parse(e)).toList();
      }
      DateTime? recEnd;
      if (json['recurrenceEndDate'] != null) recEnd = DateTime.parse(json['recurrenceEndDate'] as String).toLocal();

      List<DateTime> exDates = [];
      if (json['excludeDates'] != null && json['excludeDates'].toString().isNotEmpty) {
        exDates = json['excludeDates'].toString().split(',').map((e) => DateTime.parse(e).toLocal()).toList();
      }

      return CalendarEvent(
        uid: json['uid'] as String, href: json['href'] as String?, title: json['title'] as String,
        start: DateTime.parse(json['startTime'] as String).toLocal(), end: DateTime.parse(json['endTime'] as String).toLocal(),
        isAllDay: (json['isAllDay'] as int) == 1, participants: parts.isNotEmpty ? parts : [allEmployees.first],
        location: json['location'] as String, color: Color(json['colorValue'] as int),
        notificationsEnabled: (json['notificationsEnabled'] as int) == 1, minutesBefore: json['minutesBefore'] as int,
        recurrence: rec, recurrenceDays: recDays, recurrenceEndDate: recEnd, excludeDates: exDates,
      );
    }).toList();
  }

  Future<void> updateCache(List<CalendarEvent> serverEvents) async {
    if (kIsWeb) return;
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.delete('events');
      for (var event in serverEvents) {
        // Use REPLACE instead of the default ABORT conflict behavior: if the
        // server ever returns two events sharing the same UID (e.g. due to a
        // misconfigured calendar mapping), the later one simply overwrites
        // the earlier one instead of throwing and rolling back the entire
        // cache refresh, which would otherwise leave the calendar view empty.
        await txn.insert(
          'events',
          event.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }
}

/// Local cache used specifically for the PWA (web/iOS), since SQLite
/// isn't available there.
class WebEventCache {
  static Future<void> saveEvents(List<CalendarEvent> events) async {
    if (!kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    final jsonList = events.map((e) => e.toMap()).toList();
    await prefs.setString('web_cached_events', jsonEncode(jsonList));
  }

  static Future<List<CalendarEvent>> loadEvents(List<Employee> allEmployees) async {
    if (!kIsWeb) return [];
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString('web_cached_events');
    if (str == null) return [];

    final List<dynamic> decoded = jsonDecode(str);
    return decoded.map((json) {
      List<String> names = (json['participants'] as String).split(',');
      List<Employee> parts = allEmployees.where((emp) => names.contains(emp.name)).toList();

      Recurrence rec = Recurrence.values.firstWhere((e) => e.name == (json['recurrence'] as String?), orElse: () => Recurrence.none);
      List<int> recDays = [];
      if (json['recurrenceDays'] != null && json['recurrenceDays'].toString().isNotEmpty) {
        recDays = json['recurrenceDays'].toString().split(',').map((e) => int.parse(e)).toList();
      }
      DateTime? recEnd;
      if (json['recurrenceEndDate'] != null) recEnd = DateTime.parse(json['recurrenceEndDate'] as String).toLocal();

      List<DateTime> exDates = [];
      if (json['excludeDates'] != null && json['excludeDates'].toString().isNotEmpty) {
        exDates = json['excludeDates'].toString().split(',').map((e) => DateTime.parse(e).toLocal()).toList();
      }

      return CalendarEvent(
        uid: json['uid'] as String, href: json['href'] as String?, title: json['title'] as String,
        start: DateTime.parse(json['startTime'] as String).toLocal(), end: DateTime.parse(json['endTime'] as String).toLocal(),
        isAllDay: (json['isAllDay'] as int) == 1, participants: parts.isNotEmpty ? parts : [allEmployees.first],
        location: json['location'] as String, color: Color(json['colorValue'] as int),
        notificationsEnabled: (json['notificationsEnabled'] as int) == 1, minutesBefore: json['minutesBefore'] as int,
        recurrence: rec, recurrenceDays: recDays, recurrenceEndDate: recEnd, excludeDates: exDates,
      );
    }).toList();
  }
}