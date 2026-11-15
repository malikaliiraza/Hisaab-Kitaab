// Hisaab Kitaab — Backup & Export (v7.4).
//
// Three actions, one screen:
//  - Export backup (JSON): EVERYTHING — budgets, expenses,
//    loans, reminders, recurring rules, savings goals — in
//    one file. Passwords are never exported.
//  - Export expenses (CSV): the expense list as a
//    spreadsheet-friendly file.
//  - Import backup: restores a backup JSON, only after a
//    confirm dialog, replacing the current data.
// Files download in the browser on web, and open the system
// share sheet on a phone (see core/share_file.dart). Import
// reads the file with file_picker (works on web and mobile).

import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/gradient_button.dart';
import '../../../core/share_file.dart';
import '../../../core/theme.dart';
import '../data/expense_store.dart';

class BackupScreen extends StatelessWidget {
  const BackupScreen({super.key});

  Future<void> _exportJson(BuildContext context) async {
    final store = context.read<ExpenseStore>();
    final now = DateTime.now();
    final name =
        'hisaab-kitaab-backup-${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}.json';
    await shareTextFile(
      fileName: name,
      content: store.exportBackupJson(),
      mimeType: 'application/json',
    );
  }

  Future<void> _exportCsv(BuildContext context) async {
    final store = context.read<ExpenseStore>();
    final now = DateTime.now();
    final name =
        'hisaab-kitaab-expenses-${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}.csv';
    await shareTextFile(
      fileName: name,
      content: store.exportExpensesCsv(),
      mimeType: 'text/csv',
    );
  }

  Future<void> _import(BuildContext context) async {
    final store = context.read<ExpenseStore>();
    final strings = store.strings;
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (picked.isEmpty) return;
    // readAsBytes works on web and on mobile alike (web
    // keeps the bytes in memory; mobile reads the file).
    final bytes = await picked.single.readAsBytes();
    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.importBackup),
        content: Text(strings.importBackupConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(strings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              strings.importBackup,
              style: const TextStyle(
                color: CashWiseTheme.danger,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok =
        await store.importBackupJson(utf8.decode(bytes));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? strings.importSuccess : strings.importFailed),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ExpenseStore>();
    final strings = store.strings;

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: CashWiseTheme.headerGradientOf(context),
        ),
        title: Text(strings.backupExport),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.backup_outlined,
                            size: 28,
                            color: CashWiseTheme.accentFor(context),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(strings.backupInfo),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  GradientButton(
                    label: strings.exportBackup,
                    onPressed: () => _exportJson(context),
                  ),
                  const SizedBox(height: 12),
                  GradientButton(
                    label: strings.exportExpensesCsv,
                    onPressed: () => _exportCsv(context),
                  ),
                  const SizedBox(height: 12),
                  GradientButton(
                    label: strings.importBackup,
                    onPressed: () => _import(context),
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
