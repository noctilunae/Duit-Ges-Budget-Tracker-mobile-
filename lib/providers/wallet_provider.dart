import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart';

import '../db/database_helper.dart';
import '../models/wallet.dart';
import '../services/widget_service.dart';

class WalletProvider extends ChangeNotifier {
  final _db = DatabaseHelper.instance;

  List<Wallet> _wallets = [];
  Map<int, double> _flows = {};
  int _syncedTransactionRevision = 0;

  List<Wallet> get wallets => _wallets;

  /// Saldo dompet = saldo awal + (semua pemasukan - pengeluaran).
  double balanceOf(Wallet wallet) =>
      wallet.initialBalance + (_flows[wallet.id] ?? 0);

  double get totalBalance => _wallets.fold(0, (sum, w) => sum + balanceOf(w));

  Wallet? byId(int id) {
    for (final w in _wallets) {
      if (w.id == id) return w;
    }
    return null;
  }

  Future<void> load() async {
    _wallets = await _db.wallets();
    _flows = await _db.walletFlows();
    notifyListeners();
  }

  /// Refresh saldo doang (dipanggil otomatis tiap ada perubahan transaksi).
  Future<void> loadBalances(int transactionRevision) async {
    if (transactionRevision <= _syncedTransactionRevision) return;
    _syncedTransactionRevision = transactionRevision;
    final flows = await _db.walletFlows();
    if (transactionRevision != _syncedTransactionRevision) return;
    _flows = flows;
    notifyListeners();
  }

  Future<void> addWallet(Wallet wallet) async {
    await _db.insertWallet(wallet);
    await load();
    unawaited(WidgetService.update(syncOptions: true));
  }

  Future<void> updateWallet(Wallet wallet) async {
    await _db.updateWallet(wallet);
    await load();
    unawaited(WidgetService.update(syncOptions: true));
  }

  /// Hapus dompet. Gagal (return false) kalau masih ada transaksinya
  /// atau ini dompet terakhir.
  Future<bool> deleteWallet(int id) async {
    if (_wallets.length <= 1) return false;
    final count = await _db.transactionCountForWallet(id);
    if (count > 0) return false;
    await _db.deleteWallet(id);
    await load();
    unawaited(WidgetService.update(syncOptions: true));
    return true;
  }
}
