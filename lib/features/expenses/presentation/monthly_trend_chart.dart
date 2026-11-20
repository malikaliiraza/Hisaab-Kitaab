// Hisaab Kitaab — monthly spending trend chart (v7.6).
//
// A bar chart of the last 6 months' totals (fl_chart, the
// dependency the category pie chart already uses), on the
// Statistics / Summary page. Totals come from the scoped
// (per-budget) expenses the caller passes in, so a budget's
// own Details page charts only that budget. Months with no
// spending show a zero bar — the chart always has 6 bars.

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../data/expense_store.dart';
import '../data/monthly_trend.dart';
import '../models/expense.dart';

class MonthlyTrendChartCard extends StatelessWidget {
  final ExpenseStore store;

  /// The expenses to chart (scoped per budget by the caller).
  final List<Expense> expenses;

  const MonthlyTrendChartCard({
    super.key,
    required this.store,
    required this.expenses,
  });

  @override
  Widget build(BuildContext context) {
    final strings = store.strings;
    final totals = lastMonthsTotals(expenses);
    final isUrdu = store.locale.code == 'ur';
    final maxTotal =
        totals.fold(0.0, (max, t) => t.total > max ? t.total : max);
    final secondary = CashWiseTheme.secondaryTextFor(context);

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.monthlyTrend,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (maxTotal <= 0)
              Text(
                strings.noExpenses,
                style: TextStyle(color: secondary),
              )
            else
              SizedBox(
                height: 200,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: maxTotal * 1.15,
                    barTouchData: const BarTouchData(enabled: false),
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      show: true,
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index < 0 || index >= totals.length) {
                              return const SizedBox.shrink();
                            }
                            return SideTitleWidget(
                              meta: meta,
                              child: Text(
                                shortMonthLabel(
                                  totals[index].month,
                                  urdu: isUrdu,
                                ),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: secondary,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    barGroups: [
                      for (var i = 0; i < totals.length; i++)
                        BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: totals[i].total,
                              color: CashWiseTheme.accentFor(context),
                              width: 22,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(6),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            if (maxTotal > 0) ...[
              const SizedBox(height: 8),
              // The biggest month at a glance, under the chart.
              Row(
                children: [
                  Expanded(
                    child: Text(
                      shortMonthLabel(
                        totals
                            .reduce((a, b) =>
                                a.total >= b.total ? a : b)
                            .month,
                        urdu: isUrdu,
                      ),
                      style: TextStyle(color: secondary),
                    ),
                  ),
                  Text(
                    store.formatAmount(maxTotal),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
