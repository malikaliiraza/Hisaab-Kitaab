// Hisaab Kitaab — Monthly Report (v7.4).
//
// One shareable page for the current month, reusing the
// Summary data: total spent, top category, budget vs actual
// per budget, and the Loan Ledger's movement (lent /
// borrowed / received / paid). The Share button sends the
// same numbers as plain text — on a phone through the share
// sheet, on the web through the browser share (or the
// clipboard when the browser has no share sheet).

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/amount_row.dart';
import '../../../core/gradient_button.dart';
import '../../../core/theme.dart';
import '../data/expense_store.dart';

class MonthlyReportScreen extends StatelessWidget {
  const MonthlyReportScreen({super.key});

  Future<void> _share(BuildContext context, ExpenseStore store) async {
    final text = store.monthlyReportText();
    try {
      await SharePlus.instance.share(
        ShareParams(text: text, subject: store.strings.monthlyReport),
      );
    } catch (_) {
      // Web browsers without a share sheet: copy instead.
      if (kIsWeb) {
        await Clipboard.setData(ClipboardData(text: text));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(store.strings.copiedToClipboard)),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ExpenseStore>();
    final strings = store.strings;
    final data = store.monthlyReportData();
    final budgets = data['budgets'] as List<Map<String, dynamic>>;
    final topCategory = data['topCategory'] as String;

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: CashWiseTheme.headerGradientOf(context),
        ),
        title: Text(strings.monthlyReport),
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
                  Text(
                    store.monthYear(DateTime.now()),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AmountRow(
                            label: strings.totalSpent,
                            amount: store.formatAmount(
                              data['totalSpent'] as double,
                            ),
                            bold: true,
                          ),
                          if (topCategory.isNotEmpty)
                            AmountRow(
                              label: strings.topCategory,
                              amount:
                                  '${strings.categoryName(topCategory)} — '
                                  '${store.formatAmount(data['topCategoryAmount'] as double)}',
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            strings.budgetVsActual,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (budgets.isEmpty)
                            Text(
                              strings.noBudgetsYet,
                              style: TextStyle(
                                color: CashWiseTheme.secondaryTextFor(
                                  context,
                                ),
                              ),
                            )
                          else
                            for (final b in budgets) ...[
                              AmountRow(
                                label: '${b['name']}',
                                amount:
                                    '${store.formatAmount(b['spent'] as double)} / ${store.formatAmount(b['budget'] as double)}',
                              ),
                              AmountRow(
                                label:
                                    '${b['name']} — ${strings.remaining}',
                                amount: store.formatAmount(
                                  b['remaining'] as double,
                                ),
                              ),
                              const SizedBox(height: 4),
                            ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            strings.loanMovement,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          AmountRow(
                            label: strings.lent,
                            amount: store.formatAmount(
                              data['lent'] as double,
                            ),
                          ),
                          AmountRow(
                            label: strings.borrowed,
                            amount: store.formatAmount(
                              data['borrowed'] as double,
                            ),
                          ),
                          AmountRow(
                            label: strings.received,
                            amount: store.formatAmount(
                              data['received'] as double,
                            ),
                          ),
                          AmountRow(
                            label: strings.paid,
                            amount: store.formatAmount(
                              data['paid'] as double,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  GradientButton(
                    label: strings.shareReport,
                    onPressed: () => _share(context, store),
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
