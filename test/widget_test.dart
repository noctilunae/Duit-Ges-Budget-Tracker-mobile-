import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:duit_ges/models/category.dart';
import 'package:duit_ges/models/recurring.dart';
import 'package:duit_ges/models/transaction.dart';
import 'package:duit_ges/providers/settings_provider.dart';
import 'package:duit_ges/utils/formatters.dart';
import 'package:duit_ges/widgets/theme_artwork.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('rupiah memformat angka jadi format Rupiah', () {
    expect(rupiah(50000), 'Rp 50.000');
    expect(rupiah(1250000), 'Rp 1.250.000');
  });

  test('TransactionModel toMap/fromMap bolak-balik konsisten', () {
    final tx = TransactionModel(
      id: 1,
      amount: 25000,
      categoryId: 'makanan',
      note: 'nasi goreng',
      date: DateTime(2026, 7, 17, 12, 30),
      type: TxType.expense,
    );
    final restored = TransactionModel.fromMap(tx.toMap());
    expect(restored.id, tx.id);
    expect(restored.amount, tx.amount);
    expect(restored.categoryId, tx.categoryId);
    expect(restored.note, tx.note);
    expect(restored.date, tx.date);
    expect(restored.type, tx.type);
  });

  test('widget Android punya keypad dan simpan langsung tanpa redirect', () {
    final layout = File(
      'android/app/src/main/res/layout/saldo_widget.xml',
    ).readAsStringSync();
    final provider = File(
      'android/app/src/main/kotlin/com/noctilune/duitnia/'
      'SaldoWidgetProvider.kt',
    ).readAsStringSync();

    for (final id in [
      'widget_type_expense',
      'widget_type_income',
      'widget_category_0',
      'widget_category_icon_0',
      'widget_wallet',
      'widget_wallet_icon',
      'widget_key_000',
      'widget_save',
    ]) {
      expect(layout, contains(id));
    }
    expect(provider, contains('insertOrThrow("transactions"'));
    expect(provider, contains('MaterialIcons-Regular.otf'));
    expect(provider, isNot(contains('duitges://add')));
  });

  test('setoran target bisa digeser untuk dihapus dari halaman transaksi', () {
    final home = File('lib/screens/home_screen.dart').readAsStringSync();
    expect(home, contains('direction: DismissDirection.endToStart'));
    expect(home, isNot(contains('transaction.isGoalSaving\n')));
  });

  test('baris rekap punya dropdown menuju detail transaksi', () {
    final recap = File('lib/screens/recap_screen.dart').readAsStringSync();
    expect(recap, contains('Tampilkan detail'));
    expect(recap, contains('showTransactionDetailSheet'));
  });

  test('categoryById fallback ke kategori terakhir kalau id tidak dikenal', () {
    expect(categoryById('makanan').name, 'Makanan');
    expect(categoryById('ga-ada').id, 'lainnya_masuk');
  });

  test('input kategori massal dipisah, dirapikan, dan diduplikasi sekali', () {
    expect(parseCategoryNames('Laundry\n Kos,Langganan\nLaundry'), [
      'Laundry',
      'Kos',
      'Langganan',
    ]);
  });

  test('pilihan kategori dan ikon custom diperbanyak', () {
    expect(expenseCategories.length, greaterThanOrEqualTo(29));
    expect(incomeCategories.length, greaterThanOrEqualTo(15));
    expect(categoryIconChoices.length, greaterThanOrEqualTo(50));
    expect(categoryColorChoices.length, 21);
  });

  test('groupRibuan nyisipin titik tiap 3 digit', () {
    expect(groupRibuan('500'), '500');
    expect(groupRibuan('50000'), '50.000');
    expect(groupRibuan('1250000'), '1.250.000');
  });

  test('RibuanInputFormatter memformat ketikan & buang nol di depan', () {
    final formatter = RibuanInputFormatter();
    TextEditingValue format(String text) => formatter.formatEditUpdate(
      TextEditingValue.empty,
      TextEditingValue(text: text),
    );
    expect(format('50000').text, '50.000');
    expect(format('0500').text, '500');
    expect(format('').text, '');
  });

  test('SettingsProvider menandai data siap setelah load', () async {
    SharedPreferences.setMockInitialValues({'themeId': 'kucing'});
    final settings = SettingsProvider();
    expect(settings.ready, isFalse);
    await settings.load();
    expect(settings.ready, isTrue);
    expect(settings.preset.id, 'kucing');
    await settings.setHideWallets(true);
    await settings.setPrivacyMode(true);
    final restored = SettingsProvider();
    await restored.load();
    expect(restored.hideWallets, isTrue);
    expect(restored.privacyMode, isTrue);
  });

  test('PIN dikunci sementara setelah 5 percobaan salah', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsProvider();
    await settings.load();
    await settings.setPin('1234');
    for (var i = 0; i < 5; i++) {
      expect(await settings.verifyPin('0000'), isFalse);
    }
    expect(settings.pinCooldown, greaterThan(Duration.zero));
    expect(await settings.verifyPin('1234'), isFalse);
  });

  test('ukuran teks default, dibatasi, dan tersimpan global', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsProvider();
    await settings.load();
    expect(settings.textScale, 1);
    await settings.setTextScale(2);
    expect(settings.textScale, 1.4);
    final restored = SettingsProvider();
    await restored.load();
    expect(restored.textScale, 1.4);
  });

  test('tema bergambar memakai folder PNG dan warna khas', () {
    expect(SettingsProvider.presetColors, contains(const Color(0xFF8DB7D8)));
    expect(SettingsProvider.presetColors, hasLength(16));
    final cat = themePresets.firstWhere((theme) => theme.id == 'kucing');
    final duck = themePresets.firstWhere((theme) => theme.id == 'bebek');
    final anya = themePresets.firstWhere((theme) => theme.id == 'anya');
    final jjk = themePresets.firstWhere((theme) => theme.id == 'jjk');
    final jjk2 = themePresets.firstWhere((theme) => theme.id == 'jjk2');
    final callDuck = themePresets.firstWhere(
      (theme) => theme.id == 'call_duck',
    );
    final frieren = themePresets.firstWhere((theme) => theme.id == 'frieren');
    final frierenRial = themePresets.firstWhere(
      (theme) => theme.id == 'frieren_rial',
    );
    expect(cat.artwork, 'assets/theme/cat');
    expect(duck.artwork, 'assets/theme/duck');
    expect(anya.artwork, 'assets/theme/anya');
    expect(jjk.artwork, 'assets/theme/jjk');
    expect(frieren.artwork, 'assets/theme/frieren');
    expect(frierenRial.name, 'Frieren Rial');
    expect(frierenRial.tileGifs, {
      3: 'assets/theme/frieren_rial/footer_setelan.png',
      6: 'assets/theme/frieren_rial/footer_transaksi.png',
      7: 'assets/theme/frieren_rial/footer_budget.png',
      8: 'assets/theme/frieren_rial/footer_statistik.png',
    });
    expect(duck.defaultAccent, const Color(0xFFF5B82E));
    expect(jjk2.tabAccents, const [
      Color(0xFF42A5FF),
      Color(0xFFE04455),
      Color(0xFF8066D6),
      Color(0xFFE8883E),
    ]);
    expect(callDuck.footerGifManualControl, isTrue);
    expect(callDuck.fabGif, 'assets/theme/call_duck/add_transaction.gif');
    expect(callDuck.tileGifs[0], isNull);
    expect(cat.tones.map((tone) => tone.id), ['pink', 'blue', 'yellow']);
    expect(duck.tones.map((tone) => tone.id), ['yellow', 'blue', 'pink']);
  });

  test('template background Frieren Rial eksklusif dan tersimpan', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsProvider();
    await settings.load();
    await settings.setTheme(
      themePresets.firstWhere((theme) => theme.id == 'frieren_rial'),
    );
    expect(settings.darkMode, isTrue);
    expect(settings.cardStyle, CardStyle.frierenRialVideo135);
    expect(
      settings.frierenRialBackground,
      FrierenRialBackground.defaultBackground,
    );
    expect(FrierenRialBackground.values, hasLength(6));
    expect(FrierenRialBackground.eclipse.asset, isNotNull);
    expect(FrierenRialBackground.journey.asset, isNotNull);
    expect(
      FrierenRialBackground.values.skip(1).every((b) => b.asset != null),
      isTrue,
    );

    await settings.setFrierenRialBackground(FrierenRialBackground.meadow);
    final restored = SettingsProvider();
    await restored.load();
    expect(restored.frierenRialBackground, FrierenRialBackground.meadow);
    expect(restored.cardStyle, CardStyle.frierenRialVideo135);
    await restored.setTheme(
      themePresets.firstWhere((theme) => theme.id == 'klasik'),
    );
    expect(restored.cardStyle, CardStyle.gradient);
  });

  testWidgets('placeholder hitam JJK 2 memakai footer statis', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsProvider();
    await settings.load();
    await settings.setTheme(
      themePresets.firstWhere((theme) => theme.id == 'jjk2'),
    );
    const expectedAssets = {
      3: 'assets/theme/jjk2/footer_setelan_static.png',
      4: 'assets/theme/jjk2/footer_budget_static.png',
      6: 'assets/theme/jjk2/footer_budget_static.png',
      7: 'assets/theme/jjk2/footer_budget_static.png',
      8: 'assets/theme/jjk2/footer_statistik_static.png',
      11: 'assets/theme/jjk2/footer_budget_static.png',
    };

    for (final entry in expectedAssets.entries) {
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: settings,
          child: MaterialApp(home: ThemeArtwork(tile: entry.key, size: 88)),
        ),
      );
      final image = tester.widget<Image>(find.byType(Image));
      expect((image.image as AssetImage).assetName, entry.value);
    }
  });

  test('instalasi baru langsung memakai tema klasik', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsProvider();
    await settings.load();
    expect(settings.preset.id, 'klasik');
    expect(settings.accent, const Color(0xFF2E5BFF));
  });

  test('varian warna mengganti aset dan aksen tema aktif', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsProvider();
    await settings.load();
    await settings.setTheme(
      themePresets.firstWhere((theme) => theme.id == 'kucing'),
    );
    await settings.setTone(settings.preset.tones[1]);
    expect(settings.artwork, 'assets/theme/cat_blue');
    expect(settings.accent, const Color(0xFF5D9EDB));
  });

  test('template video JJK 2 kembali default saat ganti tema', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsProvider();
    await settings.load();
    await settings.setTheme(
      themePresets.firstWhere((theme) => theme.id == 'jjk2'),
    );
    await settings.setCardStyle(CardStyle.jjkVideo1);
    expect(settings.cardStyle, CardStyle.jjkVideo1);
    await settings.setTheme(
      themePresets.firstWhere((theme) => theme.id == 'klasik'),
    );
    expect(settings.cardStyle, CardStyle.gradient);
  });

  testWidgets('PNG tema tersedia di bundle aplikasi', (_) async {
    // Dipakai semua tema.
    const universalNames = [
      'mascot_utama',
      'header_home',
      'header_setelan',
      'konten_budget',
      'footer_transaksi_default',
      'header_budget',
      'header_statistik',
      'konten_target',
    ];
    // Cuma diminta pas tema frieren/jjk aktif (lihat main_shell.dart) —
    // di tema lain filenya sengaja ga ada biar ga numpang di APK.
    const friJjkOnlyNames = [
      'footer_transaksi_frieren',
      'footer_budget',
      'footer_statistik',
      'footer_transaksi_jjk',
      'footer_setelan_frieren',
      'footer_setelan_jjk',
    ];
    for (final theme in [
      'cat',
      'cat_blue',
      'cat_yellow',
      'duck',
      'duck_blue',
      'duck_pink',
      'anya',
      'jjk',
      'frieren',
      'spongebob',
      'jjk2',
    ]) {
      for (final name in universalNames) {
        final data = await rootBundle.load('assets/theme/$theme/$name.png');
        expect(data.lengthInBytes, greaterThan(0));
      }
    }
    for (final theme in ['jjk', 'frieren']) {
      for (final name in friJjkOnlyNames) {
        final data = await rootBundle.load('assets/theme/$theme/$name.png');
        expect(data.lengthInBytes, greaterThan(0));
      }
    }
    // Spongebob punya slot footer sendiri (tile 5/9/14).
    for (final name in [
      'footer_budget',
      'footer_statistik',
      'footer_setelan',
    ]) {
      final data = await rootBundle.load('assets/theme/spongebob/$name.png');
      expect(data.lengthInBytes, greaterThan(0));
    }
    for (final path in [
      'assets/theme/frieren/add_transaction.gif',
      'assets/theme/spongebob/add_transaction.gif',
      'assets/theme/spongebob/header_home.gif',
      'assets/theme/spongebob/mascot_utama.gif',
      'assets/theme/jjk2/add_transaction.gif',
      'assets/theme/jjk2/add_transaction_idle.gif',
      'assets/theme/jjk2/mascot_utama.gif',
      'assets/theme/jjk2/visibility.gif',
      'assets/theme/jjk2/footer_transaksi.gif',
      'assets/theme/jjk2/footer_budget.gif',
      'assets/theme/jjk2/footer_statistik.gif',
      'assets/theme/jjk2/footer_setelan.gif',
      'assets/theme/jjk2/card_saldo_1.mp4',
      'assets/theme/jjk2/card_saldo_2.mp4',
      'assets/theme/call_duck/add_transaction.gif',
      'assets/theme/call_duck/add_transaction_static.png',
      'assets/theme/call_duck/footer_transaksi.gif',
      'assets/theme/call_duck/footer_budget.gif',
      'assets/theme/call_duck/footer_statistik.gif',
      'assets/theme/call_duck/footer_setelan.gif',
      'assets/theme/call_duck/109.png',
      'assets/theme/call_duck/110.png',
      'assets/theme/call_duck/footer_transaksi_static.png',
      'assets/theme/call_duck/footer_budget_static.png',
      'assets/theme/call_duck/footer_statistik_static.png',
      'assets/theme/call_duck/footer_setelan_static.png',
      'assets/theme/frieren_rial/background_eclipse.jpg',
      'assets/theme/frieren_rial/background_journey.jpg',
      'assets/theme/frieren_rial/background_meadow.jpg',
      'assets/theme/frieren_rial/background_lotus.jpg',
      'assets/theme/frieren_rial/background_blue_sky.jpg',
      'assets/theme/frieren_rial/add_transaction.gif',
      'assets/theme/frieren_rial/card_saldo_135.mp4',
      'assets/theme/frieren_rial/card_saldo_136.mp4',
      'assets/theme/frieren_rial/card_saldo_137.mp4',
      'assets/theme/frieren_rial/card_saldo_138.mp4',
      'assets/theme/frieren_rial/footer_transaksi.png',
      'assets/theme/frieren_rial/footer_budget.png',
      'assets/theme/frieren_rial/footer_statistik.png',
      'assets/theme/frieren_rial/footer_setelan.png',
      'assets/theme/frieren_rial/visibility.png',
    ]) {
      final gif = await rootBundle.load(path);
      expect(gif.lengthInBytes, greaterThan(0));
    }
    // Static PNG pendamping tiap GIF footer jjk2 (footerGifManualControl).
    for (final name in [
      'footer_transaksi',
      'footer_budget',
      'footer_statistik',
      'footer_setelan',
    ]) {
      final data = await rootBundle.load(
        'assets/theme/jjk2/${name}_static.png',
      );
      expect(data.lengthInBytes, greaterThan(0));
    }
    for (final theme in ['frieren', 'jjk', 'anya', 'spongebob', 'call_duck']) {
      final visibility = await rootBundle.load(
        'assets/theme/$theme/visibility.png',
      );
      expect(visibility.lengthInBytes, greaterThan(0));
    }
  });

  testWidgets('GIF tema bisa di-decode codec Flutter (bukan cuma ada)', (
    tester,
  ) async {
    // File ada != file kebaca: GIF yang encoding-nya aneh bakal lolos
    // cek ukuran tapi tetep nongol sebagai kotak-X di HP. Makanya di sini
    // di-decode beneran pake codec dart:ui — sama kayak runtime aslinya.
    // runAsync wajib: decoding jalan di thread IO engine (async beneran),
    // ga bisa di dalam fake-async zone-nya testWidgets.
    await tester.runAsync(() async {
      for (final path in [
        'assets/theme/frieren/add_transaction.gif',
        'assets/theme/spongebob/add_transaction.gif',
        'assets/theme/spongebob/header_home.gif',
        'assets/theme/spongebob/mascot_utama.gif',
        'assets/theme/jjk2/add_transaction.gif',
        'assets/theme/jjk2/add_transaction_idle.gif',
        'assets/theme/jjk2/mascot_utama.gif',
        'assets/theme/jjk2/visibility.gif',
        'assets/theme/jjk2/footer_transaksi.gif',
        'assets/theme/jjk2/footer_budget.gif',
        'assets/theme/jjk2/footer_statistik.gif',
        'assets/theme/jjk2/footer_setelan.gif',
        'assets/theme/call_duck/add_transaction.gif',
        'assets/theme/call_duck/footer_transaksi.gif',
        'assets/theme/call_duck/footer_budget.gif',
        'assets/theme/call_duck/footer_statistik.gif',
        'assets/theme/call_duck/footer_setelan.gif',
      ]) {
        final data = await rootBundle.load(path);
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        expect(
          codec.frameCount,
          greaterThan(0),
          reason: '$path gagal di-decode',
        );
        final frame = await codec.getNextFrame();
        expect(frame.image.width, greaterThan(0), reason: '$path frame kosong');
        codec.dispose();
      }
    });
  });

  test('Recurring.nextDueAfter mentok ke akhir bulan pendek', () {
    // Tanggal 31 ketemu Februari → jadi 28 (atau 29 pas kabisat)
    final jan31 = DateTime(2026, 1, 31);
    final feb = Recurring.nextDueAfter(jan31, 31);
    expect(feb, DateTime(2026, 2, 28));
    // Habis Februari, balik lagi ke 31 (bukan nyangkut di 28)
    final mar = Recurring.nextDueAfter(feb, 31);
    expect(mar, DateTime(2026, 3, 31));
    // Tahun kabisat: Februari 29
    final feb2028 = Recurring.nextDueAfter(DateTime(2028, 1, 31), 31);
    expect(feb2028, DateTime(2028, 2, 29));
  });

  test('Recurring.nextDueAfter lintas tahun', () {
    final des = DateTime(2026, 12, 15);
    expect(Recurring.nextDueAfter(des, 15), DateTime(2027, 1, 15));
  });

  test('Recurring toMap/fromMap bolak-balik konsisten', () {
    final recurring = Recurring(
      id: 3,
      amount: 5000000,
      categoryId: 'gaji',
      walletId: 2,
      note: 'Gaji kantor',
      type: TxType.income,
      day: 25,
      nextDue: DateTime(2026, 7, 25),
      active: true,
    );
    final restored = Recurring.fromMap(recurring.toMap());
    expect(restored.id, recurring.id);
    expect(restored.amount, recurring.amount);
    expect(restored.categoryId, recurring.categoryId);
    expect(restored.walletId, recurring.walletId);
    expect(restored.note, recurring.note);
    expect(restored.type, recurring.type);
    expect(restored.day, recurring.day);
    expect(restored.nextDue, recurring.nextDue);
    expect(restored.active, recurring.active);
  });

  test('rupiahSingkat mendekin angka buat cell kalender', () {
    expect(rupiahSingkat(500), '500');
    expect(rupiahSingkat(50000), '50rb');
    expect(rupiahSingkat(1250000), '1,3jt');
    expect(rupiahSingkat(2000000000), '2M');
  });
}
