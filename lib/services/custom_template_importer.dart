import 'dart:io';

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import '../models/custom_template.dart';

class TemplateCandidate {
  const TemplateCandidate({
    required this.path,
    required this.media,
    this.duration = Duration.zero,
    this.width = 0,
    this.height = 0,
    required this.bytes,
  });

  final String path;
  final CustomTemplateMedia media;
  final Duration duration;
  final double width;
  final double height;
  final int bytes;

  bool canSkipCompression(int limit) =>
      bytes <= limit && width <= 1280 && height <= 1280;
}

abstract final class CustomTemplateImporter {
  static const _compressor = MethodChannel('duit_ges/video_compressor');
  static const maxInputBytes = 50 * 1024 * 1024;
  static const maxDuration = Duration(seconds: 15);

  static Future<TemplateCandidate?> pickImage(CustomTemplateKind kind) async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: kind == CustomTemplateKind.card ? 800 : 720,
      maxHeight: kind == CustomTemplateKind.card ? 800 : 1280,
      imageQuality: 80,
    );
    if (picked == null) return null;
    return TemplateCandidate(
      path: picked.path,
      media: CustomTemplateMedia.image,
      bytes: await picked.length(),
    );
  }

  static Future<TemplateCandidate?> pickVideo() async {
    final picked = await ImagePicker().pickVideo(
      source: ImageSource.gallery,
      maxDuration: maxDuration,
    );
    if (picked == null) return null;
    final bytes = await picked.length();
    if (bytes > maxInputBytes) {
      throw const FormatException('Video maksimal 50 MB');
    }
    final controller = VideoPlayerController.file(
      File(picked.path),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    try {
      await controller.initialize();
      final duration = controller.value.duration;
      final size = controller.value.size;
      if (duration > maxDuration) {
        throw const FormatException('Durasi video maksimal 15 detik');
      }
      final longSide = size.width > size.height ? size.width : size.height;
      final shortSide = size.width < size.height ? size.width : size.height;
      if (longSide > 1920 || shortSide > 1080) {
        throw const FormatException('Resolusi input maksimal Full HD');
      }
      return TemplateCandidate(
        path: picked.path,
        media: CustomTemplateMedia.video,
        duration: duration,
        width: size.width,
        height: size.height,
        bytes: bytes,
      );
    } finally {
      await controller.dispose();
    }
  }

  static Future<String> compressVideo(String input, CustomTemplateKind kind) =>
      compressVideoToHeight(
        input,
        kind == CustomTemplateKind.card ? 720 : 1280,
        prefix: 'template',
      );

  static Future<String> compressVideoToHeight(
    String input,
    int height, {
    String prefix = 'video',
  }) async {
    final temp = await getTemporaryDirectory();
    final output =
        '${temp.path}/${prefix}_${DateTime.now().microsecondsSinceEpoch}.mp4';
    return await _compressor.invokeMethod<String>('compress', {
          'input': input,
          'output': output,
          'height': height,
        }) ??
        (throw StateError('Kompresi tidak menghasilkan file'));
  }

  static Future<String> save(
    String source,
    CustomTemplateMedia media,
    String id,
  ) async {
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory('${documents.path}/custom_templates');
    await directory.create(recursive: true);
    final extension = media == CustomTemplateMedia.video ? 'mp4' : 'jpg';
    return (await File(source).copy('${directory.path}/$id.$extension')).path;
  }
}
