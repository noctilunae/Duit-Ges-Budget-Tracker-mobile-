import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart' hide Category;
import 'package:shared_preferences/shared_preferences.dart';

import '../db/database_helper.dart';
import '../models/category.dart';
import '../services/widget_service.dart';

/// Ngelola kategori custom bikinan user + gabungin sama kategori bawaan.
class CategoryProvider extends ChangeNotifier {
  final _db = DatabaseHelper.instance;

  List<CustomCategory> _custom = [];
  List<CustomCategory> get custom => _custom;
  Set<String> _highlighted = {};
  Set<String> _hidden = {};

  /// Naik tiap data kategori beneran berubah (load ulang dari DB).
  /// Dipakai proxy di main.dart biar refresh transaksi cuma jalan pas
  /// kategorinya berubah — bukan tiap SettingsProvider notify apa aja.
  int _version = 0;
  int get version => _version;

  bool isHighlighted(String id) => _highlighted.contains(id);

  /// Kategori pengeluaran lengkap: bawaan + custom, 'Lainnya' tetep paling
  /// akhir biar gampang dicari.
  List<Category> get expenseAll =>
      _highlightedFirst(_merged(expenseCategories, TxType.expense));

  List<Category> get incomeAll =>
      _highlightedFirst(_merged(incomeCategories, TxType.income));

  List<Category> _highlightedFirst(List<Category> categories) => [
    ...categories.where((category) => isHighlighted(category.id)),
    ...categories.where((category) => !isHighlighted(category.id)),
  ];

  List<Category> _merged(List<Category> builtIn, TxType type) {
    final customCats = _custom
        .where((c) => c.type == type)
        .map((c) => c.toCategory())
        .toList();
    return [
      ...builtIn.sublist(0, builtIn.length - 1),
      ...customCats,
      builtIn.last, // 'Lainnya'
    ].where((category) => !_hidden.contains(category.id)).toList();
  }

  Future<void> load() async {
    _custom = await _db.customCategories();
    final prefs = await SharedPreferences.getInstance();
    _highlighted =
        (prefs.getStringList('highlightedCategories') ??
                [
                  'makanan',
                  'transportasi',
                  'belanja',
                  'tagihan',
                  'gaji',
                  'freelance',
                ])
            .toSet();
    _hidden = (prefs.getStringList('hiddenCategories') ?? const []).toSet();
    // Registry global biar categoryById() kenal kategori custom
    customCategoryRegistry
      ..clear()
      ..addEntries(_custom.map((c) => MapEntry(c.id, c.toCategory())));
    _version++;
    notifyListeners();
  }

  Future<void> saveCategory(CustomCategory category) async {
    await _db.upsertCustomCategory(category);
    await load();
    unawaited(WidgetService.update(syncOptions: true));
  }

  Future<void> saveCategories(Iterable<CustomCategory> categories) async {
    await _db.upsertCustomCategories(categories);
    await load();
    unawaited(WidgetService.update(syncOptions: true));
  }

  Future<void> toggleHighlight(String id) async {
    if (!_highlighted.add(id)) _highlighted.remove(id);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('highlightedCategories', _highlighted.toList());
    unawaited(WidgetService.update(syncOptions: true));
  }

  /// Hapus kategori. Gagal (false) kalau masih dipakai transaksi.
  Future<bool> deleteCategory(String id) async {
    final count = await _db.transactionCountForCategory(id);
    if (count > 0) return false;
    final category = categoryById(id);
    final sameType = category.type == TxType.expense ? expenseAll : incomeAll;
    if (sameType.length <= 1) return false;

    final prefs = await SharedPreferences.getInstance();
    if (_custom.any((category) => category.id == id)) {
      await _db.deleteCustomCategory(id);
    } else {
      _hidden.add(id);
      await prefs.setStringList('hiddenCategories', _hidden.toList());
    }
    if (_highlighted.remove(id)) {
      await prefs.setStringList('highlightedCategories', _highlighted.toList());
    }
    await load();
    unawaited(WidgetService.update(syncOptions: true));
    return true;
  }
}
