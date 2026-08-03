import 'dart:io';

import 'package:flutter/material.dart';

const storedImagePrefix = 'image:';

bool isStoredImageIcon(String key) => key.startsWith(storedImagePrefix);
bool isValidStoredImageIcon(String key) => parseStoredImageIcon(key) != null;

({double scale, String path})? parseStoredImageIcon(String key) {
  final match = RegExp(r'^image:([0-9.]+):(.+)$').firstMatch(key);
  final scale = double.tryParse(match?.group(1) ?? '');
  final path = match?.group(2);
  if (scale == null || path == null) return null;
  return (scale: scale.clamp(0.6, 2.5), path: path);
}

String storedImageIcon(String path, double scale) =>
    'image:${scale.clamp(0.6, 2.5).toStringAsFixed(2)}:$path';

Widget storedIconWidget(String key, {required Widget fallback, double? size}) {
  if (!isStoredImageIcon(key)) return fallback;
  final image = parseStoredImageIcon(key);
  if (image == null) return fallback;
  final displaySize = (size ?? 24) * image.scale;
  return Image.file(
    File(image.path),
    width: displaySize,
    height: displaySize,
    fit: BoxFit.contain,
    cacheWidth: (displaySize * 3).round(),
    errorBuilder: (_, _, _) => fallback,
  );
}
