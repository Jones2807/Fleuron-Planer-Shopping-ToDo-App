import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/grocy_models.dart';
import '../l10n/app_localizations.dart';

/// Bottom sheet to add a new CalDAV/VTODO-backed shopping-list item,
/// with an inline "create new category" shortcut.
class AddCalDavItemBottomSheet extends StatefulWidget {
  final String initialName;
  final List<String> existingCategories;
  final Function(String title, String category) onSave;

  const AddCalDavItemBottomSheet({super.key, required this.initialName, required this.existingCategories, required this.onSave});

  @override
  State<AddCalDavItemBottomSheet> createState() => _AddCalDavItemBottomSheetState();
}

class _AddCalDavItemBottomSheetState extends State<AddCalDavItemBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late List<String> _categories;
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialName);
    _categories = List.from(widget.existingCategories);
    if (!_categories.contains("SONSTIGES")) _categories.add("SONSTIGES");
    _selectedCategory = "SONSTIGES";
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _showAddCategoryDialog() {
    final l10n = AppLocalizations.of(context)!;
    final ctrl = TextEditingController();
    showDialog(
        context: context,
        builder: (c) => AlertDialog(
            title: Text(l10n.newCategoryTitle),
            content: TextField(controller: ctrl, autofocus: true, textCapitalization: TextCapitalization.words, decoration: InputDecoration(hintText: l10n.newCategoryHint)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c), child: Text(l10n.cancel)),
              ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A73D1), foregroundColor: Colors.white),
                  onPressed: () {
                    final newCat = ctrl.text.trim().toUpperCase();
                    if (newCat.isNotEmpty) {
                      setState(() {
                        if (!_categories.contains(newCat)) _categories.add(newCat);
                        _selectedCategory = newCat;
                      });
                      Navigator.pop(c);
                    }
                  },
                  child: Text(l10n.create)
              )
            ]
        )
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, bottomInset + 24),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.newItemTitle, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            TextFormField(
                controller: _titleController,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: l10n.whatDoYouNeedLabel, prefixIcon: const Icon(Icons.shopping_bag_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                validator: (val) => (val == null || val.trim().isEmpty) ? l10n.pleaseEnterNameValidator : null
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                      initialValue: _selectedCategory,
                      decoration: InputDecoration(labelText: l10n.categoryPlainLabel, prefixIcon: const Icon(Icons.category_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                      items: _categories.map((c) => DropdownMenuItem<String>(value: c, child: Text(c))).toList(),
                      onChanged: (val) => setState(() => _selectedCategory = val),
                      validator: (val) => val == null ? l10n.pleaseSelectValidator : null
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.green, size: 32),
                  tooltip: l10n.newCategoryTooltip,
                  onPressed: _showAddCategoryDialog,
                )
              ],
            ),

            const SizedBox(height: 32),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A73D1), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  widget.onSave(_titleController.text.trim(), _selectedCategory!);
                }
              },
              child: Text(l10n.addButtonLabel, style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet to create a brand-new Grocy product and add it to
/// the shopping list in one step, using the workspace's configured
/// default unit/location for anything not asked here.
class AddProductFormBottomSheet extends StatefulWidget {
  final String accountId;
  final String initialName;
  final List<GrocyProductGroup> productGroups;
  final List<GrocyQuantityUnit> quantityUnits;
  final List<GrocyLocation> locations;
  final Future<GrocyProductGroup?> Function(String) onCreateGroup;
  final Function(String name, String groupId, String unitId, String locationId) onSave;

  const AddProductFormBottomSheet({super.key, required this.accountId, required this.initialName, required this.onSave, required this.productGroups, required this.quantityUnits, required this.locations, required this.onCreateGroup});
  @override
  State<AddProductFormBottomSheet> createState() => _AddProductFormBottomSheetState();
}

class _AddProductFormBottomSheetState extends State<AddProductFormBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  String? _selectedGroupId;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    if (widget.productGroups.isNotEmpty) _selectedGroupId = widget.productGroups.first.id;
  }
  @override
  void dispose() { _nameController.dispose(); super.dispose(); }

  void _showAddCategoryDialog() {
    final l10n = AppLocalizations.of(context)!;
    final ctrl = TextEditingController();
    showDialog(
        context: context,
        builder: (c) => AlertDialog(
            title: Text(l10n.newCategoryTitle),
            content: TextField(controller: ctrl, autofocus: true, textCapitalization: TextCapitalization.words, decoration: InputDecoration(hintText: l10n.newCategoryHint)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c), child: Text(l10n.cancel)),
              ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A73D1), foregroundColor: Colors.white),
                  onPressed: () async {
                    if (ctrl.text.trim().isNotEmpty) {
                      Navigator.pop(c);
                      final newGroup = await widget.onCreateGroup(ctrl.text.trim());
                      if (newGroup != null) setState(() => _selectedGroupId = newGroup.id);
                    }
                  },
                  child: Text(l10n.create)
              )
            ]
        )
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, bottomInset + 24),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.newItemTitle, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            TextFormField(controller: _nameController, autofocus: true, textCapitalization: TextCapitalization.sentences, decoration: InputDecoration(labelText: l10n.whatDoYouNeedLabel, prefixIcon: const Icon(Icons.shopping_bag_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), validator: (val) => (val == null || val.trim().isEmpty) ? l10n.pleaseEnterNameValidator : null),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                      initialValue: _selectedGroupId,
                      decoration: InputDecoration(labelText: l10n.categoryPlainLabel, prefixIcon: const Icon(Icons.category_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                      items: widget.productGroups.map((g) => DropdownMenuItem<String>(value: g.id, child: Text(g.name))).toList(),
                      onChanged: (val) => setState(() => _selectedGroupId = val), validator: (val) => val == null ? l10n.pleaseSelectValidator : null
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.green, size: 32),
                  tooltip: l10n.newCategoryTooltip,
                  onPressed: _showAddCategoryDialog,
                )
              ],
            ),

            const SizedBox(height: 32),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A73D1), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  final prefs = await SharedPreferences.getInstance();
                  final defaultUnit = prefs.getString('grocy_default_unit_${widget.accountId}') ?? widget.quantityUnits.first.id;
                  final defaultLocation = prefs.getString('grocy_default_location_${widget.accountId}') ?? widget.locations.first.id;

                  widget.onSave(_nameController.text.trim(), _selectedGroupId!, defaultUnit, defaultLocation);
                  if (mounted) Navigator.pop(context);
                }
              },
              child: Text(l10n.addButtonLabel, style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet to edit an existing Grocy product's master data
/// (name/category) - affects the product everywhere in the Grocy
/// inventory, not just this shopping list.
class EditGrocyProductBottomSheet extends StatefulWidget {
  final String initialName;
  final String? initialGroupId;
  final List<GrocyProductGroup> productGroups;
  final Future<GrocyProductGroup?> Function(String) onCreateGroup;
  final Function(String name, String groupId) onSave;

  const EditGrocyProductBottomSheet({super.key, required this.initialName, required this.initialGroupId, required this.productGroups, required this.onCreateGroup, required this.onSave});
  @override
  State<EditGrocyProductBottomSheet> createState() => _EditGrocyProductBottomSheetState();
}

class _EditGrocyProductBottomSheetState extends State<EditGrocyProductBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  String? _selectedGroupId;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _selectedGroupId = widget.initialGroupId;
  }
  @override
  void dispose() { _nameController.dispose(); super.dispose(); }

  void _showAddCategoryDialog() {
    final l10n = AppLocalizations.of(context)!;
    final ctrl = TextEditingController();
    showDialog(
        context: context,
        builder: (c) => AlertDialog(
            title: Text(l10n.newCategoryTitle),
            content: TextField(controller: ctrl, autofocus: true, textCapitalization: TextCapitalization.words),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c), child: Text(l10n.cancel)),
              ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A73D1), foregroundColor: Colors.white),
                  onPressed: () async {
                    if (ctrl.text.trim().isNotEmpty) {
                      Navigator.pop(c);
                      final newGroup = await widget.onCreateGroup(ctrl.text.trim());
                      if (newGroup != null) setState(() => _selectedGroupId = newGroup.id);
                    }
                  },
                  child: Text(l10n.create)
              )
            ]
        )
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, bottomInset + 24),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.editMasterDataTitle, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text(l10n.editMasterDataWarning, style: const TextStyle(fontSize: 12, color: Colors.orange)),
            const SizedBox(height: 16),
            TextFormField(controller: _nameController, autofocus: true, textCapitalization: TextCapitalization.sentences, decoration: InputDecoration(labelText: l10n.titleLabel, prefixIcon: const Icon(Icons.shopping_bag_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), validator: (val) => (val == null || val.trim().isEmpty) ? l10n.pleaseEnterNameValidator : null),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                      initialValue: _selectedGroupId,
                      decoration: InputDecoration(labelText: l10n.categoryPlainLabel, prefixIcon: const Icon(Icons.category_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                      items: widget.productGroups.map((g) => DropdownMenuItem<String>(value: g.id, child: Text(g.name))).toList(),
                      onChanged: (val) => setState(() => _selectedGroupId = val), validator: (val) => val == null ? l10n.pleaseSelectValidator : null
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.green, size: 32),
                  tooltip: l10n.newCategoryTooltip,
                  onPressed: _showAddCategoryDialog,
                )
              ],
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A73D1), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  widget.onSave(_nameController.text.trim(), _selectedGroupId!);
                  if (mounted) Navigator.pop(context);
                }
              },
              child: Text(l10n.save, style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lets the user drag-and-drop reorder shopping-list categories for
/// a single store profile, producing the sort order used to render
/// the list when that profile is active.
class ReorderCategoriesScreen extends StatefulWidget {
  final String profileName;
  final List<String> categories;
  const ReorderCategoriesScreen({super.key, required this.profileName, required this.categories});
  @override
  State<ReorderCategoriesScreen> createState() => _ReorderCategoriesScreenState();
}
class _ReorderCategoriesScreenState extends State<ReorderCategoriesScreen> {
  late List<String> _currentOrder;
  @override
  void initState() { super.initState(); _currentOrder = List.from(widget.categories); }
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0, leading: IconButton(icon: const Icon(Icons.close, color: Colors.black), onPressed: () => Navigator.pop(context)), title: Text(l10n.routeTitle(widget.profileName), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)), actions: [IconButton(icon: const Icon(Icons.check, color: Colors.green, size: 28), onPressed: () => Navigator.pop(context, _currentOrder))]),
      body: Column(
        children: [
          Padding(padding: const EdgeInsets.all(16.0), child: Text(l10n.reorderCategoriesInstructions, style: const TextStyle(color: Colors.grey))),
          Expanded(child: ReorderableListView.builder(padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: _currentOrder.length, onReorder: (int o, int n) { setState(() { if (o < n) n -= 1; final item = _currentOrder.removeAt(o); _currentOrder.insert(n, item); }); }, itemBuilder: (context, index) {
            final category = _currentOrder[index];
            return Card(key: ValueKey(category), elevation: 2, margin: const EdgeInsets.only(bottom: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), title: Text(category.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)), trailing: const Icon(Icons.drag_handle, color: Colors.grey)));
          })),
        ],
      ),
    );
  }
}