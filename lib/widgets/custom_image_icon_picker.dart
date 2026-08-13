import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../utils/icon_crop.dart';
import '../utils/stored_icon.dart';

class CustomImageIconPicker extends StatelessWidget {
  const CustomImageIconPicker({
    super.key,
    required this.iconKey,
    required this.fallbackKey,
    required this.onChanged,
    this.previewColor,
    this.directoryName = 'custom_icons',
  });

  final String iconKey;
  final String fallbackKey;
  final ValueChanged<String> onChanged;
  final Color? previewColor;
  final String directoryName;

  Future<void> _pick(BuildContext context) async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 90,
    );
    if (picked == null || !context.mounted) return;
    try {
      final bytes = await picked.readAsBytes();
      if (!context.mounted) return;
      final cropped = await _crop(context, bytes);
      if (cropped == null) return;
      final directory = Directory(
        '${(await getApplicationDocumentsDirectory()).path}/$directoryName',
      );
      await directory.create(recursive: true);
      final target = File(
        '${directory.path}/icon_${DateTime.now().microsecondsSinceEpoch}.png',
      );
      await target.writeAsBytes(cropped, flush: true);
      onChanged(storedImageIcon(target.path, 1));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gambar tidak dapat diproses')),
        );
      }
    }
  }

  Future<Uint8List?> _crop(BuildContext context, Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    codec.dispose();
    if (!context.mounted) {
      frame.image.dispose();
      return null;
    }
    final cropped = await showDialog<Uint8List>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _IconCropDialog(image: frame.image),
    );
    frame.image.dispose();
    return cropped;
  }

  Future<void> _recrop(BuildContext context, String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      if (!context.mounted) return;
      final cropped = await _crop(context, bytes);
      if (cropped == null) return;
      await File(path).writeAsBytes(cropped, flush: true);
      await FileImage(File(path)).evict();
      onChanged(iconKey);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gambar tidak dapat diproses')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final image = parseStoredImageIcon(iconKey);
    return Column(
      children: [
        if (image != null) ...[
          Center(
            child: Container(
              key: const ValueKey('custom-icon-preview'),
              width: 160,
              height: 160,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (previewColor ?? Theme.of(context).colorScheme.primary)
                    .withValues(alpha: 0.15),
              ),
              child: Center(
                child: storedIconWidget(
                  iconKey,
                  size: 96,
                  fallback: const Icon(Icons.broken_image_outlined, size: 36),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Preview di lingkaran',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Row(
            children: [
              const Text('Ukuran'),
              Expanded(
                child: Slider(
                  value: image.scale,
                  min: 0.6,
                  max: 2.5,
                  divisions: 19,
                  label: '${(image.scale * 100).round()}%',
                  onChanged: (value) =>
                      onChanged(storedImageIcon(image.path, value)),
                ),
              ),
            ],
          ),
        ],
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => _pick(context),
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(image == null ? 'Pilih PNG/JPG' : 'Ganti'),
            ),
            if (image != null) ...[
              OutlinedButton.icon(
                onPressed: () => _recrop(context, image.path),
                icon: const Icon(Icons.crop),
                label: const Text('Crop ulang'),
              ),
              TextButton.icon(
                onPressed: () => onChanged(fallbackKey),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Hapus'),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _IconCropDialog extends StatefulWidget {
  const _IconCropDialog({required this.image});

  final ui.Image image;

  @override
  State<_IconCropDialog> createState() => _IconCropDialogState();
}

class _IconCropDialogState extends State<_IconCropDialog> {
  final _transform = TransformationController();
  double? _cropSize;
  double _baseScale = 1;
  bool _saving = false;

  void _initialize(double size) {
    if (_cropSize == size) return;
    _cropSize = size;
    _baseScale = size / widget.image.height;
    if (widget.image.width < widget.image.height) {
      _baseScale = size / widget.image.width;
    }
    final width = widget.image.width * _baseScale;
    final height = widget.image.height * _baseScale;
    _transform.value = Matrix4.identity()
      ..translateByDouble((size - width) / 2, (size - height) / 2, 0, 1);
  }

  Future<void> _save() async {
    final size = _cropSize!;
    final source = iconCropSourceRect(
      imageSize: ui.Size(
        widget.image.width.toDouble(),
        widget.image.height.toDouble(),
      ),
      previewSize: size,
      baseScale: _baseScale,
      transform: _transform.value,
    );
    setState(() => _saving = true);
    final bytes = await cropIconImage(widget.image, source);
    if (mounted) Navigator.pop(context, bytes);
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = (MediaQuery.sizeOf(context).width - 80).clamp(220.0, 320.0);
    _initialize(size);
    final width = widget.image.width * _baseScale;
    final height = widget.image.height * _baseScale;
    return AlertDialog(
      title: const Text('Sesuaikan Ikon'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: size,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRect(
                    child: InteractiveViewer(
                      transformationController: _transform,
                      constrained: false,
                      minScale: 1,
                      maxScale: 6,
                      boundaryMargin: EdgeInsets.zero,
                      child: RawImage(
                        image: widget.image,
                        width: width,
                        height: height,
                        fit: BoxFit.fill,
                      ),
                    ),
                  ),
                ),
                const Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(painter: _CropMask()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Geser dan cubit untuk zoom. Bagian di dalam lingkaran menjadi ikon.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Memproses...' : 'Gunakan'),
        ),
      ],
    );
  }
}

class _CropMask extends CustomPainter {
  const _CropMask();

  @override
  void paint(Canvas canvas, Size size) {
    final diameter = math.min(size.width, size.height);
    final circle = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: diameter / 2,
    );
    final outside = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      Path()..addOval(circle),
    );
    canvas.drawPath(outside, Paint()..color = Colors.black54);
    canvas.drawOval(
      circle.deflate(1),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_CropMask oldDelegate) => false;
}
