class Expense {
  final String id;
  final String title;
  final double amountPkr;
  final String category;
  final DateTime date;

  /// The budget this expense belongs to ('' = the first/only
  /// budget, kept for expenses saved before multi-budget).
  final String budgetId;

  /// Optional free-text note (v7.12): where it was bought,
  /// who it was for — anything the user wants to remember.
  /// '' when no note was written.
  final String note;

  const Expense({
    required this.id,
    required this.title,
    required this.amountPkr,
    required this.category,
    required this.date,
    this.budgetId = '',
    this.note = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'amountPkr': amountPkr,
        'category': category,
        'date': date.toIso8601String(),
        'budgetId': budgetId,
        'note': note,
      };

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        id: json['id'] as String,
        title: json['title'] as String,
        amountPkr: (json['amountPkr'] as num).toDouble(),
        category: json['category'] as String,
        date: DateTime.parse(json['date'] as String),
        budgetId: (json['budgetId'] as String?) ?? '',
        note: (json['note'] as String?) ?? '',
      );
}

const List<String> expenseCategories = [
  'Food',
  'Transport',
  'Bills',
  'Shopping',
  'Health',
  'Education',
  'Other',
];
