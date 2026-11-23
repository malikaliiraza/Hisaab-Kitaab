// Hisaab Kitaab — manage expense categories (v7.9).
//
// A bottom sheet in the category-cap sheet's style: add a
// custom category, see the built-in categories (not
// editable), and rename or delete your own. A category in
// use by an expense or a recurring rule cannot be deleted
// until nothing uses it any more — the sheet says so instead
// of deleting it.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/gradient_button.dart';
import '../../../core/theme.dart';
import '../data/expense_store.dart';
import '../models/expense.dart';

Future<void> showManageCategoriesSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _ManageCategoriesSheet(),
  );
}

class _ManageCategoriesSheet extends StatefulWidget {
  const _ManageCategoriesSheet();

  @override
  State<_ManageCategoriesSheet> createState() =>
      _ManageCategoriesSheetState();
}

class _ManageCategoriesSheetState extends State<_ManageCategoriesSheet> {
  final _nameController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final store = context.read<ExpenseStore>();
    final strings = store.strings;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = strings.enterCategoryName);
      return;
    }
    final added = await store.addCustomCategory(name);
    if (!added) {
      setState(() => _error = strings.categoryAlreadyExists);
      return;
    }
    _nameController.clear();
    setState(() => _error = null);
  }

  Future<void> _rename(String oldName) async {
    final store = context.read<ExpenseStore>();
    final strings = store.strings;
    final controller = TextEditingController(text: oldName);
    String? dialogError;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(strings.renameCategory),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const Key('renameCategoryField'),
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: strings.newCategoryHint,
                ),
                onChanged: (_) {
                  if (dialogError != null) {
                    setDialogState(() => dialogError = null);
                  }
                },
              ),
              if (dialogError != null) ...[
                const SizedBox(height: 12),
                Text(
                  dialogError!,
                  style: const TextStyle(
                    color: CashWiseTheme.danger,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(strings.cancel),
            ),
            TextButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isEmpty) {
                  setDialogState(
                      () => dialogError = strings.enterCategoryName);
                  return;
                }
                final ok = await store.renameCustomCategory(
                  oldName,
                  name,
                );
                if (!ok) {
                  setDialogState(() =>
                      dialogError = strings.categoryAlreadyExists);
                  return;
                }
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(true);
                }
              },
              child: Text(strings.save),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (saved == true && mounted) setState(() => _error = null);
  }

  Future<void> _delete(String name) async {
    final store = context.read<ExpenseStore>();
    final strings = store.strings;
    final deleted = await store.deleteCustomCategory(name);
    if (!mounted) return;
    if (!deleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.categoryInUse)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ExpenseStore>();
    final strings = store.strings;
    final customs = store.customCategories;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              strings.manageCategories,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('newCategoryField'),
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: strings.addCategory,
                      hintText: strings.newCategoryHint,
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) {
                      if (_error != null) {
                        setState(() => _error = null);
                      }
                    },
                    onSubmitted: (_) => _add(),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 120,
                  child: GradientButton(
                    label: strings.addCategory,
                    onPressed: _add,
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(
                  color: CashWiseTheme.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 20),
            Text(
              strings.builtInCategories,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            ...expenseCategories.map(
              (c) => ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(strings.categoryName(c)),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              strings.yourCategories,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            if (customs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  strings.noCustomCategories,
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? CashWiseTheme.darkSecondaryText
                        : CashWiseTheme.secondaryText,
                  ),
                ),
              )
            else
              ...customs.map(
                (c) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(c),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        tooltip: strings.renameCategory,
                        onPressed: () => _rename(c),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 20),
                        tooltip: strings.deleteCategory,
                        onPressed: () => _delete(c),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
