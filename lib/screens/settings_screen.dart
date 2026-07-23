import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/secure_vault.dart';
import '../services/grocy_service.dart';
import '../models/grocy_models.dart';
import '../l10n/app_localizations.dart';

/// Lists all configured CalDAV workspaces (accounts) and lets the
/// user add, edit, or open one for editing.
class SettingsScreen extends StatefulWidget {
  final VoidCallback onSaved;

  const SettingsScreen({super.key, required this.onSaved});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  List<CalDavAccount> _accounts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    final accounts = await SecureVault.getAllAccounts();
    if (mounted) {
      setState(() {
        _accounts = accounts;
        _isLoading = false;
      });
    }
  }

  void _openAccountEditor({CalDavAccount? account, int? index}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AccountEditorScreen(
          existingAccount: account,
          onSave: (updatedAccount) async {
            setState(() {
              if (index != null) {
                _accounts[index] = updatedAccount;
              } else {
                _accounts.add(updatedAccount);
              }
            });
            await SecureVault.saveAllAccounts(_accounts);
            widget.onSaved();
          },
          onDelete: () async {
            setState(() {
              if (index != null) _accounts.removeAt(index);
            });
            await SecureVault.saveAllAccounts(_accounts);
            widget.onSaved();
            Navigator.pop(context);
          },
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
        title: Text(l10n.workspacesAndAccounts),
        backgroundColor: const Color(0xFF4A73D1),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _accounts.isEmpty
          ? _buildEmptyState(l10n)
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _accounts.length,
        itemBuilder: (context, index) {
          final acc = _accounts[index];
          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: CircleAvatar(
                backgroundColor: acc.isActive ? const Color(0xFF4A73D1).withValues(alpha: 0.1) : Colors.grey.shade200,
                child: Icon(acc.isReadOnly ? Icons.calendar_today : Icons.dns, color: acc.isActive ? const Color(0xFF4A73D1) : Colors.grey),
              ),
              title: Text(acc.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: acc.isActive ? Colors.black : Colors.grey)),
              subtitle: Text(acc.isReadOnly ? l10n.readOnlyCalendarSubtitle : l10n.caldavWorkspaceSubtitle, style: TextStyle(color: Colors.grey.shade600)),
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
              onTap: () => _openAccountEditor(account: acc, index: index),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAccountEditor(),
        backgroundColor: const Color(0xFF4A73D1),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(l10n.newWorkspace),
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.dns_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(l10n.noWorkspacesTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black54)),
          const SizedBox(height: 8),
          Text(l10n.noWorkspacesSubtitle, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

/// Full-page editor for a single CalDAV workspace: connection
/// details plus the optional to-do, shopping-list and settings-sync
/// modules that can be attached to it.
class AccountEditorScreen extends StatefulWidget {
  final CalDavAccount? existingAccount;
  final Function(CalDavAccount) onSave;
  final VoidCallback? onDelete;

  const AccountEditorScreen({super.key, this.existingAccount, required this.onSave, this.onDelete});

  @override
  State<AccountEditorScreen> createState() => _AccountEditorScreenState();
}

class _AccountEditorScreenState extends State<AccountEditorScreen> {
  late String _accountId;
  bool _isLoading = true;

  // Basic CalDAV connection.
  final _nameCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isReadOnly = false;
  bool _isActive = true;
  bool _isPassVisible = false;

  // Optional modules.
  bool _syncTodos = false;

  // Shopping list mode: 'none', 'caldav', 'grocy'.
  String _shoppingMode = 'none';
  final _grocyUrlCtrl = TextEditingController();
  final _grocyKeyCtrl = TextEditingController();
  bool _isTestingGrocy = false;

  // Grocy master data (units/locations), fetched via _testGrocyConnection.
  String? _defaultUnitId;
  String? _defaultLocationId;
  List<GrocyQuantityUnit> _availableUnits = [];
  List<GrocyLocation> _availableLocations = [];

  // Settings-sync mode: 'none', 'caldav', 'webdav'.
  String _teamSyncMode = 'none';
  final _webdavUrlCtrl = TextEditingController();
  final _webdavUserCtrl = TextEditingController();
  final _webdavPassCtrl = TextEditingController();
  bool _isWebdavPassVisible = false;

  @override
  void initState() {
    super.initState();
    _accountId = widget.existingAccount?.id ?? 'workspace_${DateTime.now().millisecondsSinceEpoch}';
    _loadWorkspaceSettings();
  }

  Future<void> _loadWorkspaceSettings() async {
    final prefs = await SharedPreferences.getInstance();

    if (widget.existingAccount != null) {
      _nameCtrl.text = widget.existingAccount!.name;
      _urlCtrl.text = widget.existingAccount!.url;
      _userCtrl.text = widget.existingAccount!.username;
      _passCtrl.text = widget.existingAccount!.password;
      _isReadOnly = widget.existingAccount!.isReadOnly;
      _isActive = widget.existingAccount!.isActive;
      _syncTodos = widget.existingAccount!.syncTodos;

      _shoppingMode = prefs.getString('shopping_mode_$_accountId') ?? (widget.existingAccount!.syncShopping ? 'caldav' : 'none');
      _grocyUrlCtrl.text = prefs.getString('grocy_url_$_accountId') ?? "";
      _grocyKeyCtrl.text = prefs.getString('grocy_key_$_accountId') ?? "";

      // Restore the previously fetched Grocy master data, if any.
      _defaultUnitId = prefs.getString('grocy_default_unit_$_accountId');
      _defaultLocationId = prefs.getString('grocy_default_location_$_accountId');

      final unitsJson = prefs.getString('grocy_units_$_accountId');
      if (unitsJson != null) {
        final List<dynamic> decoded = jsonDecode(unitsJson);
        _availableUnits = decoded.map((u) => GrocyQuantityUnit(id: u['id'].toString(), name: u['name'].toString())).toList();
      }

      final locsJson = prefs.getString('grocy_locations_$_accountId');
      if (locsJson != null) {
        final List<dynamic> decoded = jsonDecode(locsJson);
        _availableLocations = decoded.map((l) => GrocyLocation(id: l['id'].toString(), name: l['name'].toString())).toList();
      }

      _teamSyncMode = prefs.getString('sync_mode_$_accountId') ?? 'none';
      _webdavUrlCtrl.text = prefs.getString('webdav_url_$_accountId') ?? "";
      _webdavUserCtrl.text = prefs.getString('webdav_user_$_accountId') ?? "";
      _webdavPassCtrl.text = prefs.getString('webdav_pass_$_accountId') ?? "";
    }

    setState(() => _isLoading = false);
  }

  Future<void> _saveWorkspace() async {
    final l10n = AppLocalizations.of(context)!;

    if (_nameCtrl.text.isEmpty || _urlCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.nameUrlRequired)));
      return;
    }

    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('shopping_mode_$_accountId', _shoppingMode);
    if (_shoppingMode == 'grocy') {
      await prefs.setString('grocy_url_$_accountId', _grocyUrlCtrl.text.trim());
      await prefs.setString('grocy_key_$_accountId', _grocyKeyCtrl.text.trim());

      if (_defaultUnitId != null) await prefs.setString('grocy_default_unit_$_accountId', _defaultUnitId!);
      if (_defaultLocationId != null) await prefs.setString('grocy_default_location_$_accountId', _defaultLocationId!);
    }

    await prefs.setString('sync_mode_$_accountId', _teamSyncMode);
    if (_teamSyncMode == 'webdav') {
      await prefs.setString('webdav_url_$_accountId', _webdavUrlCtrl.text.trim());
      await prefs.setString('webdav_user_$_accountId', _webdavUserCtrl.text.trim());
      await prefs.setString('webdav_pass_$_accountId', _webdavPassCtrl.text.trim());
    }

    final updatedAccount = CalDavAccount(
      id: _accountId,
      name: _nameCtrl.text.trim(),
      url: _urlCtrl.text.trim(),
      username: _isReadOnly ? '' : _userCtrl.text.trim(),
      password: _isReadOnly ? '' : _passCtrl.text.trim(),
      isReadOnly: _isReadOnly,
      isActive: _isActive,
      syncTodos: _syncTodos,
      syncShopping: _shoppingMode == 'caldav',
    );

    widget.onSave(updatedAccount);
    Navigator.pop(context);
  }

  Future<void> _testGrocyConnection() async {
    if (_grocyUrlCtrl.text.isEmpty || _grocyKeyCtrl.text.isEmpty) return;
    setState(() => _isTestingGrocy = true);

    final service = GrocyService(baseUrl: _grocyUrlCtrl.text.trim(), apiKey: _grocyKeyCtrl.text.trim());
    final data = await service.fetchFormData();

    if (mounted) {
      final l10n = AppLocalizations.of(context)!;
      setState(() => _isTestingGrocy = false);
      if (data != null && data.isNotEmpty) {
        _availableUnits = data['units'] as List<GrocyQuantityUnit>;
        _availableLocations = data['locations'] as List<GrocyLocation>;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('grocy_units_$_accountId', jsonEncode(_availableUnits.map((u) => {'id': u.id, 'name': u.name}).toList()));
        await prefs.setString('grocy_locations_$_accountId', jsonEncode(_availableLocations.map((l) => {'id': l.id, 'name': l.name}).toList()));

        if (_defaultUnitId == null || !_availableUnits.any((u) => u.id == _defaultUnitId)) {
          _defaultUnitId = _availableUnits.isNotEmpty ? _availableUnits.first.id : null;
        }
        if (_defaultLocationId == null || !_availableLocations.any((l) => l.id == _defaultLocationId)) {
          _defaultLocationId = _availableLocations.isNotEmpty ? _availableLocations.first.id : null;
        }

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.grocyConnectSuccess), backgroundColor: Colors.green));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.grocyConnectFailed), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: Text(widget.existingAccount == null ? l10n.newWorkspaceTitle : l10n.editWorkspaceTitle, style: const TextStyle(fontSize: 18)),
        backgroundColor: const Color(0xFF4A73D1),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.check), onPressed: _saveWorkspace),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: SwitchListTile(
                title: Text(l10n.activateWorkspace, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(l10n.activateWorkspaceSubtitle),
                value: _isActive,
                activeThumbColor: const Color(0xFF4A73D1),
                onChanged: (val) => setState(() => _isActive = val),
              ),
            ),
            const SizedBox(height: 24),

            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 8),
              child: Text(l10n.sectionCalendarBasics, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
            ),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(controller: _nameCtrl, decoration: InputDecoration(labelText: l10n.displayNameLabel)),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: Text(l10n.readOnlySubscription, style: const TextStyle(fontSize: 14)),
                      value: _isReadOnly,
                      onChanged: (val) => setState(() => _isReadOnly = val),
                      contentPadding: EdgeInsets.zero,
                    ),
                    TextField(controller: _urlCtrl, decoration: InputDecoration(labelText: l10n.serverUrlLabel), keyboardType: TextInputType.url),
                    if (!_isReadOnly) ...[
                      const SizedBox(height: 12),
                      TextField(controller: _userCtrl, decoration: InputDecoration(labelText: l10n.usernameLabel)),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _passCtrl,
                        obscureText: !_isPassVisible,
                        decoration: InputDecoration(
                          labelText: l10n.passwordLabel,
                          suffixIcon: IconButton(icon: Icon(_isPassVisible ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _isPassVisible = !_isPassVisible)),
                        ),
                      ),
                    ]
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            if (!_isReadOnly) ...[
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 8),
                child: Text(l10n.sectionTodos, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
              ),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: SwitchListTile(
                  title: Text(l10n.enableTodoModule),
                  subtitle: Text(l10n.enableTodoModuleSubtitle),
                  value: _syncTodos,
                  activeThumbColor: const Color(0xFF4A73D1),
                  onChanged: (val) => setState(() => _syncTodos = val),
                ),
              ),
              const SizedBox(height: 24),

              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 8),
                child: Text(l10n.sectionShoppingList, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
              ),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    RadioListTile<String>(title: Text(l10n.disabled), value: 'none', groupValue: _shoppingMode, activeColor: const Color(0xFF4A73D1), onChanged: (val) => setState(() => _shoppingMode = val!)),
                    RadioListTile<String>(title: Text(l10n.shoppingCaldav), subtitle: Text(l10n.shoppingCaldavSubtitle), value: 'caldav', groupValue: _shoppingMode, activeColor: const Color(0xFF4A73D1), onChanged: (val) => setState(() => _shoppingMode = val!)),
                    RadioListTile<String>(title: Text(l10n.grocyServer), subtitle: Text(l10n.grocyServerSubtitle), value: 'grocy', groupValue: _shoppingMode, activeColor: const Color(0xFF4A73D1), onChanged: (val) => setState(() => _shoppingMode = val!)),

                    if (_shoppingMode == 'grocy')
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                          child: Column(
                            children: [
                              TextField(controller: _grocyUrlCtrl, decoration: InputDecoration(labelText: l10n.grocyUrlLabel, filled: true, fillColor: Colors.white, border: const OutlineInputBorder(borderSide: BorderSide.none))),
                              const SizedBox(height: 12),
                              TextField(controller: _grocyKeyCtrl, obscureText: true, decoration: InputDecoration(labelText: l10n.apiKeyLabel, filled: true, fillColor: Colors.white, border: const OutlineInputBorder(borderSide: BorderSide.none))),
                              const SizedBox(height: 12),
                              SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: _isTestingGrocy ? null : _testGrocyConnection, icon: _isTestingGrocy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.sync), label: Text(l10n.testAndLoadDefaults))),

                              if (_availableUnits.isNotEmpty && _availableLocations.isNotEmpty) ...[
                                const Divider(height: 32),
                                Text(l10n.defaultsForNewItems, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<String>(
                                  initialValue: _defaultLocationId,
                                  decoration: InputDecoration(labelText: l10n.defaultLocationLabel, filled: true, fillColor: Colors.white, border: const OutlineInputBorder(borderSide: BorderSide.none)),
                                  items: _availableLocations.map((l) => DropdownMenuItem(value: l.id, child: Text(l.name))).toList(),
                                  onChanged: (val) => setState(() => _defaultLocationId = val),
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<String>(
                                  initialValue: _defaultUnitId,
                                  decoration: InputDecoration(labelText: l10n.defaultUnitLabel, filled: true, fillColor: Colors.white, border: const OutlineInputBorder(borderSide: BorderSide.none)),
                                  items: _availableUnits.map((u) => DropdownMenuItem(value: u.id, child: Text(u.name))).toList(),
                                  onChanged: (val) => setState(() => _defaultUnitId = val),
                                ),
                              ]
                            ],
                          ),
                        ),
                      )
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 8),
                child: Text(l10n.sectionSettingsSync, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
              ),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    RadioListTile<String>(title: Text(l10n.syncLocalNone), value: 'none', groupValue: _teamSyncMode, activeColor: const Color(0xFF4A73D1), onChanged: (val) => setState(() => _teamSyncMode = val!)),
                    RadioListTile<String>(title: Text(l10n.syncCaldavJournal), subtitle: Text(l10n.syncCaldavJournalSubtitle), value: 'caldav', groupValue: _teamSyncMode, activeColor: const Color(0xFF4A73D1), onChanged: (val) => setState(() => _teamSyncMode = val!)),
                    RadioListTile<String>(title: Text(l10n.syncExternalWebdav), subtitle: Text(l10n.syncExternalWebdavSubtitle), value: 'webdav', groupValue: _teamSyncMode, activeColor: const Color(0xFF4A73D1), onChanged: (val) => setState(() => _teamSyncMode = val!)),

                    if (_teamSyncMode == 'webdav')
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
                          child: Column(
                            children: [
                              TextField(controller: _webdavUrlCtrl, decoration: InputDecoration(labelText: l10n.webdavUrlLabel, filled: true, fillColor: Colors.white, border: const OutlineInputBorder(borderSide: BorderSide.none))),
                              const SizedBox(height: 12),
                              TextField(controller: _webdavUserCtrl, decoration: InputDecoration(labelText: l10n.usernameLabel, filled: true, fillColor: Colors.white, border: const OutlineInputBorder(borderSide: BorderSide.none))),
                              const SizedBox(height: 12),
                              TextField(controller: _webdavPassCtrl, obscureText: !_isWebdavPassVisible, decoration: InputDecoration(labelText: l10n.passwordLabel, filled: true, fillColor: Colors.white, border: const OutlineInputBorder(borderSide: BorderSide.none), suffixIcon: IconButton(icon: Icon(_isWebdavPassVisible ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _isWebdavPassVisible = !_isWebdavPassVisible)))),
                            ],
                          ),
                        ),
                      )
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),
            if (widget.existingAccount != null && widget.onDelete != null)
              Center(
                child: TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    icon: const Icon(Icons.delete_forever),
                    label: Text(l10n.deleteWorkspaceButton),
                    onPressed: () {
                      showDialog(
                          context: context,
                          builder: (dialogContext) => AlertDialog(
                            title: Text(l10n.deleteWorkspaceTitle),
                            content: Text(l10n.deleteWorkspaceMessage),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(l10n.cancel)),
                              TextButton(onPressed: () { Navigator.pop(dialogContext); widget.onDelete!(); }, child: Text(l10n.delete, style: const TextStyle(color: Colors.red))),
                            ],
                          )
                      );
                    }
                ),
              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}