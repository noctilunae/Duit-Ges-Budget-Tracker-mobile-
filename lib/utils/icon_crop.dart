import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

const customIconPixels = 160;

ui.Rect iconCropSourceRect({
  required ui.Size imageSize,
  required double previewSize,
  required double baseScale,
  required Matrix4 transform,
}) {
  final inverse = Matrix4.inverted(transform);
  final topLeft = MatrixUtils.transformPoint(inverse, ui.Offset.zero);
  final bottomRight = MatrixUtils.transformPoint(
    inverse,
    ui.Offset(previewSize, previewSize),
  );
  final previewRect = ui.Rect.fromPoints(topLeft, bottomRight);
  final source = ui.Rect.fromLTWH(
    previewRect.left / baseScale,
    previewRect.top / baseScale,
    previewRect.width / baseScale,
    previewRect.height / baseScale,
  );
  return source.intersect(ui.Offset.zero & imageSize);
}

Future<Uint8List> cropIconImage(ui.Image image, ui.Rect source) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.clipPath(
    ui.Path()..addOval(const ui.Rect.fromLTWH(0, 0, 160, 160)),
    doAntiAlias: true,
  );
  canvas.drawImageRect(
    image,
    source,
    const ui.Rect.fromLTWH(0, 0, 160, 160),
    ui.Paint()..filterQuality = ui.FilterQuality.high,
  );
  final result = await recorder.endRecording().toImage(
    customIconPixels,
    customIconPixels,
  );
  final data = await result.toByteData(format: ui.ImageByteFormat.png);
  result.dispose();
  if (data == null) throw StateError('Gagal mengubah hasil crop ke PNG');
  return data.buffer.asUint8List();
}
