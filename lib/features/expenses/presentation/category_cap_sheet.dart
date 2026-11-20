// Hisaab Kitaab — set / edit a per-category monthly cap (v7.6).
//
// A bottom sheet in the savings-goal sheet's style: one amount
// field with the currency prefix, Save, and — when a cap
// already exists — a Remove cap button. The cap lives on one
// (budget, category) pair; setting it to 0 removes it.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/gradient_button.dart';
import '../../../core/theme.dart';
import '../data/expense_store.dart';
import '../models/category_cap.dart';

Future<void> showCategoryCapSheet(
  BuildContext context, {
  required String budgetId,
  required String category,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) =>
        _CategoryCapSheet(budgetId: budgetId, category: category),
  );
}

class _CategoryCapSheet extends StatefulWidget {
  final String budgetId;
  final String category;

  const _CategoryCapSheet({
    required this.budgetId,
    required this.category,
  });

  @override
  State<_CategoryCapSheet> createState() => _CategoryCapSheetState();
}

class _CategoryCapSheetState extends State<_CategoryCapSheet> {
  late final TextEditingController _amountController;
  String? _error;

  @override
  void initState() {
    super.initState();
    final store = context.read<ExpenseStore>();
    final existing =
        store.capFor(widget.budgetId, widget.category);
    _amountController = TextEditingController(
      text: existing == null ? '' : existing.amount.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final store = context.read<ExpenseStore>();
    final strings = store.strings;
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = strings.enterValidAmount);
      return;
    }
    await store.setCategoryCap(
      CategoryCap(
        category: widget.category,
        amount: amount,
        budgetId: widget.budgetId,
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ExpenseStore>();
    final strings = store.strings;
    final existing =
        store.capFor(widget.budgetId, widget.category);

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
              '${strings.monthlyCap} — '
              '${strings.categoryName(widget.category)}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: strings.monthlyCap,
                prefixText: store.currencyPrefix,
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(
                  color: CashWiseTheme.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 24),
            GradientButton(
              label: strings.save,
              onPressed: _save,
            ),
            if (existing != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  await store.removeCategoryCap(
                    widget.budgetId,
                    widget.category,
                  );
                  if (mounted) navigator.pop();
                },
                child: Text(
                  strings.removeCap,
                  style: const TextStyle(color: CashWiseTheme.danger),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
