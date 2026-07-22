import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'providers/budget_provider.dart';
import 'providers/category_provider.dart';
import 'providers/debt_provider.dart';
import 'providers/goal_provider.dart';
import 'providers/recurring_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/transaction_provider.dart';
import 'providers/wallet_provider.dart';
import 'screens/lock_screen.dart';
import 'screens/main_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Load data nama bulan/hari bahasa Indonesia buat package intl.
  await initializeDateFormatting('id_ID');
  runApp(const DuitGesApp());
}

class DuitGesApp extends StatelessWidget {
  const DuitGesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()..load()),
        ChangeNotifierProvider(create: (_) => CategoryProvider()..load()),
        // Proxy: kategori custom ke-load/berubah → tampilan transaksi
        // (nama/icon dari categoryById + cache statistik) ikut refresh.
        // Tanpa ini, transaksi kategori custom keburu ke-render sebagai
        // "Lainnya" pas app baru buka dan ga pernah bener sendiri.
        // Sekalian denger SettingsProvider buat setting awal periode
        // bulanan (mulai hitung dari tanggal berapa).
        ChangeNotifierProxyProvider2<
          CategoryProvider,
          SettingsProvider,
          TransactionProvider
        >(
          create: (_) => TransactionProvider()..load(applyRecurrings: true),
          update: (_, categories, settings, tx) => tx!
            ..categoriesChanged(categories.version)
            ..setMonthStartDay(settings.monthStartDay),
        ),
        ChangeNotifierProvider(create: (_) => BudgetProvider()..load()),
        ChangeNotifierProvider(create: (_) => GoalProvider()..load()),
        ChangeNotifierProvider(create: (_) => DebtProvider()..load()),
        ChangeNotifierProvider(create: (_) => RecurringProvider()..load()),
        // Proxy: tiap ada perubahan transaksi, saldo dompet ikut ke-refresh
        ChangeNotifierProxyProvider<TransactionProvider, WalletProvider>(
          create: (_) => WalletProvider()..load(),
          update: (_, tx, wallet) => wallet!..loadBalances(tx.walletRevision),
        ),
      ],
      child:
          Selector<
            SettingsProvider,
            ({
              String font,
              double textScale,
              Color accent,
              List<Color> light,
              List<Color> dark,
              bool darkMode,
              bool ready,
              bool locked,
            })
          >(
            selector: (_, settings) => (
              font: settings.font.family,
              textScale: settings.textScale,
              accent: settings.accent,
              light: settings.lightBackground,
              dark: settings.darkBackground,
              darkMode: settings.darkMode,
              ready: settings.ready,
              locked: settings.locked,
            ),
            builder: (context, settings, _) => MaterialApp(
              title: 'Duit Ges',
              debugShowCheckedModeBanner: false,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(settings.textScale)),
                child: child!,
              ),
              theme: ThemeData(
                useMaterial3: true,
                fontFamily: settings.font,
                colorScheme: ColorScheme.fromSeed(seedColor: settings.accent),
                scaffoldBackgroundColor: settings.light.first,
                inputDecorationTheme: InputDecorationTheme(
                  filled: true,
                  fillColor: settings.light.last,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                ),
                appBarTheme: const AppBarTheme(
                  centerTitle: true,
                  backgroundColor: Colors.transparent,
                  scrolledUnderElevation: 0,
                ),
              ),
              darkTheme: ThemeData(
                useMaterial3: true,
                fontFamily: settings.font,
                colorScheme: ColorScheme.fromSeed(
                  seedColor: settings.accent,
                  brightness: Brightness.dark,
                ),
                scaffoldBackgroundColor: settings.dark.first,
                inputDecorationTheme: InputDecorationTheme(
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                ),
                appBarTheme: const AppBarTheme(
                  centerTitle: true,
                  backgroundColor: Colors.transparent,
                  scrolledUnderElevation: 0,
                ),
              ),
              themeMode: settings.darkMode ? ThemeMode.dark : ThemeMode.light,
              home: settings.ready
                  ? settings.locked
                        ? const LockScreen()
                        : const MainShell()
                  : const SizedBox.shrink(),
            ),
          ),
    );
  }
}
