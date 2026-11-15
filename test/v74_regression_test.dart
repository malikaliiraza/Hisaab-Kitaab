// Hisaab Kitaab — v7.4 regression tests (coordinator).
//
// Covers the four v7.4 features at the store level:
//  1. Recurring auto-post fires once per cycle (never twice
//     in one month), fires again next month, and clamps a
//     31st rule to the 30th in a 30-day month.
//  2. Backup JSON round-trips: export, fresh store, import —
//     every list comes back, and the password is never in
//     the exported file.
//  3. Savings goal "Add money" grows `saved`, records a real
//     "Savings: <name>" expense, and drops the remaining
//     budget by exactly that amount (budget math stays
//     consistent); it refuses when there is no budget.
//  4. Monthly report data: this month's spent, top category,
//     per-budget actuals and the loan movement (lent /
//     borrowed / received / paid).

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cashwise_ai/features/expenses/data/expense_store.dart';
import 'package:cashwise_ai/features/expenses/models/expense.dart';
import 'package:cashwise_ai/features/expenses/models/recurring_rule.dart';
import 'package:cashwise_ai/features/expenses/models/savings_goal.dart';
import 'package:cashwise_ai/features/expenses/models/udhar_entry.dart';

Future<ExpenseStore> makeStore() async {
  SharedPreferences.setMockInitialValues({});
  final store = ExpenseStore();
  await store.load();
  final created = await store.register(
    name: 'Malik Ali Raza',
    email: 'melicalyraza5@gmail.com',
    password: 'Strong1!',
  );
  expect(created, isTrue);
  await store.addBudget(50000, name: 'Home');
  return store;
}

