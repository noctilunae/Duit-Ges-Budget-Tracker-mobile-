import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:image/image.dart' as image;
import 'package:path_provider/path_provider.dart';

import '../utils/theme_icon_media.dart';
import '../utils/icon_crop.dart';
import 'custom_template_importer.dart';

enum AnimatedThemeIconMedia { gif, video }

class AnimatedThemeIconCandidate {
  const AnimatedThemeIconCandidate({
    required this.path,
    required this.media,
    required this.bytes,
    required this.width,
    required this.height,
    required this.duration,
    this.frames = 0,
  });

  final String path;
  final AnimatedThemeIconMedia media;
  final int bytes;
  final int width;
  final int height;
  final Duration duration;
  final int frames;

  bool get canSkipCompression => media == AnimatedThemeIconMedia.gif
      ? bytes <= 2 * 1024 * 1024 &&
            width <= customIconPixels &&
            height <= customIconPixels
      : bytes <= 5 * 1024 * 1024 &&
            width <= customIconPixels &&
            height <= customIconPixels &&
            duration <= const Duration(seconds: 5);
}

abstract final class ThemeIconImporter {
  static const maxGifBytes = 8 * 1024 * 1024;
  static const maxVideoBytes = 50 * 1024 * 1024;
  static const maxDuration = Duration(seconds: 10);
  static const maxGifFrames = 120;
  static const maxGifPixelFrames = 24 * 1024 * 1024;

  static Future<AnimatedThemeIconCandidate?> pickGif() async {
    final picked = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'GIF', extensions: ['gif']),
      ],
    );
    if (picked == null) return null;
    final bytes = await picked.readAsBytes();
    if (bytes.length > maxGifBytes) {
      throw const FormatException('GIF maksimal 8 MB');
    }
    final metadata = await Isolate.run(() => _inspectGif(bytes));
    if (metadata == null) throw const FormatException('File GIF tidak valid');
    final (:width, :height, :frames, :durationMs) = metadata;
    if (width > 1080 || height > 1080) {
      throw const FormatException('Resolusi GIF maksimal 1080×1080');
    }
    if (frames > maxGifFrames || width * height * frames > maxGifPixelFrames) {
      throw const FormatException(
        'GIF terlalu berat; maksimal 120 frame dengan kompleksitas wajar',
      );
    }
    final duration = Duration(milliseconds: durationMs);
    if (duration > maxDuration) {
      throw const FormatException('Durasi GIF maksimal 10 detik');
    }
    final preview = await Isolate.run(() => _firstGifFrame(bytes));
    if (preview == null) {
      throw const FormatException('Preview GIF gagal dibuat');
    }
    final temp = await getTemporaryDirectory();
    final path =
        '${temp.path}/theme_icon_source_${DateTime.now().microsecondsSinceEpoch}.gif';
    await File(path).writeAsBytes(bytes, flush: true);
    await File('$path.preview.png').writeAsBytes(preview, flush: true);
    return AnimatedThemeIconCandidate(
      path: path,
      media: AnimatedThemeIconMedia.gif,
      bytes: bytes.length,
      width: width,
      height: height,
      frames: frames,
      duration: duration,
    );
  }

  static Future<AnimatedThemeIconCandidate?> pickVideo() async {
    final candidate = await CustomTemplateImporter.pickVideo();
    if (candidate == null) return null;
    if (candidate.bytes > maxVideoBytes) {
      throw const FormatException('Video maksimal 50 MB');
    }
    if (candidate.duration > maxDuration) {
      throw const FormatException('Durasi ikon video maksimal 10 detik');
    }
    return AnimatedThemeIconCandidate(
      path: candidate.path,
      media: AnimatedThemeIconMedia.video,
      bytes: candidate.bytes,
      width: candidate.width.round(),
      height: candidate.height.round(),
      duration: candidate.duration,
    );
  }

  static Future<String> save(
    AnimatedThemeIconCandidate candidate, {
    required bool compress,
  }) async {
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory('${documents.path}/custom_theme_profile_icons');
    await directory.create(recursive: true);
    final id = DateTime.now().microsecondsSinceEpoch;
    if (candidate.media == AnimatedThemeIconMedia.video) {
      final source = compress
          ? await CustomTemplateImporter.compressVideoToHeight(
              candidate.path,
              _iconVideoHeight(candidate),
              prefix: 'theme_icon',
            )
          : candidate.path;
      final path = '${directory.path}/theme_icon_$id.mp4';
      await File(source).copy(path);
      return storedThemeVideo(path);
    }

    final sourceBytes = await File(candidate.path).readAsBytes();
    final result = await Isolate.run(
      () => _prepareGif(sourceBytes, compress: compress),
    );
    if (result == null) throw const FormatException('GIF tidak dapat diproses');
    if (result.gif.length > 5 * 1024 * 1024) {
      throw const FormatException(
        'Hasil GIF masih terlalu besar (maksimal 5 MB)',
      );
    }
    final path = '${directory.path}/theme_icon_$id.gif';
    await File(path).writeAsBytes(result.gif, flush: true);
    await File('$path.preview.png').writeAsBytes(result.preview, flush: true);
    return storedThemeGif(path);
  }
}

int _iconVideoHeight(AnimatedThemeIconCandidate candidate) {
  final height = candidate.width > candidate.height
      ? (customIconPixels * candidate.height / candidate.width).round()
      : customIconPixels;
  return ((height ~/ 2) * 2).clamp(2, customIconPixels);
}

Uint8List? _firstGifFrame(Uint8List bytes) {
  final decoder = image.GifDecoder();
  if (decoder.startDecode(bytes) == null) return null;
  final frame = decoder.decodeFrame(0);
  return frame == null ? null : image.encodePng(frame);
}

({int width, int height, int frames, int durationMs})? _inspectGif(
  Uint8List bytes,
) {
  final decoder = image.GifDecoder();
  final info = decoder.startDecode(bytes);
  if (info == null) return null;
  return (
    width: info.width,
    height: info.height,
    frames: info.numFrames,
    durationMs: info.frames.fold(0, (sum, frame) => sum + frame.duration * 10),
  );
}

({Uint8List gif, Uint8List preview})? _prepareGif(
  Uint8List bytes, {
  required bool compress,
}) {
  final decoded = image.decodeGif(bytes);
  if (decoded == null) return null;
  final output =
      compress &&
          (decoded.width > customIconPixels ||
              decoded.height > customIconPixels)
      ? image.copyResize(
          decoded,
          width: decoded.width >= decoded.height ? customIconPixels : null,
          height: decoded.height > decoded.width ? customIconPixels : null,
          interpolation: image.Interpolation.average,
        )
      : decoded;
  return (
    gif: compress ? image.encodeGif(output, samplingFactor: 20) : bytes,
    preview: image.encodePng(output.frames.first),
  );
}
