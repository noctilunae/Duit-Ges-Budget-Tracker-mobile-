import 'dart:io';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

import '../db/database_helper.dart';
import '../models/category.dart';
import '../models/transaction.dart';

/// Baca file .xlsx (format yang sama kayak hasil export) dan masukin
/// isinya sebagai transaksi baru.
///
/// Kolom yang diharapkan di sheet "Transaksi":
/// Tanggal | Jam | Tipe | Kategori | Dompet | Jumlah | Catatan
/// (format lama tanpa kolom Dompet juga dideteksi otomatis)
class ExcelImporter {
  static Future<({int imported, int skipped})> import(String path) async {
    final excel = Excel.decodeBytes(await File(path).readAsBytes());
    final sheet =
        excel.tables['Transaksi'] ??
        (excel.tables.isEmpty ? null : excel.tables.values.first);
    if (sheet == null) return (imported: 0, skipped: 0);

    final wallets = await DatabaseHelper.instance.wallets();
    final customCats = await DatabaseHelper.instance.customCategories();
    // Pool kategori buat pencocokan nama (bawaan + custom), lowercase.
    final categoryByName = <String, Category>{
      for (final c in allCategories) c.name.toLowerCase(): c,
      for (final c in customCats) c.name.toLowerCase(): c.toCategory(),
    };
    final walletByName = {for (final w in wallets) w.name.toLowerCase(): w.id!};

    final dateFormat = DateFormat('d MMM yyyy', 'id_ID');
    final txs = <TransactionModel>[];
    var skipped = 0;

    for (final row in sheet.rows) {
      final tanggal = _text(row, 0);
      if (tanggal.isEmpty || tanggal.toLowerCase() == 'tanggal') continue;

      // Deteksi format: file baru punya kolom Dompet di index 4,
      // file lama langsung Jumlah di index 4.
      final hasWalletColumn = _number(row, 5) != null || row.length >= 7;
      final amount = _number(row, hasWalletColumn ? 5 : 4);
      final date = _parseDate(tanggal, dateFormat);
      if (amount == null || amount <= 0 || date == null) {
        skipped++;
        continue;
      }

      final jam = _text(row, 1);
      var hour = 0;
      var minute = 0;
      final jamParts = jam.split(':');
      if (jamParts.length == 2) {
        hour = int.tryParse(jamParts[0]) ?? 0;
        minute = int.tryParse(jamParts[1]) ?? 0;
      }

      final isIncome = _text(row, 2).toLowerCase() == 'pemasukan';
      final type = isIncome ? TxType.income : TxType.expense;

      // Kategori dicocokin per nama; ga ketemu / beda tipe → Lainnya.
      final matched = categoryByName[_text(row, 3).toLowerCase()];
      final categoryId = (matched != null && matched.type == type)
          ? matched.id
          : (isIncome ? 'lainnya_masuk' : 'lainnya_keluar');

      final walletId = hasWalletColumn
          ? walletByName[_text(row, 4).toLowerCase()] ?? wallets.first.id!
          : wallets.first.id!;

      txs.add(
        TransactionModel(
          amount: amount,
          categoryId: categoryId,
          note: _text(row, hasWalletColumn ? 6 : 5),
          date: DateTime(date.year, date.month, date.day, hour, minute),
          type: type,
          walletId: walletId,
        ),
      );
    }

    if (txs.isNotEmpty) {
      await DatabaseHelper.instance.insertAllTransactions(txs);
    }
    return (imported: txs.length, skipped: skipped);
  }

  static String _text(List<Data?> row, int index) {
    if (index >= row.length) return '';
    final value = row[index]?.value;
    if (value == null) return '';
    if (value is TextCellValue) return value.value.text ?? '';
    return value.toString();
  }

  static double? _number(List<Data?> row, int index) {
    if (index >= row.length) return null;
    final value = row[index]?.value;
    if (value is DoubleCellValue) return value.value;
    if (value is IntCellValue) return value.value.toDouble();
    if (value is TextCellValue) {
      final raw = (value.value.text ?? '')
          .replaceAll('Rp', '')
          .replaceAll('.', '')
          .replaceAll(',', '.')
          .trim();
      return double.tryParse(raw);
    }
    return null;
  }

  static DateTime? _parseDate(String raw, DateFormat idFormat) {
    try {
      return idFormat.parse(raw);
    } catch (_) {
      return DateTime.tryParse(raw);
    }
  }
}