void main() {
  test('recurring rule posts once per cycle, never twice', () async {
    final store = await makeStore();
    await store.addRecurringRule(
      RecurringRule(
        id: 'r1',
        title: 'Electricity bill',
        amountPkr: 5000,
        category: 'Bills',
        budgetId: store.activeBudgetId,
        dayOfMonth: 10,
        createdAt: DateTime(2026, 11, 1),
      ),
    );
    await store.addRecurringRule(
      RecurringRule(
        id: 'r2',
        title: 'Internet',
        amountPkr: 3000,
        category: 'Bills',
        budgetId: store.activeBudgetId,
        dayOfMonth: 20,
        createdAt: DateTime(2026, 11, 1),
      ),
    );

    // 10 Nov: the 10th rule posts, the 20th does not.
    final posted = store.postDueRecurring(now: DateTime(2026, 11, 10));
    expect(posted, 1);
    expect(
      store.allExpenses
          .where((e) => e.title == 'Electricity bill')
          .length,
      1,
    );
    expect(
      store.allExpenses.any((e) => e.title == 'Internet'),
      isFalse,
    );

    // Same day again: nothing posts twice.
    expect(store.postDueRecurring(now: DateTime(2026, 11, 10)), 0);
    expect(
      store.allExpenses
          .where((e) => e.title == 'Electricity bill')
          .length,
      1,
    );

    // 20 Nov: the second rule posts; the first stays at one.
    expect(store.postDueRecurring(now: DateTime(2026, 11, 20)), 1);
    expect(
      store.allExpenses
          .where((e) => e.title == 'Electricity bill')
          .length,
      1,
    );

    // Next month, 10 Dec: the first rule posts again — a new cycle.
    expect(store.postDueRecurring(now: DateTime(2026, 12, 10)), 1);
    expect(
      store.allExpenses
          .where((e) => e.title == 'Electricity bill')
          .length,
      2,
    );
  });

  test('a 31st rule clamps to the 30th in a 30-day month', () async {
    final store = await makeStore();
    await store.addRecurringRule(
      RecurringRule(
        id: 'r31',
        title: 'Rent',
        amountPkr: 20000,
        category: 'Bills',
        budgetId: store.activeBudgetId,
        dayOfMonth: 31,
        createdAt: DateTime(2026, 11, 1),
      ),
    );
    expect(store.postDueRecurring(now: DateTime(2026, 11, 30)), 1);
    final expense =
        store.allExpenses.firstWhere((e) => e.title == 'Rent');
    expect(expense.date, DateTime(2026, 11, 30));
  });

  test('backup JSON round-trips and never contains the password',
      () async {
    final store = await makeStore();
    await store.addExpense(
      Expense(
        id: 'e1',
        title: 'Groceries',
        amountPkr: 2500,
        category: 'Food',
        date: DateTime(2026, 11, 5),
      ),
    );
    await store.addUdhar(
      UdharEntry(
        id: 'u1',
        person: 'Ahmad',
        amountPkr: 4000,
        isLent: true,
        date: DateTime(2026, 11, 3),
      ),
    );
    await store.addRecurringRule(
      RecurringRule(
        id: 'r1',
        title: 'Electricity bill',
        amountPkr: 5000,
        category: 'Bills',
        budgetId: store.activeBudgetId,
        dayOfMonth: 10,
        createdAt: DateTime(2026, 11, 1),
      ),
    );
    await store.addSavingsGoal(
      SavingsGoal(
        id: 'g1',
        name: 'Umrah',
        target: 500000,
        saved: 120000,
        createdAt: DateTime(2026, 11, 1),
      ),
    );
    await store.addCustomReminder({
      'id': 'c1',
      'kind': 'loan',
      'person': 'Ahmad',
      'amount': 4000,
      'date': '2026-11-20',
      'timeMinutes': 600,
      'createdAt': '2026-11-01',
    });

    final json = store.exportBackupJson();
    expect(json.contains('Strong1!'), isFalse);
    expect(json.contains('Groceries'), isTrue);
    expect(json.contains('Umrah'), isTrue);

    // A fresh store imports it back, whole.
    SharedPreferences.setMockInitialValues({});
    final restored = ExpenseStore();
    await restored.load();
    expect(await restored.importBackupJson(json), isTrue);
    expect(restored.allExpenses.length, 1);
    expect(restored.allExpenses.first.title, 'Groceries');
    expect(restored.budgets.length, 1);
    expect(restored.udharEntries.length, 1);
    expect(restored.recurringRules.length, 1);
    expect(restored.savingsGoals.length, 1);
    expect(restored.savingsGoals.first.saved, 120000);
    expect(restored.customReminders.length, 1);
    expect(restored.userName, 'Malik Ali Raza');

    // A bad file changes nothing.
    expect(await restored.importBackupJson('not json'), isFalse);
    expect(restored.allExpenses.length, 1);
    expect(
      await restored.importBackupJson('{"app":"Something else"}'),
      isFalse,
    );
  });

  test('expenses CSV has a header and one row per expense', () async {
    final store = await makeStore();
    await store.addExpense(
      Expense(
        id: 'e1',
        title: 'Groceries, weekly',
        amountPkr: 2500,
        category: 'Food',
        date: DateTime(2026, 11, 5),
      ),
    );
    final csv = store.exportExpensesCsv();
    final lines = csv.split('\n');
    expect(lines.first, 'Date,Title,Category,Budget,Amount (Rs.)');
    expect(lines.length, 2);
    // The comma in the title is quoted, so the row stays one row.
    expect(lines[1], contains('"Groceries, weekly"'));
    expect(lines[1], contains('2026-11-05'));
  });

  test('add money to a goal records an expense and drops remaining',
      () async {
    final store = await makeStore();
    await store.addSavingsGoal(
      SavingsGoal(
        id: 'g1',
        name: 'Umrah',
        target: 500000,
        createdAt: DateTime(2026, 11, 1),
      ),
    );
    final remainingBefore = store.remaining;
    expect(
      await store.addMoneyToGoal(goalId: 'g1', amount: 10000),
      isTrue,
    );
    expect(store.savingsGoals.first.saved, 10000);
    expect(
      store.allExpenses.any((e) => e.title == 'Savings: Umrah'),
      isTrue,
    );
    expect(store.remaining, remainingBefore - 10000);
    expect(store.totalSpent, 10000);
  });

  test('add money refuses when there is no budget', () async {
    SharedPreferences.setMockInitialValues({});
    final store = ExpenseStore();
    await store.load();
    await store.addSavingsGoal(
      SavingsGoal(
        id: 'g1',
        name: 'Umrah',
        target: 500000,
        createdAt: DateTime(2026, 11, 1),
      ),
    );
    expect(
      await store.addMoneyToGoal(goalId: 'g1', amount: 10000),
      isFalse,
    );
    expect(store.savingsGoals.first.saved, 0);
    expect(store.allExpenses, isEmpty);
  });

  test('monthly report data: spent, top category, loan movement',
      () async {
    final store = await makeStore();
    await store.addExpense(
      Expense(
        id: 'e1',
        title: 'Groceries',
        amountPkr: 8000,
        category: 'Food',
        date: DateTime(2026, 11, 5),
      ),
    );
    await store.addExpense(
      Expense(
        id: 'e2',
        title: 'Bus',
        amountPkr: 2000,
        category: 'Transport',
        date: DateTime(2026, 11, 6),
      ),
    );
    await store.addExpense(
      Expense(
        id: 'e3',
        title: 'October bill',
        amountPkr: 9000,
        category: 'Bills',
        date: DateTime(2026, 10, 28),
      ),
    );
    await store.addUdhar(
      UdharEntry(
        id: 'u1',
        person: 'Ahmad',
        amountPkr: 5000,
        isLent: true,
        date: DateTime(2026, 11, 3),
      ),
    );
    await store.addUdharPayment(
      id: 'u1',
      amount: 1000,
      date: DateTime(2026, 11, 10),
    );

    final data = store.monthlyReportData(now: DateTime(2026, 11, 14));
    expect(data['totalSpent'], 10000); // October is excluded.
    expect(data['topCategory'], 'Food');
    expect(data['topCategoryAmount'], 8000);
    final budgets = data['budgets'] as List<Map<String, dynamic>>;
    expect(budgets.length, 1);
    expect(budgets.first['spent'], 10000);
    expect(budgets.first['remaining'], 40000);
    expect(data['lent'], 5000);
    expect(data['received'], 1000);
    expect(data['borrowed'], 0);
    expect(data['paid'], 0);

    final text = store.monthlyReportText(now: DateTime(2026, 11, 14));
    expect(text, contains('Rs. 10,000'));
    expect(text, contains('Food'));
  });
}
