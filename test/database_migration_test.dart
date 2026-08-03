import 'dart:io';

import 'package:duit_ges/db/database_helper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test('migrasi v7 membulatkan nominal dan menambah relasi pembayaran', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dir = Directory.systemTemp.createTempSync('duit_ges_migration_');
    addTearDown(() => dir.deleteSync(recursive: true));
    await databaseFactory.setDatabasesPath(dir.path);
    final old = await openDatabase(
      '${dir.path}/duit_ges.db',
      version: 7,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE transactions(
            id INTEGER PRIMARY KEY AUTOINCREMENT, amount REAL NOT NULL,
            category_id TEXT NOT NULL, note TEXT NOT NULL DEFAULT '',
            date TEXT NOT NULL, type TEXT NOT NULL,
            wallet_id INTEGER NOT NULL DEFAULT 1, receipt_path TEXT)
        ''');
        await db.execute(
          'CREATE TABLE budgets(category_id TEXT PRIMARY KEY, amount REAL NOT NULL)',
        );
        await db.execute('''
          CREATE TABLE wallets(
            id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL,
            icon TEXT NOT NULL, color INTEGER NOT NULL,
            initial_balance REAL NOT NULL DEFAULT 0)
        ''');
        await db.execute('''
          CREATE TABLE goals(
            id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL,
            target REAL NOT NULL, saved REAL NOT NULL, color INTEGER NOT NULL)
        ''');
        await db.execute('''
          CREATE TABLE debts(
            id INTEGER PRIMARY KEY AUTOINCREMENT, person TEXT NOT NULL,
            amount REAL NOT NULL, is_receivable INTEGER NOT NULL,
            note TEXT NOT NULL, date TEXT NOT NULL, settled INTEGER NOT NULL)
        ''');
        await db.execute('''
          CREATE TABLE recurrings(
            id INTEGER PRIMARY KEY AUTOINCREMENT, amount REAL NOT NULL,
            category_id TEXT NOT NULL, wallet_id INTEGER NOT NULL,
            note TEXT NOT NULL, type TEXT NOT NULL, day INTEGER NOT NULL,
            next_due TEXT NOT NULL, active INTEGER NOT NULL)
        ''');
        await db.insert('transactions', {
          'amount': 10000.6,
          'category_id': 'makanan',
          'date': DateTime(2026, 7, 18).toIso8601String(),
          'type': 'expense',
        });
        await db.insert('budgets', {'category_id': 'makanan', 'amount': 9.6});
        await db.insert('wallets', {
          'name': 'Tunai',
          'icon': 'cash',
          'color': 1,
          'initial_balance': 8.6,
        });
        await db.insert('goals', {
          'name': 'Tes',
          'target': 7.6,
          'saved': 6.6,
          'color': 1,
        });
        await db.insert('debts', {
          'person': 'Tes',
          'amount': 5.6,
          'is_receivable': 0,
          'note': '',
          'date': DateTime(2026, 7, 18).toIso8601String(),
          'settled': 0,
        });
        await db.insert('recurrings', {
          'amount': 4.6,
          'category_id': 'makanan',
          'wallet_id': 1,
          'note': '',
          'type': 'expense',
          'day': 1,
          'next_due': DateTime(2026, 8).toIso8601String(),
          'active': 1,
        });
      },
    );
    await old.close();

    final db = await DatabaseHelper.instance.database;
    for (final (table, column, expected) in [
      ('transactions', 'amount', 10001),
      ('budgets', 'amount', 10),
      ('wallets', 'initial_balance', 9),
      ('goals', 'target', 8),
      ('goals', 'saved', 7),
      ('debts', 'amount', 6),
      ('recurrings', 'amount', 5),
    ]) {
      final row = (await db.rawQuery(
        'SELECT $column AS value, typeof($column) AS type FROM $table LIMIT 1',
      )).single;
      expect(row['value'], expected);
      expect(row['type'], 'integer');
    }
    final transactionColumns = await db.rawQuery(
      'PRAGMA table_info(transactions)',
    );
    expect(
      transactionColumns.map((column) => column['name']),
      containsAll(['source_type', 'source_id', 'budget_id']),
    );
    final debt = (await db.rawQuery('SELECT paid FROM debts LIMIT 1')).single;
    expect(debt['paid'], 0);
    expect(
      (await db.rawQuery(
        'PRAGMA table_info(budgets)',
      )).map((column) => column['name']),
      containsAll([
        'id',
        'name',
        'icon',
        'color',
        'budget_type',
        'scope',
        'category_id',
      ]),
    );
    expect(
      (await db.rawQuery(
        'PRAGMA table_info(debts)',
      )).map((column) => column['name']),
      contains('due_date'),
    );
    expect(
      (await db.rawQuery(
        'PRAGMA table_info(goals)',
      )).map((column) => column['name']),
      contains('icon'),
    );
    final indexes = (await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'index'",
    )).map((row) => row['name']);
    expect(indexes, containsAll(['idx_tx_date_id', 'idx_tx_wallet_date_id']));
    expect(indexes, isNot(contains('idx_tx_date')));
    expect(indexes, isNot(contains('idx_tx_wallet')));
  });
}
