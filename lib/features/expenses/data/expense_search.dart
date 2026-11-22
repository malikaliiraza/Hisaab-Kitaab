// Hisaab Kitaab — expense search, filter and sort (v7.8).
//
// Pure Dart, no Flutter imports, so it is unit-testable on
// its own. The budget detail screen and the Statistics
// screen share this logic: a query matches an expense's
// title OR its category (case-insensitive, trimmed), and
// the sort orders the filtered list. Both functions return
// a NEW list and never mutate the input.

import '../models/expense.dart';

/// The four orders the expense list can be shown in.
enum ExpenseSort { newest, oldest, amountHighToLow, amountLowToHigh }

/// The expenses in [expenses] that match [query] and
/// [category]. An empty query matches everything; a null
/// or 'All' category matches every category.
List<Expense> filterExpenses(
  List<Expense> expenses, {
  String query = '',
  String? category,
}) {
  final q = query.trim().toLowerCase();
  final matchesAllCategories =
      category == null || category == 'All';
  return expenses.where((e) {
    if (!matchesAllCategories && e.category != category) {
      return false;
    }
    if (q.isEmpty) return true;
    return e.title.toLowerCase().contains(q) ||
        e.category.toLowerCase().contains(q);
  }).toList();
}

/// [expenses] in the order [sort] asks for. Returns a new
/// list; the input list is left untouched. Sorts are stable:
/// expenses that compare equal keep their original order.
List<Expense> sortExpenses(List<Expense> expenses, ExpenseSort sort) {
  final sorted = List<Expense>.of(expenses);
  switch (sort) {
    case ExpenseSort.newest:
      sorted.sort((a, b) => b.date.compareTo(a.date));
    case ExpenseSort.oldest:
      sorted.sort((a, b) => a.date.compareTo(b.date));
    case ExpenseSort.amountHighToLow:
      sorted.sort((a, b) => b.amountPkr.compareTo(a.amountPkr));
    case ExpenseSort.amountLowToHigh:
      sorted.sort((a, b) => a.amountPkr.compareTo(b.amountPkr));
  }
  return sorted;
}
