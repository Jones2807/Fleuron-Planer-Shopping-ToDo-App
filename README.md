# Fleuron

A free, cross-platform calendar, to-do, and shopping-list app for families, clubs, and small teams — built on your own CalDAV server. No cloud lock-in, no subscription, no proprietary backend required.

---

## Why this exists

My wife and I were looking for a way to plan events with different participants. FamilyWall seemed like the obvious choice, but the free tier is quite limited, and we didn't want to pay for premium — especially for something that stores everything on US-based cloud servers.

On top of that, I wanted a calendar widget in Home Assistant, similar to what dedicated smart displays offer. Most calendar apps treat "participants" on a single shared calendar as metadata, not as first-class calendars of their own — which means everyone ends up with the same color, and Home Assistant (and most other integrations) can't tell them apart.

I already had a Synology NAS with the CalDAV package running, so I set up one CalDAV calendar per person and went looking for an app that could bring those calendars together properly. I couldn't find one that really satisfied me — so, mostly out of curiosity about how much effort it would actually be, I asked an AI. That question turned into this app.

Along the way it became clear that the same idea is useful for more than just a family calendar — a fire department roster, a sports club schedule, or a patchwork family that wants to combine several household calendars in one place. That's the idea this app is built around: not one calendar, but as many independent **workspaces** as you need, each with its own CalDAV account, team, and settings.

---

## A note on how this was built

I'm not a programmer. Fleuron was built entirely through conversations with large language models (LLMs) — I described what I wanted, reviewed what came back, and iterated from there. I'm being upfront about that because it seems more honest than pretending otherwise, and because it might matter to you if you're deciding whether to use or contribute to this project.

That said, the app has gone through a real security and code-quality pass (removing hardcoded secrets, hardening CORS configuration, fixing several data-handling bugs found during testing), and it's actively maintained. If you're an experienced Flutter developer and something looks off, I'd genuinely appreciate an issue or a pull request — that kind of review is exactly what a project like this benefits from.

---

## Features

- **Multiple workspaces** — run several independent CalDAV accounts side by side (e.g. family, club, work), each with its own team, shopping list, and sync settings
- **Works with any standard CalDAV server** — Synology Calendar, Nextcloud, or any other CalDAV-capable service; no proprietary backend
- **Per-person calendars, properly separated** — each participant gets their own real calendar and color, recognized correctly by other CalDAV clients and integrations (e.g. Home Assistant)
- **Automatic calendar selection for shared events** — beyond one calendar per person, you can create additional *group* calendars directly in your CalDAV account (e.g. a calendar shared by two specific people). Fleuron detects these group calendars and maps them to the combination of participants they were created for. When creating an event, simply select the people attending it — if a matching calendar exists for that exact combination, the app automatically picks it, so the event ends up in the right place without any manual calendar selection
- **To-dos** — CalDAV-based task lists (VTODO), shared or private
- **Shopping list** — either CalDAV-based, or connected to a [Grocy](https://grocy.info) instance for real household inventory tracking
- **Store profiles & route sorting** — arrange shopping-list categories in the order you walk through a specific store, per store
- **Settings sync across devices** — team members, calendar colors, and store routes can be synced between devices via WebDAV or piggybacked on the CalDAV account itself, with per-device filters so each device can pick and choose what to adopt
- **Public holidays** — automatically marked in the calendar, based on country/region
- **Bilingual** — German and English, switchable in-app without restart
- **Offline-first** — cached locally; a lost connection shows the last known data instead of an empty screen, and syncs quietly once you're back online
- **No cloud dependency** — your data stays on servers you control

## Web / PWA support

The app also runs as a web app / iOS PWA. Since browsers block direct cross-origin requests to your calendar server (CORS), the web version needs a small PHP tunnel (`cors.php`, included in this repo) hosted on any PHP-capable webspace to relay requests securely. This isn't needed for the native Android app.

## Getting started

A full setup and usage guide is built into the app itself (Menu → Guide & Help), covering:
- Setting up your first workspace
- Configuring the optional Grocy and WebDAV-sync modules
- Setting up the CORS tunnel for web/PWA use

## Tech stack

- [Flutter](https://flutter.dev) (Android, and Web/PWA)
- CalDAV for calendar and task sync
- Optional [Grocy](https://grocy.info) integration for the shopping list
- Optional WebDAV for cross-device settings sync
- Local SQLite / SharedPreferences caching for offline use

## Contributing

Contributions, bug reports, and code review are all welcome.

**One specific thing I could really use help with:** publishing the app to the **Apple App Store**. I don't currently have an Apple Developer account, and would love to find someone willing to handle the iOS release (or point me toward the least painful way to do it myself). If that's something you can help with, please open an issue or reach out.

## License

This project is licensed under the [MIT License](LICENSE) — use it, modify it, build on it, including commercially. Just keep the copyright notice.

## Disclaimer

This project isn't affiliated with or endorsed by Synology, Grocy, Nextcloud, or any other third-party service it happens to connect to. All trademarks belong to their respective owners.
