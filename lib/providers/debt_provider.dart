import 'package:flutter/foundation.dart';

import '../db/database_helper.dart';
import '../models/debt.dart';

class DebtProvider extends ChangeNotifier {
  final _db = DatabaseHelper.instance;

  List<Debt> _debts = [];
  List<Debt> get debts => _debts;

  /// Total utang kita yang belum lunas.
  double get totalOwed => _debts
      .where((d) => !d.isReceivable && !d.settled)
      .fold(0, (sum, d) => sum + d.remaining);

  /// Total piutang (duit kita di orang) yang belum balik.
  double get totalReceivable => _debts
      .where((d) => d.isReceivable && !d.settled)
      .fold(0, (sum, d) => sum + d.remaining);

  Future<void> load() async {
    _debts = await _db.debts();
    notifyListeners();
  }

  Future<void> addDebt(Debt debt) async {
    await _db.insertDebt(debt);
    await load();
  }

  Future<bool> deleteDebt(int id) async {
    if (await _db.paymentCountForDebt(id) > 0) return false;
    await _db.deleteDebt(id);
    await load();
    return true;
  }
}
