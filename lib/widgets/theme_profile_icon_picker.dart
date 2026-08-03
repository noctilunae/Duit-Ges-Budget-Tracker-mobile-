import 'package:flutter/material.dart';

import '../services/theme_icon_importer.dart';
import '../utils/stored_icon.dart';
import '../utils/theme_icon_media.dart';
import 'custom_image_icon_picker.dart';
import 'theme_icon_view.dart';

class ThemeProfileIconPicker extends StatelessWidget {
  const ThemeProfileIconPicker({
    super.key,
    required this.iconKey,
    required this.previewSeconds,
    required this.color,
    required this.onChanged,
    required this.onPreviewSecondsChanged,
    this.animatedOnly = false,
    this.showPreviewDuration = true,
  });

  final String? iconKey;
  final int previewSeconds;
  final Color color;
  final ValueChanged<String?> onChanged;
  final ValueChanged<int> onPreviewSecondsChanged;
  final bool animatedOnly;
  final bool showPreviewDuration;

  Future<void> _pick(BuildContext context, AnimatedThemeIconMedia media) async {
    var progressOpen = false;
    try {
      final candidate = media == AnimatedThemeIconMedia.gif
          ? await ThemeIconImporter.pickGif()
          : await ThemeIconImporter.pickVideo();
      if (candidate == null || !context.mounted) return;
      final compress = await _compressionChoice(context, candidate);
      if (compress == null || !context.mounted) return;
      final sourceKey = media == AnimatedThemeIconMedia.gif
          ? storedThemeGif(candidate.path)
          : storedThemeVideo(candidate.path);
      final preview = await _preview(context, sourceKey);
      if (preview == null || !context.mounted) return;
      _showProgress(context, media);
      progressOpen = true;
      var key = await ThemeIconImporter.save(candidate, compress: compress);
      key = withThemeIconCrop(
        key,
        zoom: preview.zoom,
        alignX: preview.alignX,
        alignY: preview.alignY,
      );
      if (!context.mounted) return;
      Navigator.pop(context);
      progressOpen = false;
      onPreviewSecondsChanged(preview.seconds);
      onChanged(key);
    } on FormatException catch (error) {
      if (context.mounted) {
        if (progressOpen) Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (context.mounted) {
        if (progressOpen) Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ikon tidak dapat diproses')),
        );
      }
    }
  }

