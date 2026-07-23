import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'dart:convert';

import '../models/employee.dart';
import '../services/secure_vault.dart';
import '../l10n/app_localizations.dart';

/// Screen for managing team members, per workspace (multi-tenant).
///
/// Allows adding, editing, and deleting people scoped to whichever
/// CalDAV workspace is currently selected.
class TeamManagerScreen extends StatefulWidget {
  final VoidCallback onTeamChanged;

  const TeamManagerScreen({super.key, required this.onTeamChanged});

  @override
  State<TeamManagerScreen> createState() => _TeamManagerScreenState();
}

class _TeamManagerScreenState extends State<TeamManagerScreen> {
  List<Employee> _team = [];

  List<CalDavAccount> _accounts = [];
  CalDavAccount? _selectedAccount;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAccountsAndTeam();
  }

  Future<void> _loadAccountsAndTeam() async {
    final allAccounts = await SecureVault.getAllAccounts();

    if (mounted) {
      setState(() {
        _accounts = allAccounts;
        if (_accounts.isNotEmpty) {
          _selectedAccount = _accounts.first;
        }
      });
    }

    if (_selectedAccount != null) {
      await _loadTeamForSelectedAccount();
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadTeamForSelectedAccount() async {
    if (!mounted || _selectedAccount == null) return;
    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final accountId = _selectedAccount!.id;

    // Team storage is scoped to this specific workspace.
    final String? teamJson = prefs.getString('saved_team_$accountId');

    List<Employee> loadedTeam = [];

    if (teamJson != null) {
      final List<dynamic> decoded = jsonDecode(teamJson);
      loadedTeam = decoded.map((e) => Employee.fromJson(e)).toList();
    } else {
      // Only the very first (primary) workspace gets the legacy-data
      // migration fallback; every other workspace starts empty.
      if (_accounts.isNotEmpty && accountId == _accounts.first.id) {
        final String? globalJson = prefs.getString('saved_team');
        if (globalJson != null) {
          final List<dynamic> decoded = jsonDecode(globalJson);
          loadedTeam = decoded.map((e) => Employee.fromJson(e)).toList();
        } else {
          loadedTeam = [const Employee("Ich", Color(0xFF4A73D1))];
        }
      } else {
        loadedTeam = [];
      }
    }

    if (mounted) {
      setState(() {
        _team = loadedTeam;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveTeam() async {
    if (_selectedAccount == null) return;

    final prefs = await SharedPreferences.getInstance();
    final accountId = _selectedAccount!.id;

    final String encoded = jsonEncode(_team.map((e) => e.toJson()).toList());

    // Persist strictly scoped to this workspace.
    await prefs.setString('saved_team_$accountId', encoded);

    // Also mirror the primary workspace's team into the legacy global
    // key, so the calendar screen doesn't crash on old data during
    // startup.
    if (_accounts.isNotEmpty && _selectedAccount!.id == _accounts.first.id) {
      await prefs.setString('saved_team', encoded);
    }

    widget.onTeamChanged();
  }

  void _addOrEditMember({Employee? existingMember, int? index}) {
    final l10n = AppLocalizations.of(context)!;
    final nameController = TextEditingController(text: existingMember?.name ?? "");
    Color selectedColor = existingMember?.color ?? Colors.blue;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text(existingMember == null ? l10n.addPersonTitle : l10n.editPersonTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: l10n.nameLabel, border: const OutlineInputBorder()),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              Text(l10n.chooseColorLabel, style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 8),
              ColorPicker(
                pickerColor: selectedColor,
                onColorChanged: (color) => setModalState(() => selectedColor = color),
                pickerAreaHeightPercent: 0.6,
                enableAlpha: false,
                hexInputBar: true,
                labelTypes: const [],
              ),
            ],
          ),
          actions: [
            if (existingMember != null)
              TextButton(
                onPressed: () {
                  setState(() => _team.removeAt(index!));
                  _saveTeam();
                  Navigator.pop(context);
                },
                child: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
              ),
            TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A73D1), foregroundColor: Colors.white),
              onPressed: () {
                if (nameController.text.trim().isNotEmpty) {
                  final newEmp = Employee(nameController.text.trim(), selectedColor);
                  setState(() {
                    if (existingMember == null) {
                      _team.add(newEmp);
                    } else {
                      _team[index!] = newEmp;
                    }
                  });
                  _saveTeam();
                  Navigator.pop(context);
                }
              },
              child: Text(l10n.save),
            ),
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
        title: _accounts.length > 1
            ? DropdownButtonHideUnderline(
          child: DropdownButton<CalDavAccount>(
            dropdownColor: const Color(0xFF4A73D1),
            icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
            isExpanded: true,
            value: _selectedAccount,
            items: _accounts.map((acc) => DropdownMenuItem(
                value: acc,
                child: Text(acc.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))
            )).toList(),
            onChanged: (newAcc) {
              if (newAcc != null && newAcc.id != _selectedAccount?.id) {
                setState(() => _selectedAccount = newAcc);
                _loadTeamForSelectedAccount();
              }
            },
          ),
        )
            : Text(l10n.teamAndColorsTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF4A73D1),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _accounts.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(l10n.noWorkspaceAvailable, style: const TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      )
          : _team.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_add_disabled, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(l10n.noPeopleInWorkspace, style: const TextStyle(color: Colors.grey, fontSize: 16)),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => _addOrEditMember(),
              icon: const Icon(Icons.add),
              label: Text(l10n.addFirstPerson),
            )
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _team.length,
        itemBuilder: (context, index) {
          final emp = _team[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: CircleAvatar(
                backgroundColor: emp.color,
                child: Text(emp.initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              title: Text(emp.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              trailing: const Icon(Icons.edit, color: Colors.grey),
              onTap: () => _addOrEditMember(existingMember: emp, index: index),
            ),
          );
        },
      ),
      floatingActionButton: _accounts.isNotEmpty ? FloatingActionButton(
        onPressed: () => _addOrEditMember(),
        backgroundColor: const Color(0xFF4A73D1),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ) : null,
    );
  }
}