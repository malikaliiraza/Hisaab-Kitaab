// Hisaab Kitaab — v7.7 tests: yearly overview (pure logic),
// duplicate expense (store), and the Summary tab showing the
// yearly overview card + the Duplicate button on the expense
// detail screen.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cashwise_ai/features/expenses/data/expense_store.dart';
import 'package:cashwise_ai/features/expenses/data/yearly_overview.dart';
import 'package:cashwise_ai/features/expenses/models/expense.dart';
import 'package:cashwise_ai/features/expenses/presentation/expense_detail_screen.dart';
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
  group('yearly overview', () {
    test('totals, active months, average, highest and lowest', () {
      final overview = yearlyOverview(
        [
          expense('a', 5000, 'Food', DateTime(2026, 3, 5)),
          expense('b', 12000, 'Bills', DateTime(2026, 3, 20)),
          expense('c', 2000, 'Transport', DateTime(2026, 7, 10)),
          expense('d', 9000, 'Shopping', DateTime(2025, 12, 20)),
        ],
        now: DateTime(2026, 11, 14),
      );
      expect(overview.year, 2026);
      expect(overview.total, 19000);
      expect(overview.monthsWithSpending, 2);
      expect(overview.averagePerActiveMonth, 9500);
      expect(overview.highestMonth!.month, 3);
      expect(overview.highestMonth!.total, 17000);
      expect(overview.lowestMonth!.month, 7);
      expect(overview.lowestMonth!.total, 2000);
    });

    test('empty year: zeros and nulls, no crash', () {
      final overview = yearlyOverview([], now: DateTime(2026, 11, 14));
      expect(overview.total, 0);
      expect(overview.monthsWithSpending, 0);
      expect(overview.averagePerActiveMonth, 0);
      expect(overview.highestMonth, isNull);
      expect(overview.lowestMonth, isNull);
    });

    test('a zero month is never the lowest month', () {
      final overview = yearlyOverview(
        [expense('a', 4000, 'Food', DateTime(2026, 5, 5))],
        now: DateTime(2026, 11, 14),
      );
      expect(overview.monthsWithSpending, 1);
      expect(overview.highestMonth!.month, 5);
      expect(overview.lowestMonth!.month, 5);
    });
  });

  group('duplicate expense', () {
    test('copy keeps title, amount and category; new id, fixed date',
        () async {
      final store = await makeStore();
      final original =
          expense('orig', 1500, 'Food', DateTime(2026, 11, 10));
      await store.addExpense(original);
      final copy = await store.duplicateExpense(
        original,
        now: DateTime(2026, 11, 21),
      );
      expect(copy, isNotNull);
      expect(store.expenses.length, 2);
      expect(copy!.id, isNot(original.id));
      expect(copy.title, 'orig');
      expect(copy.amountPkr, 1500);
      expect(copy.category, 'Food');
      expect(copy.date, DateTime(2026, 11, 21));
      // The original is untouched.
      expect(store.expenses.any((e) => e.id == 'orig'), isTrue);
    });

    test('no budget, no duplicate', () async {
      SharedPreferences.setMockInitialValues({});
      final store = ExpenseStore();
      await store.load();
      final copy = await store.duplicateExpense(
        expense('x', 100, 'Food', DateTime(2026, 11, 1)),
      );
      expect(copy, isNull);
      expect(store.expenses, isEmpty);
    });
  });

  group('Summary tab shows the yearly overview card', () {
    testWidgets('yearly card renders with real totals',
        (tester) async {
      final store = await makeStore();
      final year = DateTime.now().year;
      await store.addExpense(
        expense('e1', 8000, 'Food', DateTime(year, 1, 5)),
      );
      await store.addExpense(
        expense('e2', 2000, 'Transport', DateTime(year, 3, 6)),
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

      // The v7.7 card is on the Summary tab, under the v7.6 cards.
      expect(find.text('This year at a glance'), findsOneWidget);
      expect(find.text('Rs. 10,000'), findsWidgets);
      expect(find.text('Rs. 5,000'), findsWidgets);
      expect(find.text('Highest month — Jan'), findsOneWidget);
      expect(find.text('Lowest month — Mar'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('expense detail screen duplicate button', () {
    testWidgets('tapping Duplicate adds a copy dated today',
        (tester) async {
      final store = await makeStore();
      final original =
          expense('orig', 1500, 'Food', DateTime(2026, 11, 10));
      await store.addExpense(original);

      // The detail screen is pushed from a list screen in the
      // real app, so Duplicate's pop returns there — and the
      // SnackBar shows on the list. Pumping the detail screen
      // as the home route would pop the whole app instead, and
      // the SnackBar would go with it, so the test pushes it
      // the same way the app does.
      await tester.pumpWidget(
        ChangeNotifierProvider<ExpenseStore>.value(
          value: store,
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            ExpenseDetailScreen(expense: original),
                      ),
                    ),
                    child: const Text('open detail'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('open detail'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.copy_all_outlined), findsOneWidget);
      await tester.tap(find.byIcon(Icons.copy_all_outlined));
      await tester.pumpAndSettle();

      expect(store.expenses.length, 2);
      expect(find.text('Expense duplicated for today.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
