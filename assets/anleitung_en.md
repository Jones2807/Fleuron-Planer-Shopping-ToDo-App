# 📅 Fleuron – User Guide

Fleuron is a cross-platform calendar, to-do manager, and shopping-list planner. It works with **any regular CalDAV account** - there's no requirement to use a specific server or provider. Grocy integration, settings sync, and the PHP tunnel for the web version are optional add-on modules, not a prerequisite.

---

## 🧩 1. The core concept: workspaces

Fleuron organizes everything around **workspaces**. A workspace is a self-contained CalDAV account with its own settings - its own team, its own shopping list, its own sync.

That means you can set up several workspaces at once, for example one for the family and another for a club or work. Each workspace can be configured independently and disabled if needed, without affecting the others.

Everything else in this guide - team, calendar mapping, shopping list, sync - always refers to **one** workspace you currently have selected.

---

## 🛠 2. Setting up your first workspace

Open the menu (the three lines in the top left) and tap **Workspaces & Accounts**.

Tap **New Workspace** and fill in:

- **Display name** - any name you like (e.g. "Family" or "Club")
- **Server URL** - your calendar provider's CalDAV address. This works with any standard CalDAV server (e.g. Synology Calendar, Nextcloud, or another CalDAV-capable service)
- **Username** and **password**

If you only want to **read** an existing calendar rather than edit it, enable **Read-only subscription (.ics)** - a public .ics URL is enough for that, no credentials needed.

---

## 🌐 3. Special case: web app / iOS as a PWA

You only need this section if you use Fleuron **in a browser** or as a web app saved to the iOS home screen - it's not relevant for the native Android app.

For security reasons, modern browsers block direct connections to third-party servers (CORS policy). For web use, you therefore need a small PHP tunnel (`cors.php`) on your own webspace that securely forwards requests to your calendar server.

The server URL then looks like this:
```
https://your-webspace.com/path/cors.php?target=https://your-calendar-server.com
```

---

## ⚙️ 4. Optional modules per workspace

When editing a workspace (Workspaces & Accounts → tap a workspace), you'll find three independent add-on modules:

### Tasks (to-dos)
A toggle enables the to-do module for this workspace. Tasks are stored as CalDAV tasks (VTODO) in the same account.

### Shopping list
Three modes to choose from:
- **Disabled** - no shopping list for this workspace
- **CalDAV (VTODO)** - stores purchases as tasks in the same account, no extra service needed
- **Grocy server** - connects to a running [Grocy](https://grocy.info) instance (open-source household management) for a real inventory. Enter the Grocy URL and an API key (in Grocy: wrench icon → manage API keys), then load the existing categories/units/locations via **Test & load defaults**

### Settings sync
Three modes:
- **Local (no sync)** - each device keeps its own settings
- **CalDAV (VJOURNAL)** - stores the sync file invisibly in the same CalDAV account, no extra service needed
- **External WebDAV server** - uses a separate WebDAV server (e.g. on a Synology via the "WebDAV Server" package)

---

## 👥 5. People & calendar mapping

In the menu, under **Team & Groups**:

- **Add people** - add everyone who uses this workspace, each with their own color
- **Team colors (groups)** - once a calendar is shared by more than one person, you can give that combination its own color
- **Assign folders** - the app scans your server for available calendars; here you decide which people belong to which calendar folder

### Group calendars & automatic selection

Beyond one calendar per person, you can create **additional group calendars** directly on your CalDAV server - for example, a shared calendar for two specific people. Under "Assign folders", you then map that calendar folder to exactly the people it's meant for.

When creating an event, you select the participating people as usual. If a mapped calendar exists for **exactly that combination**, the app selects it automatically - no need to manually search for the right calendar, the event ends up in the right place on its own. If no matching calendar exists yet for the chosen combination, the app lets you know, so you can create and map the right folder on the server first.

---

## 🌍 6. Country & holidays

Under **Country & Holidays** in the menu, choose a country and (for Germany) a state. The matching public holidays are then marked automatically in the calendar.

---

## 🗣 7. Language

Fleuron is bilingual (German/English). Under the **Language** menu entry you can choose between "System" (follows the device language), "German", and "English" - switching takes effect immediately, no restart needed.

---

## 🔄 8. Team sync in detail

If you've enabled settings sync (see section 4), you'll find the control center under **Team Sync (Manual)** in the menu:

- **Device filters:** Three toggles (team & calendar colors / stores / routes) decide which data packages this device actually applies when loading. A device can, say, adopt new calendar colors while keeping its own personal store route.
- **Send** uploads the current local state to the server as the master file.
- **Check & Load** compares the server version against the local state and shows you the differences **grouped by the three device filters**. Sections whose filter is turned off are shown grayed out and won't be applied when you confirm - so you can see transparently what's different, and also what will actually take effect.

---

## 🛒 9. Store profiles & route sorting

In the shopping list, tap the small green plus to create different store profiles (e.g. Aldi, Rewe, hardware store). Tap the small road icon next to an active profile to open route sorting: drag and drop categories into the order you walk through that particular store. The shopping list then sorts itself accordingly.

Tip: swipe the profile bar sideways if you have several profiles set up.

---

## 💡 10. More tips

- **Offline support:** Events, tasks, and shopping lists are cached locally. Without a connection, the app keeps showing the most recently loaded data instead of appearing empty, and syncs quietly in the background as soon as a connection is available again.
- **Live search:** Search reacts in real time to every keystroke, both for events and in the shopping list.
- **Privacy for to-dos:** Use the three dots in the top right ("Manage visibility") to hide private lists without deleting them.
