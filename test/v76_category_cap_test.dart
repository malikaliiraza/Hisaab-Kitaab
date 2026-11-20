// Hisaab Kitaab — v7.6 tests: per-category monthly caps.
//
// Covers the cap model + store: set / replace / remove, the
// month-to-date spend check, the over-cap warning logic,
// persistence across a fresh store load, backup round-trip,
// and that a backup made before caps existed still imports
// cleanly (as "no caps").

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cashwise_ai/features/expenses/data/expense_store.dart';
import 'package:cashwise_ai/features/expenses/models/category_cap.dart';
import 'package:cashwise_ai/features/expenses/models/expense.dart';

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

Future<void> addExpense(
  ExpenseStore store,
  String id,
  double amount,
  String category,
  DateTime date,
) =>
    store.addExpense(
      Expense(
        id: id,
        title: id,
        amountPkr: amount,
        category: category,
        date: date,
      ),
    );

void main() {
  test('cap model round-trips through JSON', () {
    const cap = CategoryCap(
      category: 'Food',
      amount: 15000,
      budgetId: 'b1',
    );
    final restored = CategoryCap.fromJson(cap.toJson());
    expect(restored.category, 'Food');
    expect(restored.amount, 15000);
    expect(restored.budgetId, 'b1');
    // Old JSON without a budget id loads as '' (unlimited scope).
    final legacy = CategoryCap.fromJson({
      'category': 'Food',
      'amount': 15000,
    });
    expect(legacy.budgetId, '');
  });

  test('over-cap detection uses this month only', () async {
    final store = await makeStore();
    final budgetId = store.activeBudgetId;
    await store.setCategoryCap(
      CategoryCap(category: 'Food', amount: 10000, budgetId: budgetId),
    );
    // Last month's big spend does not count.
    await addExpense(
        store, 'e1', 20000, 'Food', DateTime(2026, 10, 20));
    expect(
      store.categorySpentThisMonth(budgetId, 'Food',
          now: DateTime(2026, 11, 14)),
      0,
    );
    expect(
      store.isCategoryOverCap(budgetId, 'Food',
          now: DateTime(2026, 11, 14)),
      isFalse,
    );
    // This month: 6,000 + 5,000 = 11,000 > 10,000 cap.
    await addExpense(
        store, 'e2', 6000, 'Food', DateTime(2026, 11, 5));
    await addExpense(
        store, 'e3', 5000, 'Food', DateTime(2026, 11, 10));
    expect(
      store.categorySpentThisMonth(budgetId, 'Food',
          now: DateTime(2026, 11, 14)),
      11000,
    );
    expect(
      store.isCategoryOverCap(budgetId, 'Food',
          now: DateTime(2026, 11, 14)),
      isTrue,
    );
    // Exactly at the cap is not over.
    await store.setCategoryCap(
      CategoryCap(category: 'Food', amount: 11000, budgetId: budgetId),
    );
    expect(
      store.isCategoryOverCap(budgetId, 'Food',
          now: DateTime(2026, 11, 14)),
      isFalse,
    );
  });

  test('no cap means unlimited, and a cap is per budget', () async {
    final store = await makeStore();
    final firstId = store.activeBudgetId;
    // Budget ids come from the clock (milliseconds), so wait a
    // tick — two budgets made in the same millisecond would
    // share one id.
    await Future.delayed(const Duration(milliseconds: 2));
    await store.addBudget(30000, name: 'Business');
    final secondId = store.activeBudgetId;
    expect(
      store.isCategoryOverCap(firstId, 'Food',
          now: DateTime(2026, 11, 14)),
      isFalse,
    );
    await store.setCategoryCap(
      CategoryCap(category: 'Food', amount: 1000, budgetId: firstId),
    );
    expect(store.capFor(firstId, 'Food')?.amount, 1000);
    // The same category in the other budget is still unlimited.
    expect(store.capFor(secondId, 'Food'), isNull);
    expect(
      store.isCategoryOverCap(secondId, 'Food',
          now: DateTime(2026, 11, 14)),
      isFalse,
    );
  });

  test('setting a cap twice replaces it; 0 removes it', () async {
    final store = await makeStore();
    final budgetId = store.activeBudgetId;
    await store.setCategoryCap(
      CategoryCap(category: 'Bills', amount: 5000, budgetId: budgetId),
    );
    await store.setCategoryCap(
      CategoryCap(category: 'Bills', amount: 8000, budgetId: budgetId),
    );
    expect(store.categoryCaps.length, 1);
    expect(store.capFor(budgetId, 'Bills')?.amount, 8000);
    await store.setCategoryCap(
      CategoryCap(category: 'Bills', amount: 0, budgetId: budgetId),
    );
    expect(store.capFor(budgetId, 'Bills'), isNull);
    expect(store.categoryCaps, isEmpty);
  });

  test('removing a cap clears it', () async {
    final store = await makeStore();
    final budgetId = store.activeBudgetId;
    await store.setCategoryCap(
      CategoryCap(
          category: 'Transport', amount: 4000, budgetId: budgetId),
    );
    await store.removeCategoryCap(budgetId, 'Transport');
    expect(store.capFor(budgetId, 'Transport'), isNull);
  });

  test('caps survive a fresh store load', () async {
    final store = await makeStore();
    final budgetId = store.activeBudgetId;
    await store.setCategoryCap(
      CategoryCap(category: 'Food', amount: 15000, budgetId: budgetId),
    );
    // A fresh store reads the same (mock) SharedPreferences.
    final reloaded = ExpenseStore();
    await reloaded.load();
    expect(reloaded.categoryCaps.length, 1);
    expect(reloaded.capFor(budgetId, 'Food')?.amount, 15000);
  });

  test('backup round-trips caps; old backups import as no caps',
      () async {
    final store = await makeStore();
    final budgetId = store.activeBudgetId;
    await store.setCategoryCap(
      CategoryCap(category: 'Food', amount: 15000, budgetId: budgetId),
    );
    final json = store.exportBackupJson();
    expect(json, contains('categoryCaps'));
    expect(json, contains('15000'));

    SharedPreferences.setMockInitialValues({});
    final restored = ExpenseStore();
    await restored.load();
    expect(await restored.importBackupJson(json), isTrue);
    expect(restored.categoryCaps.length, 1);
    expect(restored.capFor(budgetId, 'Food')?.amount, 15000);

    // A v7.4 backup has no 'categoryCaps' key at all.
    SharedPreferences.setMockInitialValues({});
    final legacy = ExpenseStore();
    await legacy.load();
    expect(
      await legacy.importBackupJson(
        '{"app":"Hisaab Kitaab","version":7,"expenses":[],"budgets":[]}',
      ),
      isTrue,
    );
    expect(legacy.categoryCaps, isEmpty);
  });
}
