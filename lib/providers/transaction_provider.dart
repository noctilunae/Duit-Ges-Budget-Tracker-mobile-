import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart' hide Category;

import '../db/database_helper.dart';
import '../models/category.dart';
import '../models/debt.dart';
import '../models/goal.dart';
import '../models/transaction.dart';
import '../services/widget_service.dart';

class TransactionProvider extends ChangeNotifier {
  final _db = DatabaseHelper.instance;

  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  int _monthStartDay = 1;
  List<TransactionModel> _transactions = [];
  bool _loading = false;
  int? _walletFilter;
  int _revision = 0;
  int _walletRevision = 0;
  int _loadToken = 0;

  /// Naik tiap data berubah — buat cache (misal grafik tren) tau
  /// kapan mesti query ulang tanpa fetch tiap rebuild.
  int get revision => _revision;
  int get walletRevision => _walletRevision;

  DateTime get month => _month;
  List<TransactionModel> get transactions => _transactions;
  bool get loading => _loading;
  int? get walletFilter => _walletFilter;

  /// Transfer cuma dihitung kalau lagi filter per dompet — secara global
  /// transfer itu bukan pemasukan/pengeluaran beneran (cuma mindahin duit).
  bool _counted(TransactionModel t) => _walletFilter != null || !t.isTransfer;

  // Income/expense di-hitung sekali pas load(), bukan tiap getter diakses —
  // dulu tiap widget yang baca balance/totalIncome/totalExpense di build()
  // masing-masing scan penuh _transactions sendiri-sendiri.
  double _totalIncome = 0;
  double _totalExpense = 0;
  double get totalIncome => _totalIncome;
  double get totalExpense => _totalExpense;
  double get balance => _totalIncome - _totalExpense;

  Map<DateTime, List<TransactionModel>>? _cachedGroupedByDay;
  int _groupedByDayRevision = -1;
  final Map<TxType, List<MapEntry<Category, double>>> _cachedTotalsByCategory =
      {};
  int _totalsByCategoryRevision = -1;

  /// Transaksi dikelompokkan per hari (key = tanggal tanpa jam), urut terbaru.
  /// Di-cache per `_revision` biar ga re-group tiap rebuild widget.
  Map<DateTime, List<TransactionModel>> get groupedByDay {
    if (_groupedByDayRevision != _revision) {
      final map = <DateTime, List<TransactionModel>>{};
      for (final tx in _transactions) {
        final day = DateTime(tx.date.year, tx.date.month, tx.date.day);
        map.putIfAbsent(day, () => []).add(tx);
      }
      _cachedGroupedByDay = map;
      _groupedByDayRevision = _revision;
    }
    return _cachedGroupedByDay!;
  }

  /// Total per kategori untuk satu tipe, urut dari yang terbesar.
  /// Transfer ga pernah diitung di sini (bukan pengeluaran/pemasukan asli).
  /// Di-cache per `_revision` biar ga re-scan+sort tiap rebuild widget
  /// (misal tiap drag di pie chart Statistik).
  List<MapEntry<Category, double>> totalsByCategory(TxType type) {
    if (_totalsByCategoryRevision != _revision) {
      _cachedTotalsByCategory.clear();
      _totalsByCategoryRevision = _revision;
    }
    return _cachedTotalsByCategory.putIfAbsent(type, () {
      final totals = <String, double>{};
      for (final tx in _transactions.where(
        (t) => t.type == type && !t.isTransfer,
      )) {
        totals[tx.categoryId] = (totals[tx.categoryId] ?? 0) + tx.amount;
      }
      final entries =
          totals.entries
              .map((e) => MapEntry(categoryById(e.key), e.value))
              .toList()
            ..sort((a, b) => b.value.compareTo(a.value));
      return entries;
    });
  }

