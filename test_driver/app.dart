import 'package:flutter_driver/driver_extension.dart';
import 'package:fleuron/main.dart' as app;

/// Entry point for remote control via flutter_driver (e.g. the Dart MCP server).
///
/// Reuses the regular startup in `lib/main.dart`, so all initialization
/// (date formatting, locale, notifications) stays in one place.
/// Start with: `flutter run -t test_driver/app.dart`
void main() {
  enableFlutterDriverExtension();
  app.main();
}
