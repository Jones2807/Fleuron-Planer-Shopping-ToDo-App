import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/employee.dart';
import '../screens/settings_screen.dart';
import '../screens/calendar_mapping_screen.dart';
import '../screens/team_manager_screen.dart';
import '../screens/group_color_screen.dart';
import '../screens/help_screen.dart';
import '../screens/sync_settings_screen.dart';
import '../l10n/app_localizations.dart';
import 'language_switcher_dialog.dart';

/// The app's main navigation drawer: user switcher, display toggles
/// (gray out past events, week numbers, holidays), and the settings /
/// help entries.
class AppDrawer extends StatefulWidget {
  final Employee? currentUser;
  final List<Employee> allEmployees;
  final bool grayOutPastEvents;
  final bool showWeekNumbers;
  final bool showHolidays;
  final VoidCallback onUserSwitch;
  final Function(bool) onGrayOutPastEventsChanged;
  final Function(bool) onShowWeekNumbersChanged;
  final Function(bool) onShowHolidaysChanged;
  final VoidCallback onLocalizationTap; // Opens the holiday country/region dialog.
  final VoidCallback onSettingsSaved;
  final VoidCallback onTeamChanged;
  final VoidCallback onColorsChanged;
  final VoidCallback oninitializeApp;

  const AppDrawer({
    super.key,
    required this.currentUser,
    required this.allEmployees,
    required this.grayOutPastEvents,
    required this.showWeekNumbers,
    required this.showHolidays,
    required this.onUserSwitch,
    required this.onGrayOutPastEventsChanged,
    required this.onShowWeekNumbersChanged,
    required this.onShowHolidaysChanged,
    required this.onLocalizationTap,
    required this.onSettingsSaved,
    required this.onTeamChanged,
    required this.onColorsChanged,
    required this.oninitializeApp,
  });

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  bool _isTeamMenuExpanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Drawer(
      backgroundColor: Colors.white,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Header with the active user's avatar; tapping it opens the
          // user-switch dialog.
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(
              color: Color(0xFF4A73D1),
              image: DecorationImage(
                image: AssetImage('assets/splash.png'),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(Colors.black38, BlendMode.darken),
              ),
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: widget.currentUser?.color ?? Colors.white,
              child: Text(
                widget.currentUser?.initials ?? "?",
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
            accountName: Text(
              widget.currentUser?.name ?? l10n.notSignedIn,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            accountEmail: Text(l10n.activeProfile),
            onDetailsPressed: widget.onUserSwitch,
          ),

          // Display preference toggles (calendar look & feel).
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 16, bottom: 8),
            child: Align(
                alignment: Alignment.centerLeft,
                child: Text(l10n.sectionView, style: const TextStyle(color: Colors.grey, fontSize: 12, letterSpacing: 1.2, fontWeight: FontWeight.bold))
            ),
          ),
          SwitchListTile(
            activeThumbColor: const Color(0xFF4A73D1),
            title: Text(l10n.grayOutPastEventsLabel, style: const TextStyle(fontSize: 15)),
            value: widget.grayOutPastEvents,
            onChanged: (bool value) async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('grayOutPastEvents', value);
              widget.onGrayOutPastEventsChanged(value);
            },
          ),
          SwitchListTile(
            activeThumbColor: const Color(0xFF4A73D1),
            title: Text(l10n.weekNumbersLabel, style: const TextStyle(fontSize: 15)),
            value: widget.showWeekNumbers,
            onChanged: (bool value) async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('showWeekNumbers', value);
              widget.onShowWeekNumbersChanged(value);
            },
          ),
          SwitchListTile(
            activeThumbColor: const Color(0xFF4A73D1),
            title: Text(l10n.showHolidaysLabel, style: const TextStyle(fontSize: 15)),
            value: widget.showHolidays,
            onChanged: (bool value) async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('showHolidays', value);
              widget.onShowHolidaysChanged(value);
            },
          ),

          const Divider(),

          // System & configuration entries.
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 16, bottom: 8),
            child: Align(
                alignment: Alignment.centerLeft,
                child: Text(l10n.sectionSettings, style: const TextStyle(color: Colors.grey, fontSize: 12, letterSpacing: 1.2, fontWeight: FontWeight.bold))
            ),
          ),

          ExpansionTile(
            leading: const Icon(Icons.people_alt_outlined, color: Color(0xFF4A73D1)),
            title: Text(l10n.teamAndGroups, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            onExpansionChanged: (expanded) {
              setState(() => _isTeamMenuExpanded = expanded);
            },
            iconColor: const Color(0xFF4A73D1),
            childrenPadding: const EdgeInsets.only(left: 16),
            children: [
              ListTile(
                leading: const Icon(Icons.person_outline, size: 20),
                title: Text(l10n.addPeople, style: const TextStyle(fontSize: 14)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(
                      builder: (context) => TeamManagerScreen(onTeamChanged: widget.onTeamChanged)
                  ));
                },
              ),
              ListTile(
                leading: const Icon(Icons.palette_outlined, size: 20),
                title: Text(l10n.teamColors, style: const TextStyle(fontSize: 14)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(
                      builder: (context) => GroupColorScreen(onColorsChanged: widget.onColorsChanged)
                  ));
                },
              ),
              ListTile(
                leading: const Icon(Icons.cloud_sync_outlined, size: 20),
                title: Text(l10n.assignFolders, style: const TextStyle(fontSize: 14)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(
                      builder: (context) => CalendarMappingScreen(
                          allEmployees: widget.allEmployees,
                          onMappingChanged: widget.oninitializeApp
                      )
                  ));
                },
              ),
            ],
          ),

          ListTile(
            leading: const Icon(Icons.public, color: Color(0xFF4A73D1)),
            title: Text(l10n.holidaySettingsTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            onTap: () {
              Navigator.pop(context);
              widget.onLocalizationTap();
            },
          ),

          ListTile(
            leading: const Icon(Icons.language, color: Color(0xFF4A73D1)),
            title: Text(l10n.language, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            onTap: () {
              Navigator.pop(context);
              LanguageSwitcherDialog.show(context);
            },
          ),

          // Base connection settings (CalDAV/Grocy accounts).
          ListTile(
            leading: const Icon(Icons.dns_outlined, color: Color(0xFF4A73D1)),
            title: Text(l10n.workspacesAndAccounts, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(
                  builder: (context) => SettingsScreen(onSaved: widget.onSettingsSaved)
              ));
            },
          ),

          // Manual trigger for the WebDAV-based team-settings sync.
          ListTile(
            leading: const Icon(Icons.sync, color: Color(0xFF4A73D1)),
            title: Text(l10n.teamSyncManual, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(
                  builder: (context) => const SyncSettingsScreen()
              ));
            },
          ),

          const Divider(),

          ListTile(
            leading: const Icon(Icons.help_outline, color: Colors.grey),
            title: Text(l10n.helpAndGuide, style: const TextStyle(fontSize: 15)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(
                  builder: (context) => const HelpScreen()
              ));
            },
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}