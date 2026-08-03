import 'dart:async' show unawaited;
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/category.dart' show categoryColorChoices;
import '../models/custom_template.dart';
import '../models/theme_customization.dart';
import '../services/widget_service.dart';
import '../utils/stored_icon.dart';
import '../utils/theme_icon_media.dart';

/// Pilihan gaya desain kartu total saldo di home.
enum CardStyle {
  gradient('Gradient'),
  neon('Neon'),
  glass('Glass'),
  minimal('Minimal'),
  jjkVideo1('JJK Video 1'),
  jjkVideo2('JJK Video 2'),
  frierenRialVideo135('Frieren Rial 135'),
  frierenRialVideo136('Frieren Rial 136'),
  frierenRialVideo137('Frieren Rial 137'),
  frierenRialVideo138('Frieren Rial 138'),
  callDuck('Call Duck');

  final String label;
  const CardStyle(this.label);
  bool get isFrierenRial => name.startsWith('frierenRialVideo');
}

/// Pilihan font tampilan app — semua dibundel lokal (offline).
enum AppFont {
  jakarta('PlusJakartaSans', 'Jakarta Sans', 'Rapi'),
  fredoka('Fredoka', 'Fredoka', 'Bulat'),
  baloo('Baloo2', 'Baloo 2', 'Ceria'),
  quicksand('Quicksand', 'Quicksand', 'Lembut'),
  mali('Mali', 'Mali', 'Manis'),
  chewy('Chewy', 'Chewy', 'Gemoy');

  final String family;
  final String label;
  final String vibe;
  const AppFont(this.family, this.label, this.vibe);
}

class ThemeTone {
  final String id;
  final String label;
  final String artwork;
  final Color accent;
  final List<Color> lightBackground;
  final List<Color> darkBackground;

  const ThemeTone({
    required this.id,
    required this.label,
    required this.artwork,
    required this.accent,
    required this.lightBackground,
    required this.darkBackground,
  });
}

/// Tema penuh aplikasi: warna + background + icon maskot + teks dekorasi.
/// Nambah tema baru tinggal nambah satu entry di [themePresets].
class ThemePreset {
  final String id;
  final String name;

  /// Icon utama tema — dipakai di picker & maskot di judul home.
  final IconData icon;

  /// PNG tapak kaki maskot buat tombol sembunyiin saldo
  /// (null = pakai icon mata biasa).
  final String? pawAsset;

  /// Icon empty state (null = icon dompet default).
  final IconData? emptyIcon;

  /// Folder PNG individual untuk tema bergambar (null = Material icon biasa).
  final String? artwork;
  final List<ThemeTone> tones;

  /// false = tema polos tanpa icon maskot sama sekali (misal Klasik).
  final bool showMascotIcon;

  final Color defaultAccent;
  final List<Color> lightBackground;
  final List<Color> darkBackground;
  final String emptyText;

  /// GIF khusus buat tombol tambah transaksi (null = pakai
  /// ThemeArtwork tile 0/mascot_utama biasa).
  final String? fabGif;

  /// Geser posisi [fabGif] di dalam tombol FAB (biar pas framing-nya,
  /// beda GIF beda titik tengah objeknya).
  final Offset fabGifOffset;

  /// GIF khusus buat icon footer nav "Transaksi" (null = pakai
  /// ThemeArtwork tile biasa kayak footer lainnya).
  final String? footerTransaksiGif;

  /// GIF pengganti tile ThemeArtwork tertentu (key = index tile).
  /// Contoh {1: 'assets/.../header_home.gif'} = header home animasi.
  /// Tile yang ga ada di map tetap pakai PNG biasa.
  final Map<int, String> tileGifs;

  /// false (default) = GIF footer nav muter otomatis terus-terusan.
  /// true = semua footer nav diem di PNG `<nama_gif>_static.png`
  /// (sefolder) sampai di-toggle lewat tombol di bawah FAB.
  final bool footerGifManualControl;

  /// Warna aksen beda-beda per tab (index 0=Home/Transaksi, 1=Budget,
  /// 2=Statistik, 3=Setelan) — null = satu aksen aja buat semua tab
  /// (perilaku lama/default). Kalau diisi, override picker warna manual.
  final List<Color>? tabAccents;

  /// Gradient background per tab, pasangan sama urutan [tabAccents].
  /// Null = satu background aja buat semua tab.
  final List<List<Color>>? tabLightBackgrounds;
  final List<List<Color>>? tabDarkBackgrounds;

  /// Background per sub-tab DI DALAM halaman Budget (index 0=Budget,
  /// 1=Target, 2=Utang) — buat tema yang icon tiap sub-tabnya beda
  /// karakter/warna. Null = sub-tab Budget ga override apa-apa, ikutan
  /// background tab Budget yang satu itu aja (dari [tabLightBackgrounds]).
  final List<List<Color>>? budgetSubTabLightBackgrounds;
  final List<List<Color>>? budgetSubTabDarkBackgrounds;

  const ThemePreset({
    required this.id,
    required this.name,
    required this.icon,
    this.pawAsset,
    this.emptyIcon,
    this.artwork,
    this.tones = const [],
    this.showMascotIcon = true,
    required this.defaultAccent,
    required this.lightBackground,
    required this.darkBackground,
    this.emptyText =
        'Belum ada transaksi bulan ini.\nTekan tombol + buat nambahin.',
    this.fabGif,
    this.fabGifOffset = Offset.zero,
    this.footerTransaksiGif,
    this.tileGifs = const {},
    this.footerGifManualControl = false,
    this.tabAccents,
    this.tabLightBackgrounds,
    this.tabDarkBackgrounds,
    this.budgetSubTabLightBackgrounds,
    this.budgetSubTabDarkBackgrounds,
  });
}

