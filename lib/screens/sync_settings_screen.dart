import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/sync_service.dart';
import '../services/secure_vault.dart';
import '../l10n/app_localizations.dart';

/// Screen for manually controlling team-settings sync for a specific
/// workspace: upload the local team/store/route settings, or check
/// for and pull down changes from the configured backend (WebDAV or
/// CalDAV piggyback).
class SyncSettingsScreen extends StatefulWidget {
  const SyncSettingsScreen({super.key});

  @override
  State<SyncSettingsScreen> createState() => _SyncSettingsScreenState();
}

class _SyncSettingsScreenState extends State<SyncSettingsScreen> {
  List<CalDavAccount> _accounts = [];
  CalDavAccount? _selectedAccount;

  // Settings loaded from the workspace (read-only on this screen).
  String _syncMode = 'none';
  String _webdavUrl = '';
  String _webdavUser = '';
  String _webdavPass = '';
  String _caldavConfigName = '';

  // Per-device filters, adjustable here before syncing.
  bool _syncTeam = true;
  bool _syncStores = true;
  bool _syncRoutes = false;

  bool _isLoading = true;

  /// Builds the [SyncLabels] bundle [SyncService] needs for
  /// localized diff/error text, from the currently active language.
  SyncLabels _buildSyncLabels(AppLocalizations l10n) {
    return SyncLabels(
      storeAdded: (name) => l10n.syncNewStore(name),
      storeRemoved: (name) => l10n.syncStoreRemoved(name),
      routesChanged: l10n.syncRoutesChanged,
      teamOrColorsChanged: l10n.syncTeamOrColorsChanged,
      serverError: (code) => l10n.syncServerError(code),
      networkError: (error) => l10n.syncNetworkError(error),
      noActiveAccount: l10n.syncNoActiveAccount,
      noTaskListFound: l10n.syncNoTaskListFound,
      caldavError: (error) => l10n.syncCaldavError(error),
      unnamedTaskFallback: l10n.unnamedTaskFallback,
    );
  }

  @override
  void initState() {
    super.initState();
    _loadAccountsAndSettings();
  }

  Future<void> _loadAccountsAndSettings() async {
    final accounts = await SecureVault.getAllAccounts();
    final activeAccounts = accounts.where((a) => a.isActive).toList();

    if (mounted) {
      setState(() {
        _accounts = activeAccounts;
        if (_accounts.isNotEmpty) {
          _selectedAccount = _accounts.first;
        }
      });
      if (_selectedAccount != null) {
        await _loadWorkspaceSyncSettings(_selectedAccount!.id);
      } else {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadWorkspaceSyncSettings(String accountId) async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      // Sync mode, as configured on the workspace's settings screen.
      _syncMode = prefs.getString('sync_mode_$accountId') ?? 'none';

      // WebDAV connection details.
      _webdavUrl = prefs.getString('webdav_url_$accountId') ?? "";
      _webdavUser = prefs.getString('webdav_user_$accountId') ?? "";
      _webdavPass = prefs.getString('webdav_pass_$accountId') ?? "";

      // CalDAV piggyback file name - for simplicity, derived from the
      // account's display name rather than stored separately.
      _caldavConfigName = "config_${_selectedAccount?.name.replaceAll(' ', '_').toLowerCase() ?? 'team'}";

      // Device filter toggles, stored per workspace.
      _syncTeam = prefs.getBool('sync_toggle_team_$accountId') ?? true;
      _syncStores = prefs.getBool('sync_toggle_stores_$accountId') ?? true;
      _syncRoutes = prefs.getBool('sync_toggle_routes_$accountId') ?? false;

      _isLoading = false;
    });
  }

  Future<void> _saveFilterToggles() async {
    if (_selectedAccount == null) return;
    final prefs = await SharedPreferences.getInstance();
    final accountId = _selectedAccount!.id;

    await prefs.setBool('sync_toggle_team_$accountId', _syncTeam);
    await prefs.setBool('sync_toggle_stores_$accountId', _syncStores);
    await prefs.setBool('sync_toggle_routes_$accountId', _syncRoutes);
  }

