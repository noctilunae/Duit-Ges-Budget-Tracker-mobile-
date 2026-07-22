import 'dart:async' show unawaited;
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/widget_service.dart';

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

enum FrierenRialBackground {
  defaultBackground('Default', null, Color(0xFF334A70)),
  eclipse(
    'Eclipse',
    'assets/theme/frieren_rial/background_eclipse.jpg',
    Color(0xFF1D3970),
  ),
  journey(
    'Journey',
    'assets/theme/frieren_rial/background_journey.jpg',
    Color(0xFF565C8A),
  ),
  meadow(
    'Meadow',
    'assets/theme/frieren_rial/background_meadow.jpg',
    Color(0xFF236B58),
  ),
  lotus(
    'Lotus',
    'assets/theme/frieren_rial/background_lotus.jpg',
    Color(0xFF526E8A),
  ),
  blueSky(
    'Blue Sky',
    'assets/theme/frieren_rial/background_blue_sky.jpg',
    Color(0xFF167FB8),
  );

  final String label;
  final String? asset;
  final Color cardTone;
  const FrierenRialBackground(this.label, this.asset, this.cardTone);
}

/// Pilihan font tampilan app — semua dibundel lokal (offline).
enum AppFont {
  jakarta('PlusJakartaSans', 'Jakarta Sans', ''),
  fredoka('Fredoka', 'Fredoka', ''),
  baloo('Baloo2', 'Baloo 2', ''),
  quicksand('Quicksand', 'Quicksand', '');

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

final themePresets = [
  ThemePreset(
    id: 'klasik',
    name: 'Klasik',
    icon: Icons.account_balance_wallet_outlined,
    defaultAccent: const Color(0xFF2E5BFF),
    lightBackground: const [Color(0xFFF4F7FF), Color(0xFFE9EFFD)],
    darkBackground: const [Color(0xFF0E1322), Color(0xFF141B30)],
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
    emptyText:
        'Belum ada transaksi bulan ini.\n'
        'Tekan tombol + buat mulai mencatat.',
  ),
  ThemePreset(
    id: 'frieren',
    name: 'Frieren',
    icon: Icons.hourglass_empty,
    emptyIcon: Icons.hourglass_empty,
    artwork: 'assets/theme/frieren',
    defaultAccent: const Color(0xFF7889C4),
    lightBackground: const [Color(0xFFF7F8FF), Color(0xFFE7ECF8)],
    darkBackground: const [Color(0xFF111522), Color(0xFF1B2333)],
    emptyText:
        'Belum ada transaksi bulan ini.\n'
        'Perjalanan panjang dimulai dari satu catatan.',
    fabGif: 'assets/theme/frieren/add_transaction.gif',
    fabGifOffset: const Offset(2, -6),
    // Tiap tab warnanya nyesuain karakter yang kepasang di footer-nya:
    // Transaksi = Frieren (putih-lavender), Budget = Himmel (biru bunga —
    // bunga biru langit yang jadi motif ikoniknya Himmel), Statistik =
    // cewek rambut ungu, Setelan = Stark (merah).
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
    defaultAccent: const Color(0xFF9AB7FF),
    lightBackground: const [Color(0xFFF2F5FC), Color(0xFFDFE8F7)],
    darkBackground: const [Color(0xFF121827), Color(0xFF1A2436)],
    tabAccents: const [
      Color(0xFF7896C8),
      Color(0xFF8EACD6),
      Color(0xFFA99BCB),
      Color(0xFFD0AE69),
    ],
    tabLightBackgrounds: const [
      [Color(0xFFF2F5FC), Color(0xFFDFE8F7)],
      [Color(0xFFF0F5FB), Color(0xFFDDE8F5)],
      [Color(0xFFF5F1FA), Color(0xFFE7DEF3)],
      [Color(0xFFFBF5E9), Color(0xFFEFE2C7)],
    ],
    tabDarkBackgrounds: const [
      [Color(0xFF121827), Color(0xFF1A2436)],
      [Color(0xFF111B2A), Color(0xFF1B2A3D)],
      [Color(0xFF191527), Color(0xFF272038)],
      [Color(0xFF201A16), Color(0xFF332A1E)],
    ],
    fabGif: 'assets/theme/frieren_rial/add_transaction.gif',
    tileGifs: const {
      3: 'assets/theme/frieren_rial/footer_setelan.png',
      6: 'assets/theme/frieren_rial/footer_transaksi.png',
      7: 'assets/theme/frieren_rial/footer_budget.png',
      8: 'assets/theme/frieren_rial/footer_statistik.png',
    },
    emptyText:
        'Nabung ges.\n'
        'karena pahlawan himmel akan melakukan hal yang sama.',
  ),
  ThemePreset(
    id: 'spongebob',
    name: 'SpongeBob',
    // Placeholder sementara (belum ada artwork asli) — full hitam semua
    // biar keliatan tema ini emang belum jadi, bukan lupa ganti.
    icon: Icons.crop_square,
    emptyIcon: Icons.crop_square,
    artwork: 'assets/theme/spongebob',
    defaultAccent: const Color(0xFFFFC914),
    lightBackground: const [Color(0xFFFFFBEA), Color(0xFFFFF3C4)],
    darkBackground: const [Color(0xFF221C08), Color(0xFF2E260D)],
    emptyText:
        'Belum ada transaksi bulan ini.\n'
        'Siap sedia, Kapten! Tekan tombol + buat nyatet.',
    fabGif: 'assets/theme/spongebob/add_transaction.gif',
    // Header halaman Transaksi (home) pakai GIF animasi, sisanya PNG.
    tileGifs: const {
      0: 'assets/theme/spongebob/mascot_utama.gif',
      1: 'assets/theme/spongebob/header_home.gif',
    },
    // Tiap tab warnanya ganti sesuai karakter yang beneran kepasang di
    // footer-nya: Home/Transaksi = SpongeBob (kuning), Budget = Patrick
    // (pink karang), Statistik = Gary (hijau mint — asetnya Gary bukan
    // Sandy, makanya warnanya ijo bukan tan), Setelan = Squidward (teal).
    tabAccents: const [
      Color(0xFFFFC914),
      Color(0xFFFA7268),
      Color(0xFF7FB88F),
      Color(0xFF4FB6AC),
    ],
    tabLightBackgrounds: const [
      [Color(0xFFFFFBEA), Color(0xFFFFF3C4)],
      [Color(0xFFFFF3F1), Color(0xFFFFDAD3)],
      [Color(0xFFF3FAF0), Color(0xFFDFF2D8)],
      [Color(0xFFEFFBFA), Color(0xFFD6F0EC)],
    ],
    tabDarkBackgrounds: const [
      [Color(0xFF221C08), Color(0xFF2E260D)],
      [Color(0xFF241210), Color(0xFF301714)],
      [Color(0xFF141F13), Color(0xFF1D2B19)],
      [Color(0xFF0E1F1D), Color(0xFF152B28)],
    ],
    // Sub-tab Budget beda karakter beda warna: Budget=Patrick(pink),
    // Target=Squidward(teal), Utang=SpongeBob(kuning).
    budgetSubTabLightBackgrounds: const [
      [Color(0xFFFFF3F1), Color(0xFFFFDAD3)],
      [Color(0xFFEFFBFA), Color(0xFFD6F0EC)],
      [Color(0xFFFFFBEA), Color(0xFFFFF3C4)],
    ],
    budgetSubTabDarkBackgrounds: const [
      [Color(0xFF241210), Color(0xFF301714)],
      [Color(0xFF0E1F1D), Color(0xFF152B28)],
      [Color(0xFF221C08), Color(0xFF2E260D)],
    ],
  ),
  ThemePreset(
    id: 'jjk2',
    name: 'JJK 2',
    // Placeholder sementara — icon Statistik/Setelan masih full hitam,
    // header Home & Budget udah ada artnya (75/76), footer 4-4nya GIF.
    icon: Icons.circle,
    emptyIcon: Icons.circle,
    artwork: 'assets/theme/jjk2',
    defaultAccent: const Color(0xFF42A5FF),
    lightBackground: const [Color(0xFFEAF5FF), Color(0xFFCFE8FF)],
    darkBackground: const [Color(0xFF091828), Color(0xFF102A44)],
    fabGif: 'assets/theme/jjk2/add_transaction.gif',
    footerTransaksiGif: 'assets/theme/jjk2/footer_transaksi.gif',
    tileGifs: const {
      0: 'assets/theme/jjk2/mascot_utama.gif',
      5: 'assets/theme/jjk2/footer_budget.gif',
      9: 'assets/theme/jjk2/footer_statistik.gif',
      15: 'assets/theme/jjk2/footer_setelan.gif',
    },
    // Semua footer GIF diem di PNG statis, muter bareng-bareng cuma
    // kalau tombol play di bawah FAB dipencet (bukan auto-loop
    // kayak spongebob/frieren, dan bukan per-tap — itu kerasa aneh
    // soalnya nge-tap juga mindahin tab).
    footerGifManualControl: true,
    // Palet per karakter: Gojo, Sukuna, Yuta, lalu Yuji.
    tabAccents: const [
      Color(0xFF42A5FF),
      Color(0xFFE04455),
      Color(0xFF8066D6),
      Color(0xFFE8883E),
    ],
    tabLightBackgrounds: const [
      [Color(0xFFEAF5FF), Color(0xFFCFE8FF)],
      [Color(0xFFFFF1F2), Color(0xFFFFD8DC)],
      [Color(0xFFF4F1FF), Color(0xFFE1D9FA)],
      [Color(0xFFFFF5E9), Color(0xFFF3D7BC)],
    ],
    tabDarkBackgrounds: const [
      [Color(0xFF091828), Color(0xFF102A44)],
      [Color(0xFF240C12), Color(0xFF3A121A)],
      [Color(0xFF151124), Color(0xFF251C3B)],
      [Color(0xFF24160C), Color(0xFF3B2415)],
    ],
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

class SettingsProvider extends ChangeNotifier {
  static const _privacyChannel = MethodChannel('duit_ges/privacy');
  static const presetColors = [
    Color(0xFF2E5BFF), // biru electric (default)
    Color(0xFF7C4DFF), // ungu
    Color(0xFF00B8D9), // cyan
    Color(0xFF8DB7D8), // soft blue
    Color(0xFFB7A6D9), // soft lavender
    Color(0xFFD99AA5), // dusty rose
    Color(0xFF9BB89C), // sage
    Color(0xFF00C48C), // mint
    Color(0xFFFF9F1C), // oranye
    Color(0xFFFF6B6B), // coral
    Color(0xFFF72585), // pink
    Color(0xFF3A0CA3), // indigo gelap
    Color(0xFFFFD60A), // kuning
    Color(0xFF4CC9F0), // sky blue
    Color(0xFF6A4C93), // ungu tua
    Color(0xFF4A6741), // hijau tua
  ];

  Color _accent = const Color(0xFF2E5BFF);
  // Tab bottom-nav yang lagi aktif (0=Home, 1=Budget, 2=Statistik,
  // 3=Setelan) — cuma dipakai kalau preset punya tabAccents (lihat
  // getter accent/lightBackground/darkBackground di bawah). Ephemeral,
  // ga di-persist, di-set ulang tiap ganti tab dari MainShell.
  int _activeTab = 0;
  bool _darkMode = false;
  CardStyle _cardStyle = CardStyle.gradient;
  FrierenRialBackground _frierenRialBackground =
      FrierenRialBackground.defaultBackground;
  int _monthStartDay = 1;
  int _trendMonths = 6;
  AppFont _font = AppFont.jakarta;
  String _themeId = 'klasik';
  String? _toneId;
  String? _pinHash;
  bool _unlocked = false;
  bool _ready = false;
  bool _hideBalance = false;
  bool _hideWallets = false;
  bool _privacyMode = false;
  bool _reminderEnabled = false;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 20, minute: 0);
  bool _autoBackupEnabled = false;
  bool _externalBackupReminderEnabled = false;
  int _failedPinAttempts = 0;
  DateTime? _pinLockedUntil;

  bool get hideBalance => _hideBalance;
  bool get hideWallets => _hideWallets;
  bool get privacyMode => _privacyMode;
  bool get reminderEnabled => _reminderEnabled;
  TimeOfDay get reminderTime => _reminderTime;
  bool get autoBackupEnabled => _autoBackupEnabled;
  bool get externalBackupReminderEnabled => _externalBackupReminderEnabled;
  Duration get pinCooldown {
    final remaining = _pinLockedUntil?.difference(DateTime.now());
    return remaining != null && !remaining.isNegative
        ? remaining
        : Duration.zero;
  }

  Color get accent => preset.tabAccents?[_activeTab] ?? _accent;
  bool get darkMode => _darkMode;

  /// Dipanggil MainShell tiap pindah tab bottom-nav. No-op kalau tema
  /// aktifnya ga punya tabAccents (mayoritas tema — satu warna aja).
  void setActiveTab(int index) {
    if (_activeTab == index) return;
    _activeTab = index;
    if (preset.tabAccents != null) notifyListeners();
  }

  CardStyle get cardStyle => _cardStyle;
  FrierenRialBackground get frierenRialBackground => _frierenRialBackground;
  int get monthStartDay => _monthStartDay;
  int get trendMonths => _trendMonths;
  AppFont get font => _font;
  bool get ready => _ready;

  ThemePreset get preset => themePresets.firstWhere(
    (t) => t.id == _themeId,
    orElse: () => themePresets.first,
  );

  ThemeTone? get tone {
    if (preset.tones.isEmpty) return null;
    return preset.tones.firstWhere(
      (tone) => tone.id == _toneId,
      orElse: () => preset.tones.first,
    );
  }

  String? get artwork => tone?.artwork ?? preset.artwork;
  List<Color> get lightBackground =>
      preset.tabLightBackgrounds?[_activeTab] ??
      tone?.lightBackground ??
      preset.lightBackground;
  List<Color> get darkBackground =>
      preset.tabDarkBackgrounds?[_activeTab] ??
      tone?.darkBackground ??
      preset.darkBackground;

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
    _themeId = prefs.getString('themeId') ?? 'klasik';
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
      _cardStyle = savedStyle == 'frierenRialVideo'
          ? CardStyle.frierenRialVideo135
          : CardStyle.values.asNameMap()[savedStyle] ?? _cardStyle;
    }
    _frierenRialBackground =
        FrierenRialBackground.values.asNameMap()[prefs.getString(
          'frierenRialBackground',
        )] ??
        FrierenRialBackground.defaultBackground;
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
    _pinHash = prefs.getString('pinHash');
    _hideBalance = prefs.getBool('hideBalance') ?? false;
    _hideWallets = prefs.getBool('hideWallets') ?? false;
    _privacyMode = prefs.getBool('privacyMode') ?? false;
    unawaited(_applyPrivacyMode(_privacyMode));
    _reminderEnabled = prefs.getBool('reminderEnabled') ?? false;
    _reminderTime = TimeOfDay(
      hour: prefs.getInt('reminderHour') ?? 20,
      minute: prefs.getInt('reminderMinute') ?? 0,
    );
    _autoBackupEnabled = prefs.getBool('autoBackupEnabled') ?? false;
    _externalBackupReminderEnabled =
        prefs.getBool('externalBackupReminderEnabled') ?? false;
    _failedPinAttempts = prefs.getInt('failedPinAttempts') ?? 0;
    _pinLockedUntil = DateTime.tryParse(
      prefs.getString('pinLockedUntil') ?? '',
    );
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
    if (theme.id == 'frieren_rial') _darkMode = true;
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
    if (theme.id == 'frieren_rial') await prefs.setBool('darkMode', true);
    _syncWidget();
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
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cardStyle', style.name);
  }

  Future<void> setFrierenRialBackground(
    FrierenRialBackground background,
  ) async {
    _frierenRialBackground = background;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('frierenRialBackground', background.name);
  }

  Future<void> setFont(AppFont value) async {
    _font = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('font', value.name);
  }

  Future<void> setAccent(Color color) async {
    _accent = color;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('accent', color.toARGB32());
    _syncWidget();
  }

  Future<void> setDarkMode(bool value) async {
    _darkMode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', value);
    _syncWidget();
  }

  Future<void> setHideWallets(bool value) async {
    _hideWallets = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hideWallets', value);
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
    final background = _darkMode
        ? preset.tabDarkBackgrounds?.first ??
              tone?.darkBackground ??
              preset.darkBackground
        : preset.tabLightBackgrounds?.first ??
              tone?.lightBackground ??
              preset.lightBackground;
    final widgetAccent = preset.tabAccents?.first ?? _accent;
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
