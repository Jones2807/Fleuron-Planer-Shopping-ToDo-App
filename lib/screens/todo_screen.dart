import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';

import '../models/todo_task.dart';
import '../services/caldav_service.dart';
import '../services/secure_vault.dart';
import '../l10n/app_localizations.dart';

/// Offline-first local cache for to-do tasks, keyed by CalDAV list
/// path. Used so the task list still shows something useful before
/// the server round-trip completes (or if it's offline).
class WebTodoCache {
  static Future<void> saveTasksForList(String listPath, List<TodoTask> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> jsonList = tasks.map((t) => {
      'uid': t.uid,
      'title': t.title,
      'description': t.description,
      'dueDate': t.dueDate?.toIso8601String(),
      'isDone': t.isDone,
    }).toList();
    await prefs.setString('web_todos_$listPath', jsonEncode(jsonList));
  }

  static Future<List<TodoTask>> loadTasksForList(String listPath) async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString('web_todos_$listPath');
    if (str == null) return [];

    final List<dynamic> decoded = jsonDecode(str);
    return decoded.map((json) => TodoTask(
      uid: json['uid'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate'] as String) : null,
      isDone: json['isDone'] as bool,
    )).toList();
  }
}

/// Tile overview of all to-do lists for the active CalDAV account,
/// split into shared and private lists, with an option to hide lists
/// from the dashboard without deleting them.
class CalDavTodoScreen extends StatefulWidget {
  const CalDavTodoScreen({super.key});

  @override
  State<CalDavTodoScreen> createState() => _CalDavTodoScreenState();
}

class _CalDavTodoScreenState extends State<CalDavTodoScreen> {
  Set<String> _hiddenListPaths = {};
  bool _showOnlyShared = true;
  bool _isLoading = true;

  final Map<String, String> _sharedLists = {};
  final Map<String, String> _privateLists = {};

  List<CalDavAccount> _todoAccounts = [];
  CalDavAccount? _selectedAccount;

  @override
  void initState() {
    super.initState();
    _loadAccountsAndLists();
  }