  Future<bool?> _compressionChoice(
    BuildContext context,
    AnimatedThemeIconCandidate candidate,
  ) => showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Kompresi ikon'),
      content: Text(
        '${candidate.media == AnimatedThemeIconMedia.gif ? 'GIF' : 'Video'} • '
        '${candidate.width}×${candidate.height} • '
        '${(candidate.bytes / 1024 / 1024).toStringAsFixed(1)} MB • '
        '${(candidate.duration.inMilliseconds / 1000).toStringAsFixed(1)} detik\n\n'
        'Kompresi mengecilkan ikon ke maksimal 160 px dan video dibuat tanpa audio.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: candidate.canSkipCompression
              ? () => Navigator.pop(context, false)
              : null,
          child: const Text('Tanpa kompresi'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Kompres'),
        ),
      ],
    ),
  );

  Future<({int seconds, double zoom, double alignX, double alignY})?> _preview(
    BuildContext context,
    String sourceKey,
  ) {
    var seconds = previewSeconds;
    final initial = parseThemeIconMedia(sourceKey);
    var zoom = initial?.zoom ?? 1;
    var alignX = initial?.alignX ?? 0;
    var alignY = initial?.alignY ?? 0;
    return showDialog<
      ({int seconds, double zoom, double alignX, double alignY})
    >(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final key = withThemeIconCrop(
            sourceKey,
            zoom: zoom,
            alignX: alignX,
            alignY: alignY,
          );
          return AlertDialog(
            scrollable: true,
            title: const Text('Preview dan crop ikon'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ThemeIconView(
                  iconKey: key,
                  size: 160,
                  previewSeconds: seconds,
                  fallback: const Icon(Icons.broken_image_outlined, size: 64),
                ),
                const SizedBox(height: 12),
                Text('Zoom ${zoom.toStringAsFixed(1)}×'),
                Slider(
                  value: zoom,
                  min: 1,
                  max: 3,
                  divisions: 20,
                  onChanged: (value) => setState(() => zoom = value),
                ),
                const Text('Posisi horizontal'),
                Slider(
                  value: alignX,
                  min: -1,
                  max: 1,
                  divisions: 20,
                  onChanged: (value) => setState(() => alignX = value),
                ),
                const Text('Posisi vertikal'),
                Slider(
                  value: alignY,
                  min: -1,
                  max: 1,
                  divisions: 20,
                  onChanged: (value) => setState(() => alignY = value),
                ),
                if (showPreviewDuration) ...[
                  Text('Tampilkan animasi $seconds detik'),
                  Slider(
                    value: seconds.toDouble(),
                    min: 1,
                    max: 5,
                    divisions: 4,
                    label: '$seconds detik',
                    onChanged: (value) =>
                        setState(() => seconds = value.round()),
                  ),
                ],
                const Text(
                  'Ketuk preview untuk memutar ulang.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Batal'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, (
                  seconds: seconds,
                  zoom: zoom,
                  alignX: alignX,
                  alignY: alignY,
                )),
                child: const Text('Gunakan'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _editCrop(BuildContext context) async {
    final key = iconKey;
    if (key == null) return;
    final preview = await _preview(context, key);
    if (preview == null) return;
    onPreviewSecondsChanged(preview.seconds);
    onChanged(
      withThemeIconCrop(
        key,
        zoom: preview.zoom,
        alignX: preview.alignX,
        alignY: preview.alignY,
      ),
    );
  }

  void _showProgress(BuildContext context, AnimatedThemeIconMedia media) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                media == AnimatedThemeIconMedia.gif
                    ? 'Memproses GIF...'
                    : 'Mengompres video...',
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final animated = isThemeGif(iconKey) || isThemeVideo(iconKey);
    return Column(
      children: [
        if (animated) ...[
          ThemeIconView(
            iconKey: iconKey,
            size: 88,
            previewSeconds: previewSeconds,
            fallback: const Icon(Icons.broken_image_outlined, size: 48),
          ),
          if (showPreviewDuration) ...[
            Text('Preview $previewSeconds detik • ketuk untuk ulang'),
            Slider(
              value: previewSeconds.toDouble(),
              min: 1,
              max: 5,
              divisions: 4,
              label: '$previewSeconds detik',
              onChanged: (value) => onPreviewSecondsChanged(value.round()),
            ),
          ],
        ],
        if (!animatedOnly)
          CustomImageIconPicker(
            iconKey: isStoredImageIcon(iconKey ?? '') ? iconKey! : 'default',
            fallbackKey: 'default',
            directoryName: 'custom_theme_profile_icons',
            previewColor: color,
            onChanged: (value) =>
                onChanged(isStoredImageIcon(value) ? value : null),
          ),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => _pick(context, AnimatedThemeIconMedia.gif),
              icon: const Icon(Icons.gif_box_outlined),
              label: const Text('Pilih GIF'),
            ),
            OutlinedButton.icon(
              onPressed: () => _pick(context, AnimatedThemeIconMedia.video),
              icon: const Icon(Icons.video_file_outlined),
              label: const Text('Pilih video'),
            ),
            if (animated)
              OutlinedButton.icon(
                onPressed: () => _editCrop(context),
                icon: const Icon(Icons.crop),
                label: const Text('Crop ulang'),
              ),
            if (animated)
              TextButton.icon(
                onPressed: () => onChanged(null),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Hapus'),
              ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Output ikon 160×160. Batas: GIF 8 MB/10 dtk/1080 px; '
          'video 50 MB/10 dtk/Full HD. '
          'Tanpa kompresi hanya tersedia untuk file yang sudah ringan. '
          'Transparansi PNG/GIF dipertahankan; video biasanya tidak transparan.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11),
        ),
      ],
    );
  }
}
