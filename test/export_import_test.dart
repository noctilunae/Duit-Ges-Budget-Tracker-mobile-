import 'dart:io';
import 'dart:math';

import 'package:duit_ges/db/database_helper.dart';
import 'package:duit_ges/models/category.dart';
import 'package:duit_ges/models/debt.dart';
import 'package:duit_ges/models/goal.dart';
import 'package:duit_ges/models/recurring.dart';
import 'package:duit_ges/models/transaction.dart';
import 'package:duit_ges/models/wallet.dart';
import 'package:duit_ges/providers/category_provider.dart';
import 'package:duit_ges/services/excel_exporter.dart';
import 'package:duit_ges/services/excel_importer.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Uji akurasi export→import dalam kuantitas besar: ribuan transaksi
/// diexport ke .xlsx lalu diimport balik, dan tiap field dibandingkan
/// satu-satu. Jalan di komputer pakai SQLite versi FFI (tanpa HP).
void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await initializeDateFormatting('id_ID');
    // Database fresh di folder temp — ga nyampah, hasil deterministik
    final tmp = Directory.systemTemp.createTempSync('duit_ges_test_');
    await databaseFactory.setDatabasesPath(tmp.path);
  });

  test('round-trip export→import 3000+ transaksi tetap akurat', () async {
    final db = DatabaseHelper.instance;

    // ===== Seed: 3 dompet, 1 kategori custom, 3000 transaksi + 50 transfer
    final bankId = await db.insertWallet(
      const Wallet(name: 'Bank', iconKey: 'bank', color: Color(0xFF2E5BFF)),
    );
    final ewalletId = await db.insertWallet(
      const Wallet(
        name: 'E-Wallet',
        iconKey: 'ewallet',
        color: Color(0xFFFF7043),
      ),
    );
    final walletIds = [1, bankId, ewalletId];

    const skincare = CustomCategory(
      id: 'custom_skincare',
      name: 'Skincare',
      iconKey: 'category',
      color: Color(0xFFEC407A),
      type: TxType.expense,
    );
    await db.upsertCustomCategory(skincare);
    // Registry global harus diisi juga: exporter nulis nama kategori
    // lewat categoryById(), yang ngeceknya ke sini.
    customCategoryRegistry[skincare.id] = skincare.toCategory();

    final rnd = Random(42); // seed tetap = hasil selalu sama
    final categories = [...expenseCategories, ...incomeCategories];
    // Catatan yang rawan ngerusak parser: koma, kutip, newline, emoji
    const notes = [
      '',
      'nasi, goreng "spesial"',
      'bayar wifi\nbulanan',
      'jajan 🍜 malam',
      'split; bill: 50%',
    ];

    final seeded = <TransactionModel>[];
    for (var i = 0; i < 3000; i++) {
      final category = rnd.nextInt(20) == 0
          ? skincare.toCategory()
          : categories[rnd.nextInt(categories.length)];
      seeded.add(
        TransactionModel(
          amount: (rnd.nextInt(10000000) + 500).toDouble(),
          categoryId: category.id,
          note: notes[rnd.nextInt(notes.length)],
          date: DateTime(
            2024,
            1,
            1,
          ).add(Duration(minutes: rnd.nextInt(3 * 365 * 24 * 60))),
          type: category.type,
          walletId: walletIds[rnd.nextInt(walletIds.length)],
        ),
      );
    }
    await db.insertAllTransactions(seeded);
    for (var i = 0; i < 50; i++) {
      await db.insertTransfer(
        fromWalletId: 1,
        toWalletId: bankId,
        amount: 10000.0 + i * 1000,
        date: DateTime(2025, 1, 1 + (i % 28), 10, 30),
        note: 'topup rutin',
      );
    }

    // ===== Export ke bytes .xlsx beneran
    final original = await db.all(); // urut date ASC, id ASC
    expect(original.length, 3000 + 100); // 50 transfer = 100 transaksi
    final recap = await db.recapTotals(grouping: RecapGrouping.monthly);
    expect(
      recap.fold<int>(0, (sum, period) => sum + period.count),
      original.where((transaction) => !transaction.isTransfer).length,
    );
    final summary = await db.widgetSummary(DateTime(2024), DateTime(2028));
    final initialBalance = (await db.wallets()).fold<double>(
      0,
      (sum, wallet) => sum + wallet.initialBalance,
    );
    double flow(TxType type) => original
        .where((transaction) => transaction.type == type)
        .fold(0, (sum, transaction) => sum + transaction.amount);
    expect(
      summary.balance,
      initialBalance + flow(TxType.income) - flow(TxType.expense),
    );
    for (final type in TxType.values) {
      final expected = original
          .where(
            (transaction) =>
                transaction.type == type && !transaction.isTransfer,
          )
          .fold<double>(0, (sum, transaction) => sum + transaction.amount);
      expect(
        type == TxType.income ? summary.income : summary.expense,
        expected,
      );
    }
    final wallets = await db.wallets();
    final excel = ExcelExporter.build(original, {
      for (final w in wallets) w.id!: w.name,
    });
    expect(excel.tables.keys, contains('Tahunan'));
    final file = File('${Directory.systemTemp.path}/duit_ges_roundtrip.xlsx')
      ..writeAsBytesSync(excel.encode()!);
    addTearDown(() => file.deleteSync());

    // ===== Import balik, terus bandingkan field per field
    final result = await ExcelImporter.import(file.path);
    expect(result.skipped, 0, reason: 'ga boleh ada baris yang gagal kebaca');
    expect(result.imported, original.length);

    final all = await db.all();
    expect(all.length, original.length * 2);

    // Transaksi hasil import = yang id-nya lebih besar dari batch asli.
    // Diurutkan per id = urutan baris di sheet = urutan list original.
    final maxSeedId = original.map((t) => t.id!).reduce(max);
    final imported = all.where((t) => t.id! > maxSeedId).toList()
      ..sort((a, b) => a.id!.compareTo(b.id!));
    expect(imported.length, original.length);

    for (var i = 0; i < original.length; i++) {
      final o = original[i];
      final m = imported[i];
      expect(m.amount, o.amount, reason: 'nominal baris $i');
      expect(m.type, o.type, reason: 'tipe baris $i');
      expect(m.categoryId, o.categoryId, reason: 'kategori baris $i');
      expect(m.walletId, o.walletId, reason: 'dompet baris $i');
      expect(m.note, o.note, reason: 'catatan baris $i');
      // Presisi tanggal sampai menit (detik memang ga diexport)
      expect(
        m.date,
        DateTime(
          o.date.year,
          o.date.month,
          o.date.day,
          o.date.hour,
          o.date.minute,
        ),
        reason: 'tanggal baris $i',
      );
    }

    // Total agregat juga harus identik
    double sum(List<TransactionModel> list, TxType type) => list
        .where((t) => t.type == type)
        .fold(0, (total, t) => total + t.amount);
    expect(sum(imported, TxType.income), sum(original, TxType.income));
    expect(sum(imported, TxType.expense), sum(original, TxType.expense));

    final storageTypes = await (await db.database).rawQuery(
      'SELECT DISTINCT typeof(amount) AS type FROM transactions',
    );
    expect(storageTypes.map((row) => row['type']), ['integer']);
  });

  test(
    'hapus transaksi ikut membersihkan foto struk yang tidak dipakai',
    () async {
      final db = DatabaseHelper.instance;
      final receipt = File('${Directory.systemTemp.path}/struk_test.jpg');
      await receipt.writeAsBytes([1, 2, 3]);
      final id = await db.insert(
        TransactionModel(
          amount: 10000,
          categoryId: 'makanan',
          date: DateTime(2026, 7, 18),
          type: TxType.expense,
          receiptPath: receipt.path,
        ),
      );

      await db.delete(id);

      expect(await receipt.exists(), isFalse);
    },
  );

  test('hapus satu sisi transfer ikut menghapus pasangannya', () async {
    final db = DatabaseHelper.instance;
    final bankId = await db.insertWallet(
      const Wallet(
        name: 'Bank uji hapus',
        iconKey: 'bank',
        color: Color(0xFF2E5BFF),
      ),
    );
    final date = DateTime(2026, 7, 19, 14, 30);
    await db.insertTransfer(
      fromWalletId: 1,
      toWalletId: bankId,
      amount: 76543,
      date: date,
      note: 'uji hapus pasangan',
    );
    final pair = (await db.all())
        .where((tx) => tx.date == date && tx.note == 'uji hapus pasangan')
        .toList();
    expect(pair, hasLength(2));

    final deleted = await db.delete(pair.first.id!);

    expect(deleted, 2);
    expect(
      (await db.all()).where((tx) => tx.note == 'uji hapus pasangan'),
      isEmpty,
    );
  });

  test(
    'setor target menambah progres dan mencatat pengeluaran dompet',
    () async {
      final db = DatabaseHelper.instance;
      final goalId = await db.insertGoal(
        const Goal(name: 'Target atomik', target: 500000),
      );
      final goal = (await db.goals()).firstWhere((item) => item.id == goalId);
      final date = DateTime(2026, 7, 19, 15);

      await db.topUpGoal(goal: goal, walletId: 1, amount: 125000, date: date);

      expect(
        (await db.goals()).firstWhere((item) => item.id == goalId).saved,
        125000,
      );
      final transaction = (await db.all()).singleWhere(
        (tx) => tx.date == date && tx.note == 'Target: Target atomik',
      );
      expect(transaction.categoryId, goalSaving.id);
      expect(transaction.walletId, 1);
      expect(transaction.amount, 125000);

      await db.delete(transaction.id!);
      expect(
        (await db.goals()).firstWhere((item) => item.id == goalId).saved,
        0,
      );

      await db.topUpGoal(goal: goal, walletId: 1, amount: 50000, date: date);
      await db.deleteGoal(goalId);
      expect((await db.goals()).any((item) => item.id == goalId), isFalse);
      expect(
        (await db.all()).any(
          (tx) => tx.sourceType == 'goal' && tx.sourceId == goalId,
        ),
        isFalse,
      );
    },
  );

  test(
    'pembayaran utang tercatat dan bisa dibatalkan dari transaksi',
    () async {
      final db = DatabaseHelper.instance;
      final debtId = await db.insertDebt(
        Debt(
          person: 'Budi',
          amount: 100000,
          isReceivable: false,
          date: DateTime(2026, 7, 20),
        ),
      );
      final debt = (await db.debts()).firstWhere((item) => item.id == debtId);

      await db.payDebt(
        debt: debt,
        walletId: 1,
        amount: 40000,
        date: DateTime(2026, 7, 21),
      );
      await expectLater(
        db.payDebt(
          debt: debt,
          walletId: 1,
          amount: 70000,
          date: DateTime(2026, 7, 21),
        ),
        throwsStateError,
      );

      final paid = (await db.debts()).firstWhere((item) => item.id == debtId);
      expect((paid.paid, paid.remaining, paid.settled), (40000, 60000, false));
      final transaction = (await db.all()).singleWhere(
        (tx) => tx.sourceType == 'debt' && tx.sourceId == debtId,
      );
      expect(
        (transaction.type, transaction.categoryId),
        (TxType.expense, debtPaymentOut.id),
      );

      await db.delete(transaction.id!);
      final reverted = (await db.debts()).firstWhere(
        (item) => item.id == debtId,
      );
      expect(
        (reverted.paid, reverted.remaining, reverted.settled),
        (0, 100000, false),
      );
    },
  );

  test('recurring menjaga dompet dan kategori yang masih dipakai', () async {
    final db = DatabaseHelper.instance;
    final walletId = await db.insertWallet(
      const Wallet(
        name: 'Dompet recurring',
        iconKey: 'cash',
        color: Color(0xFF26A69A),
      ),
    );
    const category = CustomCategory(
      id: 'custom_recurring_guard',
      name: 'Recurring Guard',
      iconKey: 'receipt',
      color: Color(0xFF26A69A),
      type: TxType.expense,
    );
    await db.upsertCustomCategory(category);
    await db.insertRecurring(
      Recurring(
        amount: 10000,
        categoryId: category.id,
        walletId: walletId,
        type: TxType.expense,
        day: 10,
        nextDue: DateTime(2027, 1, 10),
      ),
    );
    await db.setBudget(category.id, 50000);

    expect(await db.transactionCountForWallet(walletId), 1);
    expect(await db.transactionCountForCategory(category.id), 2);
  });

  test('backup terverifikasi bisa mengembalikan database', () async {
    final db = DatabaseHelper.instance;
    final before = (await db.all()).length;
    final backup = File('${Directory.systemTemp.path}/duit_nia_test.duitges');
    await db.backupTo(backup.path);
    addTearDown(() async {
      if (await backup.exists()) await backup.delete();
    });
    await db.insert(
      TransactionModel(
        amount: 12345,
        categoryId: 'makanan',
        date: DateTime(2026, 7, 18),
        type: TxType.expense,
      ),
    );

    expect(await db.restoreFrom(backup.path), isTrue);
    expect((await db.all()).length, before);
  });

  test(
    'kategori bawaan yang tidak dipakai bisa dihapus dari pilihan',
    () async {
      SharedPreferences.setMockInitialValues({});
      final db = DatabaseHelper.instance;
      final raw = await db.database;
      for (final table in ['transactions', 'recurrings', 'budgets']) {
        await raw.delete(table, where: 'category_id = ?', whereArgs: ['kopi']);
      }

      final provider = CategoryProvider();
      await provider.load();
      expect(
        provider.expenseAll.any((category) => category.id == 'kopi'),
        isTrue,
      );

      expect(await provider.deleteCategory('kopi'), isTrue);
      expect(
        provider.expenseAll.any((category) => category.id == 'kopi'),
        isFalse,
      );
    },
  );
}
