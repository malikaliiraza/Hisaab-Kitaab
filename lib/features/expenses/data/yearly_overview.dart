// Hisaab Kitaab — yearly overview (v7.7).
//
// Pure Dart: no widgets, no store — every function takes the
// expenses it should read, so tests can fix the dates. The
// Summary tab passes the scoped (per-budget) expenses; the
// helper never sees another budget's money.
//
// The overview covers the current calendar year: the year's
// total, how many months actually had spending, the average
// across those active months, and the highest- and
// lowest-spend months. A month with no expenses is "no
// spending", never the lowest month — the lowest month is
// picked only among months that have spending.

import '../models/expense.dart';
import 'monthly_trend.dart';

/// This calendar year's spending at a glance.
class YearlyOverview {
  final int year;

  /// Total spent in the year.
  final double total;

  /// Months of the year with any spending (0..12).
  final int monthsWithSpending;

  /// Highest-spend month, or null when nothing was spent yet.
  final MonthlyTotal? highestMonth;

  /// Lowest-spend month among months with spending, or null
  /// when nothing was spent yet.
  final MonthlyTotal? lowestMonth;

  const YearlyOverview({
    required this.year,
    required this.total,
    required this.monthsWithSpending,
    required this.highestMonth,
    required this.lowestMonth,
  });

  /// Average spend across the months that had spending, or 0
  /// when no month had spending yet.
  double get averagePerActiveMonth =>
      monthsWithSpending == 0 ? 0 : total / monthsWithSpending;
}

/// The overview for [now]'s calendar year. [now] exists so
/// tests can fix the year; the screens always pass "now".
YearlyOverview yearlyOverview(
  List<Expense> expenses, {
  DateTime? now,
}) {
  final ref = now ?? DateTime.now();
  final year = ref.year;
  final months = <MonthlyTotal>[];
  for (var month = 1; month <= 12; month++) {
    final total = expenses
        .where((e) => e.date.year == year && e.date.month == month)
        .fold(0.0, (sum, e) => sum + e.amountPkr);
    months.add(MonthlyTotal(year: year, month: month, total: total));
  }
  final active = months.where((m) => m.total > 0).toList();
  MonthlyTotal? highest;
  MonthlyTotal? lowest;
  for (final month in active) {
    if (highest == null || month.total > highest.total) {
      highest = month;
    }
    if (lowest == null || month.total < lowest.total) {
      lowest = month;
    }
  }
  return YearlyOverview(
    year: year,
    total: months.fold(0.0, (sum, m) => sum + m.total),
    monthsWithSpending: active.length,
    highestMonth: highest,
    lowestMonth: lowest,
  );
}