  void _handleUpload() async {
    if (_selectedAccount == null || _syncMode == 'none') return;
    final l10n = AppLocalizations.of(context)!;
    final labels = _buildSyncLabels(l10n);

    await _saveFilterToggles();
    setState(() => _isLoading = true);

    String? errorMsg;
    if (_syncMode == 'webdav') {
      errorMsg = await SyncService.uploadSettings(
          url: _webdavUrl,
          user: _webdavUser,
          pass: _webdavPass,
          labels: labels
      );
    } else if (_syncMode == 'caldav') {
      errorMsg = await SyncService.uploadSettingsCaldav(
          fileName: _caldavConfigName,
          labels: labels
      );
    }

    setState(() => _isLoading = false);

    if (mounted) {
      if (errorMsg == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.uploadSuccessMessage),
          backgroundColor: Colors.green,
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(errorMsg),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ));
      }
    }
  }

  void _handleDownload() async {
    if (_selectedAccount == null || _syncMode == 'none') return;
    final l10n = AppLocalizations.of(context)!;
    final labels = _buildSyncLabels(l10n);

    await _saveFilterToggles();
    setState(() => _isLoading = true);

    SyncDiff? diff;
    if (_syncMode == 'webdav') {
      diff = await SyncService.compareSettings(
          url: _webdavUrl,
          user: _webdavUser,
          pass: _webdavPass,
          labels: labels
      );
    } else if (_syncMode == 'caldav') {
      diff = await SyncService.compareSettingsCaldav(
          fileName: _caldavConfigName,
          labels: labels
      );
    }

    setState(() => _isLoading = false);

    if (diff == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.downloadErrorMessage)));
      return;
    }

    if (!diff.hasChanges) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.nothingToSyncMessage)));
      return;
    }

    if (mounted) {
      final storeEntries = diff.forCategory(SyncCategory.stores);
      final routeEntries = diff.forCategory(SyncCategory.routes);
      final teamEntries = diff.forCategory(SyncCategory.team);

      final bool anythingWillApply =
          (storeEntries.isNotEmpty && _syncStores) ||
              (routeEntries.isNotEmpty && _syncRoutes) ||
              (teamEntries.isNotEmpty && _syncTeam);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.applyChangesTitle),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDiffSection(l10n.storesNamesLabel, storeEntries, _syncStores, l10n),
                _buildDiffSection(l10n.routesLabel, routeEntries, _syncRoutes, l10n),
                _buildDiffSection(l10n.teamAndCalendarColorsLabel, teamEntries, _syncTeam, l10n),
                const Divider(),
                Text(l10n.deviceFilterNote, style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                if (!anythingWillApply) ...[
                  const SizedBox(height: 8),
                  Text(l10n.nothingWillBeAppliedMessage, style: const TextStyle(color: Colors.orange, fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A73D1), foregroundColor: Colors.white),
              onPressed: !anythingWillApply ? null : () async {
                await SyncService.applySettings(diff!.rawData, accountId: _selectedAccount!.id);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.settingsAppliedMessage))
                  );
                  Navigator.pop(context, true);
                }
              },
              child: Text(l10n.update),
            )
          ],
        ),
      );
    }
  }

  /// Renders one category's diff entries in the "apply changes"
  /// dialog, grayed out with an explanatory note if [isFilterEnabled]
  /// is `false` for that category's device filter - since those
  /// entries are shown for transparency but won't actually be
  /// applied. Renders nothing if there are no entries for the
  /// category.
  Widget _buildDiffSection(String categoryLabel, List<SyncDiffEntry> entries, bool isFilterEnabled, AppLocalizations l10n) {
    if (entries.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Opacity(
        opacity: isFilterEnabled ? 1.0 : 0.5,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(categoryLabel, style: TextStyle(fontWeight: FontWeight.bold, color: isFilterEnabled ? const Color(0xFF4A73D1) : Colors.grey)),
            ...entries.map((e) => Text("• ${e.description}")),
            if (!isFilterEnabled)
              Text(l10n.notAppliedFilterOff, style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: Text(l10n.teamSyncManual),
        backgroundColor: const Color(0xFF4A73D1),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _accounts.isEmpty
          ? Center(child: Text(l10n.noWorkspacesConfigured))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Workspace picker.
            Text(l10n.activeWorkspaceLabel, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF4A73D1))),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<CalDavAccount>(
                  isExpanded: true,
                  value: _selectedAccount,
                  icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF4A73D1)),
                  items: _accounts.map((acc) => DropdownMenuItem(
                      value: acc,
                      child: Text(acc.name, style: const TextStyle(fontWeight: FontWeight.bold))
                  )).toList(),
                  onChanged: (val) {
                    if (val != null && val.id != _selectedAccount?.id) {
                      setState(() => _selectedAccount = val);
                      _loadWorkspaceSyncSettings(val.id);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Read-only info about the configured backend.
            Text(l10n.configuredBackendLabel, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF4A73D1))),
            const SizedBox(height: 8),

            if (_syncMode == 'none')
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.shade200)),
                child: Text(l10n.noSyncBackendConfigured, style: const TextStyle(color: Colors.deepOrange)),
              )
            else if (_syncMode == 'webdav')
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [const Icon(Icons.dns_outlined, color: Colors.blue), const SizedBox(width: 8), Text(l10n.synologyWebdavLabel, style: const TextStyle(fontWeight: FontWeight.bold))]),
                    const SizedBox(height: 8),
                    Text(_webdavUrl, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                  ],
                ),
              )
            else if (_syncMode == 'caldav')
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [const Icon(Icons.calendar_today, color: Colors.blue), const SizedBox(width: 8), Text(l10n.caldavPiggybackLabel, style: const TextStyle(fontWeight: FontWeight.bold))]),
                      const SizedBox(height: 8),
                      Text(l10n.fileNameLabel(_caldavConfigName), style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    ],
                  ),
                ),

            const SizedBox(height: 32),
            const Divider(height: 1, thickness: 1),
            const SizedBox(height: 24),

            // Per-device filters.
            Text(l10n.deviceFiltersLabel, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF4A73D1))),
            const SizedBox(height: 16),

            Container(
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300)
              ),
              child: Column(
                children: [
                  SwitchListTile(title: Text(l10n.teamAndCalendarColorsLabel), value: _syncTeam, activeThumbColor: const Color(0xFF4A73D1), onChanged: _syncMode == 'none' ? null : (val) => setState(() => _syncTeam = val)),
                  const Divider(height: 1),
                  SwitchListTile(title: Text(l10n.storesNamesLabel), value: _syncStores, activeThumbColor: const Color(0xFF4A73D1), onChanged: _syncMode == 'none' ? null : (val) => setState(() => _syncStores = val)),
                  const Divider(height: 1),
                  SwitchListTile(title: Text(l10n.routesLabel), value: _syncRoutes, activeThumbColor: const Color(0xFF4A73D1), onChanged: _syncMode == 'none' ? null : (val) => setState(() => _syncRoutes = val)),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Upload / download actions.
            Row(
              children: [
                Expanded(
                    child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF4A73D1),
                            side: BorderSide(color: _syncMode == 'none' ? Colors.grey : const Color(0xFF4A73D1)),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                        ),
                        icon: const Icon(Icons.cloud_download_outlined),
                        label: Text(l10n.checkAndLoad),
                        onPressed: _syncMode == 'none' ? null : _handleDownload
                    )
                ),
                const SizedBox(width: 16),
                Expanded(
                    child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4A73D1),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                        ),
                        icon: const Icon(Icons.cloud_upload_outlined),
                        label: Text(l10n.send),
                        onPressed: _syncMode == 'none' ? null : _handleUpload
                    )
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}