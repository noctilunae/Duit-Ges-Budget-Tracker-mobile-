import 'dart:typed_data';
import 'dart:ui' as ui;

const customIconPixels = 160;

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
