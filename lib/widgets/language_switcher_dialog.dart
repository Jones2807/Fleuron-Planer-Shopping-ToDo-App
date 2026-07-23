import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/locale_service.dart';

/// Dialog that lets the user pick the app's display language.
///
/// Offers "System" (follow the device language), "German" and
/// "English". The choice is persisted via [LocaleService] and takes
/// effect immediately, without restarting the app.
class LanguageSwitcherDialog extends StatelessWidget {
  const LanguageSwitcherDialog({super.key});

  /// Convenience helper to open this dialog.
  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const LanguageSwitcherDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ValueListenableBuilder<Locale?>(
      valueListenable: LocaleService.localeNotifier,
      builder: (context, currentOverride, _) {
        return SimpleDialog(
          title: Text(l10n.language),
          children: [
            RadioListTile<Locale?>(
              title: Text(l10n.languageSystem),
              value: null,
              groupValue: currentOverride,
              onChanged: (value) {
                LocaleService.setLocale(value);
                Navigator.pop(context);
              },
            ),
            RadioListTile<Locale?>(
              title: Text(l10n.languageGerman),
              value: const Locale('de'),
              groupValue: currentOverride,
              onChanged: (value) {
                LocaleService.setLocale(value);
                Navigator.pop(context);
              },
            ),
            RadioListTile<Locale?>(
              title: Text(l10n.languageEnglish),
              value: const Locale('en'),
              groupValue: currentOverride,
              onChanged: (value) {
                LocaleService.setLocale(value);
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }
}