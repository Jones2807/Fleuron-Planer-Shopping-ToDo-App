import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/grocy_service.dart';
import '../services/secure_vault.dart';
import '../models/grocy_models.dart';
import '../services/caldav_service.dart';
import '../models/todo_task.dart';
import '../widgets/shopping_dialogs.dart';
import '../l10n/app_localizations.dart';

/// The app's shopping list screen. Behaves like a chameleon: it
/// renders either a Grocy-backed list or a CalDAV/VTODO-backed list
/// depending on which mode is configured for the active workspace
/// (see `settings_screen.dart`), or an empty state if neither is
/// enabled.
class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

/// Offline-first local cache for both shopping-list backends (Grocy
/// and CalDAV), keyed by account ID.
class WebShoppingCache {
  static Future<void> saveGrocyList(String accountId, Map<String, List<GrocyItem>> groupedItems) async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> jsonMap = {};
    groupedItems.forEach((category, items) {
      jsonMap[category] = items.map((i) => {
        'id': i.id, 'productId': i.productId, 'name': i.name, 'category': i.category, 'amount': i.amount, 'isDone': i.isDone,
      }).toList();
    });
    await prefs.setString('web_shopping_grocy_$accountId', jsonEncode(jsonMap));
  }

  static Future<Map<String, List<GrocyItem>>> loadGrocyList(String accountId) async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString('web_shopping_grocy_$accountId');
    if (str == null) return {};
    final Map<String, dynamic> decoded = jsonDecode(str);
    final Map<String, List<GrocyItem>> result = {};
    decoded.forEach((category, itemsList) {
      result[category] = (itemsList as List).map((i) => GrocyItem(
        id: i['id'], productId: i['productId'], name: i['name'], category: i['category'], amount: (i['amount'] as num).toDouble(), isDone: i['isDone'],
      )).toList();
    });
    return result;
  }

  static Future<void> saveCalDavList(String accountId, List<TodoTask> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> jsonList = tasks.map((t) => {
      'uid': t.uid, 'title': t.title, 'isDone': t.isDone, 'description': t.description,
    }).toList();
    await prefs.setString('web_shopping_caldav_$accountId', jsonEncode(jsonList));
  }

  static Future<List<TodoTask>> loadCalDavList(String accountId) async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString('web_shopping_caldav_$accountId');
    if (str == null) return [];
    final List<dynamic> decoded = jsonDecode(str);
    return decoded.map((json) => TodoTask(
      uid: json['uid'] as String, title: json['title'] as String, isDone: json['isDone'] as bool, description: json['description'] as String?,
    )).toList();
  }
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  List<CalDavAccount> _accounts = [];
  CalDavAccount? _selectedAccount;
  String _shoppingMode = 'none';
  bool _isLoading = true;

  GrocyService? _grocyService;
  Map<String, List<GrocyItem>> _groupedItems = {};
  List<GrocyProduct> _allProducts = [];
  List<GrocyProductGroup> _productGroups = [];
  List<GrocyQuantityUnit> _quantityUnits = [];
  List<GrocyLocation> _locations = [];

  String? _calDavListPath;
  List<TodoTask> _calDavItems = [];

  bool _showCompleted = false;
  final Set<String> _collapsedCategories = {};
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<GrocyProduct> _searchResults = [];
  bool _isEditingMode = false;

  String _activeStoreProfile = 'Standard';
  List<String> _storeProfiles = ['Standard', 'Aldi', 'Netto'];
  Map<String, List<String>> _profileSortOrders = {
    'Standard': [],
    'Aldi': ['OBST & GEMÜSE', 'KÜHLREGAL', 'GETRÄNKE'],
  };

  @override
  void initState() {
    super.initState();
    _loadAccounts();
    _loadStoreProfiles();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    final allAccounts = await SecureVault.getAllAccounts();
    if (mounted) {
      setState(() {
        _accounts = allAccounts.where((a) => a.isActive).toList();
        if (_accounts.isNotEmpty) _selectedAccount = _accounts.first;
      });
      await _loadWorkspaceConfig();
    }
  }

  Future<void> _loadWorkspaceConfig() async {
    if (_selectedAccount == null) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() {
      _isLoading = true;
      _groupedItems.clear();
      _calDavItems.clear();
      _searchController.clear();
      _searchResults.clear();
    });

    final prefs = await SharedPreferences.getInstance();
    final accountId = _selectedAccount!.id;

    _shoppingMode = prefs.getString('shopping_mode_$accountId') ??
        (_selectedAccount!.syncShopping ? 'caldav' : 'none');

    if (_shoppingMode == 'grocy') {
      final url = prefs.getString('grocy_url_$accountId') ?? "";
      final key = prefs.getString('grocy_key_$accountId') ?? "";
      if (url.isNotEmpty && key.isNotEmpty) {
        _grocyService = GrocyService(baseUrl: url, apiKey: key);
        await _loadGrocyData();
      } else {
        setState(() => _shoppingMode = 'none');
      }
    } else if (_shoppingMode == 'caldav') {
      await _initCalDavShopping();
    } else {
      setState(() => _isLoading = false);
    }
  }

  List<String> _getCurrentCategories() {
    if (_shoppingMode == 'grocy') return _groupedItems.keys.toList();
    if (_shoppingMode == 'caldav') return _getCalDavGrouped().keys.toList();
    return [];
  }

  Future<void> _loadStoreProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final savedProfiles = prefs.getString('storeProfiles');
    final savedNames = prefs.getStringList('storeProfileNames');
    if (savedNames != null) setState(() => _storeProfiles = savedNames);
    if (savedProfiles != null) {
      final decoded = jsonDecode(savedProfiles) as Map<String, dynamic>;
      setState(() => _profileSortOrders = decoded.map((key, value) => MapEntry(key, List<String>.from(value))));
    }
  }

  Future<void> _saveStoreProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('storeProfileNames', _storeProfiles);
    await prefs.setString('storeProfiles', jsonEncode(_profileSortOrders));
  }

  void _showAddProfileDialog() {
    final l10n = AppLocalizations.of(context)!;
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.newStoreTitle),
        content: TextField(controller: controller, autofocus: true, decoration: InputDecoration(hintText: l10n.newStoreHint), textCapitalization: TextCapitalization.sentences),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                setState(() { _storeProfiles.add(controller.text.trim()); _activeStoreProfile = controller.text.trim(); });
                _saveStoreProfiles();
                Navigator.pop(context);
              }
            },
            child: Text(l10n.create),
          ),
        ],
      ),
    );
  }

  /// Confirms and performs deletion of a store profile (triggered via
  /// long-press in the store-profile bar). The built-in "Standard"
  /// profile can't be deleted.
  void _confirmDeleteProfile(String profile) {
    if (profile == 'Standard') return; // Protects the built-in default profile.

    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteStoreTitle),
        content: Text(l10n.deleteStoreMessage(profile)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              setState(() {
                _storeProfiles.remove(profile);
                _profileSortOrders.remove(profile); // Clean up its sort order too.
                if (_activeStoreProfile == profile) {
                  _activeStoreProfile = 'Standard'; // Fall back if the deleted profile was active.
                }
              });
              _saveStoreProfiles();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.profileDeletedMessage(profile))),
              );
            },
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  /// Renames a category, in whichever backend (CalDAV or Grocy) is
  /// currently active.
  void _showEditCategoryDialog(String oldCategory) {
    final l10n = AppLocalizations.of(context)!;
    final ctrl = TextEditingController(text: oldCategory);
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
            title: Text(l10n.renameCategoryTitle),
            content: TextField(controller: ctrl, autofocus: true, textCapitalization: TextCapitalization.words, decoration: InputDecoration(labelText: l10n.newNameLabel)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
              ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A73D1), foregroundColor: Colors.white),
                  onPressed: () async {
                    final newName = ctrl.text.trim();
                    if (newName.isNotEmpty && newName.toUpperCase() != oldCategory.toUpperCase()) {
                      Navigator.pop(context);

                      if (_shoppingMode == 'caldav') {
                        setState(() => _isLoading = true);
                        for (var task in _calDavItems.where((t) => (t.description ?? "SONSTIGES").toUpperCase() == oldCategory.toUpperCase())) {
                          final updatedTask = TodoTask(uid: task.uid, title: task.title, isDone: task.isDone, description: newName.toUpperCase(), dueDate: task.dueDate);
                          final index = _calDavItems.indexWhere((t) => t.uid == task.uid);
                          if (index != -1) _calDavItems[index] = updatedTask;
                          await CalDavService.updateTask(_calDavListPath!, updatedTask, account: _selectedAccount);
                        }
                        WebShoppingCache.saveCalDavList(_selectedAccount!.id, _calDavItems);
                        setState(() => _isLoading = false);

                      } else if (_shoppingMode == 'grocy') {
                        final group = _productGroups.firstWhere((g) => g.name.toUpperCase() == oldCategory.toUpperCase(), orElse: () => GrocyProductGroup(id: '', name: ''));
                        if (group.id.isNotEmpty) {
                          setState(() => _isLoading = true);
                          await _grocyService!.updateProductGroup(group.id, newName);
                          await _loadGrocyData();
                        }
                      }
                    }
                  },
                  child: Text(l10n.save)
              )
            ]
        )
    );
  }

  // --- CalDAV backend ---

  Future<void> _initCalDavShopping() async {
    final cached = await WebShoppingCache.loadCalDavList(_selectedAccount!.id);
    if (mounted && cached.isNotEmpty) setState(() => _calDavItems = cached);

    final lists = await CalDavService.fetchTodoLists(account: _selectedAccount);
    String? targetPath;
    for (var entry in lists.entries) {
      if (entry.key.toLowerCase().contains("einkauf")) { targetPath = entry.value; break; }
    }
    targetPath ??= await CalDavService.createNewList("Einkaufsliste", account: _selectedAccount);

    if (targetPath != null) {
      _calDavListPath = targetPath;
      await _refreshCalDavList();
    } else {
      setState(() => _isLoading = false);
    }
  }

  /// Refreshes the CalDAV-backed shopping list from the server.
  ///
  /// Bails out early if offline, rather than overwriting the current
  /// list (and its cache) with the empty result that
  /// [CalDavService.fetchTasks] silently returns when every request
  /// fails - see the equivalent fix in `calendar_screen.dart`'s
  /// `_loadEventsFromServer`.
  Future<void> _refreshCalDavList() async {
    if (_calDavListPath == null) return;
    if (!mounted) return;

    if (!(await CalDavService.checkConnection())) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    if (!mounted) return;

    final l10n = AppLocalizations.of(context)!;
    final tasks = await CalDavService.fetchTasks(_calDavListPath!, account: _selectedAccount, unnamedFallback: l10n.unnamedTaskFallback);
    if (mounted) {
      setState(() { _calDavItems = tasks; _isLoading = false; });
      WebShoppingCache.saveCalDavList(_selectedAccount!.id, tasks);
    }
  }

  Map<String, List<TodoTask>> _getCalDavGrouped() {
    Map<String, List<TodoTask>> map = {};
    for (var task in _calDavItems) {
      String cat = (task.description != null && task.description!.trim().isNotEmpty) ? task.description!.trim().toUpperCase() : "SONSTIGES";
      if (!map.containsKey(cat)) map[cat] = [];
      map[cat]!.add(task);
    }
    return map;
  }

  Future<void> _addCalDavItem(String title, {String category = "SONSTIGES"}) async {
    if (_calDavListPath == null || title.trim().isEmpty) return;
    final tempTask = TodoTask(uid: DateTime.now().millisecondsSinceEpoch.toString(), title: title.trim(), isDone: false, description: category.toUpperCase());
    setState(() { _calDavItems.add(tempTask); _searchController.clear(); });
    WebShoppingCache.saveCalDavList(_selectedAccount!.id, _calDavItems);
    await CalDavService.addTask(_calDavListPath!, title.trim(), description: category.toUpperCase(), account: _selectedAccount);
    _refreshCalDavList();
  }

  void _showAddCalDavItemDialog() {
    List<String> existingCats = _getCalDavGrouped().keys.toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return AddCalDavItemBottomSheet(
          initialName: _searchController.text,
          existingCategories: existingCats,
          onSave: (title, category) {
            _addCalDavItem(title, category: category);
            Navigator.pop(context);
          },
        );
      },
    );
  }

  Future<void> _toggleCalDavItem(TodoTask task) async {
    setState(() => task.isDone = !task.isDone);
    WebShoppingCache.saveCalDavList(_selectedAccount!.id, _calDavItems);
    CalDavService.updateTask(_calDavListPath!, task, account: _selectedAccount).then((success) {
      if (!success) debugPrint("Background sync failed.");
    });
  }

  Future<void> _deleteCalDavItem(TodoTask task) async {
    setState(() => _calDavItems.removeWhere((t) => t.uid == task.uid));
    WebShoppingCache.saveCalDavList(_selectedAccount!.id, _calDavItems);
    CalDavService.deleteTask(_calDavListPath!, task.uid, account: _selectedAccount);
  }

  void _showEditCalDavItemDialog(TodoTask task) {
    final l10n = AppLocalizations.of(context)!;
    final titleCtrl = TextEditingController(text: task.title);
    final catCtrl = TextEditingController(text: task.description ?? "SONSTIGES");
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.editItemTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleCtrl, textCapitalization: TextCapitalization.sentences, decoration: InputDecoration(labelText: l10n.titleLabel)),
            const SizedBox(height: 12),
            TextField(controller: catCtrl, textCapitalization: TextCapitalization.characters, decoration: InputDecoration(labelText: l10n.categoryLabel, helperText: l10n.categoryHelperText)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A73D1), foregroundColor: Colors.white),
            onPressed: () {
              if (titleCtrl.text.trim().isNotEmpty) {
                final updatedTask = TodoTask(
                  uid: task.uid,
                  title: titleCtrl.text.trim(),
                  isDone: task.isDone,
                  description: catCtrl.text.trim().toUpperCase(),
                  dueDate: task.dueDate,
                );
                setState(() {
                  final index = _calDavItems.indexWhere((t) => t.uid == task.uid);
                  if (index != -1) _calDavItems[index] = updatedTask;
                });
                WebShoppingCache.saveCalDavList(_selectedAccount!.id, _calDavItems);
                CalDavService.updateTask(_calDavListPath!, updatedTask, account: _selectedAccount);
                Navigator.pop(context);
              }
            },
            child: Text(l10n.save),
          )
        ],
      ),
    );
  }

  // --- Grocy backend ---

  /// Loads the Grocy shopping list plus supporting master data
  /// (products, groups, units, locations).
  ///
  /// Each fetch can independently fail (return `null`) without
  /// affecting the others - a failed products fetch, say, no longer
  /// wipes out an already-loaded shopping list.
  Future<void> _loadGrocyData() async {
    final cached = await WebShoppingCache.loadGrocyList(_selectedAccount!.id);
    if (mounted && cached.isNotEmpty) setState(() => _groupedItems = cached);

    final results = await Future.wait([
      _grocyService!.fetchGroupedShoppingList(),
      _grocyService!.fetchAllProducts(),
      _grocyService!.fetchFormData(),
    ]);

    if (mounted) {
      final shoppingList = results[0] as Map<String, List<GrocyItem>>?;
      final products = results[1] as List<GrocyProduct>?;
      final formData = results[2] as Map<String, dynamic>?;

      setState(() {
        if (shoppingList != null) {
          _groupedItems = shoppingList;
          WebShoppingCache.saveGrocyList(_selectedAccount!.id, _groupedItems);
        }
        if (products != null) {
          _allProducts = products;
        }
        if (formData != null) {
          _productGroups = formData['groups'];
          _quantityUnits = formData['units'];
          _locations = formData['locations'];
        }
        _isLoading = false;
      });
    }
  }

  /// Refreshes the Grocy-backed shopping list from the server.
  ///
  /// Only replaces [_groupedItems] on an actual result - `null` means
  /// the fetch failed (e.g. offline) and the current list should
  /// simply stay as-is, while `{}` means the list is genuinely empty
  /// and should be shown as such.
  Future<void> _refreshGrocyList() async {
    if (_grocyService == null) return;
    final data = await _grocyService!.fetchGroupedShoppingList();
    if (mounted && data != null) setState(() => _groupedItems = data);
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty) { setState(() => _searchResults = []); return; }
    setState(() { _searchResults = _allProducts.where((p) => p.name.toLowerCase().contains(query)).toList(); });
  }

  Future<void> _toggleGrocyItem(GrocyItem item) async {
    final newStatus = !item.isDone;
    setState(() {
      final targetList = _groupedItems[item.category]!;
      final index = targetList.indexWhere((i) => i.id == item.id);
      if (index != -1) {
        targetList[index] = GrocyItem(id: item.id, productId: item.productId, name: item.name, category: item.category, amount: item.amount, isDone: newStatus);
      }
    });
    WebShoppingCache.saveGrocyList(_selectedAccount!.id, _groupedItems);
    _grocyService!.toggleShoppingListItem(item.id, newStatus).catchError((e) => debugPrint("Error: $e"));
  }

  Future<void> _deleteGrocyItem(GrocyItem item) async {
    setState(() {
      _groupedItems[item.category]?.removeWhere((i) => i.id == item.id);
      _groupedItems.removeWhere((key, value) => value.isEmpty);
    });
    WebShoppingCache.saveGrocyList(_selectedAccount!.id, _groupedItems);
    _grocyService!.removeShoppingListItem(item.id).catchError((e) => debugPrint("Error: $e"));
  }

  Future<void> _addGrocyItemToList(GrocyProduct product) async {
    FocusScope.of(context).unfocus();
    _searchController.clear();
    setState(() { _searchResults = []; _isLoading = true; });
    await _grocyService!.addProductToShoppingList(product.id);
    await _refreshGrocyList();
    setState(() => _isLoading = false);
  }

  Future<GrocyProductGroup?> _handleCreateGroup(String newName) async {
    final newId = await _grocyService!.createProductGroup(newName);
    if (newId != null) {
      final newGroup = GrocyProductGroup(id: newId, name: newName);
      setState(() {
        _productGroups.add(newGroup);
      });
      return newGroup;
    }
    return null;
  }

  void _showAddGrocyProductForm({String initialName = ""}) {
    if (_productGroups.isEmpty || _quantityUnits.isEmpty || _locations.isEmpty) return;
    _searchController.clear();
    setState(() => _searchResults = []);

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (context) {
        return AddProductFormBottomSheet(
          accountId: _selectedAccount!.id,
          initialName: initialName, productGroups: _productGroups, quantityUnits: _quantityUnits, locations: _locations,
          onCreateGroup: _handleCreateGroup,
          onSave: (name, groupId, unitId, locationId) async {
            setState(() => _isLoading = true);
            final newId = await _grocyService!.createProduct(name: name, groupId: groupId, unitId: unitId, locationId: locationId);
            if (newId != null) {
              await _grocyService!.addProductToShoppingList(newId);
              await _loadGrocyData();
            } else {
              setState(() => _isLoading = false);
            }
          },
        );
      },
    );
  }

  void _showEditGrocyProductForm(GrocyItem item) {
    if (_productGroups.isEmpty) return;

    String? currentGroupId;
    try { currentGroupId = _productGroups.firstWhere((g) => g.name == item.category).id; }
    catch (_) { currentGroupId = _productGroups.first.id; }

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (context) {
        return EditGrocyProductBottomSheet(
          initialName: item.name,
          initialGroupId: currentGroupId,
          productGroups: _productGroups,
          onCreateGroup: _handleCreateGroup,
          onSave: (newName, newGroupId) async {
            setState(() => _isLoading = true);
            final success = await _grocyService!.updateProduct(item.productId, newName, newGroupId);
            if (success) {
              await _loadGrocyData();
            } else {
              setState(() => _isLoading = false);
            }
          },
        );
      },
    );
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4A73D1),
        foregroundColor: Colors.white,
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
                _loadWorkspaceConfig();
              }
            },
          ),
        )
            : Text(l10n.shoppingList, style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: _shoppingMode == 'none' ? [] : [
          IconButton(
            icon: Icon(_collapsedCategories.isEmpty ? Icons.unfold_less : Icons.unfold_more, color: Colors.white),
            onPressed: () => setState(() {
              if (_collapsedCategories.isEmpty) {
                _collapsedCategories.addAll(_getCurrentCategories());
              } else {
                _collapsedCategories.clear();
              }
            }),
          ),
          IconButton(
            icon: Icon(_isEditingMode ? Icons.done : Icons.edit, color: Colors.white),
            onPressed: () => setState(() => _isEditingMode = !_isEditingMode),
          ),
          IconButton(
              icon: Icon(_showCompleted ? Icons.visibility : Icons.visibility_off, color: Colors.white),
              onPressed: () => setState(() => _showCompleted = !_showCompleted)
          ),
          IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _shoppingMode == 'grocy' ? _loadGrocyData : _refreshCalDavList
          )
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final l10n = AppLocalizations.of(context)!;
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_shoppingMode == 'none') {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(l10n.noShoppingListActiveTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black54)),
            const SizedBox(height: 8),
            Text(l10n.noShoppingListActiveSubtitle, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              _shoppingMode == 'grocy' ? _buildGrocyList() : _buildCalDavList(),

              if (_shoppingMode == 'grocy' && _searchResults.isNotEmpty)
                Positioned(
                  left: 16, right: 16, bottom: 0,
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 220),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(16)), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, -4))]),
                    child: ListView.builder(
                      shrinkWrap: true, padding: EdgeInsets.zero,
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final selection = _searchResults[index];
                        return ListTile(
                          title: Text(selection.name),
                          onTap: () => _addGrocyItemToList(selection),
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),

        if (_shoppingMode != 'none') _buildStoreProfileBar(),

        Container(
          color: Colors.white,
          padding: EdgeInsets.only(left: 16, right: 16, top: 12, bottom: MediaQuery.of(context).padding.bottom + 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  onChanged: (val) => _shoppingMode == 'grocy' ? _onSearchChanged() : null,
                  onSubmitted: (val) => _shoppingMode == 'caldav' ? _addCalDavItem(val) : null,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: _shoppingMode == 'grocy' ? l10n.searchArticleHint : l10n.addArticleHint,
                    prefixIcon: Icon(_shoppingMode == 'grocy' ? Icons.search : Icons.add_shopping_cart, color: Colors.grey),
                    suffixIcon: _searchController.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear, color: Colors.grey), onPressed: () { _searchController.clear(); setState(() {}); }) : null,
                    filled: true, fillColor: const Color(0xFFF2F2F7),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: const BoxDecoration(color: Color(0xFF4A73D1), shape: BoxShape.circle),
                child: IconButton(
                  icon: const Icon(Icons.add, color: Colors.white),
                  onPressed: () {
                    if (_shoppingMode == 'caldav') {
                      if (_searchController.text.trim().isEmpty) {
                        _showAddCalDavItemDialog();
                      } else {
                        _addCalDavItem(_searchController.text);
                      }
                    } else {
                      _showAddGrocyProductForm(initialName: _searchController.text);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCalDavList() {
    final l10n = AppLocalizations.of(context)!;
    Map<String, List<TodoTask>> grouped = _getCalDavGrouped();
    Map<String, List<TodoTask>> displayItems = {};

    grouped.forEach((category, items) {
      List<TodoTask> filtered = items;
      if (!_showCompleted) filtered = filtered.where((item) => !item.isDone).toList();
      if (_searchController.text.isNotEmpty) filtered = filtered.where((item) => item.title.toLowerCase().contains(_searchController.text.toLowerCase())).toList();
      if (filtered.isNotEmpty) displayItems[category] = filtered;
    });

    if (_activeStoreProfile != 'Standard' && _profileSortOrders.containsKey(_activeStoreProfile)) {
      Map<String, List<TodoTask>> sorted = {};
      for (String cat in _profileSortOrders[_activeStoreProfile]!) {
        String? key = displayItems.keys.where((k) => k.toUpperCase() == cat.toUpperCase()).firstOrNull;
        if (key != null) sorted[key] = displayItems[key]!;
      }
      displayItems.forEach((k, v) { if (!sorted.containsKey(k)) sorted[k] = v; });
      displayItems = sorted;
    }

    if (displayItems.isEmpty) return Center(child: Text(l10n.allBoughtMessage, style: const TextStyle(color: Colors.grey, fontSize: 18)));

    return RefreshIndicator(
      onRefresh: _refreshCalDavList,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: displayItems.length,
        itemBuilder: (context, index) {
          String category = displayItems.keys.elementAt(index);
          List<TodoTask> items = displayItems[category]!;

          return Padding(
            padding: const EdgeInsets.only(bottom: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => setState(() { if (_collapsedCategories.contains(category)) {
                    _collapsedCategories.remove(category);
                  } else {
                    _collapsedCategories.add(category);
                  } }),
                  child: Container(
                    color: Colors.transparent, padding: const EdgeInsets.only(left: 8, bottom: 8, right: 8, top: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(category.toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blue.shade700, letterSpacing: 1.2)),
                            if (_isEditingMode)
                              IconButton(
                                icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
                                onPressed: () => _showEditCategoryDialog(category),
                                padding: const EdgeInsets.only(left: 8),
                                constraints: const BoxConstraints(),
                              ),
                          ],
                        ),
                        Icon(_collapsedCategories.contains(category) ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up, color: Colors.blue.shade700),
                      ],
                    ),
                  ),
                ),
                if (!_collapsedCategories.contains(category))
                  Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      children: items.map((item) {
                        return Column(
                          children: [
                            ListTile(
                              onTap: () => _toggleCalDavItem(item),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              leading: Container(width: 28, height: 28, decoration: BoxDecoration(shape: BoxShape.circle, color: item.isDone ? Colors.green : Colors.transparent, border: Border.all(color: item.isDone ? Colors.green : Colors.grey.shade400, width: 2)), child: item.isDone ? const Icon(Icons.check, size: 18, color: Colors.white) : null),
                              title: Text(item.title, style: TextStyle(fontSize: 18, decoration: item.isDone ? TextDecoration.lineThrough : TextDecoration.none, color: item.isDone ? Colors.grey : Colors.black)),
                              trailing: _isEditingMode ? Row(mainAxisSize: MainAxisSize.min, children: [
                                GestureDetector(onTap: () => _showEditCalDavItemDialog(item), child: const Padding(padding: EdgeInsets.all(8.0), child: Icon(Icons.edit, color: Colors.blue, size: 26))),
                                GestureDetector(onTap: () => _deleteCalDavItem(item), child: Padding(padding: const EdgeInsets.all(8.0), child: Icon(Icons.delete_outline, color: Colors.red, size: 26)))
                              ]) : null,
                            ),
                            if (item != items.last) const Divider(height: 1, indent: 56),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildGrocyList() {
    final l10n = AppLocalizations.of(context)!;
    Map<String, List<GrocyItem>> displayItems = {};
    _groupedItems.forEach((category, items) {
      List<GrocyItem> filtered = items;
      if (!_showCompleted) filtered = filtered.where((item) => !item.isDone).toList();
      if (_searchController.text.isNotEmpty) filtered = filtered.where((item) => item.name.toLowerCase().contains(_searchController.text.toLowerCase())).toList();
      if (filtered.isNotEmpty) displayItems[category] = filtered;
    });

    if (_activeStoreProfile != 'Standard' && _profileSortOrders.containsKey(_activeStoreProfile)) {
      Map<String, List<GrocyItem>> sorted = {};
      for (String cat in _profileSortOrders[_activeStoreProfile]!) {
        String? key = displayItems.keys.where((k) => k.toUpperCase() == cat.toUpperCase()).firstOrNull;
        if (key != null) sorted[key] = displayItems[key]!;
      }
      displayItems.forEach((k, v) { if (!sorted.containsKey(k)) sorted[k] = v; });
      displayItems = sorted;
    }

    if (displayItems.isEmpty) return Center(child: Text(l10n.allBoughtMessage, style: const TextStyle(color: Colors.grey, fontSize: 18)));

    return RefreshIndicator(
      onRefresh: _refreshGrocyList,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: displayItems.length,
        itemBuilder: (context, index) {
          String category = displayItems.keys.elementAt(index);
          List<GrocyItem> items = displayItems[category]!;

          return Padding(
            padding: const EdgeInsets.only(bottom: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => setState(() { if (_collapsedCategories.contains(category)) {
                    _collapsedCategories.remove(category);
                  } else {
                    _collapsedCategories.add(category);
                  } }),
                  child: Container(
                    color: Colors.transparent, padding: const EdgeInsets.only(left: 8, bottom: 8, right: 8, top: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(category.toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blue.shade700, letterSpacing: 1.2)),
                            if (_isEditingMode)
                              IconButton(
                                icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
                                onPressed: () => _showEditCategoryDialog(category),
                                padding: const EdgeInsets.only(left: 8),
                                constraints: const BoxConstraints(),
                              ),
                          ],
                        ),
                        Icon(_collapsedCategories.contains(category) ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up, color: Colors.blue.shade700),
                      ],
                    ),
                  ),
                ),
                if (!_collapsedCategories.contains(category))
                  Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      children: items.map((item) {
                        return Column(
                          children: [
                            ListTile(
                              onTap: () => _toggleGrocyItem(item),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              leading: Container(width: 28, height: 28, decoration: BoxDecoration(shape: BoxShape.circle, color: item.isDone ? Colors.green : Colors.transparent, border: Border.all(color: item.isDone ? Colors.green : Colors.grey.shade400, width: 2)), child: item.isDone ? const Icon(Icons.check, size: 18, color: Colors.white) : null),
                              title: Text(item.name, style: TextStyle(fontSize: 18, decoration: item.isDone ? TextDecoration.lineThrough : TextDecoration.none, color: item.isDone ? Colors.grey : Colors.black)),
                              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                Text("${item.amount.toInt()}x", style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold, fontSize: 16)),
                                if (_isEditingMode) ...[
                                  const SizedBox(width: 8),
                                  GestureDetector(onTap: () => _showEditGrocyProductForm(item), child: const Padding(padding: EdgeInsets.all(8.0), child: Icon(Icons.edit, color: Colors.blue, size: 26))),
                                  GestureDetector(onTap: () => _deleteGrocyItem(item), child: Padding(padding: const EdgeInsets.all(8.0), child: Icon(Icons.delete_outline, color: Colors.red, size: 26)))
                                ]
                              ]),
                            ),
                            if (item != items.last) const Divider(height: 1, indent: 56),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStoreProfileBar() {
    return Container(
      color: Colors.white, width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ..._storeProfiles.map((profile) {
              bool isActive = _activeStoreProfile == profile;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: GestureDetector(
                  // Long-press on a non-default profile chip to delete it.
                  onLongPress: profile == 'Standard' ? null : () => _confirmDeleteProfile(profile),
                  child: ChoiceChip(
                    label: Text(profile, style: TextStyle(color: isActive ? Colors.white : Colors.black87, fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
                    selected: isActive, selectedColor: const Color(0xFF4A73D1), backgroundColor: Colors.grey.shade200, showCheckmark: false,
                    onSelected: (selected) { if (selected) setState(() => _activeStoreProfile = profile); },
                  ),
                ),
              );
            }),
            IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.green), onPressed: () => _showAddProfileDialog()),
            if (_activeStoreProfile != 'Standard')
              IconButton(
                icon: const Icon(Icons.edit_road, color: Colors.blue),
                onPressed: () async {
                  List<String> currentOrder = _profileSortOrders[_activeStoreProfile] ?? [];
                  List<String> fullList = [...currentOrder, ..._getCurrentCategories().where((k) => !currentOrder.contains(k))];
                  final newOrder = await Navigator.push(context, MaterialPageRoute(builder: (context) => ReorderCategoriesScreen(profileName: _activeStoreProfile, categories: fullList)));
                  if (newOrder != null) { setState(() => _profileSortOrders[_activeStoreProfile] = newOrder); _saveStoreProfiles(); }
                },
              ),
          ],
        ),
      ),
    );
  }
}