final _allThemePresets = [
  ThemePreset(
    id: 'klasik',
    name: 'Klasik',
    icon: Icons.account_balance_wallet_outlined,
    defaultAccent: const Color(0xFF2E5BFF),
    lightBackground: const [Color(0xFFF4F7FF), Color(0xFFE9EFFD)],
    darkBackground: const [Color(0xFF0E1322), Color(0xFF141B30)],
  ),
  ThemePreset(
    id: 'klasik_2',
    name: 'Klasik 2',
    icon: Icons.savings_outlined,
    artwork: 'assets/theme/classic_2',
    defaultAccent: const Color(0xFFE58AB5),
    lightBackground: const [Color(0xFFFFF5FA), Color(0xFFF7DDEB)],
    darkBackground: const [Color(0xFF24131E), Color(0xFF35202D)],
  ),
  ThemePreset(
    id: 'klasik_3',
    name: 'Klasik 3',
    icon: Icons.track_changes_outlined,
    artwork: 'assets/theme/classic_3',
    defaultAccent: const Color(0xFF596FD8),
    lightBackground: const [Color(0xFFF4F6FF), Color(0xFFE2E6FF)],
    darkBackground: const [Color(0xFF11162B), Color(0xFF1D2341)],
  ),
  ThemePreset(
    id: 'klasik_4',
    name: 'Klasik 4',
    icon: Icons.account_balance_outlined,
    artwork: 'assets/theme/classic_4',
    defaultAccent: const Color(0xFF63B8AA),
    lightBackground: const [Color(0xFFF2FBF8), Color(0xFFDDF3EC)],
    darkBackground: const [Color(0xFF10201D), Color(0xFF18312C)],
  ),
  ThemePreset(
    id: 'klasik_5',
    name: 'Klasik 5',
    icon: Icons.inventory_2_outlined,
    artwork: 'assets/theme/classic_5',
    defaultAccent: const Color(0xFFC8782A),
    lightBackground: const [Color(0xFFFFF8EC), Color(0xFFF4E0BC)],
    darkBackground: const [Color(0xFF25180B), Color(0xFF3A2512)],
  ),
  ThemePreset(
    id: 'kucing',
    name: 'Kucing',
    icon: Icons.pets,
    pawAsset: 'assets/theme/paw_cat.png',
    emptyIcon: Icons.pets,
    artwork: 'assets/theme/cat',
    tones: const [
      ThemeTone(
        id: 'pink',
        label: 'Pink',
        artwork: 'assets/theme/cat',
        accent: Color(0xFFFF8FAB),
        lightBackground: [Color(0xFFFFF5F7), Color(0xFFFFE3EC)],
        darkBackground: [Color(0xFF231318), Color(0xFF2E1A22)],
      ),
      ThemeTone(
        id: 'blue',
        label: 'Biru',
        artwork: 'assets/theme/cat_blue',
        accent: Color(0xFF5D9EDB),
        lightBackground: [Color(0xFFF4F9FF), Color(0xFFDDEEFF)],
        darkBackground: [Color(0xFF101A26), Color(0xFF17283A)],
      ),
      ThemeTone(
        id: 'yellow',
        label: 'Kuning',
        artwork: 'assets/theme/cat_yellow',
        accent: Color(0xFFF5B82E),
        lightBackground: [Color(0xFFFFFBEA), Color(0xFFFFF0B8)],
        darkBackground: [Color(0xFF241C09), Color(0xFF33280D)],
      ),
    ],
    defaultAccent: const Color(0xFFFF8FAB),
    lightBackground: const [Color(0xFFFFF5F7), Color(0xFFFFE3EC)],
    darkBackground: const [Color(0xFF231318), Color(0xFF2E1A22)],
    emptyText:
        'Belum ada transaksi bulan ini, nyaa~\n'
        'Tekan tombol + buat nambahin.',
  ),
  ThemePreset(
    id: 'bebek',
    name: 'Bebek',
    icon: Icons.cruelty_free,
    pawAsset: 'assets/theme/paw_duck.png',
    emptyIcon: Icons.cruelty_free,
    artwork: 'assets/theme/duck',
    tones: const [
      ThemeTone(
        id: 'yellow',
        label: 'Kuning',
        artwork: 'assets/theme/duck',
        accent: Color(0xFFF5B82E),
        lightBackground: [Color(0xFFFFFBEA), Color(0xFFFFF0B8)],
        darkBackground: [Color(0xFF241C09), Color(0xFF33280D)],
      ),
      ThemeTone(
        id: 'blue',
        label: 'Biru',
        artwork: 'assets/theme/duck_blue',
        accent: Color(0xFF4F96DD),
        lightBackground: [Color(0xFFF4F9FF), Color(0xFFDDEEFF)],
        darkBackground: [Color(0xFF101A26), Color(0xFF17283A)],
      ),
      ThemeTone(
        id: 'pink',
        label: 'Pink',
        artwork: 'assets/theme/duck_pink',
        accent: Color(0xFFFF7FA1),
        lightBackground: [Color(0xFFFFF4F7), Color(0xFFFFDDE8)],
        darkBackground: [Color(0xFF251319), Color(0xFF341A23)],
      ),
    ],
    defaultAccent: const Color(0xFFF5B82E),
    lightBackground: const [Color(0xFFFFFBEA), Color(0xFFFFF0B8)],
    darkBackground: const [Color(0xFF241C09), Color(0xFF33280D)],
    emptyText:
        'Belum ada transaksi bulan ini, kwek~\n'
        'Tekan tombol + buat nambahin.',
  ),
  ThemePreset(
    id: 'call_duck',
    name: 'Call Duck',
    icon: Icons.egg_outlined,
    emptyIcon: Icons.egg_outlined,
    fabGif: 'assets/theme/call_duck/add_transaction.gif',
    footerTransaksiGif: 'assets/theme/call_duck/footer_transaksi.gif',
    tileGifs: const {
      1: 'assets/theme/call_duck/109.png',
      3: 'assets/theme/call_duck/footer_setelan.gif',
      4: 'assets/theme/call_duck/110.png',
      7: 'assets/theme/call_duck/footer_budget.gif',
      8: 'assets/theme/call_duck/footer_statistik.gif',
      11: 'assets/theme/call_duck/110.png',
    },
    footerGifManualControl: true,
    defaultAccent: const Color(0xFFE0A63C),
    lightBackground: const [Color(0xFFFAF5EC), Color(0xFFF3E8D2)],
    darkBackground: const [Color(0xFF241C09), Color(0xFF332309)],
    emptyText:
        'Belum ada transaksi bulan ini, quak!\n'
        'Tekan tombol + buat nambahin.',
  ),
  ThemePreset(
    id: 'anya',
    name: 'Anya',
    icon: Icons.face_3,
    emptyIcon: Icons.face_3,
    artwork: 'assets/theme/anya',
    defaultAccent: const Color(0xFFE88D9B),
    lightBackground: const [Color(0xFFFFF5F7), Color(0xFFFBE3E8)],
    darkBackground: const [Color(0xFF241417), Color(0xFF321C21)],
    emptyText:
        'Belum ada transaksi bulan ini. Waku waku!\n'
        'Tekan tombol + buat nambahin.',
  ),
  ThemePreset(
    id: 'jjk',
    name: 'JJK 1',
    icon: Icons.auto_awesome,
    emptyIcon: Icons.auto_awesome,
    artwork: 'assets/theme/jjk',
    defaultAccent: const Color(0xFF5865A6),
    lightBackground: const [Color(0xFFF5F4FA), Color(0xFFE5E7F2)],
    darkBackground: const [Color(0xFF10121A), Color(0xFF1A1E2B)],
  ),
  ThemePreset(
    id: 'frieren',
    name: 'Frieren',
    icon: Icons.hourglass_empty,
    emptyIcon: Icons.hourglass_empty,
    artwork: 'assets/theme/frieren',
    fabGif: 'assets/theme/frieren/add_transaction.gif',
    fabGifOffset: const Offset(2, -6),
    defaultAccent: const Color(0xFF7889C4),
    lightBackground: const [Color(0xFFF7F8FF), Color(0xFFE7ECF8)],
    darkBackground: const [Color(0xFF111522), Color(0xFF1B2333)],
    tabAccents: const [
      Color(0xFF8E97B8),
      Color(0xFF6FA3D6),
      Color(0xFF9587C2),
      Color(0xFFC97A52),
    ],
    tabLightBackgrounds: const [
      [Color(0xFFF7F8FF), Color(0xFFE7ECF8)],
      [Color(0xFFF1F7FD), Color(0xFFDCEBF9)],
      [Color(0xFFF6F3FB), Color(0xFFE7DFF5)],
      [Color(0xFFFDF3EC), Color(0xFFF6E0CF)],
    ],
    tabDarkBackgrounds: const [
      [Color(0xFF111522), Color(0xFF1B2333)],
      [Color(0xFF0E1A26), Color(0xFF15283A)],
      [Color(0xFF171325), Color(0xFF221C33)],
      [Color(0xFF241710), Color(0xFF331F14)],
    ],
  ),
  ThemePreset(
    id: 'frieren_rial',
    name: 'Frieren Rial',
    icon: Icons.nightlight_round,
    showMascotIcon: false,
    fabGif: 'assets/theme/frieren_rial/add_transaction.gif',
    tileGifs: const {
      3: 'assets/theme/frieren_rial/footer_setelan.png',
      6: 'assets/theme/frieren_rial/footer_transaksi.png',
      7: 'assets/theme/frieren_rial/footer_budget.png',
      8: 'assets/theme/frieren_rial/footer_statistik.png',
    },
    defaultAccent: const Color(0xFF9AB7FF),
    lightBackground: const [Color(0xFFF2F5FC), Color(0xFFDFE8F7)],
    darkBackground: const [Color(0xFF121827), Color(0xFF1A2436)],
  ),
  ThemePreset(
    id: 'spongebob',
    name: 'SpongeBob',
    icon: Icons.crop_square,
    emptyIcon: Icons.crop_square,
    artwork: 'assets/theme/spongebob',
    fabGif: 'assets/theme/spongebob/add_transaction.gif',
    tileGifs: const {
      0: 'assets/theme/spongebob/mascot_utama.gif',
      1: 'assets/theme/spongebob/header_home.gif',
    },
    defaultAccent: const Color(0xFFFFC914),
    lightBackground: const [Color(0xFFFFFBEA), Color(0xFFFFF3C4)],
    darkBackground: const [Color(0xFF221C08), Color(0xFF2E260D)],
  ),
  ThemePreset(
    id: 'jjk2',
    name: 'JJK 2',
    icon: Icons.circle,
    emptyIcon: Icons.circle,
    artwork: 'assets/theme/jjk2',
    fabGif: 'assets/theme/jjk2/add_transaction.gif',
    footerTransaksiGif: 'assets/theme/jjk2/footer_transaksi.gif',
    tileGifs: const {
      0: 'assets/theme/jjk2/mascot_utama.gif',
      5: 'assets/theme/jjk2/footer_budget.gif',
      9: 'assets/theme/jjk2/footer_statistik.gif',
      15: 'assets/theme/jjk2/footer_setelan.gif',
    },
    footerGifManualControl: true,
    defaultAccent: const Color(0xFF42A5FF),
    lightBackground: const [Color(0xFFEAF5FF), Color(0xFFCFE8FF)],
    darkBackground: const [Color(0xFF091828), Color(0xFF102A44)],
  ),
  ThemePreset(
    id: 'matcha',
    name: 'Matcha',
    icon: Icons.emoji_food_beverage,
    emptyIcon: Icons.emoji_food_beverage,
    defaultAccent: const Color(0xFF6B9E78),
    lightBackground: const [Color(0xFFF4F9F0), Color(0xFFE5F2DC)],
    darkBackground: const [Color(0xFF121A12), Color(0xFF1B261B)],
  ),
];

