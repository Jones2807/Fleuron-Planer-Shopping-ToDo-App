# 📅 Fleuron – Anleitung

Fleuron ist ein plattformübergreifender Kalender, To-Do-Manager und Einkaufslisten-Planer. Die App funktioniert mit **jedem regulären CalDAV-Konto** – es gibt keinen Zwang zu einem bestimmten Server oder Anbieter. Grocy-Anbindung, Einstellungs-Sync und der PHP-Tunnel für die Web-Version sind optionale Zusatzmodule, keine Voraussetzung.

---

## 🧩 1. Das Grundkonzept: Workspaces

Fleuron organisiert alles über **Workspaces**. Ein Workspace ist ein eigenständiges CalDAV-Konto mit seinen eigenen Einstellungen – eigenem Team, eigener Einkaufsliste, eigenem Sync.

Das bedeutet: Du kannst mehrere Workspaces gleichzeitig anlegen, zum Beispiel einen für die Familie und einen für einen Verein oder die Arbeit. Jeder Workspace lässt sich unabhängig konfigurieren und bei Bedarf auch deaktivieren, ohne dass die anderen betroffen sind.

Alles Weitere in dieser Anleitung – Team, Kalenderzuordnung, Einkaufsliste, Sync – bezieht sich immer auf **einen** Workspace, den du gerade ausgewählt hast.

---

## 🛠 2. Ersten Workspace anlegen

Öffne das Menü (die drei Striche oben links) und tippe auf **Workspaces & Konten**.

Tippe auf **Neuer Workspace** und trage ein:

- **Anzeigename** – ein Name deiner Wahl (z. B. „Familie" oder „Verein")
- **Server-URL** – die CalDAV-Adresse deines Kalender-Anbieters. Das funktioniert mit jedem Standard-CalDAV-Server (z. B. Synology Calendar, Nextcloud, oder ein anderer CalDAV-fähiger Dienst)
- **Benutzername** und **Passwort**

Falls du nur einen bestehenden Kalender **lesen**, aber nicht bearbeiten möchtest, aktiviere **Nur-Lese Abo (.ics)** – dafür reicht eine öffentliche .ics-URL, ohne Zugangsdaten.

---

## 🌐 3. Sonderfall: Web-App / iOS als PWA

Diesen Abschnitt brauchst du nur, wenn du Fleuron **im Browser** oder als auf dem iOS-Homescreen gespeicherte Web-App nutzt – für die native Android-App ist er nicht relevant.

Moderne Browser blockieren aus Sicherheitsgründen direkte Verbindungen zu fremden Servern (CORS-Richtlinie). Für die Web-Nutzung brauchst du deshalb einen kleinen PHP-Tunnel (`cors.php`) auf einem eigenen Webspace, der die Anfragen sicher an deinen Kalender-Server weiterleitet.

Die Server-URL sieht dann so aus:
```
https://dein-webspace.de/pfad/cors.php?target=https://dein-kalender-server.de
```

---

## ⚙️ 4. Optionale Module pro Workspace

Beim Bearbeiten eines Workspace (Workspaces & Konten → Workspace antippen) findest du drei unabhängige Zusatzmodule:

### Aufgaben (To-Dos)
Ein Schalter aktiviert das To-Do-Modul für diesen Workspace. Aufgaben werden als CalDAV-Aufgaben (VTODO) im selben Konto gespeichert.