  Future<void> _loadAccountsAndLists() async {
    final accounts = await CalDavService.getTodoAccounts();
    if (mounted) {
      setState(() {
        _todoAccounts = accounts;
        if (_todoAccounts.isNotEmpty) _selectedAccount = _todoAccounts.first;
      });
    }
    if (_selectedAccount != null) {
      await _loadListsForSelectedAccount();
    } else if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadListsForSelectedAccount() async {
    if (!mounted || _selectedAccount == null) return;
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final accountId = _selectedAccount!.id;

    final savedHidden = prefs.getStringList('hiddenListPaths_$accountId') ?? [];
    _hiddenListPaths = savedHidden.toSet();
    List<String> privateNames = prefs.getStringList('privateListNames_$accountId') ?? [];

    final serverLists = await CalDavService.fetchTodoLists(account: _selectedAccount);
    _sharedLists.clear();
    _privateLists.clear();

    if (serverLists.isNotEmpty) {
      serverLists.forEach((name, path) {
        if (privateNames.contains(name)) {
          _privateLists[name] = path;
        } else {
          _sharedLists[name] = path;
        }
      });
      _saveAllLists();
    } else {
      final savedShared = prefs.getString('customSharedLists_$accountId');
      if (savedShared != null) (jsonDecode(savedShared) as Map).forEach((k, v) => _sharedLists[k] = v.toString());
      final savedPrivate = prefs.getString('customPrivateLists_$accountId');
      if (savedPrivate != null) (jsonDecode(savedPrivate) as Map).forEach((k, v) => _privateLists[k] = v.toString());
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveAllLists() async {
    if (_selectedAccount == null) return;
    final prefs = await SharedPreferences.getInstance();
    final accountId = _selectedAccount!.id;
    await prefs.setString('customSharedLists_$accountId', jsonEncode(_sharedLists));
    await prefs.setString('customPrivateLists_$accountId', jsonEncode(_privateLists));
    await prefs.setStringList('privateListNames_$accountId', _privateLists.keys.toList());
    await prefs.setStringList('hiddenListPaths_$accountId', _hiddenListPaths.toList());
  }

  Map<String, String> _getVisibleLists() {
    Map<String, String> base = _showOnlyShared ? Map.from(_sharedLists) : {..._sharedLists, ..._privateLists};
    base.removeWhere((name, path) => _hiddenListPaths.contains(path));
    return base;
  }

  void _showAddListDialog() {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    bool isShared = true;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
        title: Text(l10n.newListTitle),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: controller, autofocus: true, textCapitalization: TextCapitalization.sentences, decoration: InputDecoration(hintText: l10n.newListHint)),
          const SizedBox(height: 16),
          SwitchListTile(title: Text(l10n.shareWithFamily), subtitle: Text(isShared ? l10n.everyoneSeesListSubtitle : l10n.onlyYouSeeListSubtitle), value: isShared, activeThumbColor: const Color(0xFF4A73D1), onChanged: (val) => setDialogState(() => isShared = val))
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
          TextButton(onPressed: () async {
            if (controller.text.isNotEmpty && _selectedAccount != null) {
              setState(() => _isLoading = true); Navigator.pop(context);
              final name = controller.text.trim();
              final path = await CalDavService.createNewList(name, account: _selectedAccount);
              if (path != null) {
                setState(() { if (isShared) {
                  _sharedLists[name] = path;
                } else {
                  _privateLists[name] = path;
                } });
                _saveAllLists();
              }
              setState(() => _isLoading = false);
            }
          }, child: Text(l10n.create))
        ],
      )),
    );
  }

  void _showEditListDialog(String currentName, String listPath) {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: currentName);
    showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.renameListTitle),
          content: TextField(controller: controller, autofocus: true, textCapitalization: TextCapitalization.sentences),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(l10n.cancel)),
            TextButton(
                onPressed: () async {
                  final newName = controller.text.trim();
                  if (newName.isNotEmpty && newName != currentName) {
                    // Close the dialog before the (potentially slow) server round-trip.
                    Navigator.pop(dialogContext);

                    final account = _selectedAccount;
                    if (account == null) return;

                    setState(() => _isLoading = true);

                    // Ask the server to actually rename the list.
                    final success = await CalDavService.renameList(listPath, newName, account: account);

                    if (mounted) setState(() => _isLoading = false);

                    if (success) {
                      // Server confirmed - update local state too.
                      setState(() {
                        if (_sharedLists.containsKey(currentName)) {
                          _sharedLists.remove(currentName);
                          _sharedLists[newName] = listPath;
                        } else {
                          _privateLists.remove(currentName);
                          _privateLists[newName] = listPath;
                        }
                      });
                      await _saveAllLists();
                    } else {
                      // Server refused (e.g. Synology's CalDAV implementation
                      // doesn't support renaming lists) - explain why instead
                      // of silently failing.
                      _showServerRestrictionDialog();
                    }
                  } else {
                    // Nothing changed, just close.
                    Navigator.pop(dialogContext);
                  }
                },
                child: Text(l10n.save)
            )
          ],
        )
    );
  }
  void _confirmDeleteList(String listName, String listPath) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.deleteListTitle),
        content: Text(l10n.deleteListMessage(listName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);

              final account = _selectedAccount;
              if (account == null) return;

              setState(() => _isLoading = true);

              // Try deleting the list on the server itself.
              final success = await CalDavService.deleteList(listPath, account: account);

              if (!mounted) return;
              setState(() => _isLoading = false);

              if (success) {
                // Worked (e.g. on Nextcloud).
                setState(() {
                  _privateLists.remove(listName);
                  _sharedLists.remove(listName);
                });
                await _saveAllLists();
              } else {
                // Didn't work (e.g. on Synology) - show the honest
                // explanation instead of pretending it succeeded.
                _showServerRestrictionDialog();
              }
            },
            child: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  /// Explains that the server itself refused to delete/rename a list
  /// (some CalDAV servers, e.g. Synology, block this for third-party
  /// apps) and points the user to the server's own web interface.
  void _showServerRestrictionDialog() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.security, color: Colors.orange),
            const SizedBox(width: 8),
            Text(l10n.blockedByServerTitle),
          ],
        ),
        content: Text(l10n.blockedByServerMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.understood),
          ),
        ],
      ),
    );
  }

  /// Bottom sheet to show/hide individual lists on the dashboard,
  /// without deleting them from the server.
  void _showVisibilityDialog() {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) {
          return StatefulBuilder(
              builder: (context, setModalState) {
                // All lists known for this account, shared and private combined.
                final allLists = {..._sharedLists, ..._privateLists};

                return Container(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                  decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24))
                  ),
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.manageVisibility, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(l10n.manageVisibilityDescription, style: const TextStyle(color: Colors.grey, fontSize: 14)),
                      const SizedBox(height: 16),
                      Expanded(
                        child: allLists.isEmpty
                            ? Center(child: Text(l10n.noListsFoundOnServer))
                            : ListView.builder(
                          itemCount: allLists.length,
                          itemBuilder: (context, index) {
                            String name = allLists.keys.elementAt(index);
                            String path = allLists.values.elementAt(index);
                            bool isVisible = !_hiddenListPaths.contains(path);
                            bool isPrivate = _privateLists.containsKey(name);

                            return Card(
                              elevation: 0,
                              margin: const EdgeInsets.only(bottom: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                              child: SwitchListTile(
                                title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Row(
                                  children: [
                                    Icon(isPrivate ? Icons.lock : Icons.public, size: 14, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(isPrivate ? l10n.privateLabel : l10n.sharedLabel, style: const TextStyle(color: Colors.grey)),
                                  ],
                                ),
                                value: isVisible,
                                activeThumbColor: const Color(0xFF4A73D1),
                                onChanged: (val) {
                                  setModalState(() {
                                    if (val) {
                                      _hiddenListPaths.remove(path); // Make visible again.
                                    } else {
                                      _hiddenListPaths.add(path); // Hide from the dashboard.
                                    }
                                  });
                                  // Update the main UI instantly.
                                  setState(() {});
                                  _saveAllLists();
                                },
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A73D1), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          onPressed: () => Navigator.pop(context),
                          child: Text(l10n.done, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      )
                    ],
                  ),
                );
              }
          );
        }
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final visibleLists = _getVisibleLists();
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4A73D1),
        foregroundColor: Colors.white,
        title: _todoAccounts.length > 1
            ? DropdownButtonHideUnderline(child: DropdownButton<CalDavAccount>(
          dropdownColor: const Color(0xFF4A73D1), icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
          isExpanded: true, value: _selectedAccount,
          items: _todoAccounts.map((acc) => DropdownMenuItem(value: acc, child: Text(acc.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)))).toList(),
          onChanged: (newAcc) { if (newAcc != null && newAcc.id != _selectedAccount?.id) { setState(() => _selectedAccount = newAcc); _loadListsForSelectedAccount(); } },
        ))
            : Text(l10n.tasksTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          PopupMenuButton<String>(icon: const Icon(Icons.more_vert, color: Colors.white), onSelected: (val) {
            if (val == 'newList') _showAddListDialog();
            if (val == 'togglePrivate') setState(() => _showOnlyShared = !_showOnlyShared);
            if (val == 'manageVisibility') _showVisibilityDialog();
          }, itemBuilder: (context) => [
            PopupMenuItem(value: 'newList', child: ListTile(leading: const Icon(Icons.add), title: Text(l10n.newListMenuItem), contentPadding: EdgeInsets.zero)),
            PopupMenuItem(value: 'togglePrivate', child: ListTile(leading: Icon(_showOnlyShared ? Icons.visibility : Icons.visibility_off), title: Text(_showOnlyShared ? l10n.showPrivateItems : l10n.hidePrivateItems), contentPadding: EdgeInsets.zero)),
            PopupMenuItem(value: 'manageVisibility', child: ListTile(leading: const Icon(Icons.checklist_rtl), title: Text(l10n.manageVisibility), contentPadding: EdgeInsets.zero)),
          ]),
        ],
      ),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : visibleLists.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.checklist, size: 64, color: Colors.grey.shade300), const SizedBox(height: 16), Text(l10n.noListsFound, style: const TextStyle(color: Colors.grey))]))
          : RefreshIndicator(onRefresh: _loadListsForSelectedAccount, child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 1.1),
        itemCount: visibleLists.length,
        itemBuilder: (context, index) {
          String name = visibleLists.keys.elementAt(index);
          String path = visibleLists.values.elementAt(index);
          bool isPrivate = _privateLists.containsKey(name);
          return GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TodoListDetailScreen(listName: name, listPath: path, account: _selectedAccount!))).then((_) => _loadListsForSelectedAccount()),
            child: Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))]),
              child: Stack(children: [
                Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF4A73D1).withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(isPrivate ? Icons.lock_outline : Icons.checklist, size: 32, color: const Color(0xFF4A73D1))),
                  const SizedBox(height: 12),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 8.0), child: Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis)),
                ])),
                Positioned(
                    top: 0, right: 0,
                    child: PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Colors.grey, size: 20),
                        onSelected: (val) {
                          if (val == 'rename') _showEditListDialog(name, path);
                          if (val == 'hide') { setState(() => _hiddenListPaths.add(path)); _saveAllLists(); }
                          if (val == 'delete') _confirmDeleteList(name, path);
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(value: 'rename', child: Text(l10n.rename)),
                          PopupMenuItem(value: 'hide', child: Text(l10n.hide)),
                          const PopupMenuDivider(),
                          PopupMenuItem(value: 'delete', child: Text(l10n.delete, style: const TextStyle(color: Colors.red))),
                        ]
                    )
                ),
              ]),
            ),
          );
        },
      )),
      floatingActionButton: FloatingActionButton(backgroundColor: const Color(0xFF4A73D1), onPressed: _todoAccounts.isNotEmpty ? _showAddListDialog : null, child: const Icon(Icons.add, color: Colors.white)),
    );
  }
}