const _liteThemeIds = {
  'klasik',
  'klasik_2',
  'klasik_3',
  'klasik_4',
  'klasik_5',
  'kucing',
  'bebek',
  'call_duck',
};
final themePresets = appFlavor == 'lite'
    ? _allThemePresets
          .where((theme) => _liteThemeIds.contains(theme.id))
          .toList()
    : _allThemePresets;

class SettingsProvider extends ChangeNotifier {
  static const _privacyChannel = MethodChannel('duit_ges/privacy');
  static const _emptyThemeIcon = '__empty__';
  static const presetColors = categoryColorChoices;

  Color _accent = const Color(0xFF2E5BFF);
  // Tab bottom-nav yang lagi aktif (0=Home, 1=Budget, 2=Statistik,
  // 3=Setelan) — cuma dipakai kalau preset punya tabAccents (lihat
  // getter accent/lightBackground/darkBackground di bawah). Ephemeral,
  // ga di-persist, di-set ulang tiap ganti tab dari MainShell.
  int _activeTab = 0;
  bool _darkMode = false;
  CardStyle _cardStyle = CardStyle.gradient;
  int _monthStartDay = 1;
  int _trendMonths = 6;
  AppFont _font = AppFont.jakarta;
  double _textScale = 1;
  String _themeId = 'klasik';
  String? _toneId;
  String? _pinHash;
  bool _unlocked = false;
  bool _ready = false;
  bool _hideBalance = false;
  bool _hideWidgetBalance = false;
  bool _privacyMode = false;
  bool _reminderEnabled = false;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 20, minute: 0);
  bool _autoBackupEnabled = false;
  bool _autoBackupIncludePhotos = true;
  bool _externalBackupReminderEnabled = false;
  int _failedPinAttempts = 0;
  DateTime? _pinLockedUntil;
  List<CustomTemplate> _customTemplates = [];
  Map<String, String> _customCardIds = {};
  Map<String, String> _customBackgroundIds = {};
  Map<String, ThemeCustomization> _themeCustomizations = {};
  Set<String> _hiddenBuiltInThemeIds = {};
  List<CustomThemeProfile> _customThemes = [
    const CustomThemeProfile(id: 'custom', name: 'Custom'),
  ];

  bool get hideBalance => _hideBalance;
  bool get hideWidgetBalance => _hideWidgetBalance;
  bool get privacyMode => _privacyMode;
  bool get reminderEnabled => _reminderEnabled;
  TimeOfDay get reminderTime => _reminderTime;
  bool get autoBackupEnabled => _autoBackupEnabled;
  bool get autoBackupIncludePhotos => _autoBackupIncludePhotos;
  bool get externalBackupReminderEnabled => _externalBackupReminderEnabled;
  List<CustomTemplate> get customTemplates =>
      List.unmodifiable(_customTemplates);
  List<CustomThemeProfile> get customThemes => List.unmodifiable(_customThemes);
  CustomThemeProfile? get activeCustomTheme => customThemeById(_themeId);
  CustomThemeProfile? customThemeById(String id) {
    for (final profile in _customThemes) {
      if (profile.id == id) return profile;
    }
    return null;
  }

  ThemePreset _customPreset(CustomThemeProfile profile) => ThemePreset(
    id: profile.id,
    name: profile.name,
    icon: Icons.tune,
    defaultAccent: const Color(0xFF6750A4),
    lightBackground: const [Color(0xFFF8F7FC), Color(0xFFECE8F5)],
    darkBackground: const [Color(0xFF141218), Color(0xFF211E27)],
  );

  List<ThemePreset> get availableThemes => [
    ...themePresets.where(
      (theme) => !_hiddenBuiltInThemeIds.contains(theme.id),
    ),
    ..._customThemes.map(_customPreset),
  ];
  bool get hasHiddenBuiltInThemes => _hiddenBuiltInThemeIds.isNotEmpty;
  bool get canDeleteTheme => availableThemes.length > 1;
  CustomTemplate? get customCard => _customById(_customCardIds[preset.id]);
  CustomTemplate? get customBackground =>
      _customById(_customBackgroundIds[preset.id]);
  ThemeCustomization themeCustomizationFor(String themeId) =>
      _themeCustomizations[themeId] ?? const ThemeCustomization();
  ThemeCustomization get themeCustomization => themeCustomizationFor(preset.id);
  Offset get fabPlusOffset =>
      Offset(themeCustomization.plusX, themeCustomization.plusY);
  String? themeArtworkFor(String themeId, int tile) =>
      themeCustomizationFor(themeId).artwork[tile];
  String? themeArtwork(int tile) => themeArtworkFor(preset.id, tile);
  String? themeIconOverrideFor(String themeId, String slot) {
    final value = themeCustomizationFor(themeId).icons[slot];
    return value == null || value.isEmpty || value == _emptyThemeIcon
        ? null
        : value;
  }

  String? themeIconOverride(String slot) =>
      themeIconOverrideFor(preset.id, slot);

  bool hasThemeIconOverrideFor(String themeId, String slot) =>
      themeCustomizationFor(themeId).icons.containsKey(slot);
  bool hasThemeIconOverride(String slot) =>
      hasThemeIconOverrideFor(preset.id, slot);
  bool isThemeIconEmptyFor(String themeId, String slot) =>
      themeCustomizationFor(themeId).icons[slot] == _emptyThemeIcon;
  bool isThemeIconEmpty(String slot) => isThemeIconEmptyFor(preset.id, slot);

  String? _themeIconFor(String themeId, String slot, String? legacy) {
    final icons = themeCustomizationFor(themeId).icons;
    if (!icons.containsKey(slot)) return legacy;
    final value = icons[slot]!;
    if (value.isNotEmpty && value != _emptyThemeIcon) return value;
    final pairedSlot = switch (slot) {
      'header_0' => 'footer_0',
      'header_1' => 'footer_1',
      'header_2' => 'footer_2',
      'header_3' => 'footer_3',
      'footer_0' => 'header_0',
      'footer_1' => 'header_1',
      'footer_2' => 'header_2',
      'footer_3' => 'header_3',
      _ => null,
    };
    final paired = pairedSlot == null ? null : icons[pairedSlot];
    return paired == null || paired.isEmpty || paired == _emptyThemeIcon
        ? null
        : paired;
  }

  String? headerArtworkFor(String themeId, int index) {
    final legacy = switch (index) {
      0 => themeArtworkFor(themeId, 1),
      1 =>
        themeArtworkFor(themeId, 7) ??
            themeArtworkFor(themeId, 4) ??
            themeArtworkFor(themeId, 11),
      2 => themeArtworkFor(themeId, 8),
      3 => themeArtworkFor(themeId, 3),
      _ => null,
    };
    return _themeIconFor(themeId, 'header_$index', legacy);
  }

  String? headerArtwork(int index) => headerArtworkFor(preset.id, index);

  int footerTile(int index, [ThemePreset? target]) {
    final theme = target ?? preset;
    if (const {'frieren', 'jjk', 'spongebob', 'jjk2'}.contains(theme.id)) {
      return switch (index) {
        0 =>
          theme.id == 'frieren'
              ? 2
              : theme.id == 'jjk'
              ? 10
              : 6,
        1 => 5,
        2 => 9,
        3 =>
          theme.id == 'frieren'
              ? 12
              : theme.id == 'jjk'
              ? 13
              : theme.id == 'spongebob'
              ? 14
              : 15,
        _ => -1,
      };
    }
    return switch (index) {
      0 => 6,
      1 => 7,
      2 => 8,
      3 => 3,
      _ => -1,
    };
  }

  String? staticFooterTransactionAsset([ThemePreset? target]) {
    final theme = target ?? preset;
    final asset =
        theme.footerTransaksiGif ?? theme.tileGifs[footerTile(0, theme)];
    return asset != null && asset.endsWith('.gif')
        ? asset.replaceFirst('.gif', '_static.png')
        : asset;
  }

  String? builtInThemeIconAsset(String slot) {
    if (slot == 'footer_0') return staticFooterTransactionAsset();
    if (slot != 'add_transaction') return null;
    return switch (preset.id) {
      'jjk2' => 'assets/theme/jjk2/add_transaction_idle.gif',
      'call_duck' => 'assets/theme/call_duck/add_transaction_static.png',
      _ => preset.fabGif,
    };
  }

  String? footerArtworkFor(String themeId, int index) {
    final target = availableThemes.firstWhere(
      (theme) => theme.id == themeId,
      orElse: () => preset,
    );
    final tile = footerTile(index, target);
    final customization = themeCustomizationFor(themeId);
    return _themeIconFor(
      themeId,
      'footer_$index',
      customization.footerArtwork[index] ??
          (tile >= 0 ? themeArtworkFor(themeId, tile) : null),
    );
  }

  String? footerArtwork(int index) => footerArtworkFor(preset.id, index);

  String? cardMascotArtworkFor(String themeId) => _themeIconFor(
    themeId,
    'card_mascot',
    themeId == 'jjk2'
        ? null
        : themeArtworkFor(themeId, 0) ?? customThemeById(themeId)?.iconKey,
  );
  String? get cardMascotArtwork => cardMascotArtworkFor(preset.id);
  bool get hasCustomCardMascot =>
      hasThemeIconOverride('card_mascot') || activeCustomTheme?.iconKey != null;
  String? addTransactionArtworkFor(String themeId) =>
      _themeIconFor(themeId, 'add_transaction', themeArtworkFor(themeId, 0));
  String? get addTransactionArtwork => addTransactionArtworkFor(preset.id);
  bool get hasAnimatedCustomFooter => List.generate(
    4,
    footerArtwork,
  ).any((key) => isThemeGif(key) || isThemeVideo(key));
  Duration get pinCooldown {
    final remaining = _pinLockedUntil?.difference(DateTime.now());
    return remaining != null && !remaining.isNegative
        ? remaining
        : Duration.zero;
  }

  Color pageAccent(int page) =>
      themeCustomization.pageColor(page) ?? preset.tabAccents?[page] ?? _accent;
  bool hasCustomPageColor(int page) =>
      themeCustomization.pageColor(page) != null;
  Color get accent => pageAccent(_activeTab);
  bool get darkMode => _darkMode;

  /// Dipanggil MainShell tiap pindah tab bottom-nav. No-op kalau tema
  /// aktifnya ga punya tabAccents (mayoritas tema — satu warna aja).
  void setActiveTab(int index) {
    if (_activeTab == index) return;
    _activeTab = index;
    if (preset.tabAccents != null || _themeCustomizations.isNotEmpty) {
      notifyListeners();
    }
  }

  CardStyle get cardStyle => _cardStyle;
  int get monthStartDay => _monthStartDay;
  int get trendMonths => _trendMonths;
  AppFont get font => _font;
  double get textScale => _textScale;
  bool get ready => _ready;

  ThemePreset get preset => availableThemes.firstWhere(
    (t) => t.id == _themeId,
    orElse: () => availableThemes.first,
  );

  ThemeTone? get tone {
    if (preset.tones.isEmpty) return null;
    return preset.tones.firstWhere(
      (tone) => tone.id == _toneId,
      orElse: () => preset.tones.first,
    );
  }

  String? get artwork => tone?.artwork ?? preset.artwork;
  List<Color> _customBackground(Color color, bool dark) {
    final hsl = HSLColor.fromColor(color);
    return dark
        ? [hsl.withLightness(0.09).toColor(), hsl.withLightness(0.17).toColor()]
        : [
            hsl
                .withSaturation(hsl.saturation * 0.45)
                .withLightness(0.97)
                .toColor(),
            hsl
                .withSaturation(hsl.saturation * 0.55)
                .withLightness(0.9)
                .toColor(),
          ];
  }

  List<Color> get lightBackground {
    final color = themeCustomization.pageColor(_activeTab);
    return color != null
        ? _customBackground(color, false)
        : preset.tabLightBackgrounds?[_activeTab] ??
              tone?.lightBackground ??
              preset.lightBackground;
  }

  List<Color> get darkBackground {
    final color = themeCustomization.pageColor(_activeTab);
    return color != null
        ? _customBackground(color, true)
        : preset.tabDarkBackgrounds?[_activeTab] ??
              tone?.darkBackground ??
              preset.darkBackground;
  }

  /// Versi lebih terang dari warna aksen, buat ujung atas gradient.
  Color get accentBright {
    final hsl = HSLColor.fromColor(accent);
    return hsl.withLightness((hsl.lightness + 0.12).clamp(0.0, 1.0)).toColor();
  }

  /// Versi lebih gelap, buat ujung bawah gradient.
  Color get accentDeep {
    final hsl = HSLColor.fromColor(accent);
    return hsl.withLightness((hsl.lightness - 0.22).clamp(0.0, 1.0)).toColor();
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCustomThemes = prefs.getString('customThemeProfiles');
    if (savedCustomThemes != null) {
      try {
        _customThemes = (jsonDecode(savedCustomThemes) as List)
            .map(
              (item) => CustomThemeProfile.fromMap(
                Map<String, Object?>.from(item as Map),
              ),
            )
            .toList();
      } catch (_) {
        _customThemes = [
          const CustomThemeProfile(id: 'custom', name: 'Custom'),
        ];
      }
    }
    _hiddenBuiltInThemeIds = (prefs.getStringList('hiddenBuiltInThemes') ?? [])
        .where((id) => themePresets.any((theme) => theme.id == id))
        .toSet();
    final savedThemeId = prefs.getString('themeId') ?? 'klasik';
    _themeId = switch (savedThemeId) {
      'sage' => 'klasik_4',
      'senja' => 'klasik_2',
      _ => savedThemeId,
    };
    if (!availableThemes.any((theme) => theme.id == _themeId)) {
      _themeId = availableThemes.first.id;
      await prefs.setString('themeId', _themeId);
    } else if (_themeId != savedThemeId) {
      await prefs.setString('themeId', _themeId);
    }
    _toneId =
        prefs.getString('themeTone_${preset.id}') ??
        (preset.tones.isEmpty ? null : preset.tones.first.id);
    final savedAccent = prefs.getInt('accent');
    _accent = savedAccent == null
        ? tone?.accent ?? preset.defaultAccent
        : Color(savedAccent);
    _darkMode = prefs.getBool('darkMode') ?? false;
    final savedStyle = prefs.getString('cardStyle');
    if (savedStyle != null) {
      _cardStyle = CardStyle.values.asNameMap()[savedStyle] ?? _cardStyle;
    }
    _monthStartDay = (prefs.getInt('monthStartDay') ?? 1).clamp(1, 28);
    _trendMonths = (prefs.getInt('trendMonths') ?? 6).clamp(1, 12);
    // Kartu "Call Duck" eksklusif buat tema itu — kalau kesimpen kombinasi
    // yang gak nyambung (misal abis ganti tema manual di luar setTheme),
    // balikin ke default biar gak nampilin card khusus tema lain.
    if (_cardStyle == CardStyle.callDuck && _themeId != 'call_duck') {
      _cardStyle = CardStyle.gradient;
    }
    if (const {CardStyle.jjkVideo1, CardStyle.jjkVideo2}.contains(_cardStyle) &&
        _themeId != 'jjk2') {
      _cardStyle = CardStyle.gradient;
    }
    if (_cardStyle.isFrierenRial && _themeId != 'frieren_rial') {
      _cardStyle = CardStyle.gradient;
    }
    final savedFont = prefs.getString('font');
    if (savedFont != null) {
      _font = AppFont.values.asNameMap()[savedFont] ?? _font;
    }
    _textScale = (prefs.getDouble('textScale') ?? 1).clamp(0.8, 1.4);
    _pinHash = prefs.getString('pinHash');
    _hideBalance = prefs.getBool('hideBalance') ?? false;
    _hideWidgetBalance = prefs.getBool('hideWidgetBalance') ?? false;
    _privacyMode = prefs.getBool('privacyMode') ?? false;
    unawaited(_applyPrivacyMode(_privacyMode));
    _reminderEnabled = prefs.getBool('reminderEnabled') ?? false;
    _reminderTime = TimeOfDay(
      hour: prefs.getInt('reminderHour') ?? 20,
      minute: prefs.getInt('reminderMinute') ?? 0,
    );
    _autoBackupEnabled = prefs.getBool('autoBackupEnabled') ?? false;
    _autoBackupIncludePhotos = prefs.getBool('autoBackupIncludePhotos') ?? true;
    _externalBackupReminderEnabled =
        prefs.getBool('externalBackupReminderEnabled') ?? false;
    _failedPinAttempts = prefs.getInt('failedPinAttempts') ?? 0;
    _pinLockedUntil = DateTime.tryParse(
      prefs.getString('pinLockedUntil') ?? '',
    );
    try {
      _customTemplates =
          (jsonDecode(prefs.getString('customTemplates') ?? '[]') as List)
              .map(
                (item) => CustomTemplate.fromMap(
                  Map<String, Object?>.from(item as Map),
                ),
              )
              .toList();
    } catch (_) {
      _customTemplates = [];
    }
    Map<String, String> selectedTemplates(String key, String legacyKey) {
      final encoded = prefs.getString(key);
      if (encoded != null) {
        try {
          return Map<String, String>.from(jsonDecode(encoded) as Map);
        } catch (_) {
          // Format rusak jatuh ke key legacy di bawah.
        }
      }
      final legacy = prefs.getString(legacyKey);
      return legacy == null ? {} : {_themeId: legacy};
    }

    _customCardIds = selectedTemplates('customCardIdsByTheme', 'customCardId');
    _customBackgroundIds = selectedTemplates(
      'customBackgroundIdsByTheme',
      'customBackgroundId',
    );
    try {
      final saved =
          jsonDecode(prefs.getString('themeCustomizations') ?? '{}') as Map;
      _themeCustomizations = saved.map(
        (key, value) => MapEntry(
          '$key',
          ThemeCustomization.fromMap(Map<String, Object?>.from(value as Map)),
        ),
      );
    } catch (_) {
      _themeCustomizations = {};
    }
    for (final migration in const {
      'sage': 'klasik_4',
      'senja': 'klasik_2',
    }.entries) {
      final oldCustomization = _themeCustomizations.remove(migration.key);
      if (oldCustomization != null &&
          !_themeCustomizations.containsKey(migration.value)) {
        _themeCustomizations[migration.value] = oldCustomization;
      }
      final oldCard = _customCardIds.remove(migration.key);
      if (oldCard != null && !_customCardIds.containsKey(migration.value)) {
        _customCardIds[migration.value] = oldCard;
      }
      final oldBackground = _customBackgroundIds.remove(migration.key);
      if (oldBackground != null &&
          !_customBackgroundIds.containsKey(migration.value)) {
        _customBackgroundIds[migration.value] = oldBackground;
      }
    }
    _ready = true;
    notifyListeners();
    _syncWidget();
  }

  /// Nyalain/matiin reminder harian. Penjadwalan notifikasinya diurus
  /// pemanggil (ReminderService) — di sini cuma nyimpen preferensi.
  Future<void> setReminder(bool enabled, TimeOfDay time) async {
    _reminderEnabled = enabled;
    _reminderTime = time;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('reminderEnabled', enabled);
    await prefs.setInt('reminderHour', time.hour);
    await prefs.setInt('reminderMinute', time.minute);
  }

  Future<void> setAutoBackup(bool enabled) async {
    _autoBackupEnabled = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('autoBackupEnabled', enabled);
  }

  Future<void> setAutoBackupIncludePhotos(bool enabled) async {
    _autoBackupIncludePhotos = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('autoBackupIncludePhotos', enabled);
  }

  Future<void> setExternalBackupReminder(bool enabled) async {
    _externalBackupReminderEnabled = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('externalBackupReminderEnabled', enabled);
  }

  /// Sembunyiin nominal saldo di layar (jadi "Rp ••••••").
  /// Widget home screen ikut disembunyiin.
  Future<void> setHideBalance(bool value) async {
    _hideBalance = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hideBalance', value);
    unawaited(WidgetService.update());
  }

  Future<void> setHideWidgetBalance(bool value) async {
    _hideWidgetBalance = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hideWidgetBalance', value);
    unawaited(WidgetService.update());
  }

  // ===== Kunci PIN =====

  bool get pinEnabled => _pinHash != null;

  /// App lagi kekunci? (PIN aktif dan belum dibuka di sesi ini)
  bool get locked => pinEnabled && !_unlocked;

  String _hashPin(String pin) =>
      sha256.convert(utf8.encode('duit_ges:$pin')).toString();

  Future<void> setPin(String pin) async {
    _pinHash = _hashPin(pin);
    _unlocked = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pinHash', _pinHash!);
    _syncWidget();
  }

  /// Cek PIN; kalau bener, app kebuka.
  Future<bool> verifyPin(String pin) async {
    if (pinCooldown > Duration.zero) return false;
    final prefs = await SharedPreferences.getInstance();
    if (_hashPin(pin) != _pinHash) {
      _failedPinAttempts++;
      if (_failedPinAttempts >= 5) {
        _pinLockedUntil = DateTime.now().add(const Duration(seconds: 30));
        _failedPinAttempts = 0;
        await prefs.setString(
          'pinLockedUntil',
          _pinLockedUntil!.toIso8601String(),
        );
      }
      await prefs.setInt('failedPinAttempts', _failedPinAttempts);
      notifyListeners();
      return false;
    }
    _failedPinAttempts = 0;
    _pinLockedUntil = null;
    await prefs.remove('failedPinAttempts');
    await prefs.remove('pinLockedUntil');
    _unlocked = true;
    notifyListeners();
    return true;
  }

  Future<bool> removePin(String currentPin) async {
    if (_hashPin(currentPin) != _pinHash) return false;
    _pinHash = null;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pinHash');
    _syncWidget();
    return true;
  }

  /// Ganti tema penuh — warna aksen ikut ke default tema itu
  /// (abis itu tetep bisa diubah manual lewat Warna Tema).
  Future<void> setTheme(ThemePreset theme) async {
    _themeId = theme.id;
    final prefs = await SharedPreferences.getInstance();
    _toneId =
        prefs.getString('themeTone_${theme.id}') ??
        (theme.tones.isEmpty ? null : theme.tones.first.id);
    _accent = tone?.accent ?? theme.defaultAccent;
    // Kartu "Call Duck" eksklusif buat tema itu — masuk tema ini
    // otomatis pakai kartunya, keluar dari tema ini balik ke default
    // biar gak nyangkut dipakai tema lain yang gak nyambung asetnya.
    if (theme.id == 'call_duck') {
      _cardStyle = CardStyle.callDuck;
    } else if (theme.id == 'frieren_rial') {
      _cardStyle = CardStyle.frierenRialVideo135;
    } else if (_cardStyle == CardStyle.callDuck) {
      _cardStyle = CardStyle.gradient;
    } else if (_cardStyle.isFrierenRial) {
      _cardStyle = CardStyle.gradient;
    } else if (theme.id != 'jjk2' &&
        const {CardStyle.jjkVideo1, CardStyle.jjkVideo2}.contains(_cardStyle)) {
      _cardStyle = CardStyle.gradient;
    }
    notifyListeners();
    await prefs.setString('themeId', theme.id);
    await prefs.setInt('accent', _accent.toARGB32());
    await prefs.setString('cardStyle', _cardStyle.name);
    _syncWidget();
  }

  Future<void> addCustomTheme(String name) async {
    final clean = name.trim();
    if (clean.isEmpty) return;
    final profile = CustomThemeProfile(
      id: 'custom_${DateTime.now().microsecondsSinceEpoch}',
      name: clean.length > 30 ? clean.substring(0, 30) : clean,
    );
    _customThemes.add(profile);
    await _saveCustomThemes();
    await setTheme(_customPreset(profile));
  }

  Future<void> renameCustomTheme(String id, String name) async {
    final clean = name.trim();
    final index = _customThemes.indexWhere((theme) => theme.id == id);
    if (index < 0 || clean.isEmpty) return;
    _customThemes[index] = _customThemes[index].copyWith(
      name: clean.length > 30 ? clean.substring(0, 30) : clean,
    );
    await _saveCustomThemes();
  }

  Future<void> setCustomThemeIcon(String id, String? iconKey) async {
    final index = _customThemes.indexWhere((theme) => theme.id == id);
    if (index < 0) return;
    final current = _customThemes[index];
    final oldImage = parseStoredImageIcon(current.iconKey ?? '');
    _customThemes[index] = CustomThemeProfile(
      id: current.id,
      name: current.name,
      iconKey: iconKey,
      previewSeconds: current.previewSeconds,
    );
    await _saveCustomThemes();
    final oldPath = oldImage?.path ?? themeIconPath(current.iconKey);
    final newPath = themeIconPath(iconKey);
    if (oldPath != null && oldPath != newPath) {
      File(oldPath).delete().ignore();
      File('$oldPath.preview.png').delete().ignore();
    }
  }

  Future<void> setCustomThemePreviewSeconds(String id, int seconds) async {
    final index = _customThemes.indexWhere((theme) => theme.id == id);
    if (index < 0) return;
    _customThemes[index] = _customThemes[index].copyWith(
      previewSeconds: seconds.clamp(1, 5),
    );
    await _saveCustomThemes();
  }

  Future<void> deleteTheme(String id) async {
    if (!canDeleteTheme) return;
    final profile = customThemeById(id);
    final builtIn = themePresets.any((theme) => theme.id == id);
    if (profile == null && !builtIn) return;
    final customization = _themeCustomizations[id];
    if (profile != null) {
      _customThemes.removeWhere((theme) => theme.id == id);
    } else {
      _hiddenBuiltInThemeIds.add(id);
    }
    _themeCustomizations.remove(id);
    _customCardIds.remove(id);
    _customBackgroundIds.remove(id);
    if (_themeId == id) {
      _themeId = availableThemes.first.id;
      _toneId = null;
      _accent = preset.defaultAccent;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeId', _themeId);
    await prefs.setStringList(
      'hiddenBuiltInThemes',
      _hiddenBuiltInThemeIds.toList()..sort(),
    );
    await _saveSelectedTemplates(prefs);
    await _saveThemeCustomizations();
    await _saveCustomThemes();
    final path = themeIconPath(profile?.iconKey);
    if (path != null) {
      File(path).delete().ignore();
      File('$path.preview.png').delete().ignore();
    }
    for (final key in {
      ...?customization?.artwork.values,
      ...?customization?.footerArtwork.values,
      ...?customization?.icons.values,
    }) {
      _deleteReplacedThemeMedia(key, null);
    }
  }

  Future<void> deleteCustomTheme(String id) => deleteTheme(id);

  Future<void> restoreBuiltInThemes() async {
    if (_hiddenBuiltInThemeIds.isEmpty) return;
    _hiddenBuiltInThemeIds.clear();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('hiddenBuiltInThemes');
  }

  Future<void> _saveCustomThemes() async {
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'customThemeProfiles',
      jsonEncode(_customThemes.map((theme) => theme.toMap()).toList()),
    );
  }

  Future<void> setTone(ThemeTone value) async {
    _toneId = value.id;
    _accent = value.accent;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeTone_${preset.id}', value.id);
    await prefs.setInt('accent', value.accent.toARGB32());
    _syncWidget();
  }

  /// Tanggal mulai periode bulanan (1 = kalender biasa; 25 = gajian
  /// tanggal 25, periode 25 → 24 bulan depannya). Dibatasi 1–28 biar
  /// ga ribut sama bulan pendek (Februari).
  Future<void> setMonthStartDay(int day) async {
    _monthStartDay = day.clamp(1, 28);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('monthStartDay', _monthStartDay);
    _syncWidget();
  }

  /// Jumlah bulan yang ditampilin di grafik "Tren" statistik (1–12).
  Future<void> setTrendMonths(int months) async {
    _trendMonths = months.clamp(1, 12);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('trendMonths', _trendMonths);
  }

  Future<void> setCardStyle(CardStyle style) async {
    _cardStyle = style;
    _customCardIds.remove(preset.id);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cardStyle', style.name);
    await prefs.remove('customCardId');
    await _saveSelectedTemplates(prefs);
  }

  CustomTemplate? _customById(String? id) {
    if (id == null) return null;
    for (final template in _customTemplates) {
      if (template.id == id) return template;
    }
    return null;
  }

  Future<void> addCustomTemplate(CustomTemplate template) async {
    _customTemplates.add(template);
    await _saveCustomTemplates();
    await selectCustomTemplate(template);
  }

  Future<void> selectCustomTemplate(CustomTemplate template) async {
    final prefs = await SharedPreferences.getInstance();
    if (template.kind == CustomTemplateKind.card) {
      _customCardIds[preset.id] = template.id;
      await prefs.setString('customCardId', template.id);
    } else {
      _customBackgroundIds[preset.id] = template.id;
      await prefs.setString('customBackgroundId', template.id);
    }
    await _saveSelectedTemplates(prefs);
    notifyListeners();
  }

  Future<void> updateCustomTemplate(CustomTemplate template) async {
    final index = _customTemplates.indexWhere((item) => item.id == template.id);
    if (index < 0) return;
    _customTemplates[index] = template;
    await _saveCustomTemplates();
    notifyListeners();
  }

  Future<void> deleteCustomTemplate(CustomTemplate template) async {
    _customTemplates.removeWhere((item) => item.id == template.id);
    final prefs = await SharedPreferences.getInstance();
    if (_customCardIds.values.contains(template.id)) {
      _customCardIds.removeWhere((_, id) => id == template.id);
      await prefs.remove('customCardId');
    }
    if (_customBackgroundIds.values.contains(template.id)) {
      _customBackgroundIds.removeWhere((_, id) => id == template.id);
      await prefs.remove('customBackgroundId');
    }
    await _saveSelectedTemplates(prefs);
    await _saveCustomTemplates();
    final file = File(template.path);
    if (await file.exists()) await file.delete();
    notifyListeners();
  }

  Future<void> _saveCustomTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'customTemplates',
      jsonEncode(_customTemplates.map((item) => item.toMap()).toList()),
    );
  }

  Future<void> _saveSelectedTemplates(SharedPreferences prefs) async {
    await prefs.setString('customCardIdsByTheme', jsonEncode(_customCardIds));
    await prefs.setString(
      'customBackgroundIdsByTheme',
      jsonEncode(_customBackgroundIds),
    );
  }

  Future<void> setFont(AppFont value) async {
    _font = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('font', value.name);
  }

  Future<void> setTextScale(double value) async {
    _textScale = value.clamp(0.8, 1.4);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('textScale', _textScale);
  }

  Future<void> setAccent(Color color) async {
    _accent = color;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('accent', color.toARGB32());
    _syncWidget();
  }

  Future<void> setThemePageColor(int page, Color color) async {
    if (page < 0 || page > 3 || !presetColors.contains(color)) return;
    final current = themeCustomization;
    _themeCustomizations[preset.id] = current.copyWith(
      pageColors: {...current.pageColors, page: color.toARGB32()},
    );
    await _saveThemeCustomizations();
  }

  Future<void> setThemeArtwork(Iterable<int> tiles, String? iconKey) async {
    final current = themeCustomization;
    final artwork = {...current.artwork};
    final replaced = <String>{};
    for (final tile in tiles) {
      if (artwork[tile] case final oldKey?) replaced.add(oldKey);
      if (iconKey == null) {
        artwork.remove(tile);
      } else {
        artwork[tile] = iconKey;
      }
    }
    _themeCustomizations[preset.id] = current.copyWith(artwork: artwork);
    await _saveThemeCustomizations();
    for (final oldKey in replaced) {
      if (!_themeMediaInUse(themeCustomization, oldKey)) {
        _deleteReplacedThemeMedia(oldKey, iconKey);
      }
    }
  }

  Future<void> setFooterArtwork(int index, String? iconKey) async {
    if (index < 0 || index > 3) return;
    await _setThemeIcon('footer_$index', iconKey);
  }

  Future<void> setHeaderArtwork(int index, String? iconKey) async {
    if (index < 0 || index > 3) return;
    await _setThemeIcon('header_$index', iconKey);
  }

  Future<void> setCardMascotArtwork(String? iconKey) =>
      _setThemeIcon('card_mascot', iconKey);

  Future<void> setAddTransactionArtwork(String? iconKey) =>
      _setThemeIcon('add_transaction', iconKey);

  Future<void> _setThemeIcon(String slot, String? iconKey) async {
    final current = themeCustomization;
    final icons = {...current.icons};
    final oldKey = icons[slot];
    // String kosong adalah reset eksplisit agar fallback versi lama tidak
    // muncul lagi setelah pengguna menekan Hapus.
    icons[slot] = iconKey ?? '';
    final pairedSlot = switch (slot) {
      'header_0' => 'footer_0',
      'header_1' => 'footer_1',
      'header_2' => 'footer_2',
      'header_3' => 'footer_3',
      'footer_0' => 'header_0',
      'footer_1' => 'header_1',
      'footer_2' => 'header_2',
      'footer_3' => 'header_3',
      _ => null,
    };
    if (iconKey != null &&
        iconKey.isNotEmpty &&
        pairedSlot != null &&
        const {'', _emptyThemeIcon}.contains(icons[pairedSlot])) {
      icons[pairedSlot] = iconKey;
    }
    _themeCustomizations[preset.id] = current.copyWith(icons: icons);
    await _saveThemeCustomizations();
    if (oldKey != null &&
        oldKey.isNotEmpty &&
        !_themeMediaInUse(themeCustomization, oldKey)) {
      _deleteReplacedThemeMedia(oldKey, iconKey);
    }
  }

  Future<void> useBuiltInThemeIcon(String slot) async {
    final current = themeCustomization;
    if (!current.icons.containsKey(slot)) return;
    final icons = {...current.icons};
    final oldKey = icons.remove(slot);
    _themeCustomizations[preset.id] = current.copyWith(icons: icons);
    await _saveThemeCustomizations();
    if (oldKey != null &&
        oldKey.isNotEmpty &&
        !_themeMediaInUse(themeCustomization, oldKey)) {
      _deleteReplacedThemeMedia(oldKey, null);
    }
  }

  Future<void> useCustomThemeIcon(String slot) => _setThemeIcon(slot, null);

  Future<void> useEmptyThemeIcon(String slot) =>
      _setThemeIcon(slot, _emptyThemeIcon);

  bool _themeMediaInUse(ThemeCustomization customization, String key) {
    final path = themeIconPath(key);
    if (path == null) return false;
    return {
      ...customization.artwork.values,
      ...customization.footerArtwork.values,
      ...customization.icons.values,
    }.any((value) => themeIconPath(value) == path);
  }

  void _deleteReplacedThemeMedia(String? oldKey, String? newKey) {
    final oldPath = themeIconPath(oldKey);
    if (oldPath == null || oldPath == themeIconPath(newKey)) return;
    File(oldPath).delete().ignore();
    File('$oldPath.preview.png').delete().ignore();
  }

  Future<void> setFabPlusOffset(Offset offset) async {
    _themeCustomizations[preset.id] = themeCustomization.copyWith(
      plusX: offset.dx.clamp(-18, 18),
      plusY: offset.dy.clamp(-18, 18),
    );
    await _saveThemeCustomizations();
  }

  Future<void> resetThemeCustomization() async {
    final customization = _themeCustomizations.remove(preset.id);
    await _saveThemeCustomizations();
    for (final key in {
      ...?customization?.artwork.values,
      ...?customization?.footerArtwork.values,
      ...?customization?.icons.values,
    }) {
      _deleteReplacedThemeMedia(key, null);
    }
  }

  Future<void> _saveThemeCustomizations() async {
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'themeCustomizations',
      jsonEncode(
        _themeCustomizations.map((key, value) => MapEntry(key, value.toMap())),
      ),
    );
    _syncWidget();
  }

  Future<void> setDarkMode(bool value) async {
    _darkMode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', value);
    _syncWidget();
  }

  Future<void> setPrivacyMode(bool value) async {
    _privacyMode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('privacyMode', value);
    await _applyPrivacyMode(value);
  }

  Future<void> _applyPrivacyMode(bool enabled) async {
    try {
      await _privacyChannel.invokeMethod<void>('setSecure', {
        'enabled': enabled,
      });
    } on MissingPluginException {
      // Bukan Android atau sedang unit test.
    } on PlatformException {
      // Preferensi tetap disimpan dan dicoba lagi saat aplikasi dibuka.
    }
  }

  void _syncWidget() {
    final customColor = themeCustomization.pageColor(0);
    final background = customColor != null
        ? _customBackground(customColor, _darkMode)
        : _darkMode
        ? preset.tabDarkBackgrounds?.first ??
              tone?.darkBackground ??
              preset.darkBackground
        : preset.tabLightBackgrounds?.first ??
              tone?.lightBackground ??
              preset.lightBackground;
    final widgetAccent = pageAccent(0);
    unawaited(
      WidgetService.update(
        syncOptions: true,
        backgroundStart: background.first.toARGB32(),
        backgroundEnd: background.last.toARGB32(),
        foreground: (_darkMode ? Colors.white : const Color(0xFF172033))
            .toARGB32(),
        accent: widgetAccent.toARGB32(),
        quickAddEnabled: !pinEnabled,
      ),
    );
  }
}
