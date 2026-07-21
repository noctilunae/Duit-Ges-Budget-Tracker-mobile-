import 'dart:io';

import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';

import '../db/database_helper.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../utils/formatters.dart';

/// Bikin file Excel berisi transaksi + rekap semua periode.
class ExcelExporter {
  /// Return file .xlsx yang siap dishare, atau null kalau belum ada data.
  static Future<File?> export() async {
    final txs = await DatabaseHelper.instance.all();
    return exportTransactions(txs, filePrefix: 'duit_ges');
  }

  /// Export subset transaksi, misalnya hasil filter di layar Rekap.
  static Future<File?> exportTransactions(
    List<TransactionModel> txs, {
    String filePrefix = 'rekap_duit_ges',
  }) async {
    if (txs.isEmpty) return null;

    final wallets = await DatabaseHelper.instance.wallets();
    final walletNames = {for (final w in wallets) w.id!: w.name};
    final excel = build(txs, walletNames);

    final dir = await getTemporaryDirectory();
    final now = DateTime.now();
    final name =
        '${filePrefix}_${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}.xlsx';
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(excel.encode()!);
    return file;
  }

  /// Susun workbook-nya doang (tanpa nulis file) — dipisah biar
  /// bisa diuji round-trip export→import di test tanpa HP.
  static Excel build(List<TransactionModel> txs, Map<int, String> walletNames) {
    final excel = Excel.createExcel();
    excel.rename('Sheet1', 'Transaksi');

    _fillTransaksi(excel['Transaksi'], txs, walletNames);
    _fillRekap(
      excel['Harian'],
      txs,
      keyOf: (d) => DateTime(d.year, d.month, d.day),
      labelOf: (d) => tanggalPendek(d),
    );
    _fillRekap(
      excel['Mingguan'],
      txs,
      // Kunci minggu = hari Senin-nya
      keyOf: (d) {
        final day = DateTime(d.year, d.month, d.day);
        return day.subtract(Duration(days: day.weekday - 1));
      },
      labelOf: (monday) =>
          '${tanggalPendek(monday)} - '
          '${tanggalPendek(monday.add(const Duration(days: 6)))}',
    );
    _fillRekap(
      excel['Bulanan'],
      txs,
      keyOf: (d) => DateTime(d.year, d.month),
      labelOf: (d) => namaBulan(d),
    );
    _fillRekap(
      excel['Tahunan'],
      txs,
      keyOf: (d) => DateTime(d.year),
      labelOf: (d) => '${d.year}',
    );
    return excel;
  }

  static void _boldHeader(Sheet sheet, int columnCount) {
    for (var i = 0; i < columnCount; i++) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
          .cellStyle = CellStyle(
        bold: true,
      );
    }
  }

  static void _fillTransaksi(
    Sheet sheet,
    List<TransactionModel> txs,
    Map<int, String> walletNames,
  ) {
    sheet.appendRow([
      TextCellValue('Tanggal'),
      TextCellValue('Jam'),
      TextCellValue('Tipe'),
      TextCellValue('Kategori'),
      TextCellValue('Dompet'),
      TextCellValue('Jumlah'),
      TextCellValue('Catatan'),
    ]);
    _boldHeader(sheet, 7);
    for (final tx in txs) {
      sheet.appendRow([
        TextCellValue(tanggalPendek(tx.date)),
        TextCellValue(jamPendek(tx.date)),
        TextCellValue(tx.type == TxType.income ? 'Pemasukan' : 'Pengeluaran'),
        TextCellValue(tx.category.name),
        TextCellValue(walletNames[tx.walletId] ?? '-'),
        DoubleCellValue(tx.amount),
        TextCellValue(tx.note),
      ]);
    }
  }

  static void _fillRekap(
    Sheet sheet,
    List<TransactionModel> txs, {
    required DateTime Function(DateTime) keyOf,
    required String Function(DateTime) labelOf,
  }) {
    sheet.appendRow([
      TextCellValue('Periode'),
      TextCellValue('Pemasukan'),
      TextCellValue('Pengeluaran'),
      TextCellValue('Selisih'),
    ]);
    _boldHeader(sheet, 4);

    final grouped = <DateTime, List<TransactionModel>>{};
    for (final tx in txs) {
      grouped.putIfAbsent(keyOf(tx.date), () => []).add(tx);
    }
    final keys = grouped.keys.toList()..sort();
    for (final key in keys) {
      var income = 0.0;
      var expense = 0.0;
      for (final tx in grouped[key]!) {
        if (tx.type == TxType.income) {
          income += tx.amount;
        } else {
          expense += tx.amount;
        }
      }
      sheet.appendRow([
        TextCellValue(labelOf(key)),
        DoubleCellValue(income),
        DoubleCellValue(expense),
        DoubleCellValue(income - expense),
      ]);
    }
  }
}
