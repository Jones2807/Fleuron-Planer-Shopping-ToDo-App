import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import '../services/caldav_service.dart';
import '../services/group_colors.dart';
import '../l10n/app_localizations.dart';

/// Screen for managing colors of group calendars.
///
/// These groups are generated dynamically whenever a calendar is
/// shared by more than one person (e.g. "Person A, Person B").
class GroupColorScreen extends StatefulWidget {
  final VoidCallback onColorsChanged;

  const GroupColorScreen({super.key, required this.onColorsChanged});

  @override
  State<GroupColorScreen> createState() => _GroupColorScreenState();
}

class _GroupColorScreenState extends State<GroupColorScreen> {
  void _pickGroupColor(String groupKey, Color currentColor) {
    final l10n = AppLocalizations.of(context)!;
    Color tempColor = currentColor;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.colorForGroupTitle(groupKey.replaceAll(',', ' + '))),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: tempColor,
            onColorChanged: (color) => tempColor = color,
            pickerAreaHeightPercent: 0.7,
            enableAlpha: false,
            hexInputBar: true,
            labelTypes: const [],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
          ElevatedButton(
            onPressed: () async {
              await GroupColors.saveColor(groupKey, tempColor);
              setState(() {});
              widget.onColorsChanged();
              Navigator.pop(context);
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final groups = CalDavService.activeGroups;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.groupColorsTitle),
        backgroundColor: const Color(0xFF4A73D1),
        foregroundColor: Colors.white,
      ),
      body: groups.isEmpty
          ? Center(child: Text(l10n.noGroupCalendarsFound, textAlign: TextAlign.center))
          : ListView.builder(
        itemCount: groups.length,
        itemBuilder: (context, index) {
          final groupKey = groups[index];
          final currentColor = GroupColors.getColor(groupKey);

          return ListTile(
            leading: CircleAvatar(
              backgroundColor: currentColor,
              child: const Icon(Icons.group, color: Colors.white),
            ),
            title: Text(groupKey.replaceAll(',', ' & '), style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(l10n.tapToChangeColor),
            trailing: const Icon(Icons.palette_outlined, color: Colors.grey),
            onTap: () => _pickGroupColor(groupKey, currentColor),
          );
        },
      ),
    );
  }
}