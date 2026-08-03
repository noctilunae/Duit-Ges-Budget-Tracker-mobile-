import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import 'theme_artwork.dart';

/// Header seragam buat semua tab: judul kiri + tombol aksi opsional kanan.
class PageHeader extends StatelessWidget {
  final String title;
  final Widget? action;

  final int artworkTile;
  final int headerIndex;

  const PageHeader({
    super.key,
    required this.title,
    this.action,
    this.artworkTile = 0,
    required this.headerIndex,
  });

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final artworkSize = settings.headerArtwork(headerIndex) != null
        ? 44.0
        : 36.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(width: 8),
              ThemeArtwork(
                tile: artworkTile,
                size: artworkSize,
                headerIndex: headerIndex,
              ),
            ],
          ),
          // Placeholder setinggi IconButton biar semua header sama tinggi
          action ?? const SizedBox(height: 48, width: 8),
        ],
      ),
    );
  }
}
