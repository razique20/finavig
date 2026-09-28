//ignore_for_file: avoid_print
import 'dart:io';

/// CI guard: widget/screen file-size budget.
///
/// Large widget files regress rebuild scopes and reviewability; every
/// modularization wave in this repo has been about shrinking them. This
/// ratchet fails CI when any file under lib/screens/, lib/widgets/, or
/// lib/config/ exceeds [budgetLines], so monoliths can't silently return.
///
/// Run: dart run tool/perf_budget_check.dart
void main(List<String> args) {
  // Current ratchet: files already over budget at adoption time are
  // grandfathered at their existing size +10% headroom, so they can grow a
  // little but must be split before any further major expansion.
  final budgets = {
    'lib/screens': 1200,
    'lib/widgets': 1200,
    'lib/config': 800,
    'lib/screens/document_detail_screen.dart': 2100, // grandfathered
    'lib/screens/ai_budget_plan_screen.dart': 1600, // grandfathered
    'lib/screens/login_screen.dart': 1500, // grandfathered
  };

  // Optional override: --budget=path=lines (repeatable).
  for (final arg in args) {
    if (arg.startsWith('--budget=')) {
      final parts = arg.substring('--budget='.length).split('=');
      if (parts.length == 2) {
        final parsed = int.tryParse(parts[1]);
        if (parsed != null) budgets[parts[0]] = parsed;
      }
    }
  }

  final violations = <String>[];
  final perFileBudgets = <String, int>{};
  budgets.forEach((path, budget) {
    if (!path.endsWith('.dart')) return;
    perFileBudgets[path] = budget;
  });

  var filesChecked = 0;

  for (final entry in budgets.entries) {
    if (entry.key.endsWith('.dart')) continue;
    final dir = Directory(entry.key);
    if (!dir.existsSync()) continue;
    await0(dir, (file) {
      if (!file.path.endsWith('.dart')) return;
      filesChecked++;
      final budget = perFileBudgets[file.path] ?? entry.value;
      final lines = file.readAsLinesSync().length;
      if (lines > budget) {
        violations.add('${file.path}: $lines lines (budget $budget)');
      }
    });
  }

  print('Checked $filesChecked Dart files against file-size budgets.');
  if (violations.isNotEmpty) {
    print('\nFile-size budget violations:');
    for (final v in violations) {
      print('  ✗ $v');
    }
    print(
      '\nSplit the file into modules (see lib/screens/home/, lib/screens/documents/,'
      '\nlib/screens/profile/, lib/screens/money/ for the pattern) or, if a larger'
      '\nfile is genuinely justified, raise the budget in tool/perf_budget_check.dart'
      '\nand note the reason in the PR.',
    );
    exit(1);
  }
  print('✓ All files within budget.');
}

/// Simple recursive walk (avoid async plumbing in a CI script).
void await0(Directory dir, void Function(File) onFile) {
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is File) onFile(entity);
  }
}
