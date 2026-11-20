// Hisaab Kitaab — monthly spending trend + month-over-month
// comparison (v7.6).
//
// Pure Dart: no widgets, no store — every function takes the
// expenses it should read, so tests can fix the dates. The
// screens pass the scoped (per-budget) expenses; the helper
// never sees another budget's money.

import '../models/expense.dart';

/// One month's total spend.
class MonthlyTotal {
  final int year;
  final int month; // 1..12
  final double total;

  const MonthlyTotal({
    required this.year,
    required this.month,
    required this.total,
  });
}

/// The last [count] months ending at [now]'s month, oldest
/// first. Months with no expenses total 0, so the chart always
/// has [count] bars. [now] exists so tests can fix the month;
/// the screens always pass "now".
List<MonthlyTotal> lastMonthsTotals(
  List<Expense> expenses, {
  int count = 6,
  DateTime? now,
}) {
  final ref = now ?? DateTime.now();
  final result = <MonthlyTotal>[];
  for (var i = count - 1; i >= 0; i--) {
    // DateTime normalises month overflow, so December of the
    // previous year works when `now` is in January.
    final monthStart = DateTime(ref.year, ref.month - i, 1);
    final total = expenses
        .where((e) =>
            e.date.year == monthStart.year &&
            e.date.month == monthStart.month)
        .fold(0.0, (sum, e) => sum + e.amountPkr);
    result.add(MonthlyTotal(
      year: monthStart.year,
      month: monthStart.month,
      total: total,
    ));
  }
  return result;
}

/// This month vs last month, from the same expenses.
class MonthComparison {
  final double thisMonth;
  final double lastMonth;

  /// The category (English key) whose spend rose the most
  /// this month vs last month, or null when no category rose.
  final String? biggestIncreaseCategory;

  /// How much that category rose by (0 when none rose).
  final double biggestIncreaseAmount;

  const MonthComparison({
    required this.thisMonth,
    required this.lastMonth,
    required this.biggestIncreaseCategory,
    required this.biggestIncreaseAmount,
  });

  double get difference => thisMonth - lastMonth;

  /// Percent change vs last month, or null when last month
  /// was 0 (there is no base to compare against).
  double? get percentChange =>
      lastMonth <= 0 ? null : difference / lastMonth * 100;
}

/// Compare this month with last month. [now] exists so tests
/// can fix the month; the screens always pass "now".
MonthComparison compareWithLastMonth(
  List<Expense> expenses, {
  DateTime? now,
}) {
  final ref = now ?? DateTime.now();
  final last = DateTime(ref.year, ref.month - 1, 1);
  double totalFor(int year, int month) => expenses
      .where((e) => e.date.year == year && e.date.month == month)
      .fold(0.0, (sum, e) => sum + e.amountPkr);
  final thisTotal = totalFor(ref.year, ref.month);
  final lastTotal = totalFor(last.year, last.month);

  // Per-category totals for both months, then the biggest rise.
  final thisByCategory = <String, double>{};
  final lastByCategory = <String, double>{};
  for (final e in expenses) {
    if (e.date.year == ref.year && e.date.month == ref.month) {
      thisByCategory[e.category] =
          (thisByCategory[e.category] ?? 0) + e.amountPkr;
    } else if (e.date.year == last.year && e.date.month == last.month) {
      lastByCategory[e.category] =
          (lastByCategory[e.category] ?? 0) + e.amountPkr;
    }
  }
  String? biggestCategory;
  var biggestAmount = 0.0;
  final categories = {...thisByCategory.keys, ...lastByCategory.keys};
  for (final category in categories) {
    final rise = (thisByCategory[category] ?? 0) -
        (lastByCategory[category] ?? 0);
    if (rise > biggestAmount) {
      biggestAmount = rise;
      biggestCategory = category;
    }
  }

  return MonthComparison(
    thisMonth: thisTotal,
    lastMonth: lastTotal,
    biggestIncreaseCategory: biggestCategory,
    biggestIncreaseAmount: biggestAmount,
  );
}

/// Short month label for chart axes: "Jan".."Dec" in English,
/// the (already short) Urdu month names in Urdu mode.
String shortMonthLabel(int month, {bool urdu = false}) {
  const en = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  const ur = [
    'جنوری', 'فروری', 'مارچ', 'اپریل', 'مئی', 'جون',
    'جولائی', 'اگست', 'ستمبر', 'اکتوبر', 'نومبر', 'دسمبر',
  ];
  return (urdu ? ur : en)[month - 1];
}
