// CashWise AI — a budget period (v5.9, v7.11).
//
// One monthly budget. The app used to have a single budget; since
// v5.9 the user can keep several (e.g. one per month, or one per
// purpose) and switch between them — every budget has its own
// expenses, spent/remaining and alerts, and the whole system
// works the same on each one. Expenses carry the id of the
// budget they belong to; the active budget is the one the home
// screens, chart and predictor read.
//
// Rollover (v7.11): when a new budget is created, the unspent
// balance of the previous budget can be carried into it — the
// new budget's amount already includes the carried sum, and
// `carriedAmount` records how much of it came over, so the
// budget's own screen can show it honestly.

class BudgetPeriod {
  final String id;
  final double amount;
  final DateTime createdAt;

  /// The name the user gave this budget (v7.0) — empty for
  /// budgets made before naming existed; the screens then fall
  /// back to "Budget 1", "Budget 2", ...
  final String name;

  /// How much of this budget's amount was carried over from
  /// the previous budget (v7.11) — 0 for budgets made before
  /// rollover existed, or when nothing was carried.
  final double carriedAmount;

  const BudgetPeriod({
    required this.id,
    required this.amount,
    required this.createdAt,
    this.name = '',
    this.carriedAmount = 0,
  });

  BudgetPeriod copyWith({double? amount, String? name, double? carriedAmount}) =>
      BudgetPeriod(
        id: id,
        amount: amount ?? this.amount,
        createdAt: createdAt,
        name: name ?? this.name,
        carriedAmount: carriedAmount ?? this.carriedAmount,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'amount': amount,
        'createdAt': createdAt.toIso8601String(),
        'name': name,
        'carriedAmount': carriedAmount,
      };

  factory BudgetPeriod.fromJson(Map<String, dynamic> json) =>
      BudgetPeriod(
        id: json['id'] as String,
        amount: (json['amount'] as num).toDouble(),
        createdAt: DateTime.parse(json['createdAt'] as String),
        name: json['name'] as String? ?? '',
        carriedAmount: (json['carriedAmount'] as num?)?.toDouble() ?? 0,
      );
}
