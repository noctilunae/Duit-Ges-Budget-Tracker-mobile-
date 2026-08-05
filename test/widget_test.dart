import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:duit_ges/models/category.dart';
import 'package:duit_ges/models/budget.dart';
import 'package:duit_ges/models/goal.dart';
import 'package:duit_ges/models/custom_template.dart';
import 'package:duit_ges/models/recurring.dart';
import 'package:duit_ges/models/transaction.dart';
import 'package:duit_ges/models/wallet.dart';
import 'package:duit_ges/providers/settings_provider.dart';
import 'package:duit_ges/services/custom_template_importer.dart';
import 'package:duit_ges/services/theme_icon_importer.dart';
import 'package:duit_ges/utils/formatters.dart';
import 'package:duit_ges/widgets/custom_image_icon_picker.dart';
import 'package:duit_ges/widgets/custom_template_view.dart';
import 'package:duit_ges/widgets/theme_artwork.dart';
import 'package:duit_ges/utils/stored_icon.dart';
import 'package:duit_ges/utils/theme_icon_media.dart';
import 'package:duit_ges/utils/icon_crop.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('rupiah memformat angka jadi format Rupiah', () {
    expect(rupiah(50000), 'Rp 50.000');
    expect(rupiah(1250000), 'Rp 1.250.000');
  });

  test('ukuran file memakai KB dan MB', () {
    expect(formatFileSize(1536), '2 KB');
    expect(formatFileSize(1572864), '1.50 MB');
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

  test('kategori dan dompet custom menyimpan emoji tanpa migrasi', () {
    const category = CustomCategory(
      id: 'bebek',
      name: 'Bebek',
      iconKey: 'emoji:🦆',
      color: Colors.amber,
      type: TxType.expense,
    );
    const wallet = Wallet(name: 'Celengan', iconKey: 'emoji:🐣');

    expect(category.toCategory().emoji, '🦆');
    expect(CustomCategory.fromMap(category.toMap()).iconKey, 'emoji:🦆');
    expect(Wallet.fromMap(wallet.toMap()).emoji, '🐣');
  });

  test('ikon gambar menyimpan path dan skala tanpa mengubah kolom lama', () {
    final key = storedImageIcon('/tmp/icon.png', 1.25);
    expect(isValidStoredImageIcon(key), isTrue);
    expect(parseStoredImageIcon(key), (scale: 1.25, path: '/tmp/icon.png'));
    expect(
      parseStoredImageIcon(storedImageIcon('/tmp/icon.png', 9))!.scale,
      2.5,
    );
    final wallet = Wallet(name: 'Gambar', iconKey: key);
    expect(Wallet.fromMap(wallet.toMap()).iconKey, key);
  });

  testWidgets('preview ikon gambar menunjukkan skala sampai 250%', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomImageIconPicker(
            iconKey: storedImageIcon('assets/theme/paw_cat.png', 2.5),
            fallbackKey: 'star',
            previewColor: Colors.orange,
            onChanged: (_) {},
          ),
        ),
      ),
    );

    final preview = find.byKey(const ValueKey('custom-icon-preview'));
    expect(tester.getSize(preview), const Size.square(160));
    expect(tester.widget<Slider>(find.byType(Slider)).value, 2.5);
    final image = tester.widget<Image>(
      find.descendant(of: preview, matching: find.byType(Image)),
    );
    expect((image.width, image.height), (240, 240));
  });

  testWidgets('template background menerapkan opacity', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CustomTemplateView(
          template: CustomTemplate(
            id: 'background-opacity',
            name: 'Background',
            kind: CustomTemplateKind.background,
            media: CustomTemplateMedia.image,
            path: 'assets/theme/paw_cat.png',
            opacity: 0.45,
          ),
        ),
      ),
    );

    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 0.45);
  });

  test('crop ikon menghasilkan PNG 160x160 dengan sudut transparan', () async {
    final data = await rootBundle.load('assets/theme/paw_cat.png');
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final source = (await codec.getNextFrame()).image;
    codec.dispose();
    final side = math.min(source.width, source.height).toDouble();
    final bytes = await cropIconImage(
      source,
      ui.Rect.fromLTWH(0, 0, side, side),
    );
    source.dispose();
    final croppedCodec = await ui.instantiateImageCodec(bytes);
    final cropped = (await croppedCodec.getNextFrame()).image;
    expect((cropped.width, cropped.height), (160, 160));
    final rgba = await cropped.toByteData(format: ui.ImageByteFormat.rawRgba);
    expect(rgba!.getUint8(3), 0);
    expect(rgba.getUint8(((80 * 160 + 80) * 4) + 3), greaterThan(0));
    cropped.dispose();
    croppedCodec.dispose();
  });

  test('target custom menyimpan ikon emoji', () {
    const goal = Goal(name: 'Liburan', target: 5000000, iconKey: 'emoji:🏝️');
    expect(Goal.fromMap(goal.toMap()).emoji, '🏝️');
  });

  test('Budget tipe lama yang tidak dikenal kembali ke Kebutuhan', () {
    const budget = Budget(
      id: 'investasi',
      name: 'Saham',
      iconKey: 'savings',
      color: Colors.blue,
      type: 'investasi',
      amount: 100000,
    );
    expect(Budget.fromMap(budget.toMap()).type, BudgetType.kebutuhan);
  });

  test('budget kategori dan Tabungan mengikuti tipe transaksi yang tepat', () {
    const categoryBudget = Budget(
      id: 'makanan',
      name: 'Makanan',
      iconKey: 'category',
      color: Colors.orange,
      type: BudgetType.kebutuhan,
      amount: 100000,
      scope: BudgetScope.category,
      categoryId: 'makanan',
    );
    const savingBudget = Budget(
      id: 'tabungan',
      name: 'Tabungan',
      iconKey: 'savings',
      color: Colors.blue,
      type: BudgetType.tabungan,
      amount: 100000,
    );

    expect(categoryBudget.transactionType, TxType.expense);
    expect(savingBudget.transactionType, TxType.income);
    expect(Budget.fromMap(categoryBudget.toMap()).categoryId, 'makanan');
  });

  test('widget Android punya keypad dan simpan langsung tanpa redirect', () {
    final layout = File(
      'android/app/src/main/res/layout/saldo_widget.xml',
    ).readAsStringSync();
    final provider = File(
      'android/app/src/main/kotlin/com/noctilune/duitges/'
      'SaldoWidgetProvider.kt',
    ).readAsStringSync();
    final compact = File(
      'android/app/src/main/res/layout/saldo_widget_compact.xml',
    ).readAsStringSync();
    final medium = File(
      'android/app/src/main/res/layout/saldo_widget_medium.xml',
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
    expect(provider, contains('160 to 320'));
    expect(compact, contains('widget_history'));
    expect(
      File(
        'android/app/src/main/kotlin/com/noctilune/duitges/'
        'WidgetHistoryActivity.kt',
      ).readAsStringSync(),
      allOf(
        contains('Riwayat Transaksi'),
        contains('WHERE t.date >= ? AND t.date < ?'),
        isNot(contains('LIMIT 20')),
        contains('BaseAdapter'),
        contains('periodLabel'),
      ),
    );
    expect(provider, contains('MaterialIcons-Regular.otf'));
    expect(provider, isNot(contains('duitges://add')));
    expect(medium, contains('android:paddingHorizontal="10dp"'));
  });

  test('video tema tidak mengambil audio focus aplikasi lain', () {
    final source = File(
      'lib/widgets/looping_asset_video.dart',
    ).readAsStringSync();
    expect(source, contains('VideoPlayerOptions(mixWithOthers: true)'));
  });

  test('template custom menyatu dan preview video dapat di-crop', () {
    final settings = File(
      'lib/screens/settings_screen.dart',
    ).readAsStringSync();
    final manager = File(
      'lib/widgets/custom_template_manager.dart',
    ).readAsStringSync();
    expect(settings, isNot(contains("title: 'Custom Background'")));
    expect(settings, isNot(contains("title: 'Custom Kartu Saldo'")));
    expect(manager, contains("'Preview dan crop'"));
    expect(manager, contains('scrollable: true'));
    expect(manager, contains('_VideoPreview('));
    expect(
      manager,
      contains(
        'scale: widget.scale,\n            alignment: widget.alignment,',
      ),
    );
    final player = File(
      'lib/widgets/looping_asset_video.dart',
    ).readAsStringSync();
    expect(
      player,
      contains('scale: widget.scale,\n          alignment: widget.alignment,'),
    );
  });

  test('custom template tersimpan, dapat dipilih, dan dihapus aman', () async {
    final file = File('${Directory.systemTemp.path}/custom-template-test.jpg')
      ..writeAsBytesSync([1, 2, 3]);
    addTearDown(() {
      if (file.existsSync()) file.deleteSync();
    });
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsProvider();
    await settings.load();
    final template = CustomTemplate(
      id: 'custom_test',
      name: 'Test',
      kind: CustomTemplateKind.card,
      media: CustomTemplateMedia.image,
      path: file.path,
      zoom: 2.2,
      alignX: -0.4,
      alignY: 0.7,
      opacity: 0.65,
    );
    await settings.addCustomTemplate(template);
    expect(settings.customCard?.id, template.id);

    final restored = SettingsProvider();
    await restored.load();
    expect(restored.customCard?.name, 'Test');
    expect(restored.customCard?.zoom, 2.2);
    expect(restored.customCard?.alignX, -0.4);
    expect(restored.customCard?.alignY, 0.7);
    expect(restored.customCard?.opacity, 0.65);
    await restored.setTheme(
      themePresets.firstWhere((theme) => theme.id == 'kucing'),
    );
    expect(restored.customCard, isNull);
    await restored.setTheme(
      themePresets.firstWhere((theme) => theme.id == 'klasik'),
    );
    await restored.deleteCustomTemplate(restored.customCard!);
    expect(restored.customCard, isNull);
    expect(file.existsSync(), isFalse);
  });

  test(
    'kustomisasi tema tersimpan per tema dan fallback lama tetap aman',
    () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsProvider();
      await settings.load();
      final customColor = SettingsProvider.presetColors.last;
      await settings.setThemePageColor(2, customColor);
      await settings.setFabPlusOffset(const Offset(7, -4));
      await settings.setThemeArtwork([6, 10], 'image:1.00:/tmp/theme.png');
      await settings.setFooterArtwork(
        0,
        storedThemeGif('/tmp/footer-transaction.gif'),
      );
      await settings.setHeaderArtwork(
        1,
        storedThemeVideo('/tmp/header-budget.mp4'),
      );
      await settings.setCardMascotArtwork('image:1.00:/tmp/card-mascot.png');
      await settings.setAddTransactionArtwork(
        storedThemeGif('/tmp/add-transaction.gif'),
      );

      final restored = SettingsProvider();
      await restored.load();
      expect(restored.pageAccent(2), customColor);
      expect(restored.fabPlusOffset, const Offset(7, -4));
      expect(restored.themeArtwork(6), 'image:1.00:/tmp/theme.png');
      expect(restored.themeArtwork(10), 'image:1.00:/tmp/theme.png');
      expect(
        restored.footerArtwork(0),
        storedThemeGif('/tmp/footer-transaction.gif'),
      );
      expect(restored.hasAnimatedCustomFooter, isTrue);
      expect(
        restored.headerArtwork(1),
        storedThemeVideo('/tmp/header-budget.mp4'),
      );
      expect(restored.cardMascotArtwork, 'image:1.00:/tmp/card-mascot.png');
      expect(
        restored.addTransactionArtwork,
        storedThemeGif('/tmp/add-transaction.gif'),
      );
      await restored.setFooterArtwork(0, null);
      expect(restored.footerArtwork(0), isNull);
      expect(restored.themeArtwork(6), 'image:1.00:/tmp/theme.png');
      final resetMarker = SettingsProvider();
      await resetMarker.load();
      expect(resetMarker.footerArtwork(0), isNull);
      expect(resetMarker.themeArtwork(6), 'image:1.00:/tmp/theme.png');

      await restored.setTheme(
        themePresets.firstWhere((theme) => theme.id == 'kucing'),
      );
      expect(restored.themeArtwork(6), isNull);
      expect(restored.fabPlusOffset, Offset.zero);

      await restored.setTheme(
        themePresets.firstWhere((theme) => theme.id == 'klasik'),
      );
      await restored.resetThemeCustomization();
      expect(restored.themeArtwork(6), isNull);
      expect(restored.footerArtwork(0), isNull);
      expect(restored.hasAnimatedCustomFooter, isFalse);
      expect(restored.fabPlusOffset, Offset.zero);
    },
  );

  test('tema custom bisa banyak, diubah nama dan ikonnya', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsProvider();
    await settings.load();

    await settings.addCustomTheme('Tema Pertama');
    final first = settings.activeCustomTheme!;
    await settings.renameCustomTheme(first.id, 'Tema Biru');
    await settings.setCustomThemeIcon(
      first.id,
      'image:1.00:/tmp/theme-blue.png',
    );
    await settings.setCustomThemePreviewSeconds(first.id, 5);
    await settings.setThemePageColor(0, SettingsProvider.presetColors.last);

    await settings.addCustomTheme('Tema Kedua');
    final second = settings.activeCustomTheme!;
    expect(second.id, isNot(first.id));
    expect(settings.customThemes.length, 3);
    expect(settings.hasCustomPageColor(0), isFalse);

    await settings.setTheme(
      settings.availableThemes.firstWhere((theme) => theme.id == first.id),
    );
    expect(settings.activeCustomTheme?.name, 'Tema Biru');
    expect(
      settings.activeCustomTheme?.iconKey,
      'image:1.00:/tmp/theme-blue.png',
    );
    expect(settings.activeCustomTheme?.previewSeconds, 5);
    expect(settings.hasCustomPageColor(0), isTrue);

    await settings.deleteCustomTheme(first.id);
    expect(settings.customThemeById(first.id), isNull);
    expect(settings.preset.id, 'klasik');

    final restored = SettingsProvider();
    await restored.load();
    expect(restored.customThemeById(second.id)?.name, 'Tema Kedua');
    expect(restored.customThemeById(first.id), isNull);
  });

  test('tema bawaan bisa dikustomisasi, dihapus, dan dipulihkan', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsProvider();
    await settings.load();
    await settings.setTheme(
      themePresets.firstWhere((theme) => theme.id == 'klasik_2'),
    );
    await settings.setCardMascotArtwork('image:1.00:/tmp/pink-mascot.png');
    expect(
      settings.cardMascotArtworkFor('klasik_2'),
      'image:1.00:/tmp/pink-mascot.png',
    );

    await settings.deleteTheme('klasik_2');
    expect(
      settings.availableThemes.map((theme) => theme.id),
      isNot(contains('klasik_2')),
    );
    expect(settings.preset.id, isNot('klasik_2'));
    expect(settings.hasHiddenBuiltInThemes, isTrue);

    final restored = SettingsProvider();
    await restored.load();
    expect(
      restored.availableThemes.map((theme) => theme.id),
      isNot(contains('klasik_2')),
    );
    await restored.restoreBuiltInThemes();
    expect(
      restored.availableThemes.map((theme) => theme.id),
      contains('klasik_2'),
    );
  });

  test('header dan footer kosong memakai ikon pasangan satu halaman', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsProvider();
    await settings.load();
    await settings.useCustomThemeIcon('footer_1');
    await settings.setHeaderArtwork(1, 'emoji:💰');
    expect(settings.footerArtwork(1), 'emoji:💰');

    await settings.useCustomThemeIcon('header_2');
    await settings.setFooterArtwork(2, 'emoji:📊');
    expect(settings.headerArtwork(2), 'emoji:📊');

    await settings.useEmptyThemeIcon('footer_3');
    await settings.setHeaderArtwork(3, 'emoji:⚙️');
    expect(settings.footerArtwork(3), 'emoji:⚙️');
    expect(settings.cardMascotArtwork, isNull);
  });

  testWidgets('JJK 2 memakai pasangan footer dan tanpa maskot saldo bawaan', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsProvider();
    await settings.load();
    await settings.setTheme(
      themePresets.firstWhere((theme) => theme.id == 'jjk2'),
    );

    expect(settings.cardMascotArtwork, isNull);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: settings,
        child: const MaterialApp(
          home: ThemeArtwork(tile: 8, size: 96, headerIndex: 2),
        ),
      ),
    );
    final image = tester.widget<Image>(find.byType(Image));
    expect(
      (image.image as AssetImage).assetName,
      'assets/theme/jjk2/footer_statistik_static.png',
    );
  });

  test('tema Sage dan Senja lama dimigrasikan ke seri Klasik', () async {
    SharedPreferences.setMockInitialValues({'themeId': 'sage'});
    final sage = SettingsProvider();
    await sage.load();
    expect(sage.preset.id, 'klasik_4');

    SharedPreferences.setMockInitialValues({'themeId': 'senja'});
    final senja = SettingsProvider();
    await senja.load();
    expect(senja.preset.id, 'klasik_2');
  });

  test('resolver ikon khusus dan maskot kosong tersimpan', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsProvider();
    await settings.load();

    await settings.setTheme(
      themePresets.firstWhere((theme) => theme.id == 'call_duck'),
    );
    expect(
      settings.staticFooterTransactionAsset(),
      'assets/theme/call_duck/footer_transaksi_static.png',
    );
    expect(
      settings.builtInThemeIconAsset('add_transaction'),
      'assets/theme/call_duck/add_transaction_static.png',
    );

    await settings.useEmptyThemeIcon('card_mascot');
    expect(settings.isThemeIconEmpty('card_mascot'), isTrue);
    expect(settings.cardMascotArtwork, isNull);
    final restored = SettingsProvider();
    await restored.load();
    expect(restored.isThemeIconEmpty('card_mascot'), isTrue);
    await restored.useBuiltInThemeIcon('card_mascot');
    expect(restored.hasThemeIconOverride('card_mascot'), isFalse);
  });

  test('ikon tema GIF/video punya format dan batas tanpa kompresi', () {
    expect(themeIconPath(storedThemeGif('/tmp/a.gif')), '/tmp/a.gif');
    expect(themeIconPath(storedThemeVideo('/tmp/a.mp4')), '/tmp/a.mp4');
    final cropped = withThemeIconCrop(
      storedThemeVideo('/tmp/a.mp4'),
      zoom: 2.2,
      alignX: -0.4,
      alignY: 0.7,
    );
    expect(themeIconPath(cropped), '/tmp/a.mp4');
    expect(parseThemeIconMedia(cropped), (
      path: '/tmp/a.mp4',
      zoom: 2.2,
      alignX: -0.4,
      alignY: 0.7,
    ));
    const lightGif = AnimatedThemeIconCandidate(
      path: '/tmp/a.gif',
      media: AnimatedThemeIconMedia.gif,
      bytes: 1024,
      width: 160,
      height: 160,
      frames: 30,
      duration: Duration(seconds: 3),
    );
    const heavyVideo = AnimatedThemeIconCandidate(
      path: '/tmp/a.mp4',
      media: AnimatedThemeIconMedia.video,
      bytes: 6 * 1024 * 1024,
      width: 720,
      height: 720,
      duration: Duration(seconds: 8),
    );
    expect(lightGif.canSkipCompression, isTrue);
    expect(heavyVideo.canSkipCompression, isFalse);
    final editor = File(
      'lib/widgets/theme_customization_editor.dart',
    ).readAsStringSync();
    expect(editor, contains("Text('Kelola ikon'"));
    expect(editor, contains("label: 'Maskot Kartu Saldo'"));
    expect(editor, contains("label: 'Tombol Tambah Transaksi'"));
    expect(editor, contains("child: Text('Ikon bawaan')"));
    expect(editor, contains("child: Text('Ikon custom')"));
    expect(editor, contains("child: Text('Kosong')"));
    expect(editor, isNot(contains('Konten Target')));
    expect(editor, isNot(contains('Artwork dan ikon')));
    expect(editor, contains('ThemeProfileIconPicker('));
    for (final path in [
      'lib/screens/budget_screen.dart',
      'lib/screens/goals_view.dart',
      'lib/screens/debts_view.dart',
    ]) {
      expect(
        File(path).readAsStringSync(),
        contains('headerIndex: 1'),
        reason: path,
      );
    }
  });

  test(
    'video tanpa kompres hanya lolos jika ukuran dan resolusinya ringan',
    () {
      const light = TemplateCandidate(
        path: '/tmp/light.mp4',
        media: CustomTemplateMedia.video,
        width: 1280,
        height: 720,
        bytes: 5 * 1024 * 1024,
      );
      const heavy = TemplateCandidate(
        path: '/tmp/heavy.mp4',
        media: CustomTemplateMedia.video,
        width: 1920,
        height: 1080,
        bytes: 20 * 1024 * 1024,
      );
      expect(light.canSkipCompression(5 * 1024 * 1024), isTrue);
      expect(heavy.canSkipCompression(10 * 1024 * 1024), isFalse);
    },
  );

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

  test('budget tujuan pembagian gaji bisa memilih ikon atau emoji', () {
    final salaryRule = File(
      'lib/screens/salary_rule_screen.dart',
    ).readAsStringSync();
    expect(salaryRule, contains("item.iconKey = 'emoji:"));
    expect(salaryRule, contains('categoryIconChoices.entries'));
    expect(salaryRule, contains('categoryColorChoices'));
  });

  test('template budget gaji belum tampil sebelum mendapat nominal', () {
    final provider = File(
      'lib/providers/budget_provider.dart',
    ).readAsStringSync();
    expect(provider, contains('budget.amount > 0'));
    final salaryRule = File(
      'lib/screens/salary_rule_screen.dart',
    ).readAsStringSync();
    expect(salaryRule, contains('read<BudgetProvider>().load();'));
  });

  test(
    'preview kartu video tampil dan Frieren 138 disembunyikan kompatibel',
    () {
      final settings = File(
        'lib/screens/settings_screen.dart',
      ).readAsStringSync();
      expect(settings, contains('LoopingAssetVideo('));
      expect(settings, contains('style != CardStyle.frierenRialVideo138'));
      expect(CardStyle.values, contains(CardStyle.frierenRialVideo138));
    },
  );

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
    expect(categoryColorChoices.length, 35);
    expect(categoryColorChoices.length % 7, 0);
    expect(categoryColorChoices.toSet(), hasLength(35));
    expect(categoryColorChoices.take(7), const [
      Color(0xFFD32F2F),
      Color(0xFFEF5350),
      Color(0xFFC96F53),
      Color(0xFFFF7043),
      Color(0xFFFF8F00),
      Color(0xFFFFA726),
      Color(0xFFC59A45),
    ]);
    expect(SettingsProvider.presetColors, same(categoryColorChoices));
    for (final path in [
      'lib/widgets/theme_customization_editor.dart',
      'lib/screens/settings_screen.dart',
      'lib/screens/add_transaction_screen.dart',
      'lib/screens/budget_screen.dart',
      'lib/screens/goals_view.dart',
      'lib/screens/salary_rule_screen.dart',
      'lib/screens/wallets_screen.dart',
    ]) {
      expect(
        File(path).readAsStringSync(),
        contains('crossAxisCount: 7'),
        reason: path,
      );
    }
  });

  testWidgets('font imut tersedia di bundle aplikasi', (_) async {
    expect(AppFont.mali.family, 'Mali');
    expect(AppFont.chewy.family, 'Chewy');
    for (final path in [
      'assets/fonts/Mali-Regular.ttf',
      'assets/fonts/Chewy-Regular.ttf',
    ]) {
      expect((await rootBundle.load(path)).lengthInBytes, greaterThan(1000));
    }
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

  test('RibuanInputFormatter menambah tiga nol saat mulai mengetik', () {
    final formatter = RibuanInputFormatter();
    final first = formatter.formatEditUpdate(
      TextEditingValue.empty,
      const TextEditingValue(
        text: '5',
        selection: TextSelection.collapsed(offset: 1),
      ),
    );
    expect(first.text, '5.000');
    expect(first.selection.baseOffset, 1);

    final second = formatter.formatEditUpdate(
      first,
      const TextEditingValue(
        text: '50.000',
        selection: TextSelection.collapsed(offset: 2),
      ),
    );
    expect(second.text, '50.000');
    expect(second.selection.baseOffset, 2);
  });

  test('SettingsProvider menandai data siap setelah load', () async {
    SharedPreferences.setMockInitialValues({'themeId': 'kucing'});
    final settings = SettingsProvider();
    expect(settings.ready, isFalse);
    await settings.load();
    expect(settings.ready, isTrue);
    expect(settings.preset.id, 'kucing');
    await settings.setHideWidgetBalance(true);
    await settings.setPrivacyMode(true);
    final restored = SettingsProvider();
    await restored.load();
    expect(restored.hideWidgetBalance, isTrue);
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
    expect(SettingsProvider.presetColors, contains(const Color(0xFFFF8F00)));
    expect(SettingsProvider.presetColors, contains(const Color(0xFF00897B)));
    expect(SettingsProvider.presetColors, contains(const Color(0xFFAD1457)));
    expect(SettingsProvider.presetColors, hasLength(35));
    final cat = themePresets.firstWhere((theme) => theme.id == 'kucing');
    final duck = themePresets.firstWhere((theme) => theme.id == 'bebek');
    final callDuck = themePresets.firstWhere(
      (theme) => theme.id == 'call_duck',
    );
    final classic2 = themePresets.firstWhere((theme) => theme.id == 'klasik_2');
    final classic3 = themePresets.firstWhere((theme) => theme.id == 'klasik_3');
    final classic4 = themePresets.firstWhere((theme) => theme.id == 'klasik_4');
    final classic5 = themePresets.firstWhere((theme) => theme.id == 'klasik_5');
    expect(themePresets.map((theme) => theme.id), isNot(contains('sage')));
    expect(themePresets.map((theme) => theme.id), isNot(contains('senja')));
    expect(classic2.name, 'Klasik 2');
    expect(classic2.artwork, 'assets/theme/classic_2');
    expect(classic3.name, 'Klasik 3');
    expect(classic3.artwork, 'assets/theme/classic_3');
    expect(classic4.name, 'Klasik 4');
    expect(classic4.artwork, 'assets/theme/classic_4');
    expect(classic5.name, 'Klasik 5');
    expect(classic5.artwork, 'assets/theme/classic_5');
    expect(cat.artwork, 'assets/theme/cat');
    expect(duck.artwork, 'assets/theme/duck');
    expect(duck.defaultAccent, const Color(0xFFF5B82E));
    expect(themePresets.map((theme) => theme.id), {
      'klasik',
      'klasik_2',
      'klasik_3',
      'klasik_4',
      'klasik_5',
      'kucing',
      'bebek',
      'call_duck',
      'anya',
      'jjk',
      'frieren',
      'frieren_rial',
      'spongebob',
      'jjk2',
      'matcha',
    });
    expect(callDuck.footerGifManualControl, isTrue);
    expect(callDuck.fabGif, 'assets/theme/call_duck/add_transaction.gif');
    expect(callDuck.tileGifs[0], isNull);
    expect(cat.tones.map((tone) => tone.id), ['pink', 'blue', 'yellow']);
    expect(duck.tones.map((tone) => tone.id), ['yellow', 'blue', 'pink']);
  });

  test('instalasi baru langsung memakai tema klasik', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsProvider();
    await settings.load();
    expect(settings.preset.id, 'klasik');
    expect(settings.accent, const Color(0xFF2E5BFF));
  });

  testWidgets('Budget Klasik memakai ikon kategori bawaan', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsProvider();
    await settings.load();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: settings,
        child: const MaterialApp(home: ThemeArtwork(tile: 7, size: 48)),
      ),
    );
    expect(find.byIcon(Icons.savings_outlined), findsOneWidget);
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

  testWidgets('PNG tema tersedia di bundle aplikasi', (_) async {
    // Dipakai semua tema.
    const universalNames = [
      'mascot_utama',
      'header_home',
      'header_setelan',
      'konten_budget',
      'footer_transaksi_2',
      'header_budget',
      'header_statistik',
      'konten_target',
    ];
    for (final theme in [
      'cat',
      'cat_blue',
      'cat_yellow',
      'duck',
      'duck_blue',
      'duck_pink',
    ]) {
      for (final name in universalNames) {
        final data = await rootBundle.load('assets/theme/$theme/$name.png');
        expect(data.lengthInBytes, greaterThan(0));
      }
    }
    const classicNames = [
      'mascot_utama',
      'header_home',
      'footer_transaksi_1',
      'header_setelan',
      'konten_budget',
      'footer_budget',
      'footer_transaksi_2',
      'header_budget',
      'header_statistik',
      'footer_statistik',
      'footer_transaksi_3',
      'konten_target',
      'footer_setelan_1',
      'footer_setelan_2',
      'footer_setelan_3',
      'footer_setelan_4',
    ];
    for (final theme in ['classic_2', 'classic_3', 'classic_4', 'classic_5']) {
      for (final name in classicNames) {
        final data = await rootBundle.load('assets/theme/$theme/$name.png');
        expect(data.lengthInBytes, greaterThan(0));
      }
    }
    for (final path in [
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
    ]) {
      final gif = await rootBundle.load(path);
      expect(gif.lengthInBytes, greaterThan(0));
    }
    final visibility = await rootBundle.load(
      'assets/theme/call_duck/visibility.png',
    );
    expect(visibility.lengthInBytes, greaterThan(0));
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
