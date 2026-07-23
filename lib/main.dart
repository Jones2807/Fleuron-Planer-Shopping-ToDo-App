import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/app_localizations.dart';
import 'services/notification_service.dart';
import 'services/locale_service.dart';
import 'screens/calendar_screen.dart';

/// App entry point.
///
/// Performs the async setup that must complete before the first frame
/// is drawn: date-format data for every supported language, the
/// user's persisted language override, and the local-notification
/// system.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load date formatting data (month/weekday names, etc.) for every
  // language the app ships translations for.
  await initializeDateFormatting('de_DE', null);
  await initializeDateFormatting('en_US', null);

  // Restore a manually chosen language, if the user set one in a
  // previous session. Defaults to "follow system language".
  await LocaleService.init();

  // Boots the local-notification system (this also loads timezone
  // data internally).
  await NotificationService.init();

  runApp(const MyApp());
}

/// Root widget of the application.
///
/// Wraps [MaterialApp] in a [ValueListenableBuilder] listening to
/// [LocaleService.localeNotifier], so the entire app rebuilds with
/// the new language immediately when the user switches it - no app
/// restart required.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale?>(
      valueListenable: LocaleService.localeNotifier,
      builder: (context, overrideLocale, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4A73D1)),
            useMaterial3: true,
            scaffoldBackgroundColor: const Color(0xFFF2F2F7),
            textSelectionTheme: const TextSelectionThemeData(
              cursorColor: Color(0xFF4A73D1),
              selectionColor: Color(0x664A73D1), // slightly transparent blue
              selectionHandleColor: Color(0xFF4A73D1),
            ),
            inputDecorationTheme: const InputDecorationTheme(
              isDense: true, // makes tapping/hitting the cursor more precise
            ),
          ),
          // null = follow the system language (resolved below).
          locale: overrideLocale,
          supportedLocales: LocaleService.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          // Flutter's default resolution already falls back to the
          // first entry of supportedLocales (English) when the
          // device language isn't supported. This callback makes
          // that fallback explicit and future-proof, in case the
          // list order ever changes.
          localeResolutionCallback: (deviceLocale, supported) {
            if (deviceLocale != null) {
              for (final locale in supported) {
                if (locale.languageCode == deviceLocale.languageCode) {
                  return locale;
                }
              }
            }
            return const Locale('en');
          },
          home: const TeamCalendarScreen(),
        );
      },
    );
  }
}