import 'package:flutter/foundation.dart';

import '../db/database_helper.dart';
import '../models/recurring.dart';

class RecurringProvider extends ChangeNotifier {
  final _db = DatabaseHelper.instance;

  List<Recurring> _items = [];

  List<Recurring> get items => _items;

  Future<void> load() async {
    _items = await _db.recurrings();
    notifyListeners();
  }

  Future<void> add(Recurring recurring) async {
    await _db.insertRecurring(recurring);
    await load();
  }

  Future<void> setActive(Recurring recurring, bool active) async {
    // Pas diaktifin lagi, jatuh tempo dihitung ulang dari sekarang
    // biar bulan-bulan selama nonaktif ga ikut ke-backfill.
    await _db.updateRecurring(
      recurring.copyWith(
        active: active,
        nextDue: active ? Recurring.firstDue(recurring.day) : null,
      ),
    );
    await load();
  }

  Future<void> remove(int id) async {
    await _db.deleteRecurring(id);
    await load();
  }
}
