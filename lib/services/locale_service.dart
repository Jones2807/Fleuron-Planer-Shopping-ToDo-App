import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages the user's language preference for the app.
///
/// By default the app follows the device's system language. If the
/// system language is not one the app ships translations for, it
/// falls back to English (see [MyApp.localeResolutionCallback] in
/// `main.dart`). Users can override this via the in-app language
/// switcher; the override is persisted locally and survives app
/// restarts.
class LocaleService {
  LocaleService._();

  static const String _prefsKey = 'app_locale_override';

  /// The currently active language override.
  ///
  /// A value of `null` means "follow the system language". Widgets
  /// that need to rebuild when the language changes should listen to
  /// this notifier (see `main.dart`, which wraps [MaterialApp] in a
  /// [ValueListenableBuilder]).
  static final ValueNotifier<Locale?> localeNotifier =
  ValueNotifier<Locale?>(null);

  /// Languages the app currently ships translations for.
  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('de'),
  ];

  /// Loads the persisted language override, if any.
  ///
  /// Must be called once during app startup, before [runApp].
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_prefsKey);
    if (code != null) {
      localeNotifier.value = Locale(code);
    }
  }

  /// Sets and persists a manual language override.
  ///
  /// Pass `null` to clear the override and follow the system language
  /// again. Triggers an immediate rebuild of the app via
  /// [localeNotifier].
  static Future<void> setLocale(Locale? locale) async {
    final prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      await prefs.remove(_prefsKey);
    } else {
      await prefs.setString(_prefsKey, locale.languageCode);
    }
    localeNotifier.value = locale;
  }
}