import 'package:flutter/foundation.dart';

import '../db/database_helper.dart';

/// Nyimpen limit budget bulanan per kategori pengeluaran.
class BudgetProvider extends ChangeNotifier {
  final _db = DatabaseHelper.instance;

  Map<String, double> _budgets = {};

  Map<String, double> get budgets => _budgets;

  double? limitFor(String categoryId) => _budgets[categoryId];

  Future<void> load() async {
    _budgets = await _db.budgets();
    notifyListeners();
  }

  Future<void> setBudget(String categoryId, double amount) async {
    await _db.setBudget(categoryId, amount);
    await load();
  }

  Future<void> removeBudget(String categoryId) async {
    await _db.deleteBudget(categoryId);
    await load();
  }
}