### Einkaufsliste
Drei Modi zur Auswahl:
- **Deaktiviert** – keine Einkaufsliste für diesen Workspace
- **CalDAV (VTODO)** – speichert Einkäufe als Aufgaben im selben Konto, kein Zusatzdienst nötig
- **Grocy Server** – Anbindung an eine laufende [Grocy](https://grocy.info)-Instanz (Open-Source-Haushaltsverwaltung) für ein echtes Inventar. Dafür trägst du die Grocy-URL und einen API-Schlüssel ein (in Grocy: Schraubenschlüssel-Symbol → API-Schlüssel verwalten) und lädst über **Testen & Stammdaten laden** die vorhandenen Kategorien/Einheiten/Lagerorte

### Einstellungs-Sync
Drei Modi:
- **Lokal (Kein Sync)** – jedes Gerät hat seine eigenen Einstellungen
- **CalDAV (VJOURNAL)** – speichert die Sync-Datei unsichtbar im selben CalDAV-Konto, kein Zusatzdienst nötig
- **Externer WebDAV Server** – nutzt einen separaten WebDAV-Server (z. B. auf einer Synology über das Paket „WebDAV Server")

---

## 👥 5. Personen & Kalender-Zuordnung

Im Menü unter **Team & Gruppen**:

- **Personen anlegen** – lege alle Personen an, die diesen Workspace nutzen, mit individueller Farbe
- **Team-Farben (Gruppen)** – sobald ein Kalender mehreren Personen zugeordnet ist, kannst du dieser Kombination eine eigene Farbe geben
- **Ordner zuordnen** – die App durchsucht deinen Server nach verfügbaren Kalendern; hier legst du fest, welche Personen zu welchem Kalender-Ordner gehören

### Gruppenkalender & automatische Auswahl

Neben einem Kalender pro Person kannst du direkt auf deinem CalDAV-Server auch **zusätzliche Gruppenkalender** anlegen – zum Beispiel einen gemeinsamen Kalender für zwei bestimmte Personen. Unter „Ordner zuordnen" ordnest du diesem Kalender-Ordner dann genau die Personen zu, für die er gedacht ist.

Beim Anlegen eines Termins wählst du wie gewohnt die teilnehmenden Personen aus. Existiert für **genau diese Kombination** ein zugeordneter Kalender, wählt die App ihn automatisch aus – du musst also keinen Kalender manuell suchen, der Termin landet direkt am richtigen Ort. Gibt es (noch) keinen passenden Kalender für die gewählte Kombination, weist dich die App darauf hin, und du kannst entsprechend erst den passenden Ordner auf dem Server anlegen und zuordnen.

---

## 🌍 6. Land & Feiertage

Im Menü unter **Land & Feiertage** wählst du Land und (bei Deutschland) Bundesland aus. Die passenden Feiertage werden dann automatisch im Kalender markiert.

---

## 🗣 7. Sprache

Fleuron ist zweisprachig (Deutsch/Englisch). Über den Menüpunkt **Sprache** kannst du zwischen „System" (folgt der Gerätesprache), „Deutsch" und „Englisch" wählen – die Umschaltung wirkt sofort, ohne Neustart.

---

## 🔄 8. Team-Sync im Detail

Falls du den Einstellungs-Sync aktiviert hast (siehe Punkt 4), findest du im Menü unter **Team-Sync (Manuell)** die Steuerzentrale:

- **Geräte-Filter:** Drei Schalter (Team & Kalenderfarben / Supermärkte / Routen) legen fest, welche Datenpakete dieses Gerät beim Laden überhaupt übernimmt. Ein Gerät kann z. B. neue Kalenderfarben übernehmen, aber seine eigene Supermarkt-Route behalten.
- **Senden** lädt den aktuellen lokalen Stand als Master-Datei auf den Server.
- **Prüfen & Laden** vergleicht die Server-Version mit dem lokalen Stand und zeigt dir die Unterschiede **gruppiert nach den drei Geräte-Filtern**. Bereiche, deren Filter ausgeschaltet ist, werden ausgegraut angezeigt und beim Bestätigen nicht übernommen – so siehst du transparent, was sich unterscheidet, aber auch, was davon tatsächlich wirksam wird.

---

## 🛒 9. Supermarkt-Profile & Routen-Sortierung

In der Einkaufsliste kannst du über das kleine grüne Plus verschiedene Supermarkt-Profile anlegen (z. B. Aldi, Rewe, Baumarkt). Über das kleine Straßen-Icon neben einem aktiven Profil öffnest du die Routen-Sortierung: Kategorien lassen sich per Drag & Drop in der Reihenfolge anordnen, in der du durch den jeweiligen Markt läufst. Die Einkaufsliste sortiert sich dann automatisch danach.

Tipp: Die Profil-Leiste lässt sich seitlich wischen, wenn mehrere Profile angelegt sind.

---

## 💡 10. Weitere Tipps

- **Offline-Fähigkeit:** Termine, Aufgaben und Einkaufslisten werden lokal zwischengespeichert. Ohne Verbindung zeigt die App weiterhin die zuletzt geladenen Daten an, statt leer zu erscheinen, und synchronisiert sich automatisch im Hintergrund, sobald wieder eine Verbindung besteht.
- **Live-Suche:** Sowohl bei Terminen als auch in der Einkaufsliste reagiert die Suche in Echtzeit auf jeden getippten Buchstaben.
- **Privatsphäre bei To-Dos:** Über die drei Punkte oben rechts („Sichtbarkeit verwalten") lassen sich private Listen einfach ausblenden, ohne sie zu löschen.
