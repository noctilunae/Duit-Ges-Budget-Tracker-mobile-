import 'dart:io';
import 'dart:math';

import 'package:duit_ges/db/database_helper.dart';
import 'package:duit_ges/models/category.dart';
import 'package:duit_ges/models/budget.dart';
import 'package:duit_ges/models/debt.dart';
import 'package:duit_ges/models/goal.dart';
import 'package:duit_ges/models/recurring.dart';
import 'package:duit_ges/models/transaction.dart';
import 'package:duit_ges/models/wallet.dart';
import 'package:duit_ges/providers/category_provider.dart';
import 'package:duit_ges/services/excel_exporter.dart';
import 'package:duit_ges/services/excel_importer.dart';
import 'package:duit_ges/utils/stored_icon.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:excel/excel.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Uji akurasi export→import dalam kuantitas besar: ribuan transaksi
/// diexport ke .xlsx lalu diimport balik, dan tiap field dibandingkan
/// satu-satu. Jalan di komputer pakai SQLite versi FFI (tanpa HP).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
    expect(await db.transactionCountForWallet(walletId), 1);
    expect(await db.categoryUsageCount(category.id), 1);
  });

  test('recurring jatuh tempo membuat transaksi tepat sekali', () async {
    final db = DatabaseHelper.instance;
    final now = DateTime.now();
    final recurringId = await db.insertRecurring(
      Recurring(
        amount: 43210,
        categoryId: 'makanan',
        walletId: 1,
        note: 'uji recurring jatuh tempo',
        type: TxType.expense,
        day: now.day,
        nextDue: DateTime(now.year, now.month, now.day),
      ),
    );

    expect(await db.applyDueRecurrings(), 1);
    expect(await db.applyDueRecurrings(), 0);
    final created = (await db.all()).where(
      (tx) => tx.note == 'uji recurring jatuh tempo',
    );
    expect(created, hasLength(1));
    expect(created.single.amount, 43210);
    await db.deleteRecurring(recurringId);
  });

  test('rule gaji membuat budget kategori hanya sekali per bulan', () async {
    final db = DatabaseHelper.instance;
    await db.saveBudget(
      const Budget(
        id: 'budget_makan',
        name: 'Makan',
        iconKey: 'restaurant',
        color: Color(0xFFFF7043),
        type: BudgetType.kebutuhan,
        amount: 1,
      ),
    );
    await db.saveBudget(
      const Budget(
        id: 'budget_hiburan',
        name: 'Hiburan',
        iconKey: 'movie',
        color: Color(0xFFAB47BC),
        type: BudgetType.keinginan,
        amount: 1,
      ),
    );
    await db.saveSalaryAllocations([
      {
        'budget_id': 'budget_makan',
        'amount': null,
        'percentage': 20.0,
        'salary': 5000000,
        'day': 10,
      },
      {
        'budget_id': 'budget_hiburan',
        'amount': 250000,
        'percentage': null,
        'salary': 5000000,
        'day': 10,
      },
    ]);

    expect(await db.applySalaryAllocations(DateTime(2026, 8, 10)), isTrue);
    expect(
      (await db.budgets())
          .firstWhere((item) => item.id == 'budget_makan')
          .amount,
      1000000,
    );
    await db.saveBudget(
      const Budget(
        id: 'budget_makan',
        name: 'Makan',
        iconKey: 'restaurant',
        color: Color(0xFFFF7043),
        type: BudgetType.kebutuhan,
        amount: 123,
      ),
    );
    expect(await db.applySalaryAllocations(DateTime(2026, 8, 20)), isFalse);
    expect(
      (await db.budgets())
          .firstWhere((item) => item.id == 'budget_makan')
          .amount,
      123,
    );
    expect(
      await db.applySalaryAllocations(DateTime(2026, 8, 20), true),
      isTrue,
    );
    expect(
      (await db.budgets())
          .firstWhere((item) => item.id == 'budget_makan')
          .amount,
      1000000,
    );
  });

  test('rule gaji menambah Budget tabungan sekali per bulan', () async {
    final db = DatabaseHelper.instance;
    await db.saveBudget(
      const Budget(
        id: 'budget_tabungan',
        name: 'Dana Darurat',
        iconKey: 'savings',
        color: Color(0xFF26A69A),
        type: BudgetType.tabungan,
        amount: 100000,
      ),
    );
    await db.saveSalaryAllocations([
      {
        'budget_id': 'budget_tabungan',
        'amount': 50000,
        'percentage': null,
        'salary': 100000,
        'day': 10,
      },
    ]);

    expect(await db.applySalaryAllocations(DateTime(2026, 9, 10)), isTrue);
    expect(
      (await db.budgets())
          .firstWhere((budget) => budget.id == 'budget_tabungan')
          .amount,
      150000,
    );
    expect(await db.applySalaryAllocations(DateTime(2026, 9, 20)), isFalse);
    expect(
      (await db.budgets())
          .firstWhere((budget) => budget.id == 'budget_tabungan')
          .amount,
      150000,
    );
  });

  test(
    'edit rule gaji mengganti rule tanpa menerapkan ulang bulan sama',
    () async {
      final db = DatabaseHelper.instance;
      await db.saveBudget(
        const Budget(
          id: 'budget_edit_rule',
          name: 'Edit Rule',
          iconKey: 'wallet',
          color: Color(0xFF26A69A),
          type: BudgetType.kebutuhan,
          amount: 0,
        ),
      );
      Map<String, Object?> rule(int amount) => {
        'budget_id': 'budget_edit_rule',
        'amount': amount,
        'percentage': null,
        'salary': 100000,
        'day': 10,
      };

      await db.saveSalaryAllocations([rule(40000)]);
      expect(await db.applySalaryAllocations(DateTime(2026, 10, 10)), isTrue);
      await db.saveSalaryAllocations([rule(50000)]);
      expect(await db.applySalaryAllocations(DateTime(2026, 10, 20)), isFalse);
      expect(await db.applySalaryAllocations(DateTime(2026, 11, 10)), isTrue);
      expect(
        (await db.budgets())
            .firstWhere((budget) => budget.id == 'budget_edit_rule')
            .amount,
        50000,
      );
    },
  );

  test('rule gaji menolak total pembagian di atas nominal gaji', () async {
    final db = DatabaseHelper.instance;
    expect(
      () => db.saveSalaryAllocations([
        {
          'budget_id': 'budget_berlebih',
          'amount': 110000,
          'percentage': null,
          'salary': 100000,
          'day': 10,
        },
      ]),
      throwsArgumentError,
    );
  });

  test('transaksi pemasukan bisa masuk budget Tabungan', () async {
    final db = DatabaseHelper.instance;
    const budget = Budget(
      id: 'budget_bebas',
      name: 'Budget Bebas',
      iconKey: 'savings',
      color: Color(0xFF26A69A),
      type: BudgetType.tabungan,
      amount: 500000,
    );
    await db.saveBudget(budget);
    await db.insert(
      TransactionModel(
        amount: 25000,
        categoryId: 'gaji',
        budgetId: budget.id,
        date: DateTime(2026, 8, 12),
        type: TxType.income,
      ),
    );
    expect(
      (await db.all()).where((item) => item.budgetId == budget.id),
      hasLength(1),
    );
    await db.deleteBudget(budget.id);
    expect(
      (await db.all()).where((item) => item.budgetId == budget.id),
      isEmpty,
    );
  });

  test('import Excel mencocokkan kategori dan fallback ke Lainnya', () async {
    final excel = Excel.createExcel();
    excel.rename('Sheet1', 'Transaksi');
    final sheet = excel['Transaksi'];
    sheet.appendRow([
      TextCellValue('Tanggal'),
      TextCellValue('Jam'),
      TextCellValue('Tipe'),
      TextCellValue('Kategori'),
      TextCellValue('Dompet'),
      TextCellValue('Jumlah'),
      TextCellValue('Catatan'),
    ]);
    for (final (category, note) in [
      ('Makanan', 'kategori cocok'),
      ('Kategori Belum Ada', 'kategori fallback'),
    ]) {
      sheet.appendRow([
        TextCellValue('22 Jul 2026'),
        TextCellValue('12:00'),
        TextCellValue('Pengeluaran'),
        TextCellValue(category),
        TextCellValue('Tunai'),
        IntCellValue(10000),
        TextCellValue(note),
      ]);
    }
    final file = File('${Directory.systemTemp.path}/kategori_import_test.xlsx')
      ..writeAsBytesSync(excel.encode()!);
    addTearDown(() async {
      if (await file.exists()) await file.delete();
    });

    expect(await ExcelImporter.import(file.path), (imported: 2, skipped: 0));
    final imported = (await DatabaseHelper.instance.all())
        .where((tx) => tx.note.startsWith('kategori '))
        .toList();
    expect(
      imported.singleWhere((tx) => tx.note == 'kategori cocok').categoryId,
      'makanan',
    );
    expect(
      imported.singleWhere((tx) => tx.note == 'kategori fallback').categoryId,
      'lainnya_keluar',
    );
  });

  test('backup dan restore ribuan data tetap identik', () async {
    final db = DatabaseHelper.instance;
    final documents = Directory.systemTemp.createTempSync(
      'duit_ges_restore_docs_',
    );
    addTearDown(() => documents.deleteSync(recursive: true));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => documents.path,
        );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            null,
          ),
    );

    final receiptDir = Directory('${documents.path}/struk')..createSync();
    final expectedReceipt = List.generate(4096, (index) => index % 251);
    final receipt = File('${receiptDir.path}/backup-proof.jpg')
      ..writeAsBytesSync(expectedReceipt);
    final iconDir = Directory('${documents.path}/custom_icons')..createSync();
    final expectedIcon = List.generate(512, (index) => index % 239);
    final icon = File('${iconDir.path}/backup-icon.png')
      ..writeAsBytesSync(expectedIcon);
    await db.insert(
      TransactionModel(
        amount: 987654,
        categoryId: 'makanan',
        note: 'bukti backup akurat',
        date: DateTime(2026, 7, 23),
        type: TxType.expense,
        receiptPath: receipt.path,
      ),
    );

    const tables = [
      'transactions',
      'budgets',
      'wallets',
      'goals',
      'debts',
      'custom_categories',
      'recurrings',
      'salary_allocations',
    ];
    final raw = await db.database;
    await raw.update('wallets', {
      'icon': storedImageIcon(icon.path, 1.2),
    }, where: 'id = 1');
    final before = <String, List<Map<String, Object?>>>{
      for (final table in tables)
        table: await raw.rawQuery('SELECT * FROM $table ORDER BY rowid'),
    };
    expect(before['transactions']!.length, greaterThan(6000));

    final backup = File('${Directory.systemTemp.path}/duit_ges_test.duitges');
    await db.backupTo(backup.path);
    addTearDown(() async {
      if (await backup.exists()) await backup.delete();
    });
    for (final table in tables) {
      await raw.delete(table);
    }
    receipt.writeAsBytesSync([0]);
    icon.deleteSync();

    expect(await db.restoreFrom(backup.path), isTrue);
    final restored = await db.database;
    for (final table in tables) {
      expect(
        await restored.rawQuery('SELECT * FROM $table ORDER BY rowid'),
        before[table],
        reason: 'isi tabel $table berubah setelah restore',
      );
    }
    final restoredReceipt = File(
      (await db.all())
          .singleWhere((tx) => tx.note == 'bukti backup akurat')
          .receiptPath!,
    );
    expect(await restoredReceipt.readAsBytes(), expectedReceipt);
    expect(await restoredReceipt.length(), 4096);
    final restoredIcon = parseStoredImageIcon(
      (await db.wallets()).first.iconKey,
    )!;
    expect(await File(restoredIcon.path).readAsBytes(), expectedIcon);
    expect(restoredIcon.scale, 1.2);
  });

  test('kategori hanya tersembunyi selama tidak dipakai data lain', () async {
    SharedPreferences.setMockInitialValues({});
    final db = DatabaseHelper.instance;
    final raw = await db.database;
    for (final table in ['transactions', 'recurrings']) {
      await raw.delete(table, where: 'category_id = ?', whereArgs: ['kopi']);
    }

    final provider = CategoryProvider();
    await provider.load();
    expect(
      provider.expenseAll.any((category) => category.id == 'kopi'),
      isTrue,
    );

    await db.saveBudget(
      const Budget(
        id: 'category_delete_guard',
        name: 'Kopi',
        iconKey: 'coffee',
        color: Color(0xFF795548),
        type: BudgetType.kebutuhan,
        amount: 100000,
        scope: BudgetScope.category,
        categoryId: 'kopi',
      ),
    );
    expect(await provider.deleteCategory('kopi'), isFalse);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('hiddenCategories', ['kopi']);
    await provider.load();
    expect(provider.all.any((category) => category.id == 'kopi'), isTrue);
    expect(prefs.getStringList('hiddenCategories'), isEmpty);

    await db.deleteBudget('category_delete_guard');
    expect(await provider.deleteCategory('kopi'), isTrue);
    expect(provider.all.any((category) => category.id == 'kopi'), isFalse);
  });

  test('pemakaian ikon custom dapat dilacak ke nama data', () async {
    final db = DatabaseHelper.instance;
    const path = '/tmp/ikon-terlacak.png';
    await db.upsertCustomCategory(
      CustomCategory(
        id: 'kategori_ikon_terlacak',
        name: 'Ikon Terlacak',
        iconKey: storedImageIcon(path, 1),
        color: const Color(0xFF42A5F5),
        type: TxType.expense,
      ),
    );

    expect(
      (await db.customIconUsages())[path],
      contains('Kategori: Ikon Terlacak'),
    );
    await db.deleteCustomCategory('kategori_ikon_terlacak');
  });
}
