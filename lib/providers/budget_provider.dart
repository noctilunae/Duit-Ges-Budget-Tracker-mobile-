import 'package:flutter/foundation.dart';

import '../db/database_helper.dart';
import '../models/budget.dart';

/// Nyimpen limit budget bulanan per kategori pengeluaran.
class BudgetProvider extends ChangeNotifier {
  final _db = DatabaseHelper.instance;

  List<Budget> _budgets = [];

  List<Budget> get budgets => _budgets;

  Future<void> load({bool applyRules = true}) async {
    if (applyRules) await _db.applySalaryAllocations();
    _budgets = await _db.budgets();
    notifyListeners();
  }

  Future<void> saveBudget(Budget budget) async {
    await _db.saveBudget(budget);
    await load();
  }

  Future<void> removeBudget(String id) async {
    await _db.deleteBudget(id);
    await load();
  }
}
