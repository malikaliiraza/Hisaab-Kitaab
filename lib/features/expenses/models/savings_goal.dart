// Hisaab Kitaab — savings goal (v7.4).
//
// A pot of money with a target: "Umrah fund — target Rs.
// 500,000, saved Rs. 120,000, by December 2027". `saved` only
// ever grows through "Add money" — see ExpenseStore.addMoneyToGoal
// for how the movement is recorded so the budget math stays
// consistent (the money leaves the spendable budget as a
// "Savings: <name>" expense). A goal has no expenses of its
// own; its progress is saved / target.

class SavingsGoal {
  final String id;
  final String name;
  final double target;
  final double saved;
  final DateTime? deadline;
  final DateTime createdAt;

  const SavingsGoal({
    required this.id,
    required this.name,
    required this.target,
    this.saved = 0,
    this.deadline,
    required this.createdAt,
  });

  /// 0..1 (clamped) — 1 when the goal is reached or passed.
  double get progress =>
      target <= 0 ? 0 : (saved / target).clamp(0.0, 1.0);

  bool get isReached => target > 0 && saved >= target;

  SavingsGoal copyWith({
    String? name,
    double? target,
    double? saved,
    DateTime? deadline,
    bool clearDeadline = false,
  }) =>
      SavingsGoal(
        id: id,
        name: name ?? this.name,
        target: target ?? this.target,
        saved: saved ?? this.saved,
        deadline: clearDeadline ? null : (deadline ?? this.deadline),
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'target': target,
        'saved': saved,
        'deadline': deadline?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory SavingsGoal.fromJson(Map<String, dynamic> json) =>
      SavingsGoal(
        id: json['id'] as String,
        name: json['name'] as String,
        target: (json['target'] as num).toDouble(),
        saved: (json['saved'] as num?)?.toDouble() ?? 0,
        deadline: json['deadline'] == null
            ? null
            : DateTime.parse(json['deadline'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
