import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import 'theme_artwork.dart';
import 'theme_icon_view.dart';
import 'theme_profile_icon_picker.dart';

class ThemeCustomizationEditor extends StatelessWidget {
  const ThemeCustomizationEditor({super.key});

  static const _pages = ['Home', 'Budget', 'Statistik', 'Setelan'];
  static const _footer = [
    ('Transaksi', Icons.receipt_long),
    ('Budget', Icons.savings_outlined),
    ('Statistik', Icons.pie_chart),
    ('Setelan', Icons.tune),
  ];

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Warna per halaman',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        for (var page = 0; page < _pages.length; page++)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(_pages[page]),
            leading: CircleAvatar(
              backgroundColor: settings.pageAccent(page),
              radius: 12,
            ),
            children: [
              GridView.count(
                crossAxisCount: 7,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                children: [
                  for (final color in SettingsProvider.presetColors)
                    InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => settings.setThemePageColor(page, color),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: color == settings.pageAccent(page)
                              ? Border.all(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                  width: 3,
                                )
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        const Divider(height: 28),
        Text('Posisi ikon +', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [settings.accentBright, settings.accent],
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const ThemeArtwork(tile: 0, size: 54, addTransaction: true),
                Positioned(
                  right: 3,
                  bottom: 3,
                  child: Transform.translate(
                    offset: settings.fabPlusOffset,
                    child: CircleAvatar(
                      radius: 10,
                      backgroundColor: settings.accent,
                      child: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        _OffsetSlider(
          label: 'Horizontal',
          value: settings.fabPlusOffset.dx,
          onChanged: (value) => settings.setFabPlusOffset(
            Offset(value, settings.fabPlusOffset.dy),
          ),
        ),
        _OffsetSlider(
          label: 'Vertikal',
          value: settings.fabPlusOffset.dy,
          onChanged: (value) => settings.setFabPlusOffset(
            Offset(settings.fabPlusOffset.dx, value),
          ),
        ),
        const Divider(height: 28),
        Text(
          'Kelola ikon custom',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        const Text(
          'Semua slot memakai preview dan crop 160×160 yang sama. Konten '
          'kosong otomatis mengikuti header halaman masing-masing.',
          style: TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 8),
        for (var index = 0; index < _pages.length; index++)
          _ThemeIconOption(
            label: 'Header ${_pages[index]}',
            iconKey: settings.headerArtwork(index),
            fallback: Icons.web_asset_outlined,
            color: settings.accent,
            onChanged: (value) => settings.setHeaderArtwork(index, value),
          ),
        for (var index = 0; index < _footer.length; index++)
          _ThemeIconOption(
            label: 'Footer ${_footer[index].$1}',
            iconKey: settings.footerArtwork(index),
            fallback: _footer[index].$2,
            color: settings.accent,
            onChanged: (value) => settings.setFooterArtwork(index, value),
          ),
        _ThemeIconOption(
          label: 'Maskot Kartu Saldo',
          iconKey: settings.cardMascotArtwork,
          fallback: Icons.credit_card,
          color: settings.accent,
          onChanged: settings.setCardMascotArtwork,
        ),
        _ThemeIconOption(
          label: 'Tombol Tambah Transaksi',
          iconKey: settings.addTransactionArtwork,
          fallback: Icons.add_circle_outline,
          color: settings.accent,
          onChanged: settings.setAddTransactionArtwork,
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _reset(context, settings),
          icon: const Icon(Icons.restart_alt),
          label: Text('Reset tema ${settings.preset.name}'),
        ),
      ],
    );
  }

  Future<void> _reset(BuildContext context, SettingsProvider settings) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset kustomisasi tema?'),
        content: Text(
          '${settings.preset.name} akan kembali ke tampilan bawaannya. '
          'Data transaksi tidak terpengaruh.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed == true) await settings.resetThemeCustomization();
  }
}

class _ThemeIconOption extends StatelessWidget {
  const _ThemeIconOption({
    required this.label,
    required this.iconKey,
    required this.fallback,
    required this.color,
    required this.onChanged,
  });

  final String label;
  final String? iconKey;
  final IconData fallback;
  final Color color;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => ExpansionTile(
    tilePadding: EdgeInsets.zero,
    title: Text(label),
    leading: ThemeIconView(
      iconKey: iconKey,
      size: 36,
      previewSeconds: 3,
      animate: false,
      fallback: Icon(fallback, size: 26),
    ),
    children: [
      ThemeProfileIconPicker(
        iconKey: iconKey,
        previewSeconds: 3,
        color: color,
        showPreviewDuration: false,
        onChanged: onChanged,
        onPreviewSecondsChanged: (_) {},
      ),
      const SizedBox(height: 8),
    ],
  );
}

class _OffsetSlider extends StatelessWidget {
  const _OffsetSlider({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(width: 76, child: Text(label)),
      Expanded(
        child: Slider(
          value: value,
          min: -18,
          max: 18,
          divisions: 36,
          label: '${value.round()}',
          onChanged: onChanged,
        ),
      ),
    ],
  );
}
