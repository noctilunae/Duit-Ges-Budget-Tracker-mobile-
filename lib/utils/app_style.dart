import 'package:flutter/material.dart';

/// Warna pemasukan/pengeluaran — sengaja fix (ga ikut tema)
/// karena hijau=masuk merah=keluar itu konvensi universal duit.
const incomeColor = Color(0xFF00C48C);
const expenseColor = Color(0xFFEF5350);

/// Warna kartu/tile yang ngikutin mode terang/gelap.
Color cardColor(BuildContext context) => Theme.of(context).colorScheme.surface;

/// Gradient buat lingkaran icon kategori biar ada dimensi, ga flat.
LinearGradient categoryGradient(Color color) {
  final hsl = HSLColor.fromColor(color);
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      hsl.withLightness((hsl.lightness + 0.08).clamp(0.0, 1.0)).toColor(),
      hsl.withLightness((hsl.lightness - 0.12).clamp(0.0, 1.0)).toColor(),
    ],
  );
}

/// Shadow halus buat kartu/tile, nyesuaian mode.
List<BoxShadow> cardShadow(BuildContext context) => [
  BoxShadow(
    color: Theme.of(context).brightness == Brightness.light
        ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.07)
        : Colors.black.withValues(alpha: 0.35),
    blurRadius: 12,
    offset: const Offset(0, 4),
  ),
];
