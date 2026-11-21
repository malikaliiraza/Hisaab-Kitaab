// Hisaab Kitaab — yearly overview card (v7.7).
//
// This calendar year at a glance, from the scoped
// (per-budget) expenses the caller passes in: the year's
// total, the average across months that had spending, and
// the highest- and lowest-spend months. Shown on the
// Statistics / Summary page, under the month-over-month
// comparison card.

import 'package:flutter/material.dart';

import '../../../core/amount_row.dart';
import '../../../core/theme.dart';
import '../data/expense_store.dart';
import '../data/monthly_trend.dart';
import '../data/yearly_overview.dart';
import '../models/expense.dart';

class YearlyOverviewCard extends StatelessWidget {
  final ExpenseStore store;

  /// The expenses to summarise (scoped per budget by the caller).
  final List<Expense> expenses;

  const YearlyOverviewCard({
    super.key,
    required this.store,
    required this.expenses,
  });

  @override
  Widget build(BuildContext context) {
    final strings = store.strings;
    final isUrdu = store.locale.code == 'ur';
    final overview = yearlyOverview(expenses);

    // "Highest month — Mar": the month name in the current
    // language, so the row reads naturally in Urdu too.
    String monthRowLabel(String label, MonthlyTotal month) =>
        '$label — ${shortMonthLabel(month.month, urdu: isUrdu)}';

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.yearlyOverview,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (overview.total == 0)
              Text(
                strings.noSpendingThisYear,
                style: TextStyle(
                  color: CashWiseTheme.secondaryTextFor(context),
                ),
              )
            else ...[
              AmountRow(
                label: strings.yearTotal,
                amount: store.formatAmount(overview.total),
              ),
              AmountRow(
                label: strings.averagePerMonth,
                amount: store.formatAmount(overview.averagePerActiveMonth),
              ),
              const SizedBox(height: 8),
              Text(
                strings.monthsWithSpending(overview.monthsWithSpending),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: CashWiseTheme.secondaryTextFor(context),
                ),
              ),
              const SizedBox(height: 8),
              AmountRow(
                label: monthRowLabel(
                  strings.highestMonth,
                  overview.highestMonth!,
                ),
                amount: store.formatAmount(overview.highestMonth!.total),
              ),
              AmountRow(
                label: monthRowLabel(
                  strings.lowestMonth,
                  overview.lowestMonth!,
                ),
                amount: store.formatAmount(overview.lowestMonth!.total),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
