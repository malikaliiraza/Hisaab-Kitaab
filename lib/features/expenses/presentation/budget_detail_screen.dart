// Hisaab Kitaab — one budget's own home page (v7.2).
//
// Tapping a budget opens its OWN home: its name, its totals,
// then its own options as full-width rows — Details, Add
// Expense, AI Predictor, Summary — ALL scoped to this budget
// (StatisticsScreen / AddExpenseScreen with budgetId), never
// the global active budget. Below the options: its categories
// with totals and its own expense list. Going back shows the
// budget list again.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/amount_row.dart';
import '../../../core/page_transitions.dart';
import '../../../core/share_file.dart';
import '../../../core/theme.dart';
import '../data/expense_search.dart';
import '../data/expense_store.dart';
import '../models/budget.dart';
import '../models/expense.dart';
import 'add_expense_screen.dart';
import 'budget_screen.dart';
import 'category_cap_sheet.dart';
import 'expense_detail_screen.dart';
import 'statistics_screen.dart';

/// Short date, one line: "12 Nov 2026" in English; Urdu months
/// are already short, so the store format is used as-is there.
String shortDate(ExpenseStore store, DateTime date) {
  if (store.locale.code == 'ur') return store.formatDate(date);
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

class BudgetDetailScreen extends StatefulWidget {
  final BudgetPeriod budget;

  const BudgetDetailScreen({super.key, required this.budget});

  @override
  State<BudgetDetailScreen> createState() => _BudgetDetailScreenState();
}

/// One budget's own home page (v7.2). Search, filter and
/// sort for its expense list arrived in v7.8, so the screen
/// is stateful — the rest of the page is unchanged.
class _BudgetDetailScreenState extends State<BudgetDetailScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  String? _filterCategory;
  ExpenseSort _sort = ExpenseSort.newest;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Share just the filtered list as a CSV (v7.8) — the
  /// same share helper the Backup screen uses.
  Future<void> _shareFiltered(
    ExpenseStore store,
    List<Expense> filtered,
  ) async {
    final now = DateTime.now();
    final name =
        'hisaab-kitaab-filtered-${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}.csv';
    await shareTextFile(
      fileName: name,
      content: store.exportExpensesCsvFor(filtered),
      mimeType: 'text/csv',
    );
  }

  static Color _secondary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? CashWiseTheme.darkSecondaryText
          : CashWiseTheme.secondaryText;

  Future<void> _rename(BuildContext context, ExpenseStore store) async {
    final strings = store.strings;
    final controller =
        TextEditingController(text: store.budgetDisplayName(widget.budget));
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.renameBudget),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: strings.budgetName,
            hintText: strings.budgetNameHint,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(strings.save),
          ),
        ],
      ),
    );
    if (saved == true && controller.text.trim().isNotEmpty) {
      await store.renameBudget(widget.budget.id, controller.text);
    }
  }

  /// Primary button (v7.2): fixed 48dp, label fully visible —
  /// FittedBox scaleDown, one line, never ellipsised.
  Widget _primaryButton({
    required String label,
    required VoidCallback? onPressed,
  }) {
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: SizedBox(
        height: 48,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: enabled
                  ? const [Color(0xFF0C4444), Color(0xFF0F766E)]
                  : const [Color(0xFF9CA3AF), Color(0xFF6B7280)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// One full-width option row: a tinted icon, a bold label
  /// and a chevron.
  Widget _actionRow({
    required BuildContext context,
    required String label,
    required IconData icon,
    required Color tint,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor:
                    isDark ? CashWiseTheme.darkCard : tint,
                foregroundColor: iconColor,
                child: Icon(icon, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: _secondary(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ExpenseStore>();
    final strings = store.strings;
    // Re-read the budget from the store, so a rename shows
    // immediately without leaving the screen.
    final b = store.budgets.firstWhere(
      (x) => x.id == widget.budget.id,
      orElse: () => widget.budget,
    );
    final name = store.budgetDisplayName(b);
    final spent = store.budgetSpent(b);
    final remaining = store.budgetRemaining(b);
    final fraction =
        b.amount <= 0 ? 0.0 : (spent / b.amount).clamp(0.0, 1.0);
    final expenses = store.expensesForBudget(b.id);
    final isActive = b.id == store.activeBudgetId;

    // Search, filter and sort for this budget's own list
    // (v7.8) — the pure-Dart helpers in expense_search.dart.
    final filtered = sortExpenses(
      filterExpenses(
        expenses,
        query: _query,
        category: _filterCategory,
      ),
      _sort,
    );
    final filterActive = _query.trim().isNotEmpty ||
        _filterCategory != null ||
        _sort != ExpenseSort.newest;
    // Only the categories this budget actually has get a
    // chip, in the usual category order — custom categories
    // included (v7.9).
    final presentCategories = store.allCategories
        .where((c) => expenses.any((e) => e.category == c))
        .toList();

    // Category totals for this budget only.
    final Map<String, double> byCategory = {};
    for (final e in expenses) {
      byCategory[e.category] =
          (byCategory[e.category] ?? 0) + e.amountPkr;
    }
    final sortedCategories = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxCategory =
        sortedCategories.isEmpty ? 1.0 : sortedCategories.first.value;

    void openDetails(int tab) {
      Navigator.of(context).push(
        slideRoute(
          StatisticsScreen(initialTab: tab, budgetId: b.id),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: CashWiseTheme.headerGradientOf(context),
        ),
        title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, size: 20),
            tooltip: strings.renameBudget,
            onPressed: () => _rename(context, store),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (isActive)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: CashWiseTheme.lightAccent
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    strings.active,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: CashWiseTheme.lightAccent,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          AmountRow(
                            label: strings.budget,
                            amount: store.formatAmount(b.amount),
                          ),
                          // Rollover (v7.11): how much of this
                          // budget came over from the previous one.
                          if (b.carriedAmount > 0)
                            AmountRow(
                              label: strings.carriedOver,
                              amount: store.formatAmount(b.carriedAmount),
                            ),
                          AmountRow(
                            label: strings.spentThisMonth,
                            amount: store.formatAmount(spent),
                          ),
                          AmountRow(
                            label: strings.remaining,
                            amount: store.formatAmount(remaining),
                          ),
                          AmountRow(
                            label: strings.dailyAverage,
                            amount: store.formatAmount(
                                store.budgetDailyAverage(b)),
                          ),
                          AmountRow(
                            label: strings.projectedMonthEnd,
                            amount: store.formatAmount(
                                store.budgetProjectedMonthEnd(b)),
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: fraction,
                              minHeight: 10,
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                fraction >= 1
                                    ? CashWiseTheme.danger
                                    : fraction >= 0.8
                                        ? CashWiseTheme.warning
                                        : CashWiseTheme.lightAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!isActive) ...[
                    _primaryButton(
                      label: strings.useThisBudget,
                      onPressed: () async {
                        await store.switchBudget(b.id);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              strings.budgetNowActive(name),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                  // This budget's own options (v7.2) — every one
                  // scoped to this budget, not the active one.
                  _actionRow(
                    context: context,
                    label: strings.details,
                    icon: Icons.bar_chart,
                    tint: const Color(0xFFF5F3FF),
                    iconColor: const Color(0xFF6D28D9),
                    onTap: () => openDetails(0),
                  ),
                  _actionRow(
                    context: context,
                    label: strings.addExpense,
                    icon: Icons.add,
                    tint: const Color(0xFFECFDF5),
                    iconColor: const Color(0xFF047857),
                    onTap: () {
                      Navigator.of(context).push(
                        slideRoute(
                          AddExpenseScreen(budgetId: b.id),
                        ),
                      );
                    },
                  ),
                  _actionRow(
                    context: context,
                    label: strings.aiPredictor,
                    icon: Icons.psychology,
                    tint: const Color(0xFFE3EDE8),
                    iconColor: const Color(0xFF0F766E),
                    onTap: () => openDetails(1),
                  ),
                  _actionRow(
                    context: context,
                    label: strings.summary,
                    icon: Icons.summarize,
                    tint: const Color(0xFFE0E7FF),
                    iconColor: const Color(0xFF3730A3),
                    onTap: () => openDetails(2),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.edit, size: 20),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          strings.editBudget,
                          maxLines: 1,
                        ),
                      ),
                      onPressed: () async {
                        // The Set budget screen edits the
                        // active budget, so make this one
                        // active first.
                        await store.switchBudget(b.id);
                        if (!context.mounted) return;
                        Navigator.of(context).push(
                          slideRoute(const BudgetScreen()),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    strings.categories,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (sortedCategories.isEmpty)
                    Text(
                      strings.noExpenses,
                      style: TextStyle(
                        color: _secondary(context),
                      ),
                    )
                  else
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            for (final entry in sortedCategories) ...[
                              // Category name WITH its total (v7.2):
                              // the amount sits in one straight
                              // right-aligned column.
                              AmountRow(
                                label: strings.categoryName(entry.key),
                                amount:
                                    store.formatAmount(entry.value),
                                bold: true,
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: maxCategory <= 0
                                      ? 0
                                      : entry.value / maxCategory,
                                  minHeight: 8,
                                  backgroundColor: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                    CashWiseTheme.lightAccent,
                                  ),
                                ),
                              ),
                              // Monthly cap (v7.6): this month's
                              // spend against the cap, with a
                              // warning when it is over — and a
                              // tap to set or change the cap.
                              const SizedBox(height: 6),
                              Builder(
                                builder: (context) {
                                  final cap = store.capFor(
                                    b.id,
                                    entry.key,
                                  );
                                  final spentThisMonth =
                                      store.categorySpentThisMonth(
                                    b.id,
                                    entry.key,
                                  );
                                  final overAmount =
                                      cap != null &&
                                              spentThisMonth > cap.amount
                                          ? spentThisMonth - cap.amount
                                          : null;
                                  final capText = cap == null
                                      ? strings.noCapSet
                                      : '${strings.monthlyCap}: '
                                          '${store.formatAmount(cap.amount)}'
                                          ' • ${strings.thisMonth}: '
                                          '${store.formatAmount(spentThisMonth)}';
                                  return Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              capText,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: _secondary(context),
                                              ),
                                            ),
                                            if (overAmount != null) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                strings.overCapBy(
                                                  store.formatAmount(
                                                    overAmount,
                                                  ),
                                                ),
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight:
                                                      FontWeight.bold,
                                                  color:
                                                      CashWiseTheme.danger,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            showCategoryCapSheet(
                                          context,
                                          budgetId: b.id,
                                          category: entry.key,
                                        ),
                                        child: Text(
                                          cap == null
                                              ? strings.setCategoryCap
                                              : strings.editCategoryCap,
                                          style: const TextStyle(
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                              if (entry != sortedCategories.last)
                                const SizedBox(height: 12),
                            ],
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          strings.expenses,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      // Share just the filtered list (v7.8):
                      // only when a filter is active and there
                      // is something to share.
                      if (filterActive && filtered.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.share, size: 20),
                          tooltip: strings.shareFilteredList,
                          onPressed: () =>
                              _shareFiltered(store, filtered),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Search, sort and category filter (v7.8) —
                  // the same controls as the Details page's
                  // Expenses tab, for this budget's own list.
                  if (expenses.isNotEmpty) ...[
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: strings.searchHint,
                        prefixIcon:
                            const Icon(Icons.search, size: 20),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                icon:
                                    const Icon(Icons.clear, size: 20),
                                tooltip: strings.searchExpenses,
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _query = '');
                                },
                              ),
                      ),
                      onChanged: (value) =>
                          setState(() => _query = value),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          strings.sortBy,
                          style: TextStyle(color: _secondary(context)),
                        ),
                        const SizedBox(width: 8),
                        DropdownButton<ExpenseSort>(
                          value: _sort,
                          underline: const SizedBox.shrink(),
                          items: [
                            DropdownMenuItem(
                              value: ExpenseSort.newest,
                              child: Text(strings.newestFirst),
                            ),
                            DropdownMenuItem(
                              value: ExpenseSort.oldest,
                              child: Text(strings.oldestFirst),
                            ),
                            DropdownMenuItem(
                              value: ExpenseSort.amountHighToLow,
                              child: Text(strings.highestAmount),
                            ),
                            DropdownMenuItem(
                              value: ExpenseSort.amountLowToHigh,
                              child: Text(strings.lowestAmount),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _sort = value);
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        ChoiceChip(
                          label: Text(strings.allCategories),
                          selected: _filterCategory == null,
                          onSelected: (_) =>
                              setState(() => _filterCategory = null),
                        ),
                        ...presentCategories.map(
                          (c) => ChoiceChip(
                            label: Text(strings.categoryName(c)),
                            selected: _filterCategory == c,
                            onSelected: (_) =>
                                setState(() => _filterCategory = c),
                          ),
                        ),
                      ],
                    ),
                    if (filterActive) ...[
                      const SizedBox(height: 8),
                      Text(
                        strings.showingExpenses(
                          filtered.length,
                          expenses.length,
                        ),
                        style: TextStyle(color: _secondary(context)),
                      ),
                    ],
                    const SizedBox(height: 8),
                  ],
                  if (expenses.isEmpty)
                    Text(
                      strings.noExpenses,
                      style: TextStyle(
                        color: _secondary(context),
                      ),
                    )
                  else if (filtered.isEmpty)
                    Text(
                      strings.noMatchingExpenses,
                      style: TextStyle(
                        color: _secondary(context),
                      ),
                    )
                  else
                    ...filtered.map(
                      (e) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: CashWiseTheme.lightAccent
                                .withValues(alpha: 0.15),
                            foregroundColor: CashWiseTheme.lightAccent,
                            child: const Icon(Icons.receipt, size: 20),
                          ),
                          title: Text(
                            e.title.isEmpty
                                ? strings.categoryName(e.category)
                                : e.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${strings.categoryName(e.category)} • '
                            '${shortDate(store, e.date)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Text(
                            store.formatAmount(e.amountPkr),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onTap: () {
                            Navigator.of(context).push(
                              slideRoute(
                                  ExpenseDetailScreen(expense: e)),
                            );
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
