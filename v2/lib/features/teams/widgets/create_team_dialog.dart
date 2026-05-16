import 'package:flutter/material.dart';
import 'package:viro_team_v2/config/viro_colors.dart';
import 'package:viro_team_v2/config/viro_spacing.dart';
import 'package:viro_team_v2/utils/team_categories.dart';

Future<({String name, String category})?> showCreateTeamDialog({
  required BuildContext context,
  required String sport,
}) {
  return showDialog<({String name, String category})>(
    context: context,
    builder: (ctx) => _CreateTeamDialog(sport: sport),
  );
}

class _CreateTeamDialog extends StatefulWidget {
  const _CreateTeamDialog({required this.sport});

  final String sport;

  @override
  State<_CreateTeamDialog> createState() => _CreateTeamDialogState();
}

class _CreateTeamDialogState extends State<_CreateTeamDialog> {
  final _nameController = TextEditingController();
  late String _category;
  late final List<String> _categories;

  @override
  void initState() {
    super.initState();
    _categories = teamCategoriesForSport(widget.sport);
    _category = _categories.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Nouvelle équipe'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Nom de l\'équipe',
              hintText: 'ex : Équipe A',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: ViroSpacing.md),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: InputDecoration(
              labelText: 'Catégorie',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            items: _categories
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _category = v);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Annuler',
            style: TextStyle(color: ViroColors.gray600),
          ),
        ),
        FilledButton(
          onPressed: () {
            final name = _nameController.text.trim();
            if (name.isEmpty) return;
            Navigator.pop(context, (name: name, category: _category));
          },
          child: const Text('Créer'),
        ),
      ],
    );
  }
}
