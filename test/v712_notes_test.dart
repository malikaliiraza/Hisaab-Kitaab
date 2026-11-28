// Hisaab Kitaab — v7.12 tests: expense notes.
//
//  1. `note` survives a JSON round-trip, and old saved
//     expenses without the key load as ''.
//  2. `filterExpenses` finds an expense by a word that only
//     appears in its note, and still finds by title/category.
//  3. Store-level: `addExpense` with a note persists it
//     (including across a reload), `updateExpense` changes
//     it, and `duplicateExpense` copies it.
//  4. `exportExpensesCsvFor` includes the note as the last
//     column, quoted like every other field.
//  5. The expense detail screen shows the note in view mode.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cashwise_ai/features/expenses/data/expense_search.dart';
import 'package:cashwise_ai/features/expenses/data/expense_store.dart';
import 'package:cashwise_ai/features/expenses/models/expense.dart';
import 'package:cashwise_ai/features/expenses/presentation/expense_detail_screen.dart';

Expense expense(
  String id,
  String title,
  double amount,
  String category,
  DateTime date, {
  String note = '',
}) =>
    Expense(
      id: id,
      title: title,
      amountPkr: amount,
      category: category,
      date: date,
      note: note,
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
  test('note survives a JSON round-trip', () {
    final withNote = expense(
      'e1',
      'Groceries',
      2500,
      'Food',
      DateTime(2026, 11, 28),
      note: 'Bought at Imtiaz Super Market',
    );
    final restored = Expense.fromJson(withNote.toJson());
    expect(restored.note, 'Bought at Imtiaz Super Market');
    expect(restored.title, 'Groceries');
    expect(restored.amountPkr, 2500);

    // Old saved expenses have no note key at all.
    final old = Expense.fromJson({
      'id': 'e0',
      'title': 'Bus ticket',
      'amountPkr': 200,
      'category': 'Transport',
      'date': DateTime(2026, 11, 20).toIso8601String(),
    });
    expect(old.note, '');
    // And one written without a note serialises as ''.
    expect(
      Expense.fromJson(expense('e2', 'Tea', 100, 'Food',
              DateTime(2026, 11, 28))
          .toJson())
          .note,
      '',
    );
  });

  group('filterExpenses', () {
    final sample = [
      expense('a', 'Groceries', 2500, 'Food', DateTime(2026, 11, 28),
          note: 'Bought at Imtiaz Super Market'),
      expense('b', 'Bus ticket', 200, 'Transport',
          DateTime(2026, 11, 27)),
      expense('c', 'Biryani lunch', 800, 'Food', DateTime(2026, 11, 26),
          note: 'With Ahmed at the dhaba'),
    ];

    test('query matches a word only in the note', () {
      final found = filterExpenses(sample, query: 'imtiaz');
      expect(found.map((e) => e.id), ['a']);
      expect(
        filterExpenses(sample, query: '  DHABA '),
        hasLength(1),
      );
      expect(
        filterExpenses(sample, query: 'dhaba').first.id,
        'c',
      );
    });

    test('query still matches title and category', () {
      expect(
        filterExpenses(sample, query: 'biryani').map((e) => e.id),
        ['c'],
      );
      expect(
        filterExpenses(sample, query: 'food').map((e) => e.id),
        ['a', 'c'],
      );
      // A word in no title, category or note matches nothing.
      expect(filterExpenses(sample, query: 'zzz'), isEmpty);
    });
  });

  group('store', () {
    test('addExpense persists the note, across a reload', () async {
      final store = await makeStore();
      await store.addExpense(expense(
        'e1',
        'Groceries',
        2500,
        'Food',
        DateTime(2026, 11, 28),
        note: 'Bought at Imtiaz Super Market',
      ));
      expect(store.expenses.single.note,
          'Bought at Imtiaz Super Market');

      final reloaded = ExpenseStore();
      await reloaded.load();
      expect(reloaded.expenses.single.note,
          'Bought at Imtiaz Super Market');
    });

    test('updateExpense changes the note', () async {
      final store = await makeStore();
      await store.addExpense(expense(
        'e1',
        'Groceries',
        2500,
        'Food',
        DateTime(2026, 11, 28),
        note: 'Bought at Imtiaz',
      ));
      await store.updateExpense(expense(
        'e1',
        'Groceries',
        2500,
        'Food',
        DateTime(2026, 11, 28),
        note: 'Bought at Chase Up instead',
      ));
      expect(store.expenses.single.note,
          'Bought at Chase Up instead');

      // Clearing the note works too.
      await store.updateExpense(expense(
        'e1',
        'Groceries',
        2500,
        'Food',
        DateTime(2026, 11, 28),
      ));
      expect(store.expenses.single.note, '');
    });

    test('duplicateExpense copies the note', () async {
      final store = await makeStore();
      await store.addExpense(expense(
        'e1',
        'Groceries',
        2500,
        'Food',
        DateTime(2026, 11, 28),
        note: 'Bought at Imtiaz Super Market',
      ));
      final copy = await store.duplicateExpense(store.expenses.single);
      expect(copy, isNotNull);
      expect(copy!.note, 'Bought at Imtiaz Super Market');
      expect(copy.id, isNot(store.expenses.last.id));
      expect(store.expenses, hasLength(2));
    });
  });

  test('exportExpensesCsvFor includes the note column', () async {
    final store = await makeStore();
    await store.addExpense(expense(
      'a',
      'Groceries',
      2500,
      'Food',
      DateTime(2026, 11, 28),
      note: 'Bought at Imtiaz, with "Ahmed"',
    ));
    await store.addExpense(expense(
      'b',
      'Bus ticket',
      200,
      'Transport',
      DateTime(2026, 11, 27),
    ));

    final csv = store.exportExpensesCsv();
    final lines = csv.split('\n');
    expect(lines.first, 'Date,Title,Category,Budget,Amount (Rs.),Note');
    expect(lines, hasLength(3));
    // addExpense puts the newest first, so the bus ticket
    // (added last) is the first row, with an empty note.
    expect(lines[1], '2026-11-27,Bus ticket,Transport,Home,200,');
    // The comma and quotes in the note are quoted, like a title.
    expect(
      lines[2],
      '2026-11-28,Groceries,Food,Home,2500,'
      '"Bought at Imtiaz, with ""Ahmed"""',
    );
  });

  testWidgets('detail screen shows the note in view mode',
      (tester) async {
    final store = await makeStore();
    final noted = expense(
      'e1',
      'Groceries',
      2500,
      'Food',
      DateTime(2026, 11, 28),
      note: 'Bought at Imtiaz Super Market',
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<ExpenseStore>.value(
        value: store,
        child: MaterialApp(
          home: ExpenseDetailScreen(expense: noted),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bought at Imtiaz Super Market'), findsOneWidget);
    expect(find.text('Note (optional)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('detail screen hides the note section when empty',
      (tester) async {
    final store = await makeStore();
    final plain = expense(
      'e1',
      'Bus ticket',
      200,
      'Transport',
      DateTime(2026, 11, 27),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<ExpenseStore>.value(
        value: store,
        child: MaterialApp(
          home: ExpenseDetailScreen(expense: plain),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Note (optional)'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
