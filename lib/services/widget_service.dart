import 'dart:convert';

import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../db/database_helper.dart';
import '../models/category.dart';
import '../utils/formatters.dart';

/// Ngirim data saldo ke home screen widget Android.
///
/// Sisi Flutter cuma nyimpen angka-angkanya; yang gambar tampilannya
/// kode native di SaldoWidgetProvider.kt (widget Android ga bisa
/// dirender Flutter).
class WidgetService {
  WidgetService._();

  /// Hitung ulang angka widget dan refresh tampilannya.
  /// Fire-and-forget: gagal pun ga boleh ganggu app.
  static Future<void> update({
    bool syncOptions = false,
    int? backgroundStart,
    int? backgroundEnd,
    int? foreground,
    int? accent,
    bool? quickAddEnabled,
  }) async {
    try {
      final db = DatabaseHelper.instance;
      final now = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      final startDay = (prefs.getInt('monthStartDay') ?? 1).clamp(1, 28);
      final period = now.day >= startDay
          ? DateTime(now.year, now.month)
          : DateTime(now.year, now.month - 1);
      final start = DateTime(period.year, period.month, startDay);
      final end = DateTime(period.year, period.month + 1, startDay);
      final summary = await db.widgetSummary(start, end);

      // Hormati mode sembunyiin saldo
      final hide =
          (prefs.getBool('hideBalance') ?? false) ||
          (prefs.getBool('hideWidgetBalance') ?? false);
      String fmt(double value) => hide ? 'Rp ••••' : rupiah(value);

      String hex(int color) =>
          '#${color.toRadixString(16).padLeft(8, '0').toUpperCase()}';
      final accentHex = hex(accent ?? prefs.getInt('accent') ?? 0xFFFF8FAB);

      await HomeWidget.saveWidgetData('widget_saldo', fmt(summary.balance));
      await HomeWidget.saveWidgetData('widget_masuk', fmt(summary.income));
      await HomeWidget.saveWidgetData('widget_keluar', fmt(summary.expense));
      await HomeWidget.saveWidgetData('widget_bulan', namaBulan(period));
      await HomeWidget.saveWidgetData('widget_accent', accentHex);
      await HomeWidget.saveWidgetData('widget_hide_balance', hide);
      await HomeWidget.saveWidgetData('widget_month_start_day', startDay);
      if (backgroundStart != null) {
        await HomeWidget.saveWidgetData(
          'widget_bg_start',
          hex(backgroundStart),
        );
      }
      if (backgroundEnd != null) {
        await HomeWidget.saveWidgetData('widget_bg_end', hex(backgroundEnd));
      }
      if (foreground != null) {
        await HomeWidget.saveWidgetData('widget_foreground', hex(foreground));
      }
      if (quickAddEnabled != null) {
        await HomeWidget.saveWidgetData(
          'widget_quick_add_enabled',
          quickAddEnabled,
        );
      }
      if (syncOptions) await _syncOptions(db, prefs);
      await HomeWidget.updateWidget(androidName: 'SaldoWidgetProvider');
      await HomeWidget.updateWidget(androidName: 'SaldoWidgetMediumProvider');
      await HomeWidget.updateWidget(androidName: 'SaldoWidgetCompactProvider');
    } catch (_) {
      // Widget gagal update (misal belum dipasang) — bukan masalah.
    }
  }

  static Future<void> _syncOptions(
    DatabaseHelper db,
    SharedPreferences prefs,
  ) async {
    final custom = await db.customCategories();
    final highlighted =
        (prefs.getStringList('highlightedCategories') ??
                const [
                  'makanan',
                  'transportasi',
                  'belanja',
                  'tagihan',
                  'gaji',
                  'freelance',
                ])
            .toSet();
    final hidden = (prefs.getStringList('hiddenCategories') ?? const [])
        .toSet();

    List<Map<String, Object>> categories(TxType type) {
      final builtIn = type == TxType.expense
          ? expenseCategories
          : incomeCategories;
      final merged = [
        ...builtIn.sublist(0, builtIn.length - 1),
        ...custom
            .where((item) => item.type == type)
            .map((item) => item.toCategory()),
        builtIn.last,
      ].where((category) => !hidden.contains(category.id)).toList();
      if (merged.isEmpty) merged.add(builtIn.last);
      final ordered = [
        ...merged.where((category) => highlighted.contains(category.id)),
        ...merged.where((category) => !highlighted.contains(category.id)),
      ];
      return [
        for (final category in ordered)
          {
            'id': category.id,
            'name': category.name,
            'icon': category.icon.codePoint,
            if (category.emoji != null) 'emoji': category.emoji!,
            'color': category.color.toARGB32(),
          },
      ];
    }

    final wallets = await db.wallets();
    await HomeWidget.saveWidgetData(
      'widget_expense_categories',
      jsonEncode(categories(TxType.expense)),
    );
    await HomeWidget.saveWidgetData(
      'widget_income_categories',
      jsonEncode(categories(TxType.income)),
    );
    await HomeWidget.saveWidgetData(
      'widget_wallets',
      jsonEncode([
        for (final wallet in wallets)
          {
            'id': wallet.id,
            'name': wallet.name,
            'icon': wallet.icon.codePoint,
            if (wallet.emoji != null) 'emoji': wallet.emoji!,
            'color': wallet.color.toARGB32(),
          },
      ]),
    );
  }
}
