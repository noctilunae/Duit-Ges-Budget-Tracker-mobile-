import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../utils/stored_icon.dart';
import '../utils/theme_icon_media.dart';

class ThemeIconView extends StatelessWidget {
  const ThemeIconView({
    super.key,
    required this.iconKey,
    required this.size,
    required this.previewSeconds,
    required this.fallback,
    this.animate = true,
    this.continuous = false,
  });

  final String? iconKey;
  final double size;
  final int previewSeconds;
  final Widget fallback;
  final bool animate;
  final bool continuous;

  @override
  Widget build(BuildContext context) {
    final media = parseThemeIconMedia(iconKey);
    final alignment = Alignment(media?.alignX ?? 0, media?.alignY ?? 0);
    if (isThemeGif(iconKey)) {
      if (!animate) {
        return _CroppedIcon(
          size: size,
          zoom: media?.zoom ?? 1,
          alignment: alignment,
          child: Image.file(
            File('${media!.path}.preview.png'),
            fit: BoxFit.cover,
            alignment: alignment,
            errorBuilder: (_, _, _) => fallback,
          ),
        );
      }
      if (continuous) {
        return _CroppedIcon(
          size: size,
          zoom: media?.zoom ?? 1,
          alignment: alignment,
          child: Image.file(
            File(media!.path),
            key: ValueKey(iconKey),
            fit: BoxFit.cover,
            alignment: alignment,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => fallback,
          ),
        );
      }
      return _TimedGif(
        key: ValueKey(media!.path),
        path: media.path,
        size: size,
        seconds: previewSeconds,
        zoom: media.zoom,
        alignment: alignment,
        fallback: fallback,
      );
    }
    if (isThemeVideo(iconKey)) {
      if (!animate) return fallback;
      return _TimedVideo(
        key: ValueKey(media!.path),
        path: media.path,
        size: size,
        seconds: continuous ? null : previewSeconds,
        zoom: media.zoom,
        alignment: alignment,
        fallback: fallback,
      );
    }
    return SizedBox.square(
      dimension: size,
      child: Center(
        child: storedIconWidget(iconKey ?? '', size: size, fallback: fallback),
      ),
    );
  }
}

class _CroppedIcon extends StatelessWidget {
  const _CroppedIcon({
    required this.size,
    required this.zoom,
    required this.alignment,
    required this.child,
  });

  final double size;
  final double zoom;
  final Alignment alignment;
  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: ClipOval(
      child: Transform.scale(scale: zoom, alignment: alignment, child: child),
    ),
  );
}

class _TimedGif extends StatefulWidget {
  const _TimedGif({
    super.key,
    required this.path,
    required this.size,
    required this.seconds,
    required this.zoom,
    required this.alignment,
    required this.fallback,
  });

  final String path;
  final double size;
  final int seconds;
  final double zoom;
  final Alignment alignment;
  final Widget fallback;

  @override
  State<_TimedGif> createState() => _TimedGifState();
}

class _TimedGifState extends State<_TimedGif> {
  Timer? _timer;
  bool _playing = true;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(_TimedGif oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path || oldWidget.seconds != widget.seconds) {
      _start();
    }
  }

  void _start() {
    _timer?.cancel();
    _playing = true;
    _generation++;
    _timer = Timer(Duration(seconds: widget.seconds), () {
      if (mounted) setState(() => _playing = false);
    });
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final preview = File('${widget.path}.preview.png');
    final file = !_playing && preview.existsSync()
        ? preview
        : File(widget.path);
    return _CroppedIcon(
      size: widget.size,
      zoom: widget.zoom,
      alignment: widget.alignment,
      child: GestureDetector(
        onTap: _start,
        child: Image.file(
          file,
          key: ValueKey('${file.path}:$_generation'),
          fit: BoxFit.cover,
          alignment: widget.alignment,
          gaplessPlayback: false,
          errorBuilder: (_, _, _) => widget.fallback,
        ),
      ),
    );
  }
}

class _TimedVideo extends StatefulWidget {
  const _TimedVideo({
    super.key,
    required this.path,
    required this.size,
    required this.seconds,
    required this.zoom,
    required this.alignment,
    required this.fallback,
  });

  final String path;
  final double size;
  final int? seconds;
  final double zoom;
  final Alignment alignment;
  final Widget fallback;

  @override
  State<_TimedVideo> createState() => _TimedVideoState();
}

class _TimedVideoState extends State<_TimedVideo> {
  late final VideoPlayerController _controller;
  Timer? _timer;
  bool _failed = false;
  bool _tickerEnabled = true;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(
      File(widget.path),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _controller.initialize();
      await _controller.setVolume(0);
      await _controller.setLooping(true);
      if (_tickerEnabled) await _play();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final enabled = TickerMode.valuesOf(context).enabled;
    if (_tickerEnabled == enabled) return;
    _tickerEnabled = enabled;
    if (!_controller.value.isInitialized) return;
    (enabled ? _play() : _controller.pause()).ignore();
  }

  Future<void> _play() async {
    _timer?.cancel();
    await _controller.seekTo(Duration.zero);
    await _controller.play();
    if (widget.seconds case final seconds?) {
      _timer = Timer(
        Duration(seconds: seconds),
        () => _controller.pause().ignore(),
      );
    }
  }

  @override
  void didUpdateWidget(_TimedVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seconds != widget.seconds &&
        _controller.value.isInitialized) {
      _play();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return widget.fallback;
    if (!_controller.value.isInitialized) {
      return SizedBox.square(
        dimension: widget.size,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    final videoSize = _controller.value.size;
    return _CroppedIcon(
      size: widget.size,
      zoom: widget.zoom,
      alignment: widget.alignment,
      child: GestureDetector(
        onTap: _play,
        child: FittedBox(
          fit: BoxFit.cover,
          alignment: widget.alignment,
          child: SizedBox(
            width: videoSize.width,
            height: videoSize.height,
            child: VideoPlayer(_controller),
          ),
        ),
      ),
    );
  }
}