/// Detail view of a single to-do list: task items with a checkbox,
/// optional due date/note, and the add/edit task dialog.
class TodoListDetailScreen extends StatefulWidget {
  final String listName;
  final String listPath;
  final CalDavAccount account;
  const TodoListDetailScreen({super.key, required this.listName, required this.listPath, required this.account});
  @override
  State<TodoListDetailScreen> createState() => _TodoListDetailScreenState();
}

class _TodoListDetailScreenState extends State<TodoListDetailScreen> {
  List<TodoTask> _currentTasks = [];
  bool _isLoading = true;

  @override
  void initState() { super.initState(); _refreshTasks(); }

  void _refreshTasks() async {
    final cached = await WebTodoCache.loadTasksForList(widget.listPath);
    if (mounted && cached.isNotEmpty) {
      setState(() => _currentTasks = cached);
    } else {
      setState(() => _isLoading = true);
    }
    if (!(await CalDavService.checkConnection())) { if (mounted) setState(() => _isLoading = false); return; }
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final tasks = await CalDavService.fetchTasks(widget.listPath, account: widget.account, unnamedFallback: l10n.unnamedTaskFallback);
    await WebTodoCache.saveTasksForList(widget.listPath, tasks);
    if (mounted) setState(() { _currentTasks = tasks; _isLoading = false; });
  }

