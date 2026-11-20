// Hisaab Kitaab — per-category monthly cap (v7.6).
//
// A monthly spending limit for one category inside one
// budget: "Food — Rs. 15,000 a month, in the Home budget".
// No cap means unlimited — categories without a cap are
// simply not limited, and old data (saved before caps
// existed) has no caps at all, so nothing changes for it.

class CategoryCap {
  /// English category key ('Food', 'Transport', ...).
  final String category;

  /// The monthly limit in PKR.
  final double amount;

  /// The budget this cap belongs to.
  final String budgetId;

  const CategoryCap({
    required this.category,
    required this.amount,
    required this.budgetId,
  });

  CategoryCap copyWith({double? amount}) => CategoryCap(
        category: category,
        amount: amount ?? this.amount,
        budgetId: budgetId,
      );

  Map<String, dynamic> toJson() => {
        'category': category,
        'amount': amount,
        'budgetId': budgetId,
      };

  factory CategoryCap.fromJson(Map<String, dynamic> json) =>
      CategoryCap(
        category: json['category'] as String,
        amount: (json['amount'] as num).toDouble(),
        budgetId: (json['budgetId'] as String?) ?? '',
      );
}
