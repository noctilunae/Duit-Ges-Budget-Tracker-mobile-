import 'stored_icon.dart';

const themeGifIconPrefix = 'theme_gif:';
const themeVideoIconPrefix = 'theme_video:';

typedef ThemeIconMediaData = ({
  String path,
  double zoom,
  double alignX,
  double alignY,
});

ThemeIconMediaData? parseThemeIconMedia(String? key) {
  if (key == null) return null;
  final prefix = key.startsWith(themeGifIconPrefix)
      ? themeGifIconPrefix
      : key.startsWith(themeVideoIconPrefix)
      ? themeVideoIconPrefix
      : null;
  if (prefix == null) return null;
  final value = key.substring(prefix.length);
  if (!value.startsWith('crop=')) {
    return (path: value, zoom: 1, alignX: 0, alignY: 0);
  }
  final separator = value.indexOf(':');
  if (separator < 0) return null;
  final crop = value.substring(5, separator).split(',');
  if (crop.length != 3) return null;
  final zoom = double.tryParse(crop[0]);
  final alignX = double.tryParse(crop[1]);
  final alignY = double.tryParse(crop[2]);
  if (zoom == null || alignX == null || alignY == null) return null;
  return (
    path: value.substring(separator + 1),
    zoom: zoom.clamp(1, 3),
    alignX: alignX.clamp(-1, 1),
    alignY: alignY.clamp(-1, 1),
  );
}

String _storedThemeMedia(
  String prefix,
  String path, {
  double zoom = 1,
  double alignX = 0,
  double alignY = 0,
}) {
  final safeZoom = zoom.clamp(1, 3);
  final safeX = alignX.clamp(-1, 1);
  final safeY = alignY.clamp(-1, 1);
  if (safeZoom == 1 && safeX == 0 && safeY == 0) return '$prefix$path';
  return '$prefix'
      'crop=${safeZoom.toStringAsFixed(2)},'
      '${safeX.toStringAsFixed(2)},${safeY.toStringAsFixed(2)}:$path';
}

String storedThemeGif(
  String path, {
  double zoom = 1,
  double alignX = 0,
  double alignY = 0,
}) => _storedThemeMedia(
  themeGifIconPrefix,
  path,
  zoom: zoom,
  alignX: alignX,
  alignY: alignY,
);

String storedThemeVideo(
  String path, {
  double zoom = 1,
  double alignX = 0,
  double alignY = 0,
}) => _storedThemeMedia(
  themeVideoIconPrefix,
  path,
  zoom: zoom,
  alignX: alignX,
  alignY: alignY,
);

String withThemeIconCrop(
  String key, {
  required double zoom,
  required double alignX,
  required double alignY,
}) {
  final media = parseThemeIconMedia(key);
  if (media == null) return key;
  return isThemeGif(key)
      ? storedThemeGif(media.path, zoom: zoom, alignX: alignX, alignY: alignY)
      : storedThemeVideo(
          media.path,
          zoom: zoom,
          alignX: alignX,
          alignY: alignY,
        );
}

String? themeIconPath(String? key) =>
    parseStoredImageIcon(key ?? '')?.path ?? parseThemeIconMedia(key)?.path;

bool isThemeGif(String? key) => key?.startsWith(themeGifIconPrefix) ?? false;
bool isThemeVideo(String? key) =>
    key?.startsWith(themeVideoIconPrefix) ?? false;
