// Hisaab Kitaab — recurring expense / bill rule (v7.4, v7.10).
//
// A rule posts one Expense automatically, once per month, on
// its day-of-month: "Electricity bill, Rs. 5,000, Bills, on the
// 10th of every month". `lastPostedMonth` is "yyyy-MM" of the
// month the rule last posted for — it is what stops the same
// rule posting twice in one cycle. `dayOfMonth` is clamped to
// the month's length when posting (a 31st rule posts on the
// 30th in a 30-day month). A paused rule (v7.10) never posts
// until it is resumed.

class RecurringRule {
  final String id;
  final String title;
  final double amountPkr;
  final String category;
  final String budgetId;
  final int dayOfMonth;
  final DateTime createdAt;

  /// "yyyy-MM" of the month this rule last posted for
  /// ('' = never posted yet).
  final String lastPostedMonth;

  /// Paused rules never post (v7.10) — they keep their
  /// lastPostedMonth untouched while paused.
  final bool paused;

  const RecurringRule({
    required this.id,
    required this.title,
    required this.amountPkr,
    required this.category,
    required this.budgetId,
    required this.dayOfMonth,
    required this.createdAt,
    this.lastPostedMonth = '',
    this.paused = false,
  });

  RecurringRule copyWith({
    String? title,
    double? amountPkr,
    String? category,
    String? budgetId,
    int? dayOfMonth,
    String? lastPostedMonth,
    bool? paused,
  }) =>
      RecurringRule(
        id: id,
        title: title ?? this.title,
        amountPkr: amountPkr ?? this.amountPkr,
        category: category ?? this.category,
        budgetId: budgetId ?? this.budgetId,
        dayOfMonth: dayOfMonth ?? this.dayOfMonth,
        createdAt: createdAt,
        lastPostedMonth: lastPostedMonth ?? this.lastPostedMonth,
        paused: paused ?? this.paused,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'amountPkr': amountPkr,
        'category': category,
        'budgetId': budgetId,
        'dayOfMonth': dayOfMonth,
        'createdAt': createdAt.toIso8601String(),
        'lastPostedMonth': lastPostedMonth,
        'paused': paused,
      };

  factory RecurringRule.fromJson(Map<String, dynamic> json) =>
      RecurringRule(
        id: json['id'] as String,
        title: json['title'] as String,
        amountPkr: (json['amountPkr'] as num).toDouble(),
        category: json['category'] as String,
        budgetId: (json['budgetId'] as String?) ?? '',
        dayOfMonth: (json['dayOfMonth'] as num?)?.toInt() ?? 1,
        createdAt: DateTime.parse(json['createdAt'] as String),
        lastPostedMonth: (json['lastPostedMonth'] as String?) ?? '',
        paused: json['paused'] as bool? ?? false,
      );
}
