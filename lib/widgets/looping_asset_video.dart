import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class LoopingAssetVideo extends StatefulWidget {
  final String? asset;
  final String? filePath;
  final int quarterTurns;
  final Alignment alignment;
  final double scale;

  const LoopingAssetVideo({
    super.key,
    this.asset,
    this.filePath,
    this.quarterTurns = 0,
    this.alignment = Alignment.center,
    this.scale = 1,
  }) : assert((asset == null) != (filePath == null));

  @override
  State<LoopingAssetVideo> createState() => _LoopingAssetVideoState();
}

class _LoopingAssetVideoState extends State<LoopingAssetVideo> {
  late final VideoPlayerController _controller;
  bool _tickerEnabled = true;

  @override
  void initState() {
    super.initState();
    final options = VideoPlayerOptions(mixWithOthers: true);
    _controller = widget.filePath == null
        ? VideoPlayerController.asset(
            widget.asset!,
            videoPlayerOptions: options,
          )
        : VideoPlayerController.file(
            File(widget.filePath!),
            videoPlayerOptions: options,
          );
    _start();
  }

  Future<void> _start() async {
    try {
      await _controller.initialize();
      // Video artwork ini murni dekorasi visual — di-mute walau file
      // aslinya punya audio track. Dipanggil sebelum play() biar ga
      // sempet kedengeran walau cuma sepersekian detik.
      await _controller.setVolume(0);
      await _controller.setLooping(true);
      if (_tickerEnabled) await _controller.play();
      if (mounted) setState(() {});
    } catch (_) {
      // Tetap tampilkan warna dasar kartu kalau codec video gagal.
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final enabled = TickerMode.valuesOf(context).enabled;
    if (_tickerEnabled == enabled) return;
    _tickerEnabled = enabled;
    if (!_controller.value.isInitialized) return;
    (enabled ? _controller.play() : _controller.pause()).ignore();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) return const SizedBox.expand();
    final size = _controller.value.size;
    return SizedBox.expand(
      child: ClipRect(
        child: Transform.scale(
          scale: widget.scale,
          alignment: widget.alignment,
          child: FittedBox(
            fit: BoxFit.cover,
            alignment: widget.alignment,
            child: RotatedBox(
              quarterTurns: widget.quarterTurns,
              child: SizedBox(
                width: size.width,
                height: size.height,
                child: VideoPlayer(_controller),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
