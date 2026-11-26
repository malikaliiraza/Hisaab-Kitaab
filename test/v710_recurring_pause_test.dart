// Hisaab Kitaab — v7.10 tests: pause/resume recurring bills.
//
//  1. The `paused` flag survives a JSON round-trip, and old
//     saved rules without the key load as unpaused.
//  2. `nextPostDateFor` returns the next posting date: this
//     month's clamped day when it has not passed yet and the
//     rule has not posted this month, otherwise next month's
//     clamped day — and null when the rule is paused.
//  3. `postDueRecurring` never posts a paused rule, and a
//     paused rule keeps its lastPostedMonth untouched.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cashwise_ai/features/expenses/data/expense_store.dart';
import 'package:cashwise_ai/features/expenses/models/recurring_rule.dart';

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

RecurringRule rule({
  String id = 'r1',
  int dayOfMonth = 10,
  bool paused = false,
  String lastPostedMonth = '',
}) =>
    RecurringRule(
      id: id,
      title: 'Electricity bill',
      amountPkr: 5000,
      category: 'Bills',
      budgetId: '',
      dayOfMonth: dayOfMonth,
      createdAt: DateTime(2026, 11, 1),
      lastPostedMonth: lastPostedMonth,
      paused: paused,
    );

void main() {
  test('paused survives a JSON round-trip', () {
    final restored = RecurringRule.fromJson(rule(paused: true).toJson());
    expect(restored.paused, isTrue);
    expect(restored.title, 'Electricity bill');
    expect(restored.dayOfMonth, 10);

    final active = RecurringRule.fromJson(rule().toJson());
    expect(active.paused, isFalse);
  });

  test('a rule saved without the paused key loads as unpaused', () {
    final json = rule().toJson()..remove('paused');
    expect(RecurringRule.fromJson(json).paused, isFalse);
  });

  test('copyWith keeps paused unless told otherwise', () {
    final pausedRule = rule(paused: true);
    expect(pausedRule.copyWith(title: 'New name').paused, isTrue);
    expect(pausedRule.copyWith(paused: false).paused, isFalse);
    expect(rule().copyWith(paused: true).paused, isTrue);
  });

  test('nextPostDateFor: this month when the day has not passed', () {
    final store = ExpenseStore();
    expect(
      store.nextPostDateFor(rule(dayOfMonth: 10), now: DateTime(2026, 11, 5)),
      DateTime(2026, 11, 10),
    );
    // The day itself, not posted yet, posts today.
    expect(
      store.nextPostDateFor(rule(dayOfMonth: 10), now: DateTime(2026, 11, 10)),
      DateTime(2026, 11, 10),
    );
  });

  test('nextPostDateFor: a 31st rule clamps to the 30th', () {
    final store = ExpenseStore();
    expect(
      store.nextPostDateFor(rule(dayOfMonth: 31), now: DateTime(2026, 11, 10)),
      DateTime(2026, 11, 30),
    );
    // February clamps to the 28th.
    expect(
      store.nextPostDateFor(rule(dayOfMonth: 31), now: DateTime(2027, 2, 10)),
      DateTime(2027, 2, 28),
    );
  });

  test('nextPostDateFor: day already passed goes to next month', () {
    final store = ExpenseStore();
    expect(
      store.nextPostDateFor(rule(dayOfMonth: 10), now: DateTime(2026, 11, 15)),
      DateTime(2026, 12, 10),
    );
    // A 31st rule already posted in November posts on
    // 31 December, not the 30th.
    expect(
      store.nextPostDateFor(
        rule(dayOfMonth: 31, lastPostedMonth: '2026-11'),
        now: DateTime(2026, 11, 30),
      ),
      DateTime(2026, 12, 31),
    );
  });

  test('nextPostDateFor: already posted this month goes to next month',
      () {
    final store = ExpenseStore();
    expect(
      store.nextPostDateFor(
        rule(dayOfMonth: 10, lastPostedMonth: '2026-11'),
        now: DateTime(2026, 11, 5),
      ),
      DateTime(2026, 12, 10),
    );
  });

  test('nextPostDateFor: a paused rule has no next date', () {
    final store = ExpenseStore();
    expect(
      store.nextPostDateFor(
        rule(dayOfMonth: 10, paused: true),
        now: DateTime(2026, 11, 5),
      ),
      isNull,
    );
  });

  test('postDueRecurring posts an active due rule, not a paused one',
      () async {
    final store = await makeStore();
    await store.addRecurringRule(
      rule(id: 'r-active', dayOfMonth: 10),
    );
    await store.addRecurringRule(
      rule(id: 'r-paused', dayOfMonth: 10, paused: true),
    );

    // 10 Nov: only the active rule posts.
    expect(store.postDueRecurring(now: DateTime(2026, 11, 10)), 1);
    expect(store.allExpenses.length, 1);
    expect(store.allExpenses.first.id, 'rec-r-active-2026-11');

    // The paused rule's lastPostedMonth is untouched, so it
    // still has a cycle to post once it is resumed.
    final paused = store.recurringRules
        .firstWhere((r) => r.id == 'r-paused');
    expect(paused.lastPostedMonth, '');
    expect(paused.paused, isTrue);

    // The active rule recorded this month.
    final active = store.recurringRules
        .firstWhere((r) => r.id == 'r-active');
    expect(active.lastPostedMonth, '2026-11');

    // Next month the paused rule still does not post.
    expect(store.postDueRecurring(now: DateTime(2026, 12, 10)), 1);
    expect(store.allExpenses.length, 2);
  });

  test('a paused rule posts again once resumed', () async {
    final store = await makeStore();
    await store.addRecurringRule(
      rule(id: 'r1', dayOfMonth: 10, paused: true),
    );
    expect(store.postDueRecurring(now: DateTime(2026, 11, 10)), 0);
    await store.updateRecurringRule(
      store.recurringRules.first.copyWith(paused: false),
    );
    expect(store.postDueRecurring(now: DateTime(2026, 11, 10)), 1);
    expect(store.allExpenses.length, 1);
  });

  test('renaming a category keeps a rule paused', () async {
    final store = await makeStore();
    await store.addCustomCategory('Gym');
    await store.addRecurringRule(
      RecurringRule(
        id: 'r1',
        title: 'Gym fee',
        amountPkr: 3000,
        category: 'Gym',
        budgetId: store.activeBudgetId,
        dayOfMonth: 5,
        createdAt: DateTime(2026, 11, 1),
        paused: true,
      ),
    );
    expect(await store.renameCustomCategory('Gym', 'Fitness'), isTrue);
    final renamed =
        store.recurringRules.firstWhere((r) => r.id == 'r1');
    expect(renamed.category, 'Fitness');
    expect(renamed.paused, isTrue);
  });
}
