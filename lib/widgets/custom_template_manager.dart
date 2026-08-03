import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../models/custom_template.dart';
import '../providers/settings_provider.dart';
import '../services/custom_template_importer.dart';

class CustomTemplateManager extends StatelessWidget {
  const CustomTemplateManager({super.key, required this.kind});

  final CustomTemplateKind kind;

  Future<void> _add(BuildContext context) async {
    final media = await showModalBottomSheet<CustomTemplateMedia>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            const ListTile(
              title: Text('Spesifikasi ideal'),
              subtitle: Text(
                'Video MP4 H.264, tanpa audio, ≤15 detik, ≤1080p, ≤50 MB. '
                'Hasil kompres maksimal 720p.',
              ),
            ),
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('Tambah gambar'),
              onTap: () => Navigator.pop(context, CustomTemplateMedia.image),
            ),
            ListTile(
              leading: const Icon(Icons.video_library_outlined),
              title: const Text('Tambah video'),
              onTap: () => Navigator.pop(context, CustomTemplateMedia.video),
            ),
          ],
        ),
      ),
    );
    if (media == null || !context.mounted) return;
    var progressOpen = false;
    try {
      var candidate = media == CustomTemplateMedia.image
          ? await CustomTemplateImporter.pickImage(kind)
          : await CustomTemplateImporter.pickVideo();
      if (candidate == null || !context.mounted) return;
      final name = TextEditingController(
        text: kind == CustomTemplateKind.card
            ? 'Kartu Custom'
            : 'Background Custom',
      );
      final crop = await _crop(context, candidate, name: name);
      final templateName = name.text.trim();
      name.dispose();
      if (crop == null || !context.mounted) return;
      if (media == CustomTemplateMedia.video) {
        final limit = kind == CustomTemplateKind.card
            ? 5 * 1024 * 1024
            : 10 * 1024 * 1024;
        final compress = await _compressionChoice(context, candidate, limit);
        if (compress == null || !context.mounted) return;
        if (compress) {
          _showProgress(context);
          progressOpen = true;
          final compressed = await CustomTemplateImporter.compressVideo(
            candidate.path,
            kind,
          );
          if (!context.mounted) return;
          Navigator.pop(context);
          progressOpen = false;
          candidate = TemplateCandidate(
            path: compressed,
            media: media,
            bytes: await File(compressed).length(),
          );
        }
      }
      if (!context.mounted) return;
      final id = 'custom_${DateTime.now().microsecondsSinceEpoch}';
      final path = await CustomTemplateImporter.save(candidate.path, media, id);
      if (!context.mounted) return;
      await context.read<SettingsProvider>().addCustomTemplate(
        CustomTemplate(
          id: id,
          name: templateName,
          kind: kind,
          media: media,
          path: path,
          zoom: crop.zoom,
          alignX: crop.alignX,
          alignY: crop.alignY,
          opacity: crop.opacity,
        ),
      );
    } on FormatException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (context.mounted) {
        if (progressOpen) Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Media tidak dapat diproses')),
        );
      }
    }
  }

  Future<bool?> _compressionChoice(
    BuildContext context,
    TemplateCandidate candidate,
    int limit,
  ) => showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Kompresi video'),
      content: Text(
        'Ukuran ${(candidate.bytes / 1024 / 1024).toStringAsFixed(1)} MB • '
        '${candidate.width.round()}×${candidate.height.round()} • '
        '${candidate.duration.inSeconds} detik\n\n'
        'Kompresi: H.264 720p tanpa audio. Tanpa kompresi hanya tersedia '
        'untuk video yang sudah ringan.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: candidate.canSkipCompression(limit)
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

  void _showProgress(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Expanded(child: Text('Mengompres video...')),
          ],
        ),
      ),
    );
  }

  Future<_TemplateCrop?> _crop(
    BuildContext context,
    TemplateCandidate candidate, {
    _TemplateCrop initial = const _TemplateCrop(),
    TextEditingController? name,
  }) => showDialog<_TemplateCrop>(
    context: context,
    builder: (context) {
      var zoom = initial.zoom;
      var alignX = initial.alignX;
      var alignY = initial.alignY;
      var opacity = initial.opacity;
      return StatefulBuilder(
        builder: (context, setState) {
          final alignment = Alignment(alignX, alignY);
          return AlertDialog(
            scrollable: true,
            title: Text(name == null ? 'Atur crop' : 'Preview dan crop'),
            content: SizedBox(
              width: 320,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AspectRatio(
                    aspectRatio: kind == CustomTemplateKind.card ? 2 : 9 / 16,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Opacity(
                        opacity: opacity,
                        child: candidate.media == CustomTemplateMedia.image
                            ? ClipRect(
                                child: Transform.scale(
                                  scale: zoom,
                                  alignment: alignment,
                                  child: Image.file(
                                    File(candidate.path),
                                    fit: BoxFit.cover,
                                    alignment: alignment,
                                  ),
                                ),
                              )
                            : _VideoPreview(
                                path: candidate.path,
                                alignment: alignment,
                                scale: zoom,
                              ),
                      ),
                    ),
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
                  Text('Opacity ${(opacity * 100).round()}%'),
                  Slider(
                    value: opacity,
                    min: 0.1,
                    max: 1,
                    divisions: 18,
                    onChanged: (value) => setState(() => opacity = value),
                  ),
                  if (name != null) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: name,
                      maxLength: 30,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Nama template',
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Batal'),
              ),
              FilledButton(
                onPressed: name != null && name.text.trim().isEmpty
                    ? null
                    : () => Navigator.pop(
                        context,
                        _TemplateCrop(
                          zoom: zoom,
                          alignX: alignX,
                          alignY: alignY,
                          opacity: opacity,
                        ),
                      ),
                child: const Text('Terapkan'),
              ),
            ],
          );
        },
      );
    },
  );

  Future<void> _editCrop(BuildContext context, CustomTemplate template) async {
    final bytes = await File(template.path).length();
    if (!context.mounted) return;
    final crop = await _crop(
      context,
      TemplateCandidate(
        path: template.path,
        media: template.media,
        bytes: bytes,
      ),
      initial: _TemplateCrop(
        zoom: template.zoom,
        alignX: template.alignX,
        alignY: template.alignY,
        opacity: template.opacity,
      ),
    );
    if (crop == null || !context.mounted) return;
    await context.read<SettingsProvider>().updateCustomTemplate(
      template.copyWith(
        zoom: crop.zoom,
        alignX: crop.alignX,
        alignY: crop.alignY,
        opacity: crop.opacity,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final active = kind == CustomTemplateKind.card
        ? settings.customCard
        : settings.customBackground;
    final items = settings.customTemplates
        .where((item) => item.kind == kind)
        .toList();
    return Column(
      children: [
        for (final item in items)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: SizedBox(
              width: 56,
              height: 40,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Opacity(
                  opacity: item.opacity,
                  child: item.media == CustomTemplateMedia.image
                      ? Image.file(File(item.path), fit: BoxFit.cover)
                      : const ColoredBox(
                          color: Colors.black,
                          child: Icon(
                            Icons.play_circle_outline,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
            title: Text(item.name),
            subtitle: Text(
              item.media == CustomTemplateMedia.video ? 'Video' : 'Gambar',
            ),
            selected: active?.id == item.id,
            onTap: () => settings.selectCustomTemplate(item),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Edit crop',
                  onPressed: () => _editCrop(context, item),
                  icon: const Icon(Icons.crop),
                ),
                IconButton(
                  tooltip: 'Hapus template',
                  onPressed: () => settings.deleteCustomTemplate(item),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => _add(context),
            icon: const Icon(Icons.add),
            label: const Text('Tambah custom'),
          ),
        ),
      ],
    );
  }
}

class _VideoPreview extends StatefulWidget {
  const _VideoPreview({
    required this.path,
    this.alignment = Alignment.center,
    this.scale = 1,
  });
  final String path;
  final Alignment alignment;
  final double scale;

  @override
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview> {
  late final VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        VideoPlayerController.file(
            File(widget.path),
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
          )
          ..initialize().then((_) {
            _controller
              ..setVolume(0)
              ..setLooping(true)
              ..play();
            if (mounted) setState(() {});
          });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _controller.value.isInitialized
      ? ClipRect(
          child: Transform.scale(
            scale: widget.scale,
            alignment: widget.alignment,
            child: FittedBox(
              fit: BoxFit.cover,
              alignment: widget.alignment,
              child: SizedBox(
                width: _controller.value.size.width,
                height: _controller.value.size.height,
                child: VideoPlayer(_controller),
              ),
            ),
          ),
        )
      : const Center(child: CircularProgressIndicator());
}

class _TemplateCrop {
  const _TemplateCrop({
    this.zoom = 1,
    this.alignX = 0,
    this.alignY = 0,
    this.opacity = 1,
  });

  final double zoom;
  final double alignX;
  final double alignY;
  final double opacity;
}
