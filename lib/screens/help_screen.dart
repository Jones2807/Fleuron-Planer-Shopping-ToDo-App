import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_markdown/flutter_markdown.dart';

import '../l10n/app_localizations.dart';

/// Loads the user guide from assets and renders it as formatted
/// markdown. Picks the German or English guide file depending on the
/// app's currently active language.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  Future<String> _loadMarkdown(BuildContext context) async {
    final isGerman = Localizations.localeOf(context).languageCode == 'de';
    final assetPath = isGerman ? 'assets/anleitung_de.md' : 'assets/anleitung_en.md';
    return await rootBundle.loadString(assetPath);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.helpAndGuide),
        backgroundColor: const Color(0xFF4A73D1),
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<String>(
        future: _loadMarkdown(context),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(l10n.helpLoadError));
          }
          return Markdown(
            data: snapshot.data ?? "",
            styleSheet: MarkdownStyleSheet(
              h1: const TextStyle(color: Color(0xFF4A73D1), fontSize: 24, fontWeight: FontWeight.bold),
              h2: const TextStyle(color: Color(0xFF4A73D1), fontSize: 20, fontWeight: FontWeight.bold),
              p: const TextStyle(fontSize: 16, height: 1.5),
            ),
          );
        },
      ),
    );
  }
}