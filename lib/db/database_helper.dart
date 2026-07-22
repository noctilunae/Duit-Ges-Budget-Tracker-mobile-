import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/category.dart'
    show
        CustomCategory,
        TxType,
        debtPaymentIn,
        debtPaymentOut,
        goalSaving,
        transferIn,
        transferOut;
import '../models/budget.dart';
import '../models/debt.dart';
import '../models/goal.dart';
import '../models/recurring.dart';
import '../models/transaction.dart';
import '../models/wallet.dart';

enum RecapGrouping { daily, weekly, monthly, yearly }

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();
  static const schemaVersion = 13;

  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    final dbPath = join(await getDatabasesPath(), 'duit_ges.db');
    return openDatabase(
      dbPath,
      version: schemaVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE transactions(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            amount INTEGER NOT NULL,
            category_id TEXT NOT NULL,
            note TEXT NOT NULL DEFAULT '',
            date TEXT NOT NULL,
            type TEXT NOT NULL,
            wallet_id INTEGER NOT NULL DEFAULT 1,
            receipt_path TEXT,
            source_type TEXT,
            source_id INTEGER,
            budget_id TEXT
          )
        ''');
        await db.execute(_createBudgets);
        await db.execute(_createWallets);
        await _seedDefaultWallet(db);
        await db.execute(_createGoals);
        await db.execute(_createDebts);
        await db.execute(_createCustomCategories);
        for (final sql in _createIndexes) {
          await db.execute(sql);
        }
        await db.execute(_createRecurrings);
        await db.execute(_createSalaryAllocations);
      },
      // Migrasi bertahap buat app yang udah keinstall — data lama aman.
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(_createBudgetsV2);
        }
        if (oldVersion < 3) {
          await db.execute(_createWallets);
          await _seedDefaultWallet(db);
          // Semua transaksi lama otomatis masuk dompet default (Tunai)
          await db.execute(
            "ALTER TABLE transactions ADD COLUMN wallet_id INTEGER NOT NULL DEFAULT 1",
          );
        }
        if (oldVersion < 4) {
          await db.execute(_createGoalsV4);
          await db.execute(_createDebtsV4);
        }
        if (oldVersion < 5) {
          await db.execute(
            'ALTER TABLE transactions ADD COLUMN receipt_path TEXT',
          );
          await db.execute(_createCustomCategories);
        }
        if (oldVersion < 6) {
          // Index bikin query per bulan/dompet/kategori tetep ngebut
          // walau transaksinya udah ribuan (jangka panjang).
          for (final sql in _createIndexes) {
            await db.execute(sql);
          }
        }
        if (oldVersion < 7) {
          await db.execute(_createRecurrings);
        }
        if (oldVersion < 8) {
          await _migrateMoneyToIntegers(db);
        }
        if (oldVersion < 9) {
          await db.execute(
            'ALTER TABLE transactions ADD COLUMN source_type TEXT',
          );
          await db.execute(
            'ALTER TABLE transactions ADD COLUMN source_id INTEGER',
          );
          await db.execute(
            'ALTER TABLE debts ADD COLUMN paid INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldVersion < 10) {
          await db.execute(
            "ALTER TABLE budgets ADD COLUMN budget_type TEXT NOT NULL DEFAULT 'kebutuhan'",
          );
          await db.execute('ALTER TABLE debts ADD COLUMN due_date TEXT');
          await db.execute(_createSalaryAllocationsV10);
        }
        if (oldVersion < 11) {
          await db.execute('ALTER TABLE budgets RENAME TO budgets_category');
          await db.execute(_createBudgets);
          await db.execute('''
            INSERT INTO budgets(id, name, icon, color, budget_type, amount)
            SELECT category_id,
                   upper(substr(category_id, 1, 1)) ||
                     replace(substr(category_id, 2), '_', ' '),
                   'category', 4286151036,
                   budget_type, amount FROM budgets_category
          ''');
          await db.execute('DROP TABLE budgets_category');
          await db.execute(
            'ALTER TABLE salary_allocations RENAME TO salary_allocations_category',
          );
          await db.execute(_createSalaryAllocations);
          await db.execute('''
            INSERT INTO salary_allocations(
              budget_id, amount, percentage, salary, day, last_period)
            SELECT category_id, amount, percentage, salary, day, last_period
            FROM salary_allocations_category
          ''');
          await db.execute('DROP TABLE salary_allocations_category');
        }
        if (oldVersion < 12) {
          await db.execute(
            'ALTER TABLE transactions ADD COLUMN budget_id TEXT',
          );
        }
        if (oldVersion < 13) {
          await db.execute(
            "ALTER TABLE goals ADD COLUMN icon TEXT NOT NULL DEFAULT 'savings'",
          );
        }
      },
    );
  }

  static const _createIndexes = [
    'CREATE INDEX IF NOT EXISTS idx_tx_date ON transactions(date)',
    'CREATE INDEX IF NOT EXISTS idx_tx_wallet ON transactions(wallet_id)',
    'CREATE INDEX IF NOT EXISTS idx_tx_category ON transactions(category_id)',
  ];

  static const _createCustomCategories = '''
    CREATE TABLE IF NOT EXISTS custom_categories(
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      icon TEXT NOT NULL,
      color INTEGER NOT NULL,
      type TEXT NOT NULL
    )
  ''';

  static const _createRecurrings = '''
    CREATE TABLE IF NOT EXISTS recurrings(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      amount INTEGER NOT NULL,
      category_id TEXT NOT NULL,
      wallet_id INTEGER NOT NULL DEFAULT 1,
      note TEXT NOT NULL DEFAULT '',
      type TEXT NOT NULL,
      day INTEGER NOT NULL,
      next_due TEXT NOT NULL,
      active INTEGER NOT NULL DEFAULT 1
    )
  ''';

  static const _createBudgets = '''
    CREATE TABLE IF NOT EXISTS budgets(
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      icon TEXT NOT NULL,
      color INTEGER NOT NULL,
      budget_type TEXT NOT NULL DEFAULT 'kebutuhan',
      amount INTEGER NOT NULL
    )
  ''';

  static const _createBudgetsV2 = '''
    CREATE TABLE IF NOT EXISTS budgets(
      category_id TEXT PRIMARY KEY,
      amount REAL NOT NULL
    )
  ''';

  static const _createSalaryAllocations = '''
    CREATE TABLE IF NOT EXISTS salary_allocations(
      budget_id TEXT PRIMARY KEY,
      amount INTEGER,
      percentage REAL,
      salary INTEGER NOT NULL,
      day INTEGER NOT NULL,
      last_period TEXT
    )
  ''';

  static const _createSalaryAllocationsV10 = '''
    CREATE TABLE IF NOT EXISTS salary_allocations(
      category_id TEXT PRIMARY KEY,
      budget_type TEXT NOT NULL,
      amount INTEGER,
      percentage REAL,
      salary INTEGER NOT NULL,
      day INTEGER NOT NULL,
      last_period TEXT
    )
  ''';

  static const _createWallets = '''
    CREATE TABLE IF NOT EXISTS wallets(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      icon TEXT NOT NULL DEFAULT 'cash',
      color INTEGER NOT NULL,
      initial_balance INTEGER NOT NULL DEFAULT 0
    )
  ''';

  static const _createGoals = '''
    CREATE TABLE IF NOT EXISTS goals(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      target INTEGER NOT NULL,
      saved INTEGER NOT NULL DEFAULT 0,
      color INTEGER NOT NULL,
      icon TEXT NOT NULL DEFAULT 'savings'
    )
  ''';

  static const _createGoalsV4 = '''
    CREATE TABLE IF NOT EXISTS goals(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      target REAL NOT NULL,
      saved REAL NOT NULL DEFAULT 0,
      color INTEGER NOT NULL
    )
  ''';

  static const _createDebts = '''
    CREATE TABLE IF NOT EXISTS debts(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      person TEXT NOT NULL,
      amount INTEGER NOT NULL,
      is_receivable INTEGER NOT NULL,
      note TEXT NOT NULL DEFAULT '',
      date TEXT NOT NULL,
      settled INTEGER NOT NULL DEFAULT 0,
      paid INTEGER NOT NULL DEFAULT 0,
      due_date TEXT
    )
  ''';

  static const _createDebtsV4 = '''
    CREATE TABLE IF NOT EXISTS debts(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      person TEXT NOT NULL,
      amount REAL NOT NULL,
      is_receivable INTEGER NOT NULL,
      note TEXT NOT NULL DEFAULT '',
      date TEXT NOT NULL,
      settled INTEGER NOT NULL DEFAULT 0
    )
  ''';

  static Future<void> _seedDefaultWallet(Database db) async {
    await db.insert('wallets', {
      'id': 1,
      'name': 'Tunai',
      'icon': 'cash',
      'color': 0xFF26A69A,
      'initial_balance': 0,
    });
  }

  static Future<void> _migrateMoneyToIntegers(Database db) async {
    final migrations = <(String, String, List<String>)>[
      (
        'transactions',
        '''CREATE TABLE transactions(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          amount INTEGER NOT NULL,
          category_id TEXT NOT NULL,
          note TEXT NOT NULL DEFAULT '',
          date TEXT NOT NULL,
          type TEXT NOT NULL,
          wallet_id INTEGER NOT NULL DEFAULT 1,
          receipt_path TEXT
        )''',
        [
          'id',
          'amount',
          'category_id',
          'note',
          'date',
          'type',
          'wallet_id',
          'receipt_path',
        ],
      ),
      (
        'budgets',
        '''CREATE TABLE budgets(
          category_id TEXT PRIMARY KEY,
          amount INTEGER NOT NULL
        )''',
        ['category_id', 'amount'],
      ),
      (
        'wallets',
        _createWallets.replaceFirst(' IF NOT EXISTS', ''),
        ['id', 'name', 'icon', 'color', 'initial_balance'],
      ),
      (
        'goals',
        '''CREATE TABLE goals(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          target INTEGER NOT NULL,
          saved INTEGER NOT NULL DEFAULT 0,
          color INTEGER NOT NULL
        )''',
        ['id', 'name', 'target', 'saved', 'color'],
      ),
      (
        'debts',
        '''CREATE TABLE debts(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          person TEXT NOT NULL,
          amount INTEGER NOT NULL,
          is_receivable INTEGER NOT NULL,
          note TEXT NOT NULL DEFAULT '',
          date TEXT NOT NULL,
          settled INTEGER NOT NULL DEFAULT 0
        )''',
        ['id', 'person', 'amount', 'is_receivable', 'note', 'date', 'settled'],
      ),
      (
        'recurrings',
        _createRecurrings.replaceFirst(' IF NOT EXISTS', ''),
        [
          'id',
          'amount',
          'category_id',
          'wallet_id',
          'note',
          'type',
          'day',
          'next_due',
          'active',
        ],
      ),
    ];
    const moneyColumns = {'amount', 'initial_balance', 'target', 'saved'};
    for (final (table, createSql, columns) in migrations) {
      final oldTable = '${table}_real';
      await db.execute('ALTER TABLE $table RENAME TO $oldTable');
      await db.execute(createSql);
      final select = columns
          .map(
            (column) => moneyColumns.contains(column)
                ? 'CAST(ROUND($column) AS INTEGER)'
                : column,
          )
          .join(', ');
      await db.execute(
        'INSERT INTO $table (${columns.join(', ')}) '
        'SELECT $select FROM $oldTable',
      );
      await db.execute('DROP TABLE $oldTable');
    }
    for (final sql in _createIndexes) {
      await db.execute(sql);
    }
  }

  Future<int> insert(TransactionModel tx) async {
    final db = await database;
    final map = tx.toMap()..remove('id');
    return db.insert('transactions', map);
  }

  /// Ambil semua transaksi di satu periode bulanan, terbaru duluan.
  /// [walletId] opsional buat filter per dompet. [startDay] = tanggal
  /// mulai periode (default 1 = bulan kalender biasa; 25 = 25 → 24
  /// bulan depannya, buat yang gajiannya bukan tanggal 1).
  Future<List<TransactionModel>> byMonth(
    DateTime month, {
    int? walletId,
    int startDay = 1,
  }) async {
    final db = await database;
    final start = DateTime(month.year, month.month, startDay);
    final end = DateTime(month.year, month.month + 1, startDay);
    var where = 'date >= ? AND date < ?';
    final args = <Object>[start.toIso8601String(), end.toIso8601String()];
    if (walletId != null) {
      where += ' AND wallet_id = ?';
      args.add(walletId);
    }
    final rows = await db.query(
      'transactions',
      where: where,
      whereArgs: args,
      orderBy: 'date DESC, id DESC',
    );
    return rows.map(TransactionModel.fromMap).toList();
  }

  /// Semua transaksi dari awal sampai sekarang, urut tanggal naik.
  Future<List<TransactionModel>> all() async {
    final db = await database;
    final rows = await db.query('transactions', orderBy: 'date ASC, id ASC');
    return rows.map(TransactionModel.fromMap).toList();
  }

  Future<int> delete(int id) async {
    final db = await database;
    final receiptPaths = <String?>[];
    final deleted = await db.transaction((txn) async {
      final rows = await txn.query(
        'transactions',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) return 0;

      final target = rows.single;
      final ids = <int>[id];
      receiptPaths.add(target['receipt_path'] as String?);

      final sourceType = target['source_type'] as String?;
      final sourceId = target['source_id'] as int?;
      final amount = target['amount'] as int;
      if (sourceType == 'goal' && sourceId != null) {
        await txn.rawUpdate(
          'UPDATE goals SET saved = MAX(0, saved - ?) WHERE id = ?',
          [amount, sourceId],
        );
      } else if (sourceType == 'debt' && sourceId != null) {
        await txn.rawUpdate(
          'UPDATE debts SET paid = MAX(0, paid - ?), '
          'settled = CASE WHEN MAX(0, paid - ?) >= amount THEN 1 ELSE 0 END '
          'WHERE id = ?',
          [amount, amount, sourceId],
        );
      } else if (target['category_id'] == goalSaving.id) {
        // Setoran versi lama belum punya source_id; cocokkan nama persis.
        final note = target['note'] as String? ?? '';
        if (note.startsWith('Target: ')) {
          final matches = await txn.query(
            'goals',
            columns: ['id'],
            where: 'name = ?',
            whereArgs: [note.substring(8)],
            limit: 2,
          );
          if (matches.length == 1) {
            await txn.rawUpdate(
              'UPDATE goals SET saved = MAX(0, saved - ?) WHERE id = ?',
              [amount, matches.single['id']],
            );
          }
        }
      }

      // Transfer disimpan sebagai dua baris berurutan. Menghapus satu sisi
      // saja bikin saldo kedua dompet timpang, jadi cari dan hapus pasangannya
      // dalam transaksi database yang sama. Data lama belum punya group id;
      // timestamp + nominal + catatan mengidentifikasi pasangan terdekatnya.
      final categoryId = target['category_id'] as String;
      final oppositeCategoryId = categoryId == transferOut.id
          ? transferIn.id
          : categoryId == transferIn.id
          ? transferOut.id
          : null;
      if (oppositeCategoryId != null) {
        final pair = await txn.rawQuery(
          'SELECT id, receipt_path FROM transactions '
          'WHERE category_id = ? AND amount = ? AND date = ? AND note = ? '
          'AND id != ? ORDER BY ABS(id - ?) LIMIT 1',
          [
            oppositeCategoryId,
            target['amount'],
            target['date'],
            target['note'],
            id,
            id,
          ],
        );
        if (pair.isNotEmpty) {
          ids.add(pair.single['id'] as int);
          receiptPaths.add(pair.single['receipt_path'] as String?);
        }
      }

      final placeholders = List.filled(ids.length, '?').join(',');
      return txn.delete(
        'transactions',
        where: 'id IN ($placeholders)',
        whereArgs: ids,
      );
    });
    for (final path in receiptPaths) {
      await _deleteReceiptIfUnused(path);
    }
    return deleted;
  }

  Future<int> update(TransactionModel tx) async {
    final db = await database;
    final rows = await db.query(
      'transactions',
      columns: ['receipt_path'],
      where: 'id = ?',
      whereArgs: [tx.id],
      limit: 1,
    );
    final oldReceiptPath = rows.isEmpty
        ? null
        : rows.first['receipt_path'] as String?;
    final map = tx.toMap()..remove('id');
    final updated = await db.update(
      'transactions',
      map,
      where: 'id = ?',
      whereArgs: [tx.id],
    );
    if (oldReceiptPath != tx.receiptPath) {
      await _deleteReceiptIfUnused(oldReceiptPath);
    }
    return updated;
  }

  Future<void> _deleteReceiptIfUnused(String? path) async {
    if (path == null) return;
    final db = await database;
    final count = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM transactions WHERE receipt_path = ?',
        [path],
      ),
    );
    if (count != 0) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // Transaksinya tetap berhasil; file yatim bisa dibersihkan dari Setelan.
    }
  }

  /// Cari di catatan (LIKE) atau berdasarkan kategori yang namanya cocok.
  /// [categoryId]/[start]/[end] opsional buat nyaring hasil per kategori
  /// atau rentang tanggal ([end] eksklusif) — bisa juga tanpa kata kunci.
  Future<List<TransactionModel>> search(
    String query,
    List<String> categoryIds, {
    String? categoryId,
    DateTime? start,
    DateTime? end,
  }) async {
    final db = await database;
    final where = <String>[];
    final args = <Object>[];
    if (query.isNotEmpty) {
      if (categoryIds.isEmpty) {
        where.add('note LIKE ?');
        args.add('%$query%');
      } else {
        final placeholders = List.filled(categoryIds.length, '?').join(',');
        where.add('(note LIKE ? OR category_id IN ($placeholders))');
        args
          ..add('%$query%')
          ..addAll(categoryIds);
      }
    }
    if (categoryId != null) {
      where.add('category_id = ?');
      args.add(categoryId);
    }
    if (start != null) {
      where.add('date >= ?');
      args.add(start.toIso8601String());
    }
    if (end != null) {
      where.add('date < ?');
      args.add(end.toIso8601String());
    }
    final rows = await db.query(
      'transactions',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'date DESC, id DESC',
      limit: 200,
    );
    return rows.map(TransactionModel.fromMap).toList();
  }

  /// Transaksi buat layar Recap: rentang tanggal & kategori opsional
  /// (null/kosong = semua). Transfer dikecualikan, sama kayak statistik.
  /// Method ini hanya dipakai saat export; tampilan memakai [recapTotals]
  /// agar tidak memuat seluruh riwayat ke memori.
  Future<List<TransactionModel>> recapTransactions({
    DateTime? start,
    DateTime? end,
    List<String>? categoryIds,
  }) async {
    final db = await database;
    final where = <String>[
      "category_id NOT IN ('transfer_keluar', 'transfer_masuk')",
    ];
    final args = <Object>[];
    if (start != null) {
      where.add('date >= ?');
      args.add(start.toIso8601String());
    }
    if (end != null) {
      where.add('date < ?');
      args.add(end.toIso8601String());
    }
    if (categoryIds != null && categoryIds.isNotEmpty) {
      final placeholders = List.filled(categoryIds.length, '?').join(',');
      where.add('category_id IN ($placeholders)');
      args.addAll(categoryIds);
    }
    final rows = await db.query(
      'transactions',
      where: where.join(' AND '),
      whereArgs: args,
      orderBy: 'date DESC, id DESC',
    );
    return rows.map(TransactionModel.fromMap).toList();
  }

  /// Agregasi Rekap dikerjakan SQLite supaya layar tidak perlu memuat dan
  /// membuat object untuk seluruh riwayat transaksi.
  Future<List<({DateTime start, double income, double expense, int count})>>
  recapTotals({
    required RecapGrouping grouping,
    DateTime? start,
    DateTime? end,
    List<String>? categoryIds,
  }) async {
    final db = await database;
    final where = <String>[
      "category_id NOT IN ('transfer_keluar', 'transfer_masuk')",
    ];
    final args = <Object>[];
    if (start != null) {
      where.add('date >= ?');
      args.add(start.toIso8601String());
    }
    if (end != null) {
      where.add('date < ?');
      args.add(end.toIso8601String());
    }
    if (categoryIds != null && categoryIds.isNotEmpty) {
      final placeholders = List.filled(categoryIds.length, '?').join(',');
      where.add('category_id IN ($placeholders)');
      args.addAll(categoryIds);
    }
    final periodSql = switch (grouping) {
      RecapGrouping.daily => 'substr(date, 1, 10)',
      RecapGrouping.weekly =>
        "date(substr(date, 1, 10), '-' || "
            "((CAST(strftime('%w', date) AS INTEGER) + 6) % 7) || ' days')",
      RecapGrouping.monthly => "substr(date, 1, 7) || '-01'",
      RecapGrouping.yearly => "substr(date, 1, 4) || '-01-01'",
    };
    final rows = await db.rawQuery(
      'SELECT $periodSql AS period_start, '
      'SUM(CASE WHEN type = ? THEN amount ELSE 0 END) AS income, '
      'SUM(CASE WHEN type = ? THEN amount ELSE 0 END) AS expense, '
      'COUNT(*) AS count FROM transactions '
      'WHERE ${where.join(' AND ')} '
      'GROUP BY period_start ORDER BY period_start DESC',
      [TxType.income.name, TxType.expense.name, ...args],
    );
    return [
      for (final row in rows)
        (
          start: DateTime.parse(row['period_start'] as String),
          income: (row['income'] as num).toDouble(),
          expense: (row['expense'] as num).toDouble(),
          count: row['count'] as int,
        ),
    ];
  }

  Future<List<Budget>> budgets() async {
    final db = await database;
    final rows = await db.query('budgets', orderBy: 'budget_type, name');
    return rows.map(Budget.fromMap).toList();
  }

  Future<void> saveBudget(Budget budget) async {
    final db = await database;
    await db.insert(
      'budgets',
      budget.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, Object?>>> salaryAllocations() async {
    final db = await database;
    return db.query('salary_allocations', orderBy: 'budget_id');
  }

  Future<void> saveSalaryAllocations(List<Map<String, Object?>> rows) async {
    final categories = <Object?>{};
    for (final row in rows) {
      final day = row['day'] as int? ?? 0;
      final salary = row['salary'] as int? ?? 0;
      final amount = row['amount'] as int?;
      final percentage = row['percentage'] as num?;
      if (!categories.add(row['budget_id']) ||
          day < 1 ||
          day > 28 ||
          salary < 0 ||
          (amount == null) == (percentage == null) ||
          (amount != null && amount <= 0) ||
          (percentage != null && (percentage <= 0 || percentage > 100))) {
        throw ArgumentError('Rule pembagian gaji tidak valid');
      }
    }
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('salary_allocations');
      for (final row in rows) {
        await txn.insert('salary_allocations', row);
      }
    });
  }

  /// Terapkan rule bulan ini sekali saja. Budget kategori yang tidak ada di
  /// rule tidak disentuh.
  Future<bool> applySalaryAllocations([
    DateTime? at,
    bool force = false,
  ]) async {
    final db = await database;
    final now = at ?? DateTime.now();
    final rows = await db.query('salary_allocations');
    if (rows.isEmpty || (!force && now.day < (rows.first['day'] as int))) {
      return false;
    }
    final period = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    if (!force && rows.first['last_period'] == period) return false;
    await db.transaction((txn) async {
      for (final row in rows) {
        final salary = row['salary'] as int;
        final percentage = row['percentage'] as num?;
        final amount =
            row['amount'] as int? ?? (salary * (percentage ?? 0) / 100).round();
        if (amount <= 0) continue;
        final budget = await txn.query(
          'budgets',
          columns: ['amount', 'budget_type'],
          where: 'id = ?',
          whereArgs: [row['budget_id']],
          limit: 1,
        );
        if (budget.isEmpty) continue;
        final savedAmount =
            budget.first['budget_type'] == BudgetType.tabungan.name
            ? (budget.first['amount'] as int) + amount
            : amount;
        await txn.update(
          'budgets',
          {'amount': savedAmount},
          where: 'id = ?',
          whereArgs: [row['budget_id']],
        );
      }
      await txn.update('salary_allocations', {'last_period': period});
    });
    return true;
  }

  Future<void> deleteBudget(String id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update(
        'transactions',
        {'budget_id': null},
        where: 'budget_id = ?',
        whereArgs: [id],
      );
      await txn.delete(
        'salary_allocations',
        where: 'budget_id = ?',
        whereArgs: [id],
      );
      await txn.delete('budgets', where: 'id = ?', whereArgs: [id]);
    });
  }

  // ===== Dompet =====

  Future<List<Wallet>> wallets() async {
    final db = await database;
    final rows = await db.query('wallets', orderBy: 'id ASC');
    return rows.map(Wallet.fromMap).toList();
  }

  Future<int> insertWallet(Wallet wallet) async {
    final db = await database;
    final map = wallet.toMap()..remove('id');
    return db.insert('wallets', map);
  }

  Future<int> updateWallet(Wallet wallet) async {
    final db = await database;
    final map = wallet.toMap()..remove('id');
    return db.update('wallets', map, where: 'id = ?', whereArgs: [wallet.id]);
  }

  Future<int> deleteWallet(int id) async {
    final db = await database;
    return db.delete('wallets', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> transactionCountForWallet(int walletId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT '
      '(SELECT COUNT(*) FROM transactions WHERE wallet_id = ?) + '
      '(SELECT COUNT(*) FROM recurrings WHERE wallet_id = ?) AS c',
      [walletId, walletId],
    );
    return result.first['c'] as int;
  }

  /// Saldo tiap dompet sepanjang masa: pemasukan - pengeluaran
  /// (saldo awal ditambahin di provider).
  Future<Map<int, double>> walletFlows() async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT wallet_id, type, SUM(amount) AS total '
      'FROM transactions GROUP BY wallet_id, type',
    );
    final flows = <int, double>{};
    for (final row in rows) {
      final walletId = row['wallet_id'] as int;
      final total = (row['total'] as num?)?.toDouble() ?? 0;
      final sign = row['type'] == TxType.income.name ? 1 : -1;
      flows[walletId] = (flows[walletId] ?? 0) + sign * total;
    }
    return flows;
  }

  /// Ringkasan widget dalam satu query tanpa membuat object transaksi/dompet.
  Future<({double balance, double income, double expense})> widgetSummary(
    DateTime start,
    DateTime end,
  ) async {
    final db = await database;
    final row = (await db.rawQuery(
      'SELECT '
      'COALESCE((SELECT SUM(initial_balance) FROM wallets), 0) + '
      'COALESCE(SUM(CASE WHEN type = ? THEN amount ELSE -amount END), 0) '
      'AS balance, '
      'COALESCE(SUM(CASE WHEN date >= ? AND date < ? AND type = ? '
      'AND category_id NOT IN (?, ?) THEN amount ELSE 0 END), 0) AS income, '
      'COALESCE(SUM(CASE WHEN date >= ? AND date < ? AND type = ? '
      'AND category_id NOT IN (?, ?) THEN amount ELSE 0 END), 0) AS expense '
      'FROM transactions',
      [
        TxType.income.name,
        start.toIso8601String(),
        end.toIso8601String(),
        TxType.income.name,
        transferOut.id,
        transferIn.id,
        start.toIso8601String(),
        end.toIso8601String(),
        TxType.expense.name,
        transferOut.id,
        transferIn.id,
      ],
    )).single;
    return (
      balance: (row['balance'] as num).toDouble(),
      income: (row['income'] as num).toDouble(),
      expense: (row['expense'] as num).toDouble(),
    );
  }

  /// Transfer antar dompet = sepasang transaksi kategori khusus,
  /// dibikin atomik (dua-duanya masuk atau dua-duanya batal).
  Future<void> insertTransfer({
    required int fromWalletId,
    required int toWalletId,
    required double amount,
    required DateTime date,
    String note = '',
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('transactions', {
        'amount': amount.round(),
        'category_id': transferOut.id,
        'note': note,
        'date': date.toIso8601String(),
        'type': TxType.expense.name,
        'wallet_id': fromWalletId,
      });
      await txn.insert('transactions', {
        'amount': amount.round(),
        'category_id': transferIn.id,
        'note': note,
        'date': date.toIso8601String(),
        'type': TxType.income.name,
        'wallet_id': toWalletId,
      });
    });
  }

  // ===== Tren bulanan =====

  /// Total pemasukan & pengeluaran per bulan ('yyyy-MM'),
  /// [monthsBack] bulan ke belakang, transfer ga dihitung.
  Future<Map<String, ({double income, double expense})>> monthlyTotals(
    int monthsBack,
  ) async {
    final db = await database;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month - (monthsBack - 1));
    final rows = await db.rawQuery(
      'SELECT substr(date, 1, 7) AS ym, type, SUM(amount) AS total '
      'FROM transactions '
      'WHERE date >= ? AND category_id NOT IN (?, ?) '
      'GROUP BY ym, type',
      [start.toIso8601String(), transferOut.id, transferIn.id],
    );
    final result = <String, ({double income, double expense})>{};
    for (final row in rows) {
      final ym = row['ym'] as String;
      final total = (row['total'] as num?)?.toDouble() ?? 0;
      final prev = result[ym] ?? (income: 0.0, expense: 0.0);
      result[ym] = row['type'] == TxType.income.name
          ? (income: prev.income + total, expense: prev.expense)
          : (income: prev.income, expense: prev.expense + total);
    }
    return result;
  }

  // ===== Target nabung (goals) =====

  Future<List<Goal>> goals() async {
    final db = await database;
    final rows = await db.query('goals', orderBy: 'id ASC');
    return rows.map(Goal.fromMap).toList();
  }

  Future<int> insertGoal(Goal goal) async {
    final db = await database;
    return db.insert('goals', goal.toMap()..remove('id'));
  }

  Future<int> updateGoal(Goal goal) async {
    final db = await database;
    return db.update(
      'goals',
      goal.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [goal.id],
    );
  }

  /// Setor target dan potong dompet sebagai satu operasi atomik.
  Future<void> topUpGoal({
    required Goal goal,
    required int walletId,
    required double amount,
    required DateTime date,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      final updated = await txn.rawUpdate(
        'UPDATE goals SET saved = saved + ? WHERE id = ?',
        [amount.round(), goal.id],
      );
      if (updated != 1) throw StateError('Target tidak ditemukan');
      await txn.insert('transactions', {
        'amount': amount.round(),
        'category_id': goalSaving.id,
        'note': 'Target: ${goal.name}',
        'date': date.toIso8601String(),
        'type': TxType.expense.name,
        'wallet_id': walletId,
        'source_type': 'goal',
        'source_id': goal.id,
      });
    });
  }

  Future<int> deleteGoal(int id) async {
    final db = await database;
    return db.transaction((txn) async {
      final goals = await txn.query(
        'goals',
        columns: ['name'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (goals.isEmpty) return 0;
      final name = goals.single['name'] as String;
      var paymentWhere = "source_type = 'goal' AND source_id = ?";
      final paymentArgs = <Object>[id];
      final sameName =
          Sqflite.firstIntValue(
            await txn.rawQuery('SELECT COUNT(*) FROM goals WHERE name = ?', [
              name,
            ]),
          ) ??
          0;
      if (sameName == 1) {
        paymentWhere +=
            " OR (source_type IS NULL AND category_id = ? AND note = ?)";
        paymentArgs.addAll([goalSaving.id, 'Target: $name']);
      }
      await txn.delete(
        'transactions',
        where: paymentWhere,
        whereArgs: paymentArgs,
      );
      return txn.delete('goals', where: 'id = ?', whereArgs: [id]);
    });
  }

  // ===== Utang/piutang =====

  Future<List<Debt>> debts() async {
    final db = await database;
    final rows = await db.query('debts', orderBy: 'settled ASC, date DESC');
    return rows.map(Debt.fromMap).toList();
  }

  Future<int> insertDebt(Debt debt) async {
    final db = await database;
    return db.insert('debts', debt.toMap()..remove('id'));
  }

  /// Bayar utang / terima piutang dan catat transaksi secara atomik.
  Future<void> payDebt({
    required Debt debt,
    required int walletId,
    required double amount,
    required DateTime date,
  }) async {
    final value = amount.round();
    if (value <= 0 || value > debt.remaining.round()) {
      throw ArgumentError.value(amount, 'amount', 'Pembayaran tidak valid');
    }
    final db = await database;
    await db.transaction((txn) async {
      final updated = await txn.rawUpdate(
        'UPDATE debts SET paid = paid + ?, '
        'settled = CASE WHEN paid + ? >= amount THEN 1 ELSE 0 END '
        'WHERE id = ? AND paid + ? <= amount',
        [value, value, debt.id, value],
      );
      if (updated != 1) {
        throw StateError('Pembayaran melebihi sisa utang/piutang');
      }
      await txn.insert('transactions', {
        'amount': value,
        'category_id': debt.isReceivable ? debtPaymentIn.id : debtPaymentOut.id,
        'note': debt.isReceivable
            ? 'Pembayaran piutang: ${debt.person}'
            : 'Bayar utang: ${debt.person}',
        'date': date.toIso8601String(),
        'type': debt.isReceivable ? TxType.income.name : TxType.expense.name,
        'wallet_id': walletId,
        'source_type': 'debt',
        'source_id': debt.id,
      });
    });
  }

  Future<int> paymentCountForDebt(int id) async {
    final db = await database;
    return Sqflite.firstIntValue(
          await db.rawQuery(
            "SELECT COUNT(*) FROM transactions WHERE source_type = 'debt' AND source_id = ?",
            [id],
          ),
        ) ??
        0;
  }

  Future<int> deleteDebt(int id) async {
    final db = await database;
    return db.delete('debts', where: 'id = ?', whereArgs: [id]);
  }

  /// Insert banyak transaksi sekaligus dalam satu batch (buat import).
  Future<void> insertAllTransactions(List<TransactionModel> txs) async {
    final db = await database;
    final batch = db.batch();
    for (final tx in txs) {
      batch.insert('transactions', tx.toMap()..remove('id'));
    }
    await batch.commit(noResult: true);
  }

  /// Semua path foto struk yang masih dipakai transaksi.
  Future<Set<String>> usedReceiptPaths() async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT DISTINCT receipt_path FROM transactions '
      'WHERE receipt_path IS NOT NULL',
    );
    return rows.map((r) => r['receipt_path'] as String).toSet();
  }

  /// Lepasin referensi foto dari transaksi (dipanggil pas foto dihapus).
  Future<void> clearReceiptPath(String path) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE transactions SET receipt_path = NULL WHERE receipt_path = ?',
      [path],
    );
  }

  // ===== Kategori custom =====

  Future<List<CustomCategory>> customCategories() async {
    final db = await database;
    final rows = await db.query('custom_categories', orderBy: 'name ASC');
    return rows.map(CustomCategory.fromMap).toList();
  }

  Future<void> upsertCustomCategory(CustomCategory category) async {
    final db = await database;
    await db.insert(
      'custom_categories',
      category.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> upsertCustomCategories(
    Iterable<CustomCategory> categories,
  ) async {
    final db = await database;
    final batch = db.batch();
    for (final category in categories) {
      batch.insert(
        'custom_categories',
        category.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> deleteCustomCategory(String id) async {
    final db = await database;
    await db.delete('custom_categories', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> transactionCountForCategory(String categoryId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT '
      '(SELECT COUNT(*) FROM transactions WHERE category_id = ?) + '
      '(SELECT COUNT(*) FROM recurrings WHERE category_id = ?) AS c',
      [categoryId, categoryId],
    );
    return result.first['c'] as int;
  }

  // ===== Transaksi berulang =====

  Future<List<Recurring>> recurrings() async {
    final db = await database;
    final rows = await db.query('recurrings', orderBy: 'day ASC, id ASC');
    return rows.map(Recurring.fromMap).toList();
  }

  Future<int> insertRecurring(Recurring recurring) async {
    final db = await database;
    return db.insert('recurrings', recurring.toMap()..remove('id'));
  }

  Future<int> updateRecurring(Recurring recurring) async {
    final db = await database;
    return db.update(
      'recurrings',
      recurring.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [recurring.id],
    );
  }

  Future<int> deleteRecurring(int id) async {
    final db = await database;
    return db.delete('recurrings', where: 'id = ?', whereArgs: [id]);
  }

  Future<int>? _applyingRecurrings;

  /// Masukin semua transaksi berulang yang udah jatuh tempo.
  /// Idempoten: next_due maju bareng insert dalam satu transaksi DB,
  /// jadi dipanggil berkali-kali pun ga bakal dobel. Balikin jumlah
  /// transaksi yang dibikin.
  Future<int> applyDueRecurrings() {
    // Lock: kalau lagi jalan, panggilan kedua numpang hasil yang sama.
    return _applyingRecurrings ??= _doApplyRecurrings().whenComplete(
      () => _applyingRecurrings = null,
    );
  }

  Future<int> _doApplyRecurrings() async {
    final db = await database;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final rows = await db.query(
      'recurrings',
      where: 'active = 1 AND next_due <= ?',
      whereArgs: [today.toIso8601String()],
    );
    if (rows.isEmpty) return 0;
    var inserted = 0;
    await db.transaction((txn) async {
      for (final row in rows) {
        final recurring = Recurring.fromMap(row);
        var due = recurring.nextDue;
        // Catch-up: kalau app lama ga dibuka, semua bulan yang
        // kelewat diisi satu-satu sampai due lewat dari hari ini.
        while (!due.isAfter(today)) {
          await txn.insert('transactions', {
            'amount': recurring.amount.round(),
            'category_id': recurring.categoryId,
            'note': recurring.note,
            'date': due.toIso8601String(),
            'type': recurring.type.name,
            'wallet_id': recurring.walletId,
          });
          inserted++;
          due = Recurring.nextDueAfter(due, recurring.day);
        }
        await txn.update(
          'recurrings',
          {'next_due': due.toIso8601String()},
          where: 'id = ?',
          whereArgs: [recurring.id],
        );
      }
    });
    return inserted;
  }

  // ===== Backup & restore =====

  Future<String> databasePath() async =>
      join(await getDatabasesPath(), 'duit_ges.db');

  /// Backup lengkap: database + foto struk yang masih dipakai.
  Future<void> backupTo(String targetPath) async {
    final db = await database;
    await db.rawQuery('PRAGMA wal_checkpoint(FULL)');
    final encoder = ZipFileEncoder()..create(targetPath);
    try {
      await encoder.addFile(File(await databasePath()), 'duit_ges.db');
      for (final path in await usedReceiptPaths()) {
        final file = File(path);
        if (await file.exists()) {
          await encoder.addFile(file, 'struk/${basename(path)}');
        }
      }
    } finally {
      await encoder.close();
    }
  }

  /// Restore backup ZIP baru atau file database lama.
  Future<bool> restoreFrom(String sourcePath) async {
    final dbPath = await databasePath();
    final candidate = File('$dbPath.restore');
    final safety = File('$dbPath.before_restore');
    Archive? archive;
    var replaced = false;
    try {
      final bytes = await File(sourcePath).readAsBytes();
      if (bytes.length >= 2 && bytes[0] == 0x50 && bytes[1] == 0x4B) {
        archive = ZipDecoder().decodeBytes(bytes, verify: true);
        final databaseFile = archive.findFile('duit_ges.db');
        if (databaseFile == null) return false;
        await candidate.writeAsBytes(databaseFile.content as List<int>);
      } else {
        await File(sourcePath).copy(candidate.path);
      }
      if (!await _isValidBackup(candidate.path)) return false;

      final active = File(dbPath);
      final current = await database;
      await current.rawQuery('PRAGMA wal_checkpoint(FULL)');
      await current.close();
      _db = null;
      if (await safety.exists()) await safety.delete();
      if (await active.exists()) await active.rename(safety.path);
      await candidate.rename(dbPath);
      replaced = true;
      await _deleteIfExists('$dbPath-wal');
      await _deleteIfExists('$dbPath-shm');
      await database;
      await _restoreReceiptPaths(archive);
      return true;
    } catch (_) {
      await _db?.close();
      _db = null;
      if (replaced && await safety.exists()) {
        await _deleteIfExists(dbPath);
        await safety.rename(dbPath);
      } else if (!await File(dbPath).exists() && await safety.exists()) {
        await safety.rename(dbPath);
      }
      return false;
    } finally {
      if (await candidate.exists()) await candidate.delete();
    }
  }

  Future<bool> _isValidBackup(String path) async {
    Database? check;
    try {
      check = await openDatabase(path, readOnly: true, singleInstance: false);
      final integrity = await check.rawQuery('PRAGMA integrity_check');
      final version = Sqflite.firstIntValue(
        await check.rawQuery('PRAGMA user_version'),
      );
      final tables = await check.rawQuery(
        "SELECT name FROM sqlite_master "
        "WHERE type='table' AND name='transactions'",
      );
      return integrity.first.values.first == 'ok' &&
          tables.isNotEmpty &&
          version != null &&
          version > 0 &&
          version <= schemaVersion;
    } catch (_) {
      return false;
    } finally {
      await check?.close();
    }
  }

  Future<void> _restoreReceiptPaths(Archive? archive) async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT DISTINCT receipt_path FROM transactions '
      'WHERE receipt_path IS NOT NULL',
    );
    if (rows.isEmpty) return;
    final documentDir = await getApplicationDocumentsDirectory();
    final receiptDir = Directory(join(documentDir.path, 'struk'));
    await receiptDir.create(recursive: true);
    for (final row in rows) {
      final oldPath = row['receipt_path'] as String;
      final name = basename(oldPath);
      final archived = archive?.findFile('struk/$name');
      String? newPath;
      if (archived != null) {
        newPath = join(receiptDir.path, name);
        await File(newPath).writeAsBytes(archived.content as List<int>);
      } else if (await File(oldPath).exists()) {
        newPath = oldPath;
      }
      await db.rawUpdate(
        'UPDATE transactions SET receipt_path = ? WHERE receipt_path = ?',
        [newPath, oldPath],
      );
    }
  }

  Future<void> _deleteIfExists(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}
