// Hisaab Kitaab — v7.4 PIN lock tests (coordinator).
//
// The stretch feature: a 4-digit PIN is accepted, a wrong
// PIN is refused, anything that is not exactly 4 digits is
// refused, and clearing the PIN turns the lock off. The
// stored value is a hash — the PIN itself is never saved.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cashwise_ai/features/expenses/data/expense_store.dart';

void main() {
  test('PIN lock: set, verify, refuse wrong, clear', () async {
    SharedPreferences.setMockInitialValues({});
    final store = ExpenseStore();
    await store.load();

    expect(store.pinEnabled, isFalse);
    expect(store.pinUnlocked, isFalse);

    // Not 4 digits: refused.
    expect(await store.setPin('123'), isFalse);
    expect(await store.setPin('12345'), isFalse);
    expect(await store.setPin('12ab'), isFalse);
    expect(store.pinEnabled, isFalse);

    // 4 digits: set, and setting unlocks this session.
    expect(await store.setPin('2468'), isTrue);
    expect(store.pinEnabled, isTrue);
    expect(store.pinUnlocked, isTrue);

    // A fresh load locks again (transient unlock).
    SharedPreferences.setMockInitialValues(
        {'cashwise_pin_v1': await _storedHash()});
    final reopened = ExpenseStore();
    await reopened.load();
    expect(reopened.pinEnabled, isTrue);
    expect(reopened.pinUnlocked, isFalse);

    // Wrong PIN stays locked; right PIN unlocks.
    expect(reopened.verifyPin('0000'), isFalse);
    expect(reopened.pinUnlocked, isFalse);
    expect(reopened.verifyPin('2468'), isTrue);
    expect(reopened.pinUnlocked, isTrue);

    // Clearing turns the lock off entirely.
    await reopened.clearPin();
    expect(reopened.pinEnabled, isFalse);
    expect(reopened.pinUnlocked, isFalse);
  });

  test('the stored PIN value is a hash, never the PIN itself', () async {
    SharedPreferences.setMockInitialValues({});
    final store = ExpenseStore();
    await store.load();
    await store.setPin('2468');
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('cashwise_pin_v1') ?? '';
    expect(stored, isNotEmpty);
    expect(stored.contains('2468'), isFalse);
    expect(stored.length, 64); // SHA-256 hex.
  });
}

/// The hash the first test stored — recomputed here so the
/// "fresh load" step reads the same value from prefs.
Future<String> _storedHash() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('cashwise_pin_v1') ?? '';
}
