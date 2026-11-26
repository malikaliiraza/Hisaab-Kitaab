// Hisaab Kitaab — add / edit a recurring expense (v7.4).
//
// A bottom sheet reusing the Add Expense form: title, amount
// (with the Rs. / روپے prefix), category chips, then the
// day-of-month the rule posts on and the budget it posts
// into. One rule posts one expense per month, on its day,
// once per cycle only (see ExpenseStore.postDueRecurring).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/gradient_button.dart';
import '../../../core/theme.dart';
import '../data/expense_store.dart';
import '../models/expense.dart';
import '../models/recurring_rule.dart';

Future<void> showRecurringRuleSheet(
  BuildContext context, {
  RecurringRule? rule,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _RecurringRuleSheet(rule: rule),
  );
}

class _RecurringRuleSheet extends StatefulWidget {
  final RecurringRule? rule;

  const _RecurringRuleSheet({this.rule});

  @override
  State<_RecurringRuleSheet> createState() => _RecurringRuleSheetState();
}

class _RecurringRuleSheetState extends State<_RecurringRuleSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late String _category;
  late int _dayOfMonth;
  late String _budgetId;
  late bool _paused;
  String? _error;

  @override
  void initState() {
    super.initState();
    final rule = widget.rule;
    _titleController = TextEditingController(text: rule?.title ?? '');
    _amountController = TextEditingController(
      text: rule == null ? '' : rule.amountPkr.toStringAsFixed(0),
    );
    _category = rule?.category ?? expenseCategories.first;
    _dayOfMonth = rule?.dayOfMonth ?? 1;
    _budgetId = rule?.budgetId ?? '';
    _paused = rule?.paused ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final store = context.read<ExpenseStore>();
    final strings = store.strings;
    final amount = double.tryParse(_amountController.text.trim());
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _error = strings.enterTitleValidAmount);
      return;
    }
    if (amount == null || amount <= 0) {
      setState(() => _error = strings.enterValidAmount);
      return;
    }
    final budgetId =
        _budgetId.isEmpty ? store.activeBudgetId : _budgetId;
    final rule = widget.rule;
    if (rule == null) {
      await store.addRecurringRule(
        RecurringRule(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: title,
          amountPkr: amount,
          category: _category,
          budgetId: budgetId,
          dayOfMonth: _dayOfMonth,
          createdAt: DateTime.now(),
        ),
      );
    } else {
      // Editing the day or amount never re-posts this month:
      // lastPostedMonth is carried over untouched.
      await store.updateRecurringRule(
        rule.copyWith(
          title: title,
          amountPkr: amount,
          category: _category,
          budgetId: budgetId,
          dayOfMonth: _dayOfMonth,
          paused: _paused,
        ),
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ExpenseStore>();
    final strings = store.strings;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondary = isDark
        ? CashWiseTheme.darkSecondaryText
        : CashWiseTheme.secondaryText;
    if (_budgetId.isEmpty) _budgetId = store.activeBudgetId;
    final budgets = store.budgets;

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
              widget.rule == null
                  ? strings.addRecurring
                  : strings.editRecurring,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: strings.recurringName,
                hintText: strings.whatDidYouSpend,
              ),
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: strings.amountLabel,
                prefixText: store.currencyPrefix,
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            const SizedBox(height: 20),
            Text(
              strings.category,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: store.allCategories
                  .map(
                    (c) => ChoiceChip(
                      label: Text(strings.categoryName(c)),
                      selected: _category == c,
                      onSelected: (_) =>
                          setState(() => _category = c),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _dayOfMonth,
                    decoration: InputDecoration(
                      labelText: strings.dayOfMonth,
                    ),
                    items: List.generate(
                      31,
                      (i) => DropdownMenuItem(
                        value: i + 1,
                        child: Text('${i + 1}'),
                      ),
                    ),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _dayOfMonth = value);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    strings.recurringDayLabel(_dayOfMonth),
                    style: TextStyle(color: secondary),
                  ),
                ),
              ],
            ),
            if (budgets.length > 1) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: budgets.any((b) => b.id == _budgetId)
                    ? _budgetId
                    : budgets.first.id,
                decoration: InputDecoration(
                  labelText: strings.budget,
                ),
                items: budgets
                    .map(
                      (b) => DropdownMenuItem(
                        value: b.id,
                        child: Text(
                          store.budgetDisplayName(b),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _budgetId = value);
                },
              ),
            ],
            // Pause a rule from its edit sheet (v7.10) — a
            // paused rule never posts until it is resumed.
            // New rules always start unpaused.
            if (widget.rule != null) ...[
              const SizedBox(height: 8),
              SwitchListTile(
                title: Text(strings.paused),
                value: _paused,
                onChanged: (value) =>
                    setState(() => _paused = value),
                contentPadding: EdgeInsets.zero,
              ),
            ],
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
          ],
        ),
      ),
    );
  }
}
