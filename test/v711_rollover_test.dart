// Hisaab Kitaab — v7.11 tests: budget rollover (carry the
// unspent balance of the active budget into a new budget).
//
//  1. `carriedAmount` survives a JSON round-trip, and old
//     saved budgets without the key load as 0.
//  2. `carryOverAvailable` is 0 with no budgets, equals the
//     active budget's remaining balance otherwise, and never
//     goes below zero when the budget is overspent.
//  3. `addBudget` with carryOver adds the unspent balance to
//     the new budget's amount, records it as `carriedAmount`,
//     makes the new budget active, and leaves the old budget
//     and its expenses untouched.
//  4. `addBudget` without carryOver stores the amount exactly
//     as entered, with `carriedAmount` 0.
//  5. `carriedAmount` survives a reload from SharedPreferences.
//  6. The budget detail screen shows a "Carried over" row,
//     and the budget screen offers the carry-over switch when
//     a new budget is added while money is left.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cashwise_ai/features/expenses/data/expense_store.dart';
import 'package:cashwise_ai/features/expenses/models/budget.dart';
import 'package:cashwise_ai/features/expenses/models/expense.dart';
import 'package:cashwise_ai/features/expenses/presentation/budget_detail_screen.dart';
import 'package:cashwise_ai/features/expenses/presentation/budget_screen.dart';

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

Expense expense(String id, double amount) => Expense(
      id: id,
      title: id,
      amountPkr: amount,
      category: 'Food',
      date: DateTime.now(),
    );

void main() {
  test('carriedAmount survives a JSON round-trip', () {
    final withCarry = BudgetPeriod(
      id: 'b1',
      amount: 60000,
      createdAt: DateTime(2026, 11, 1),
      name: 'Home',
      carriedAmount: 12000,
    );
    final restored = BudgetPeriod.fromJson(withCarry.toJson());
    expect(restored.carriedAmount, 12000);
    expect(restored.amount, 60000);
    expect(restored.name, 'Home');

    // Old saved budgets have no carriedAmount key at all.
    final old = BudgetPeriod.fromJson({
      'id': 'b0',
      'amount': 40000,
      'createdAt': DateTime(2026, 10, 1).toIso8601String(),
      'name': 'Old',
    });
    expect(old.carriedAmount, 0);
  });

  test('carryOverAvailable follows the active budget', () async {
    final store = await makeStore();
    // Nothing spent yet: the whole budget is left.
    expect(store.carryOverAvailable, 50000);
    expect(store.carryOverSource?.name, 'Home');

    await store.addExpense(expense('e1', 20000));
    expect(store.carryOverAvailable, 30000);

    // Overspent: never below zero.
    await store.addExpense(expense('e2', 40000));
    expect(store.carryOverAvailable, 0);
  });

  test('addBudget with carryOver moves the unspent balance', () async {
    final store = await makeStore();
    await store.addExpense(expense('e1', 20000));
    final oldId = store.activeBudgetId;

    await store.addBudget(40000, name: 'December', carryOver: true);

    final created = store.activeBudget!;
    expect(created.name, 'December');
    expect(created.amount, 70000);
    expect(created.carriedAmount, 30000);
    expect(store.carryOverAvailable, 70000);

    // The old budget keeps its own amount and expenses.
    final old = store.budgets.firstWhere((b) => b.id == oldId);
    expect(old.amount, 50000);
    expect(store.budgetSpent(old), 20000);
    expect(store.expensesForBudget(oldId).length, 1);
    expect(store.expensesForBudget(created.id), isEmpty);
  });

  test('addBudget without carryOver stores the amount as entered',
      () async {
    final store = await makeStore();
    await store.addExpense(expense('e1', 20000));

    await store.addBudget(40000, name: 'December');

    final created = store.activeBudget!;
    expect(created.amount, 40000);
    expect(created.carriedAmount, 0);
  });

  test('addBudget with carryOver carries nothing when fully spent',
      () async {
    final store = await makeStore();
    await store.addExpense(expense('e1', 50000));

    await store.addBudget(40000, name: 'December', carryOver: true);

    final created = store.activeBudget!;
    expect(created.amount, 40000);
    expect(created.carriedAmount, 0);
  });

  test('carriedAmount survives a reload', () async {
    final store = await makeStore();
    await store.addExpense(expense('e1', 20000));
    await store.addBudget(40000, name: 'December', carryOver: true);

    final reloaded = ExpenseStore();
    await reloaded.load();
    final created =
        reloaded.budgets.firstWhere((b) => b.name == 'December');
    expect(created.amount, 70000);
    expect(created.carriedAmount, 30000);
    expect(reloaded.activeBudgetId, created.id);
  });

  group('budget detail screen', () {
    testWidgets('shows the carried-over row', (tester) async {
      final store = await makeStore();
      await store.addExpense(expense('e1', 20000));
      await store.addBudget(40000, name: 'December', carryOver: true);
      final created = store.activeBudget!;

      await tester.pumpWidget(
        ChangeNotifierProvider<ExpenseStore>.value(
          value: store,
          child: MaterialApp(
            home: BudgetDetailScreen(budget: created),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Carried over'), findsOneWidget);
      expect(find.text('Rs. 30,000'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('hides the row when nothing was carried',
        (tester) async {
      final store = await makeStore();
      final home = store.activeBudget!;

      await tester.pumpWidget(
        ChangeNotifierProvider<ExpenseStore>.value(
          value: store,
          child: MaterialApp(
            home: BudgetDetailScreen(budget: home),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Carried over'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('budget screen', () {
    testWidgets('offers carry-over when adding a budget with money left',
        (tester) async {
      final store = await makeStore();
      await store.addExpense(expense('e1', 20000));

      await tester.pumpWidget(
        ChangeNotifierProvider<ExpenseStore>.value(
          value: store,
          child: const MaterialApp(home: BudgetScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add another budget'));
      await tester.pumpAndSettle();

      expect(find.text('Carry over unspent balance'), findsOneWidget);
      expect(find.text('Carry over Rs. 30,000 unspent from Home'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
