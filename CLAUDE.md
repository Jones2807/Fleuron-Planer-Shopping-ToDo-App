# CLAUDE.md – Fleuron

## Projekt
Flutter-App (Android + Web/PWA) für Kalender, To-dos und Einkaufslisten über CalDAV,
optional Grocy und WebDAV. Code in `lib/` (models, screens, services, widgets).
Die Kernlogik steckt in `lib/services/caldav_service.dart`. Der Web-Build braucht den
PHP-Tunnel `php-tunnel/cors.php`; im Repo liegt nur `cors.example.php`, `cors.php` ist
gitignored und darf nie eingecheckt werden.

## Befehle
- `flutter pub get` – Achtung: kann `pubspec.lock`, `analysis_options.yaml` und
  Plugin-Registrants verändern. Solche Nebeneffekte nicht ungefragt mitcommitten.
- `flutter analyze`
- `flutter test`
- `flutter gen-l10n` – nach Änderungen an den ARB-Dateien
- Unter Windows braucht der Build den Entwicklermodus (Symlinks).

## Arbeitsweise
- Bevor du Code änderst: Lösungsansatz vorstellen und auf mein ausdrückliches Go warten.
- Arbeite nur auf Branches `claude/<aufgabe>`, immer von einem aktuellen `develop` abgezweigt.
  Niemals direkt auf `develop` oder `master` committen.
- Pull Requests gehen immer nach `develop`, nie nach `master`, und werden mit der
  GitHub CLI erstellt: `gh pr create --base develop`.

## Konventionen
- Commit-Messages im Conventional-Commits-Format, auf Englisch
  (z. B. `fix(caldav): ...`, `feat(todo): ...`).
- Code-Kommentare auf Englisch.
- Unterhaltung mit mir auf Deutsch.
- Neue UI-Texte nur über die ARB-Dateien: Schlüssel immer in `lib/l10n/app_de.arb`
  UND `lib/l10n/app_en.arb` anlegen, dann `flutter gen-l10n`. Keine fest codierten
  Strings in Widgets; die generierten `app_localizations*.dart` nicht von Hand bearbeiten.

## Sicherheit
Das Repo ist öffentlich: Niemals Zugangsdaten, echte Server-URLs, Domains, API-Keys,
`key.properties` oder Keystores committen. Echte Daten auf Screenshots unkenntlich machen.
