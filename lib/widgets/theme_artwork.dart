import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import 'theme_icon_view.dart';

/// Menampilkan PNG transparan sesuai fungsi ikon pada tema aktif.
class ThemeArtwork extends StatelessWidget {
  static const _footerFallbacks = {
    'jjk2': {
      5: 'assets/theme/jjk2/footer_budget_static.png',
      9: 'assets/theme/jjk2/footer_statistik_static.png',
      15: 'assets/theme/jjk2/footer_setelan_static.png',
    },
    'call_duck': {
      3: 'assets/theme/call_duck/footer_setelan_static.png',
      7: 'assets/theme/call_duck/footer_budget_static.png',
      8: 'assets/theme/call_duck/footer_statistik_static.png',
    },
  };

  static const _names = [
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

  static const _legacyNames = [
    'mascot_utama',
    'header_home',
    'footer_transaksi_frieren',
    'header_setelan',
    'konten_budget',
    'footer_budget',
    'footer_transaksi_default',
    'header_budget',
    'header_statistik',
    'footer_statistik',
    'footer_transaksi_jjk',
    'konten_target',
    'footer_setelan_frieren',
    'footer_setelan_jjk',
    'footer_setelan',
    'footer_setelan_jjk2',
  ];

  static const _legacyThemes = {'anya', 'jjk', 'frieren', 'spongebob', 'jjk2'};

  final int tile;
  final double size;
  final ThemePreset? preset;
  final Widget? fallback;
  final bool animateCustom;
  final int? headerIndex;
  final bool cardMascot;
  final bool addTransaction;
  final bool ignoreCustomization;

  const ThemeArtwork({
    super.key,
    required this.tile,
    required this.size,
    this.preset,
    this.fallback,
    this.animateCustom = true,
    this.headerIndex,
    this.cardMascot = false,
    this.addTransaction = false,
    this.ignoreCustomization = false,
  }) : assert(tile >= 0 && tile < 16),
       assert(headerIndex == null || (headerIndex >= 0 && headerIndex < 4)),
       assert(
         (headerIndex == null ? 0 : 1) +
                 (cardMascot ? 1 : 0) +
                 (addTransaction ? 1 : 0) <=
             1,
       );

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = preset ?? settings.preset;
    final artwork = preset == null ? settings.artwork : theme.artwork;
    final footerFallback = _footerFallbacks[theme.id]?[tile];
    final iconSlot = headerIndex != null
        ? 'header_$headerIndex'
        : cardMascot
        ? 'card_mascot'
        : addTransaction
        ? 'add_transaction'
        : null;
    final custom = !ignoreCustomization
        ? headerIndex != null
              ? settings.headerArtworkFor(theme.id, headerIndex!)
              : cardMascot
              ? settings.cardMascotArtworkFor(theme.id)
              : addTransaction
              ? settings.addTransactionArtworkFor(theme.id)
              : settings.themeArtworkFor(theme.id, tile)
        : null;

    if (custom != null) {
      return ThemeIconView(
        iconKey: custom,
        size: size,
        previewSeconds: 3,
        animate: animateCustom,
        continuous: animateCustom,
        fallback: fallback ?? const Icon(Icons.broken_image_outlined),
      );
    }
    if (!ignoreCustomization &&
        iconSlot != null &&
        settings.isThemeIconEmptyFor(theme.id, iconSlot)) {
      return const SizedBox.shrink();
    }
    if (!ignoreCustomization &&
        iconSlot != null &&
        settings.hasThemeIconOverrideFor(theme.id, iconSlot)) {
      return SizedBox.square(
        dimension: size,
        child: Center(
          child:
              fallback ??
              Icon(theme.icon, size: size * 0.58, color: theme.defaultAccent),
        ),
      );
    }

    if (footerFallback != null) {
      return Image.asset(
        footerFallback,
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      );
    }

    // Tile tertentu bisa berupa GIF animasi. RepaintBoundary penting:
    // tanpa itu tiap ganti frame GIF ikut nge-repaint seluruh layar
    // (bikin lag), sama boundary repaint-nya kekunci di area GIF doang.
    final tileGif = theme.tileGifs[tile];
    if (tileGif != null) {
      return RepaintBoundary(
        child: Image.asset(
          tileGif,
          width: size,
          height: size,
          fit: BoxFit.contain,
          gaplessPlayback: true,
        ),
      );
    }

    if (artwork == null) {
      // Tema polos (misal Klasik): ga nampilin icon maskot sama sekali.
      if (!theme.showMascotIcon) return const SizedBox.shrink();
      final icon = theme.id == 'klasik' && const {4, 5, 7, 11}.contains(tile)
          ? Icons.savings_outlined
          : theme.icon;
      return SizedBox.square(
        dimension: size,
        child: Center(
          child:
              fallback ??
              Icon(icon, size: size * 0.58, color: theme.defaultAccent),
        ),
      );
    }

    final names = _legacyThemes.contains(theme.id) ? _legacyNames : _names;
    return Image.asset(
      '$artwork/${names[tile]}.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
  }
}
