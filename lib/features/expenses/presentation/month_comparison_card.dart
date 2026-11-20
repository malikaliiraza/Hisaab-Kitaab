// Hisaab Kitaab — month-over-month comparison card (v7.6).
//
// This month vs last month, from the scoped (per-budget)
// expenses the caller passes in: both totals, the difference
// with its % change, and the category that rose the most.
// Shown on the Statistics / Summary page, under the trend
// chart.

import 'package:flutter/material.dart';

import '../../../core/amount_row.dart';
import '../../../core/theme.dart';
import '../data/expense_store.dart';
import '../data/monthly_trend.dart';
import '../models/expense.dart';

class MonthComparisonCard extends StatelessWidget {
  final ExpenseStore store;

  /// The expenses to compare (scoped per budget by the caller).
  final List<Expense> expenses;

  const MonthComparisonCard({
    super.key,
    required this.store,
    required this.expenses,
  });

  @override
  Widget build(BuildContext context) {
    final strings = store.strings;
    final comparison = compareWithLastMonth(expenses);

    // The change line: "Rs. 2,000 more than last month
    // (+25%)", or the matching no-base / no-change text.
    String changeText() {
      if (comparison.thisMonth == 0 && comparison.lastMonth == 0) {
        return strings.noExpenses;
      }
      if (comparison.lastMonth <= 0) {
        return strings.noSpendingLastMonth;
      }
      final percent = comparison.percentChange!;
      final sign = percent >= 0 ? '+' : '';
      final percentText = '$sign${percent.round()}';
      final amount = store.formatAmount(
        comparison.difference.abs(),
      );
      if (comparison.difference == 0) return strings.sameAsLastMonth;
      if (comparison.difference > 0) {
        return strings.moreThanLastMonth(amount, percentText);
      }
      return strings.lessThanLastMonth(amount, percentText);
    }

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.monthComparison,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            AmountRow(
              label: strings.thisMonth,
              amount: store.formatAmount(comparison.thisMonth),
            ),
            AmountRow(
              label: strings.lastMonth,
              amount: store.formatAmount(comparison.lastMonth),
            ),
            const SizedBox(height: 8),
            Text(
              changeText(),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: comparison.difference > 0
                    ? CashWiseTheme.danger
                    : CashWiseTheme.accentFor(context),
              ),
            ),
            const SizedBox(height: 8),
            if (comparison.biggestIncreaseCategory != null)
              AmountRow(
                label: strings.biggestIncrease,
                amount:
                    '${strings.categoryName(comparison.biggestIncreaseCategory!)} — '
                    '${store.formatAmount(comparison.biggestIncreaseAmount)}',
              )
            else
              Text(
                strings.noIncrease,
                style: TextStyle(
                  color: CashWiseTheme.secondaryTextFor(context),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
