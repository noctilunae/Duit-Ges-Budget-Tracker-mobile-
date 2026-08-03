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
        Text('Kelola ikon', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        const Text(
          'Pilih ikon bawaan tema atau ikon custom untuk setiap slot. Semua '
          'ikon custom memakai preview dan crop 160×160 yang sama.',
          style: TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 8),
        for (var index = 0; index < _pages.length; index++)
          _ThemeIconOption(
            label: 'Header ${_pages[index]}',
            slot: 'header_$index',
            tile: const [1, 7, 8, 3][index],
            fallback: Icons.web_asset_outlined,
            onChanged: (value) => settings.setHeaderArtwork(index, value),
          ),
        for (var index = 0; index < _footer.length; index++)
          _ThemeIconOption(
            label: 'Footer ${_footer[index].$1}',
            slot: 'footer_$index',
            tile: settings.footerTile(index),
            fallback: _footer[index].$2,
            onChanged: (value) => settings.setFooterArtwork(index, value),
          ),
        _ThemeIconOption(
          label: 'Maskot Kartu Saldo',
          slot: 'card_mascot',
          tile: 0,
          fallback: Icons.credit_card,
          allowEmpty: true,
          onChanged: settings.setCardMascotArtwork,
        ),
        _ThemeIconOption(
          label: 'Tombol Tambah Transaksi',
          slot: 'add_transaction',
          tile: 0,
          fallback: Icons.add_circle_outline,
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
    required this.slot,
    required this.tile,
    required this.fallback,
    required this.onChanged,
    this.allowEmpty = false,
  });

  final String label;
  final String slot;
  final int tile;
  final IconData fallback;
  final ValueChanged<String?> onChanged;
  final bool allowEmpty;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final emptyMode = settings.isThemeIconEmpty(slot);
    final customMode = settings.hasThemeIconOverride(slot) && !emptyMode;
    final iconKey = settings.themeIconOverride(slot);
    final builtInAsset = settings.builtInThemeIconAsset(slot);
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(label),
      leading: customMode
          ? ThemeIconView(
              iconKey: iconKey,
              size: 36,
              previewSeconds: 3,
              animate: false,
              fallback: Icon(fallback, size: 26),
            )
          : emptyMode
          ? const SizedBox.square(dimension: 36)
          : builtInAsset != null
          ? Image.asset(
              builtInAsset,
              width: 36,
              height: 36,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => Icon(fallback, size: 26),
            )
          : ThemeArtwork(
              tile: tile,
              size: 36,
              ignoreCustomization: true,
              fallback: Icon(fallback, size: 26),
            ),
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey('$slot-$customMode-$emptyMode'),
          initialValue: emptyMode
              ? 'empty'
              : customMode
              ? 'custom'
              : 'built_in',
          decoration: const InputDecoration(
            labelText: 'Sumber ikon',
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem(
              value: 'built_in',
              child: Text('Ikon bawaan'),
            ),
            const DropdownMenuItem(value: 'custom', child: Text('Ikon custom')),
            if (allowEmpty)
              const DropdownMenuItem(value: 'empty', child: Text('Kosong')),
          ],
          onChanged: (value) {
            if (value == 'built_in') {
              settings.useBuiltInThemeIcon(slot);
            } else if (value == 'custom') {
              settings.useCustomThemeIcon(slot);
            } else if (value == 'empty') {
              settings.useEmptyThemeIcon(slot);
            }
          },
        ),
        if (customMode) ...[
          const SizedBox(height: 10),
          ThemeProfileIconPicker(
            iconKey: iconKey,
            previewSeconds: 3,
            color: settings.accent,
            showPreviewDuration: false,
            onChanged: onChanged,
            onPreviewSecondsChanged: (_) {},
          ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }
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
