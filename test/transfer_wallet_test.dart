import 'dart:io';

import 'package:duit_ges/db/database_helper.dart';
import 'package:duit_ges/models/category.dart';
import 'package:duit_ges/models/transaction.dart';
import 'package:duit_ges/models/wallet.dart';
import 'package:duit_ges/providers/category_provider.dart';
import 'package:duit_ges/providers/transaction_provider.dart';
import 'package:duit_ges/providers/wallet_provider.dart';
import 'package:duit_ges/screens/add_transaction_screen.dart';
import 'package:duit_ges/screens/wallets_screen.dart';
import 'package:duit_ges/widgets/transfer_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final db = DatabaseHelper.instance;
  late Directory directory;
  late int bankId;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    directory = await Directory.systemTemp.createTemp('duit_ges_transfer_');
    await databaseFactory.setDatabasesPath(directory.path);
    await initializeDateFormatting('id_ID');
    bankId = await db.insertWallet(const Wallet(name: 'Bank'));
  });

  setUp(() => SharedPreferences.setMockInitialValues({'themeId': 'klasik'}));

  test(
    'transfer lama dapat diedit dari sisi masuk tanpa mengubah ID',
    () async {
      final date = DateTime(2026, 7, 12, 9, 15);
      await db.insertTransfer(
        fromWalletId: 1,
        toWalletId: bankId,
        amount: 15000,
        date: date,
        note: 'transfer lama',
      );
      final original = (await db.all())
          .where((tx) => tx.note == 'transfer lama')
          .toList();
      final incoming = original.singleWhere(
        (tx) => tx.categoryId == transferIn.id,
      );
      final changedDate = DateTime(2026, 6, 10, 9, 15);
      await db.updateTransfer(
        id: incoming.id!,
        fromWalletId: bankId,
        toWalletId: 1,
        amount: 7500,
        date: changedDate,
        note: 'sudah diedit',
      );
      final pair = await db.transferTransactions(incoming.id!);
      expect(
        pair.map((tx) => tx.id).toSet(),
        original.map((tx) => tx.id).toSet(),
      );
      expect(pair.first.walletId, bankId);
      expect(pair.last.walletId, 1);
      expect(
        pair.every(
          (tx) =>
              tx.date == changedDate &&
              tx.amount == 7500 &&
              tx.note == 'sudah diedit',
        ),
        isTrue,
      );
      expect(pair.first.categoryId, transferOut.id);
      expect(pair.last.categoryId, transferIn.id);
      expect(await db.delete(pair.first.id!), 2);
    },
  );

  test(
    'edit tanpa pasangan atau nominal invalid tidak mengubah data',
    () async {
      await db.insertTransfer(
        fromWalletId: 1,
        toWalletId: bankId,
        amount: 12000,
        date: DateTime(2026, 7, 11),
        note: 'uji atomik',
      );
      final original = (await db.all())
          .where((tx) => tx.note == 'uji atomik')
          .toList();
      await expectLater(
        db.updateTransfer(
          id: original.first.id!,
          fromWalletId: 1,
          toWalletId: 1,
          amount: 100,
          date: DateTime(2026),
        ),
        throwsArgumentError,
      );
      expect(
        (await db.transferTransactions(original.first.id!)).first.amount,
        12000,
      );
      final sql = await db.database;
      await sql.delete(
        'transactions',
        where: 'id = ?',
        whereArgs: [original.last.id],
      );
      await expectLater(
        db.updateTransfer(
          id: original.first.id!,
          fromWalletId: bankId,
          toWalletId: 1,
          amount: 100,
          date: DateTime(2026),
        ),
        throwsStateError,
      );
      final remaining = (await db.all()).singleWhere(
        (tx) => tx.id == original.first.id,
      );
      expect(remaining.amount, 12000);
      expect(remaining.note, 'uji atomik');
      await db.delete(remaining.id!);
    },
  );

  test(
    'dompet default persisten, kompatibel preferensi lama dan fallback ID hilang',
    () async {
      final wallets = WalletProvider();
      await wallets.load();
      expect(wallets.defaultWalletId, 1);
      await wallets.setDefaultWallet(bankId);
      final reloaded = WalletProvider();
      await reloaded.load();
      expect(reloaded.defaultWalletId, bankId);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('themeId'), 'klasik');
      await prefs.setInt('defaultWalletId', 999999);
      await reloaded.load();
      expect(reloaded.defaultWalletId, 1);
      wallets.dispose();
      reloaded.dispose();
    },
  );

  testWidgets('transfer menampilkan tanggal, dompet default dan tombol tukar', (
    tester,
  ) async {
    final wallets = WalletProvider();
    await tester.runAsync(() async {
      await wallets.load();
      await wallets.setDefaultWallet(bankId);
    });
    await tester.pumpWidget(
      MultiProvider(
        providers: [ChangeNotifierProvider.value(value: wallets)],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showTransferSheet(context),
                child: const Text('Buka transfer'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Buka transfer'));
    await tester.pumpAndSettle();
    expect(find.text('Tanggal transfer'), findsOneWidget);
    var fields = tester
        .widgetList<DropdownButtonFormField<int>>(
          find.byType(DropdownButtonFormField<int>),
        )
        .toList();
    expect(fields.first.initialValue, bankId);
    await tester.tap(find.byTooltip('Tukar dompet'));
    await tester.pumpAndSettle();
    fields = tester
        .widgetList<DropdownButtonFormField<int>>(
          find.byType(DropdownButtonFormField<int>),
        )
        .toList();
    expect(fields.first.initialValue, 1);
    expect(fields.last.initialValue, bankId);
    await tester.tap(find.text('Tanggal transfer'));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    wallets.dispose();
  });

  testWidgets('kelola dompet menyediakan pilihan default', (tester) async {
    final wallets = WalletProvider();
    await tester.runAsync(wallets.load);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: wallets,
        child: const MaterialApp(home: WalletsScreen()),
      ),
    );
    await tester.tap(find.byTooltip('Jadikan dompet default').first);
    await tester.pumpAndSettle();
    expect(wallets.defaultWalletId, bankId);
    expect(find.byTooltip('Dompet default'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    wallets.dispose();
  });

  test(
    'provider menyimpan tanggal pilihan untuk transfer baru dan edit',
    () async {
      final provider = TransactionProvider();
      final date = DateTime(2026, 5, 4, 10, 11);
      await provider.addTransfer(
        fromWalletId: 1,
        toWalletId: bankId,
        amount: 23000,
        date: date,
        note: 'tanggal pilihan',
      );
      final original = (await db.all()).firstWhere(
        (tx) => tx.note == 'tanggal pilihan',
      );
      expect(original.date, date);
      final editedDate = DateTime(2026, 4, 3, 10, 11);
      await provider.addTransfer(
        fromWalletId: 1,
        toWalletId: bankId,
        amount: 24000,
        date: editedDate,
        note: 'tanggal diedit',
        existingId: original.id,
      );
      final pair = await db.transferTransactions(original.id!);
      expect(pair.every((tx) => tx.date == editedDate), isTrue);
      expect(provider.walletRevision, 2);
      await db.delete(original.id!);
      provider.dispose();
    },
  );

  testWidgets(
    'transaksi baru memilih default, edit mempertahankan dompet lama',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final wallets = WalletProvider();
      await tester.runAsync(() async {
        await wallets.load();
        await wallets.setDefaultWallet(bankId);
      });
      Future<void> showForm({TransactionModel? existing}) => tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: wallets),
            ChangeNotifierProvider(create: (_) => CategoryProvider()),
          ],
          child: MaterialApp(
            home: AddTransactionScreen(
              key: ValueKey(existing?.id),
              existing: existing,
            ),
          ),
        ),
      );
      await showForm();
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.text('Bank')).style?.fontWeight,
        FontWeight.bold,
      );
      await showForm(
        existing: TransactionModel(
          id: 999,
          amount: 1000,
          categoryId: 'makanan',
          type: TxType.expense,
          date: DateTime(2026, 7, 1),
          walletId: 1,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.text('Bank')).style?.fontWeight,
        FontWeight.w500,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      wallets.dispose();
    },
  );

  tearDownAll(() async {
    await (await db.database).close();
    await directory.delete(recursive: true);
  });
}
