// Hisaab Kitaab — v7.8 tests: expense search, filter and
// sort (pure Dart), the filtered CSV export, and the
// budget detail screen's search + filter + sort controls.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cashwise_ai/features/expenses/data/expense_search.dart';
import 'package:cashwise_ai/features/expenses/data/expense_store.dart';
import 'package:cashwise_ai/features/expenses/models/expense.dart';
import 'package:cashwise_ai/features/expenses/presentation/budget_detail_screen.dart';

Expense expense(
  String id,
  String title,
  double amount,
  String category,
  DateTime date, {
  String budgetId = '',
}) =>
    Expense(
      id: id,
      title: title,
      amountPkr: amount,
      category: category,
      date: date,
      budgetId: budgetId,
    );

final sample = [
  expense('a', 'Grocery run', 500, 'Food', DateTime(2026, 11, 20)),
  expense('b', 'Bus ticket', 200, 'Transport', DateTime(2026, 11, 18)),
  expense('c', 'Electric bill', 3000, 'Bills', DateTime(2026, 11, 10)),
  expense('d', 'Biryani lunch', 800, 'Food', DateTime(2026, 11, 5)),
];

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
  group('filterExpenses', () {
    test('empty query matches everything', () {
      expect(filterExpenses(sample), hasLength(4));
      expect(filterExpenses(sample, query: '   '), hasLength(4));
    });

    test('query matches title, case-insensitive, trimmed', () {
      final found = filterExpenses(sample, query: '  BIRYANI ');
      expect(found.map((e) => e.id), ['d']);
    });

    test('query matches category text too', () {
      final found = filterExpenses(sample, query: 'food');
      expect(found.map((e) => e.id), ['a', 'd']);
    });

    test('category filter keeps only that category', () {
      final found = filterExpenses(sample, category: 'Food');
      expect(found.map((e) => e.id), ['a', 'd']);
    });

    test("'All' category matches everything", () {
      expect(
        filterExpenses(sample, category: 'All'),
        hasLength(4),
      );
    });

    test('query and category combine', () {
      final found = filterExpenses(
        sample,
        query: 'bill',
        category: 'Bills',
      );
      expect(found.map((e) => e.id), ['c']);
      expect(
        filterExpenses(sample, query: 'bill', category: 'Food'),
        isEmpty,
      );
    });

    test('no match gives an empty list', () {
      expect(filterExpenses(sample, query: 'zzz'), isEmpty);
    });
  });

  group('sortExpenses', () {
    test('newest first by date', () {
      final sorted = sortExpenses(sample, ExpenseSort.newest);
      expect(sorted.map((e) => e.id), ['a', 'b', 'c', 'd']);
    });

    test('oldest first by date', () {
      final sorted = sortExpenses(sample, ExpenseSort.oldest);
      expect(sorted.map((e) => e.id), ['d', 'c', 'b', 'a']);
    });

    test('highest amount first', () {
      final sorted =
          sortExpenses(sample, ExpenseSort.amountHighToLow);
      expect(sorted.map((e) => e.id), ['c', 'd', 'a', 'b']);
    });

    test('lowest amount first', () {
      final sorted =
          sortExpenses(sample, ExpenseSort.amountLowToHigh);
      expect(sorted.map((e) => e.id), ['b', 'a', 'd', 'c']);
    });

    test('input list is never mutated, result is a new list', () {
      final original = List<Expense>.of(sample);
      final sorted =
          sortExpenses(sample, ExpenseSort.amountHighToLow);
      expect(identical(sorted, sample), isFalse);
      expect(sample.map((e) => e.id), original.map((e) => e.id));
    });
  });

  group('exportExpensesCsvFor', () {
    test('exports only the given list, same header and quoting',
        () async {
      final store = await makeStore();
      final budgetId = store.budgets.first.id;
      await store.addExpense(expense(
        'a',
        'Grocery run',
        500,
        'Food',
        DateTime(2026, 11, 20),
        budgetId: budgetId,
      ));
      await store.addExpense(expense(
        'b',
        'Bus ticket',
        200,
        'Transport',
        DateTime(2026, 11, 18),
        budgetId: budgetId,
      ));
      await store.addExpense(expense(
        'c',
        'Lunch, with "friends"',
        800,
        'Food',
        DateTime(2026, 11, 5),
        budgetId: budgetId,
      ));

      final filtered =
          filterExpenses(store.expenses, query: 'grocery');
      final csv = store.exportExpensesCsvFor(filtered);
      expect(csv, 'Date,Title,Category,Budget,Amount (Rs.)\n'
          '2026-11-20,Grocery run,Food,Home,500');

      // The full export still covers every expense, and the
      // comma/quote in a title is quoted the same way.
      final full = store.exportExpensesCsv();
      expect(full.split('\n'), hasLength(4));
      expect(
        full,
        contains('2026-11-05,"Lunch, with ""friends""",Food,Home,800'),
      );
    });
  });

  group('budget detail screen search + filter + sort', () {
    List<String> shownTitles(WidgetTester tester) => tester
        .widgetList<ListTile>(find.byType(ListTile))
        .map((t) => (t.title as Text).data!)
        .toList();

    Future<void> pumpDetail(WidgetTester tester) async {
      final store = await makeStore();
      final budgetId = store.budgets.first.id;
      await store.addExpense(expense(
        'a',
        'Grocery run',
        500,
        'Food',
        DateTime(2026, 11, 20),
        budgetId: budgetId,
      ));
      await store.addExpense(expense(
        'b',
        'Bus ticket',
        200,
        'Transport',
        DateTime(2026, 11, 18),
        budgetId: budgetId,
      ));
      await store.addExpense(expense(
        'c',
        'Electric bill',
        3000,
        'Bills',
        DateTime(2026, 11, 10),
        budgetId: budgetId,
      ));

      // The detail screen is pushed from a list screen in
      // the real app, so the test pushes it the same way
      // (see the v7.7 Duplicate test).
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
                        builder: (_) => BudgetDetailScreen(
                          budget: store.budgets.first,
                        ),
                      ),
                    ),
                    child: const Text('open budget'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('open budget'));
      await tester.pumpAndSettle();
    }

    testWidgets('typing a query filters the list and shows the count',
        (tester) async {
      await pumpDetail(tester);

      expect(shownTitles(tester),
          ['Grocery run', 'Bus ticket', 'Electric bill']);
      expect(find.byIcon(Icons.share), findsNothing);

      final search = find.byType(TextField);
      await tester.ensureVisible(search);
      await tester.enterText(search, 'bus');
      await tester.pumpAndSettle();

      expect(shownTitles(tester), ['Bus ticket']);
      expect(find.text('Showing 1 of 3 expenses'), findsOneWidget);
      // A filter is active, so the share button appears.
      expect(find.byIcon(Icons.share), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('no match shows the empty message, not the list',
        (tester) async {
      await pumpDetail(tester);

      final search = find.byType(TextField);
      await tester.ensureVisible(search);
      await tester.enterText(search, 'zzz');
      await tester.pumpAndSettle();

      expect(find.byType(ListTile), findsNothing);
      expect(
        find.text('No expenses match your search.'),
        findsOneWidget,
      );
      expect(find.text('Showing 0 of 3 expenses'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('category chip filters, sort reorders the list',
        (tester) async {
      await pumpDetail(tester);

      // Only the categories this budget has get a chip.
      expect(find.widgetWithText(ChoiceChip, 'Food'), findsOneWidget);
      expect(
        find.widgetWithText(ChoiceChip, 'Health'),
        findsNothing,
      );

      final foodChip = find.widgetWithText(ChoiceChip, 'Food');
      await tester.ensureVisible(foodChip);
      await tester.tap(foodChip);
      await tester.pumpAndSettle();
      expect(shownTitles(tester), ['Grocery run']);
      expect(find.text('Showing 1 of 3 expenses'), findsOneWidget);

      // Back to all, then sort by highest amount.
      final allChip = find.widgetWithText(ChoiceChip, 'All categories');
      await tester.ensureVisible(allChip);
      await tester.tap(allChip);
      await tester.pumpAndSettle();

      final sort = find.byType(DropdownButton<ExpenseSort>);
      await tester.ensureVisible(sort);
      await tester.tap(sort);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Highest amount').last);
      await tester.pumpAndSettle();

      expect(shownTitles(tester),
          ['Electric bill', 'Grocery run', 'Bus ticket']);
      expect(find.text('Showing 3 of 3 expenses'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
