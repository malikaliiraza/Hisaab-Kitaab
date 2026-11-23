// Hisaab Kitaab — v7.9 tests: custom expense categories.
//
// Covers the store: add (trim / reject empty, duplicate and
// built-in collision, case-insensitive), rename (updates
// expenses, recurring rules and caps), delete (blocked while
// an expense or a rule uses the category, drops its caps
// when allowed), persistence across a fresh store load,
// backup round-trip (version 9), and that a v8 backup
// without the key imports as no custom categories. Plus one
// widget test for the manage-categories sheet, reached from
// the Add Expense screen the way the real app opens it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cashwise_ai/core/gradient_button.dart';
import 'package:cashwise_ai/features/expenses/data/expense_store.dart';
import 'package:cashwise_ai/features/expenses/models/category_cap.dart';
import 'package:cashwise_ai/features/expenses/models/expense.dart';
import 'package:cashwise_ai/features/expenses/models/recurring_rule.dart';
import 'package:cashwise_ai/features/expenses/presentation/add_expense_screen.dart';

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
  test('add trims, rejects empty, duplicates and built-ins', () async {
    final store = await makeStore();
    expect(store.customCategories, isEmpty);
    expect(store.allCategories, expenseCategories);

    expect(await store.addCustomCategory('  Gym  '), isTrue);
    expect(store.customCategories, ['Gym']);
    expect(store.allCategories,
        [...expenseCategories, 'Gym']);

    // Empty / blank names are rejected.
    expect(await store.addCustomCategory(''), isFalse);
    expect(await store.addCustomCategory('   '), isFalse);
    expect(store.customCategories, ['Gym']);

    // Duplicates are rejected, case-insensitively.
    expect(await store.addCustomCategory('Gym'), isFalse);
    expect(await store.addCustomCategory('gym'), isFalse);
    expect(await store.addCustomCategory('GYM'), isFalse);

    // A name that equals a built-in category is rejected,
    // whatever the case.
    expect(await store.addCustomCategory('Food'), isFalse);
    expect(await store.addCustomCategory('food'), isFalse);
    expect(await store.addCustomCategory('Other'), isFalse);
    expect(store.customCategories, ['Gym']);
  });

  test('rename updates expenses, rules and caps', () async {
    final store = await makeStore();
    final budgetId = store.activeBudgetId;
    await store.addCustomCategory('Gym');
    await addExpense(
        store, 'e1', 2000, 'Gym', DateTime(2026, 11, 20));
    await store.addRecurringRule(
      RecurringRule(
        id: 'r1',
        title: 'Gym fee',
        amountPkr: 3000,
        category: 'Gym',
        budgetId: budgetId,
        dayOfMonth: 1,
        createdAt: DateTime(2026, 11, 1),
      ),
    );
    await store.setCategoryCap(
      CategoryCap(category: 'Gym', amount: 5000, budgetId: budgetId),
    );

    expect(await store.renameCustomCategory('Gym', 'Fitness'), isTrue);
    expect(store.customCategories, ['Fitness']);
    expect(store.allExpenses.first.category, 'Fitness');
    expect(store.recurringRules.first.category, 'Fitness');
    expect(store.capFor(budgetId, 'Fitness')?.amount, 5000);
    expect(store.capFor(budgetId, 'Gym'), isNull);

    // A rename that only changes the case is allowed.
    expect(
        await store.renameCustomCategory('Fitness', 'FITNESS'), isTrue);
    expect(store.customCategories, ['FITNESS']);
    expect(store.allExpenses.first.category, 'FITNESS');
  });

  test('rename rejects bad names and built-in categories', () async {
    final store = await makeStore();
    await store.addCustomCategory('Gym');
    await store.addCustomCategory('Petrol');

    // Empty new name.
    expect(await store.renameCustomCategory('Gym', '  '), isFalse);
    // Collision with another custom category (any case).
    expect(await store.renameCustomCategory('Gym', 'petrol'), isFalse);
    // Collision with a built-in category.
    expect(await store.renameCustomCategory('Gym', 'Food'), isFalse);
    // Built-in categories cannot be renamed at all.
    expect(await store.renameCustomCategory('Food', 'Meals'), isFalse);
    // Unknown names cannot be renamed.
    expect(
        await store.renameCustomCategory('Nope', 'Something'), isFalse);
    expect(store.customCategories, ['Gym', 'Petrol']);
  });

  test('delete is blocked while used, drops caps when allowed',
      () async {
    final store = await makeStore();
    final budgetId = store.activeBudgetId;
    await store.addCustomCategory('Gym');
    await store.addCustomCategory('Petrol');
    await store.setCategoryCap(
      CategoryCap(category: 'Petrol', amount: 4000, budgetId: budgetId),
    );

    // An expense using the category blocks the delete.
    await addExpense(
        store, 'e1', 2000, 'Gym', DateTime(2026, 11, 20));
    expect(await store.deleteCustomCategory('Gym'), isFalse);
    expect(store.customCategories, contains('Gym'));

    // A recurring rule using the category blocks it too.
    await store.removeExpense('e1');
    await store.addRecurringRule(
      RecurringRule(
        id: 'r1',
        title: 'Gym fee',
        amountPkr: 3000,
        category: 'Gym',
        budgetId: budgetId,
        dayOfMonth: 1,
        createdAt: DateTime(2026, 11, 1),
      ),
    );
    expect(await store.deleteCustomCategory('Gym'), isFalse);

    // Once nothing uses it, the delete goes through.
    await store.removeRecurringRule('r1');
    expect(await store.deleteCustomCategory('Gym'), isTrue);
    expect(store.customCategories, ['Petrol']);

    // Deleting a category drops its caps with it.
    expect(await store.deleteCustomCategory('Petrol'), isTrue);
    expect(store.customCategories, isEmpty);
    expect(store.capFor(budgetId, 'Petrol'), isNull);

    // Built-in categories and unknown names cannot be deleted.
    expect(await store.deleteCustomCategory('Food'), isFalse);
    expect(await store.deleteCustomCategory('Nope'), isFalse);
  });

  test('custom categories survive a fresh store load', () async {
    final store = await makeStore();
    await store.addCustomCategory('Gym');
    await store.addCustomCategory('Petrol');
    final reloaded = ExpenseStore();
    await reloaded.load();
    expect(reloaded.customCategories, ['Gym', 'Petrol']);
    expect(reloaded.allCategories,
        [...expenseCategories, 'Gym', 'Petrol']);
  });

  test('backup round-trips custom categories; v8 imports as none',
      () async {
    final store = await makeStore();
    await store.addCustomCategory('Gym');
    await addExpense(
        store, 'e1', 2000, 'Gym', DateTime(2026, 11, 20));
    final json = store.exportBackupJson();
    expect(json, contains('"version":9'));
    expect(json, contains('"customCategories":["Gym"]'));

    SharedPreferences.setMockInitialValues({});
    final restored = ExpenseStore();
    await restored.load();
    expect(await restored.importBackupJson(json), isTrue);
    expect(restored.customCategories, ['Gym']);
    expect(restored.allExpenses.first.category, 'Gym');

    // A v8 backup has no 'customCategories' key at all.
    SharedPreferences.setMockInitialValues({});
    final legacy = ExpenseStore();
    await legacy.load();
    expect(
      await legacy.importBackupJson(
        '{"app":"Hisaab Kitaab","version":8,"expenses":[],"budgets":[]}',
      ),
      isTrue,
    );
    expect(legacy.customCategories, isEmpty);
  });

  group('manage categories sheet', () {
    Future<void> pumpAddExpense(WidgetTester tester) async {
      final store = await makeStore();
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
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
                        builder: (_) => const AddExpenseScreen(),
                      ),
                    ),
                    child: const Text('add expense'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('add expense'));
      await tester.pumpAndSettle();
      // Keep the store reachable for assertions.
      expect(find.text('Manage categories'), findsOneWidget);
    }

    testWidgets('adding a category in the sheet adds its chip',
        (tester) async {
      await pumpAddExpense(tester);

      await tester.tap(find.text('Manage categories'));
      await tester.pumpAndSettle();

      // The sheet lists the built-ins and the empty state.
      expect(find.text('Built-in'), findsOneWidget);
      expect(find.text('Your categories'), findsOneWidget);
      expect(find.text('No custom categories yet — add one above.'),
          findsOneWidget);

      await tester.enterText(
          find.byKey(const Key('newCategoryField')), 'Gym');
      await tester.tap(
          find.widgetWithText(GradientButton, 'Add category'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ListTile, 'Gym'), findsOneWidget);
      expect(
          find.text('No custom categories yet — add one above.'),
          findsNothing);

      // Back on the Add Expense screen: tap the scrim above the
      // sheet to close it, then Gym is a chip there.
      await tester.tapAt(const Offset(200, 100));
      await tester.pumpAndSettle();
      expect(find.text('Your categories'), findsNothing);
      expect(find.widgetWithText(ChoiceChip, 'Gym'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('duplicate name shows the error in the sheet',
        (tester) async {
      await pumpAddExpense(tester);

      await tester.tap(find.text('Manage categories'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const Key('newCategoryField')), 'Food');
      await tester.tap(
          find.widgetWithText(GradientButton, 'Add category'));
      await tester.pumpAndSettle();

      expect(find.text('A category with this name already exists.'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
