// Hisaab Kitaab — add / edit a savings goal (v7.4).
//
// Name, target amount, and an optional deadline (a date
// picker; "No deadline" clears it). Editing a goal never
// touches its `saved` amount — money only moves through
// "Add money" (see ExpenseStore.addMoneyToGoal).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/gradient_button.dart';
import '../../../core/styled_date_picker.dart';
import '../../../core/theme.dart';
import '../data/expense_store.dart';
import '../models/savings_goal.dart';
import 'budget_detail_screen.dart' show shortDate;

Future<void> showSavingsGoalSheet(
  BuildContext context, {
  SavingsGoal? goal,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _SavingsGoalSheet(goal: goal),
  );
}

class _SavingsGoalSheet extends StatefulWidget {
  final SavingsGoal? goal;

  const _SavingsGoalSheet({this.goal});

  @override
  State<_SavingsGoalSheet> createState() => _SavingsGoalSheetState();
}

class _SavingsGoalSheetState extends State<_SavingsGoalSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _targetController;
  late DateTime? _deadline;
  String? _error;

  @override
  void initState() {
    super.initState();
    final goal = widget.goal;
    _nameController = TextEditingController(text: goal?.name ?? '');
    _targetController = TextEditingController(
      text: goal == null ? '' : goal.target.toStringAsFixed(0),
    );
    _deadline = goal?.deadline;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final store = context.read<ExpenseStore>();
    final strings = store.strings;
    final name = _nameController.text.trim();
    final target = double.tryParse(_targetController.text.trim());
    if (name.isEmpty) {
      setState(() => _error = strings.enterGoalName);
      return;
    }
    if (target == null || target <= 0) {
      setState(() => _error = strings.enterValidAmount);
      return;
    }
    final goal = widget.goal;
    if (goal == null) {
      await store.addSavingsGoal(
        SavingsGoal(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: name,
          target: target,
          deadline: _deadline,
          createdAt: DateTime.now(),
        ),
      );
    } else {
      await store.updateSavingsGoal(
        goal.copyWith(
          name: name,
          target: target,
          deadline: _deadline,
          clearDeadline: _deadline == null,
        ),
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ExpenseStore>();
    final strings = store.strings;

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
              widget.goal == null ? strings.addGoal : strings.editGoal,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: strings.goalName,
                hintText: strings.goalNameHint,
              ),
              textCapitalization: TextCapitalization.words,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _targetController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: strings.targetAmount,
                prefixText: store.currencyPrefix,
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showStyledDatePicker(
                    context: context,
                    initialDate: _deadline ?? DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() => _deadline = picked);
                  }
                },
                icon: const Icon(Icons.calendar_today, size: 20),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _deadline == null
                        ? '${strings.deadline}: ${strings.noDeadline}'
                        : '${strings.deadline}: '
                            '${shortDate(store, _deadline!)}',
                    maxLines: 1,
                  ),
                ),
              ),
            ),
            if (_deadline != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => setState(() => _deadline = null),
                  child: Text(strings.noDeadline),
                ),
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
