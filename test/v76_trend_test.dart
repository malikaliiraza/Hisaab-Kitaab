// Hisaab Kitaab — v7.6 tests: monthly trend + month-over-month
// comparison (pure logic), and savings-goal editing (the
// v7.4 sheet already edits — this proves target + deadline
// change while `saved` stays untouched, and that deleting a
// goal never refunds money already added).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cashwise_ai/features/expenses/data/expense_store.dart';
import 'package:cashwise_ai/features/expenses/data/monthly_trend.dart';
import 'package:cashwise_ai/features/expenses/models/expense.dart';
import 'package:cashwise_ai/features/expenses/models/savings_goal.dart';
import 'package:cashwise_ai/features/expenses/presentation/statistics_screen.dart';

Expense expense(
  String id,
  double amount,
  String category,
  DateTime date,
) =>
    Expense(
      id: id,
      title: id,
      amountPkr: amount,
      category: category,
      date: date,
    );

void main() {
  group('monthly trend', () {
    test('last 6 months, empty months are 0', () {
      final totals = lastMonthsTotals(
        [
          expense('a', 5000, 'Food', DateTime(2026, 11, 5)),
          expense('b', 3000, 'Transport', DateTime(2026, 9, 10)),
          expense('c', 1000, 'Food', DateTime(2026, 6, 2)),
        ],
        now: DateTime(2026, 11, 14),
      );
      expect(totals.length, 6);
      expect(totals.map((t) => t.month).toList(),
          [6, 7, 8, 9, 10, 11]);
      expect(totals.map((t) => t.total).toList(),
          [1000, 0, 0, 3000, 0, 5000]);
    });

    test('year boundary: January looks back into December', () {
      final totals = lastMonthsTotals(
        [
          expense('a', 7000, 'Bills', DateTime(2026, 12, 20)),
          expense('b', 2000, 'Food', DateTime(2027, 1, 3)),
        ],
        now: DateTime(2027, 1, 10),
      );
      expect(totals.map((t) => t.month).toList(),
          [8, 9, 10, 11, 12, 1]);
      expect(totals.map((t) => t.year).toList(),
          [2026, 2026, 2026, 2026, 2026, 2027]);
      expect(totals.map((t) => t.total).toList(),
          [0, 0, 0, 0, 7000, 2000]);
    });

    test('no expenses at all: six zeros', () {
      final totals =
          lastMonthsTotals([], now: DateTime(2026, 11, 14));
      expect(totals.length, 6);
      expect(totals.every((t) => t.total == 0), isTrue);
    });

    test('expenses outside the 6 months are ignored', () {
      final totals = lastMonthsTotals(
        [
          expense('old', 99999, 'Food', DateTime(2025, 1, 1)),
          expense('new', 4000, 'Food', DateTime(2026, 11, 1)),
        ],
        now: DateTime(2026, 11, 14),
      );
      expect(totals.last.total, 4000);
      expect(totals.first.total, 0);
    });
  });

  group('month-over-month comparison', () {
    test('totals, difference, % change, biggest increase', () {
      final comparison = compareWithLastMonth(
        [
          expense('a', 8000, 'Food', DateTime(2026, 11, 5)),
          expense('b', 4000, 'Transport', DateTime(2026, 11, 6)),
          expense('c', 5000, 'Food', DateTime(2026, 10, 5)),
          expense('d', 5000, 'Transport', DateTime(2026, 10, 6)),
        ],
        now: DateTime(2026, 11, 14),
      );
      expect(comparison.thisMonth, 12000);
      expect(comparison.lastMonth, 10000);
      expect(comparison.difference, 2000);
      expect(comparison.percentChange, 20);
      expect(comparison.biggestIncreaseCategory, 'Food');
      expect(comparison.biggestIncreaseAmount, 3000);
    });

    test('last month 0: no percent change, only this month', () {
      final comparison = compareWithLastMonth(
        [expense('a', 4000, 'Food', DateTime(2026, 11, 5))],
        now: DateTime(2026, 11, 14),
      );
      expect(comparison.thisMonth, 4000);
      expect(comparison.lastMonth, 0);
      expect(comparison.percentChange, isNull);
      expect(comparison.biggestIncreaseCategory, 'Food');
    });

    test('spending fell: negative change, no biggest increase', () {
      final comparison = compareWithLastMonth(
        [
          expense('a', 6000, 'Food', DateTime(2026, 11, 5)),
          expense('b', 10000, 'Food', DateTime(2026, 10, 5)),
        ],
        now: DateTime(2026, 11, 14),
      );
      expect(comparison.difference, -4000);
      expect(comparison.percentChange, -40);
      expect(comparison.biggestIncreaseCategory, isNull);
      expect(comparison.biggestIncreaseAmount, 0);
    });

    test('identical months: zero change, no biggest increase', () {
      final comparison = compareWithLastMonth(
        [
          expense('a', 5000, 'Food', DateTime(2026, 11, 5)),
          expense('b', 5000, 'Food', DateTime(2026, 10, 5)),
        ],
        now: DateTime(2026, 11, 14),
      );
      expect(comparison.difference, 0);
      expect(comparison.percentChange, 0);
      expect(comparison.biggestIncreaseCategory, isNull);
    });

    test('a brand-new category counts as the biggest increase', () {
      final comparison = compareWithLastMonth(
        [
          expense('a', 1000, 'Food', DateTime(2026, 11, 5)),
          expense('b', 9000, 'Shopping', DateTime(2026, 11, 6)),
          expense('c', 5000, 'Food', DateTime(2026, 10, 5)),
        ],
        now: DateTime(2026, 11, 14),
      );
      expect(comparison.biggestIncreaseCategory, 'Shopping');
      expect(comparison.biggestIncreaseAmount, 9000);
    });
  });

  test('short month labels, English and Urdu', () {
    expect(shortMonthLabel(1), 'Jan');
    expect(shortMonthLabel(11), 'Nov');
    expect(shortMonthLabel(12), 'Dec');
    expect(shortMonthLabel(1, urdu: true), 'جنوری');
    expect(shortMonthLabel(11, urdu: true), 'نومبر');
  });

  group('savings goal edit (v7.4 sheet, edit mode)', () {
    Future<ExpenseStore> makeStore() async {
      SharedPreferences.setMockInitialValues({});
      final store = ExpenseStore();
      await store.load();
      await store.register(
        name: 'Malik Ali Raza',
        email: 'melicalyraza5@gmail.com',
        password: 'Strong1!',
      );
      await store.addBudget(50000, name: 'Home');
      return store;
    }

    test('editing target + deadline keeps saved untouched', () async {
      final store = await makeStore();
      await store.addSavingsGoal(
        SavingsGoal(
          id: 'g1',
          name: 'Umrah',
          target: 500000,
          saved: 120000,
          deadline: DateTime(2027, 12, 1),
          createdAt: DateTime(2026, 11, 1),
        ),
      );
      await store.updateSavingsGoal(
        store.savingsGoals.first.copyWith(
          target: 600000,
          deadline: DateTime(2028, 6, 1),
        ),
      );
      final goal = store.savingsGoals.first;
      expect(goal.target, 600000);
      expect(goal.deadline, DateTime(2028, 6, 1));
      expect(goal.saved, 120000); // money never moves on edit.
      expect(goal.name, 'Umrah');
    });

    test('editing can clear the deadline', () async {
      final store = await makeStore();
      await store.addSavingsGoal(
        SavingsGoal(
          id: 'g1',
          name: 'Bike',
          target: 200000,
          deadline: DateTime(2027, 6, 1),
          createdAt: DateTime(2026, 11, 1),
        ),
      );
      await store.updateSavingsGoal(
        store.savingsGoals.first.copyWith(clearDeadline: true),
      );
      expect(store.savingsGoals.first.deadline, isNull);
    });

    test('deleting a goal does not refund money already added',
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
      expect(
        await store.addMoneyToGoal(goalId: 'g1', amount: 10000),
        isTrue,
      );
      await store.removeSavingsGoal('g1');
      expect(store.savingsGoals, isEmpty);
      // The "Savings: Umrah" expense stays — the money was
      // really set aside (v7.4 rule, kept in v7.6).
      expect(
        store.allExpenses.any((e) => e.title == 'Savings: Umrah'),
        isTrue,
      );
      expect(store.totalSpent, 10000);
    });
  });

  group('Summary tab shows the trend chart + comparison card', () {
    testWidgets('both v7.6 cards render, no overflow', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final store = ExpenseStore();
      await store.load();
      await store.register(
        name: 'Malik Ali Raza',
        email: 'melicalyraza5@gmail.com',
        password: 'Strong1!',
      );
      await store.addBudget(50000, name: 'Home');
      final now = DateTime.now();
      await store.addExpense(
        Expense(
          id: 'e1',
          title: 'Groceries',
          amountPkr: 8000,
          category: 'Food',
          date: DateTime(now.year, now.month, 5),
        ),
      );
      await store.addExpense(
        Expense(
          id: 'e2',
          title: 'Bus',
          amountPkr: 2000,
          category: 'Transport',
          date: DateTime(now.year, now.month - 1, 6),
        ),
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<ExpenseStore>.value(
          value: store,
          child: const MaterialApp(
            home: StatisticsScreen(initialTab: 2),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The v7.6 cards are on the Summary tab, under the totals.
      expect(find.text('Monthly spending trend'), findsOneWidget);
      expect(find.text('This month vs last month'), findsOneWidget);
      expect(find.text('Rs. 8,000'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });
}