  Future<void> load({bool applyRecurrings = false}) async {
    final token = ++_loadToken;
    _loading = true;
    notifyListeners();
    final inserted = applyRecurrings ? await _db.applyDueRecurrings() : 0;
    if (inserted > 0) _walletRevision++;
    final transactions = await _db.byMonth(
      _month,
      walletId: _walletFilter,
      startDay: _monthStartDay,
    );
    if (token != _loadToken) return;
    _transactions = transactions;
    double income = 0;
    double expense = 0;
    for (final tx in _transactions) {
      if (!_counted(tx)) continue;
      if (tx.type == TxType.income) {
        income += tx.amount;
      } else if (tx.type == TxType.expense) {
        expense += tx.amount;
      }
    }
    _totalIncome = income;
    _totalExpense = expense;
    _loading = false;
    _revision++;
    notifyListeners();
    if (inserted > 0) unawaited(WidgetService.update());
  }

  int _categoryVersion = 0;

  /// Dipanggil proxy di main.dart tiap kategori custom berubah:
  /// buang cache (yang nyimpen object Category lama/fallback "Lainnya")
  /// dan rebuild semua layar yang nampilin kategori. [version] dari
  /// CategoryProvider — kalau belum berubah (misal proxy kepicu notify
  /// SettingsProvider), ga usah ngapa-ngapain biar cache ga kebuang sia-sia.
  void categoriesChanged(int version) {
    if (version == _categoryVersion) return;
    _categoryVersion = version;
    _revision++;
    // Proxy manggil ini di tengah build — notify langsung bakal error
    // "markNeedsBuild during build", makanya ditunda semicro-task.
    Future.microtask(notifyListeners);
  }

  /// Ganti tanggal mulai periode bulanan (dari Setelan). Periode dinamai
  /// pakai bulan awalnya: startDay 25 → "Juni" artinya 25 Jun–24 Jul.
  /// Bulan yang lagi dilihat digeser ke periode yang mencakup hari ini.
  void setMonthStartDay(int day) {
    if (day == _monthStartDay) return;
    _monthStartDay = day;
    final now = DateTime.now();
    _month = now.day >= day
        ? DateTime(now.year, now.month)
        : DateTime(now.year, now.month - 1);
    load();
  }

  /// Filter transaksi per dompet (null = semua dompet).
  void setWalletFilter(int? walletId) {
    if (_walletFilter == walletId) return;
    _walletFilter = walletId;
    load();
  }

  Future<void> addTransfer({
    required int fromWalletId,
    required int toWalletId,
    required double amount,
    String note = '',
  }) async {
    await _db.insertTransfer(
      fromWalletId: fromWalletId,
      toWalletId: toWalletId,
      amount: amount,
      date: DateTime.now(),
      note: note,
    );
    _walletRevision++;
    await load();
    unawaited(WidgetService.update());
  }

  Future<void> addTransaction(TransactionModel tx) async {
    await _db.insert(tx);
    _walletRevision++;
    await load();
    unawaited(WidgetService.update());
  }

  Future<void> topUpGoal({
    required Goal goal,
    required int walletId,
    required double amount,
  }) async {
    await _db.topUpGoal(
      goal: goal,
      walletId: walletId,
      amount: amount,
      date: DateTime.now(),
    );
    _walletRevision++;
    await load();
    unawaited(WidgetService.update());
  }

  Future<void> deleteGoal(Goal goal) async {
    await _db.deleteGoal(goal.id!);
    _walletRevision++;
    await load();
    unawaited(WidgetService.update());
  }

  Future<void> payDebt({
    required Debt debt,
    required int walletId,
    required double amount,
  }) async {
    await _db.payDebt(
      debt: debt,
      walletId: walletId,
      amount: amount,
      date: DateTime.now(),
    );
    _walletRevision++;
    await load();
    unawaited(WidgetService.update());
  }

  Future<void> updateTransaction(TransactionModel tx) async {
    await _db.update(tx);
    _walletRevision++;
    await load();
    unawaited(WidgetService.update());
  }

  Future<void> deleteTransaction(int id) async {
    await _db.delete(id);
    _walletRevision++;
    await load();
    unawaited(WidgetService.update());
  }

  void previousMonth() {
    _month = DateTime(_month.year, _month.month - 1);
    load();
  }

  void nextMonth() {
    _month = DateTime(_month.year, _month.month + 1);
    load();
  }
}
