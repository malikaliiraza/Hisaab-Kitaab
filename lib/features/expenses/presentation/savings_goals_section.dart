// Hisaab Kitaab — Savings goals on the Home page (v7.4).
//
// The section reuses the Budget card UI: a prominent Card per
// goal — name, a progress ring (saved / target), aligned
// AmountRow lines, and an "Add money" button. "Add money"
// records the movement as a "Savings: <name>" expense against
// the active budget (see ExpenseStore.addMoneyToGoal), so the
// money really leaves the spendable budget.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/amount_row.dart';
import '../../../core/confirm_dialog.dart';
import '../../../core/gradient_button.dart';
import '../../../core/theme.dart';
import '../data/expense_store.dart';
import '../models/savings_goal.dart';
import 'budget_detail_screen.dart' show shortDate;
import 'savings_goal_sheet.dart';

class SavingsGoalsSection extends StatelessWidget {
  const SavingsGoalsSection({super.key});

  Future<void> _addMoney(
    BuildContext context,
    ExpenseStore store,
    SavingsGoal goal,
  ) async {
    final strings = store.strings;
    final controller = TextEditingController();
    String? error;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(strings.addMoney),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    goal.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: strings.amountLabel,
                      prefixText: store.currencyPrefix,
                    ),
                    onChanged: (_) {
                      if (error != null) {
                        setDialogState(() => error = null);
                      }
                    },
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      error!,
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
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(strings.cancel),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final amount =
                        double.tryParse(controller.text.trim());
                    if (amount == null || amount <= 0) {
                      setDialogState(
                        () => error = strings.enterValidAmount,
                      );
                      return;
                    }
                    if (!store.hasBudget) {
                      setDialogState(
                        () => error = strings.goalNeedsBudget,
                      );
                      return;
                    }
                    await store.addMoneyToGoal(
                      goalId: goal.id,
                      amount: amount,
                    );
                    if (context.mounted) {
                      Navigator.of(context).pop(true);
                    }
                  },
                  child: Text(strings.save),
                ),
              ],
            );
          },
        );
      },
    );
    controller.dispose();
    if (saved == true && context.mounted) {
      // The card updates itself through the store listener.
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ExpenseStore>();
    final strings = store.strings;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                strings.savingsGoals,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () => showSavingsGoalSheet(context),
              icon: const Icon(Icons.add, size: 20),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  strings.addGoal,
                  maxLines: 1,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (store.savingsGoals.isEmpty)
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                strings.noGoals,
                style: TextStyle(
                  color: CashWiseTheme.secondaryTextFor(context),
                ),
              ),
            ),
          )
        else
          for (final goal in store.savingsGoals)
            _GoalCard(
              goal: goal,
              onAddMoney: () => _addMoney(context, store, goal),
            ),
      ],
    );
  }
}

class _GoalCard extends StatelessWidget {
  final SavingsGoal goal;
  final VoidCallback onAddMoney;

  const _GoalCard({required this.goal, required this.onAddMoney});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ExpenseStore>();
    final strings = store.strings;
    final percent = (goal.progress * 100).round();
    final remaining = (goal.target - goal.saved).clamp(0.0, double.infinity);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Progress ring (v7.4): saved / target, with the
                // percent in the middle — the same visual language
                // as the budget progress bar, in a ring.
                SizedBox(
                  width: 64,
                  height: 64,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 64,
                        height: 64,
                        child: CircularProgressIndicator(
                          value: goal.progress,
                          strokeWidth: 6,
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(
                            goal.isReached
                                ? CashWiseTheme.success
                                : CashWiseTheme.lightAccent,
                          ),
                        ),
                      ),
                      Text(
                        '$percent%',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        goal.deadline == null
                            ? strings.noDeadline
                            : shortDate(store, goal.deadline!),
                        style: TextStyle(
                          fontSize: 13,
                          color: CashWiseTheme.secondaryTextFor(context),
                        ),
                      ),
                      if (goal.isReached) ...[
                        const SizedBox(height: 4),
                        Text(
                          strings.goalReached,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: CashWiseTheme.success,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  tooltip: strings.editGoal,
                  onPressed: () =>
                      showSavingsGoalSheet(context, goal: goal),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: CashWiseTheme.danger,
                  ),
                  tooltip: strings.delete,
                  onPressed: () async {
                    final confirmed = await confirmDelete(
                      context,
                      strings,
                      strings.deleteGoalConfirm,
                    );
                    if (confirmed) {
                      await store.removeSavingsGoal(goal.id);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            AmountRow(
              label: strings.savedAmount,
              amount: store.formatAmount(goal.saved),
            ),
            AmountRow(
              label: strings.targetAmount,
              amount: store.formatAmount(goal.target),
            ),
            AmountRow(
              label: strings.remaining,
              amount: store.formatAmount(remaining),
            ),
            const SizedBox(height: 12),
            GradientButton(
              label: strings.addMoney,
              onPressed: onAddMoney,
            ),
          ],
        ),
      ),
    );
  }
}