  void _showTaskDialog({TodoTask? existingTask}) {
    final l10n = AppLocalizations.of(context)!;
    final titleController = TextEditingController(text: existingTask?.title ?? "");
    final descController = TextEditingController(text: existingTask?.description ?? "");
    DateTime? selectedDate = existingTask?.dueDate;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
        title: Text(existingTask == null ? l10n.newTaskTitle : l10n.editTaskTitle),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: titleController, autofocus: true, textCapitalization: TextCapitalization.sentences, decoration: InputDecoration(labelText: l10n.taskTitleLabel)),
          const SizedBox(height: 12),
          TextField(controller: descController, textCapitalization: TextCapitalization.sentences, maxLines: 3, minLines: 1, decoration: InputDecoration(labelText: l10n.noteOptionalLabel)),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero, leading: const Icon(Icons.calendar_today, color: Color(0xFF4A73D1)),
            title: Text(selectedDate == null ? l10n.dueDateOptional : l10n.dueDatePrefix(DateFormat('dd.MM.yyyy').format(selectedDate!))),
            trailing: selectedDate != null ? IconButton(icon: const Icon(Icons.clear, color: Colors.grey), onPressed: () => setDialogState(() => selectedDate = null)) : null,
            onTap: () async {
              final picked = await showDatePicker(context: context, initialDate: selectedDate ?? DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 3650)));
              if (picked != null) setDialogState(() => selectedDate = picked);
            },
          ),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A73D1)),
            onPressed: () {
              if (titleController.text.trim().isNotEmpty) {
                final title = titleController.text.trim();
                final desc = descController.text.trim();
                Navigator.pop(context);

                if (existingTask == null) {
                  final temp = TodoTask(uid: DateTime.now().millisecondsSinceEpoch.toString(), title: title, description: desc, dueDate: selectedDate, isDone: false);
                  setState(() => _currentTasks.add(temp));
                  CalDavService.addTask(widget.listPath, title, description: desc, dueDate: selectedDate, account: widget.account).then((_) => _refreshTasks());
                } else {
                  setState(() {
                    int idx = _currentTasks.indexWhere((t) => t.uid == existingTask.uid);
                    if (idx != -1) _currentTasks[idx] = TodoTask(uid: existingTask.uid, title: title, description: desc, dueDate: selectedDate, isDone: existingTask.isDone);
                  });
                  CalDavService.updateTask(widget.listPath, _currentTasks.firstWhere((t) => t.uid == existingTask.uid), account: widget.account).then((_) => _refreshTasks());
                }
                WebTodoCache.saveTasksForList(widget.listPath, _currentTasks);
              }
            },
            child: Text(l10n.save, style: const TextStyle(color: Colors.white)),
          ),
        ],
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(title: Text(widget.listName, style: const TextStyle(fontWeight: FontWeight.bold)), backgroundColor: const Color(0xFF4A73D1), foregroundColor: Colors.white),
      body: _isLoading && _currentTasks.isEmpty ? const Center(child: CircularProgressIndicator()) : _currentTasks.isEmpty
          ? Center(child: Text(l10n.allDoneMessage, style: const TextStyle(color: Colors.grey)))
          : RefreshIndicator(color: const Color(0xFF4A73D1), onRefresh: () async => _refreshTasks(), child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 80),
        itemCount: _currentTasks.length,
        itemBuilder: (context, index) {
          final task = _currentTasks[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              onTap: () => _showTaskDialog(existingTask: task),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Checkbox(activeColor: const Color(0xFF4A73D1), value: task.isDone, onChanged: (val) {
                if (val == null) return;
                setState(() => task.isDone = val);
                WebTodoCache.saveTasksForList(widget.listPath, _currentTasks);
                CalDavService.updateTask(widget.listPath, task, account: widget.account).then((s) { if (!s && mounted) debugPrint("Sync failed."); });
              }),
              title: Text(task.title, style: TextStyle(fontSize: 16, decoration: task.isDone ? TextDecoration.lineThrough : TextDecoration.none, color: task.isDone ? Colors.grey : Colors.black87)),
              subtitle: (task.description != null && task.description!.isNotEmpty) ? Text(task.description!, maxLines: 1, overflow: TextOverflow.ellipsis) : null,
              trailing: PopupMenuButton<String>(icon: const Icon(Icons.more_horiz, color: Colors.grey), onSelected: (val) {
                if (val == 'edit') _showTaskDialog(existingTask: task);
                if (val == 'delete') { setState(() => _currentTasks.removeWhere((t) => t.uid == task.uid)); WebTodoCache.saveTasksForList(widget.listPath, _currentTasks); CalDavService.deleteTask(widget.listPath, task.uid, account: widget.account); }
              }, itemBuilder: (context) => [
                PopupMenuItem(value: 'edit', child: Text(l10n.editAction)),
                PopupMenuItem(value: 'delete', child: Text(l10n.delete, style: const TextStyle(color: Colors.red))),
              ]),
            ),
          );
        },
      )),
      floatingActionButton: FloatingActionButton.extended(backgroundColor: const Color(0xFF4A73D1), onPressed: () => _showTaskDialog(), icon: const Icon(Icons.add, color: Colors.white), label: Text(l10n.taskFabLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
    );
  }
}