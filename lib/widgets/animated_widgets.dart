import 'package:flutter/material.dart';

import '../utils/formatters.dart';

/// Route yang muncul slide dari bawah + fade, kayak modal.
Route<T> slideUpRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 350),
    reverseTransitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (_, _, _) => page,
    transitionsBuilder: (_, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.1),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Teks Rupiah yang "ngitung" dari nilai lama ke nilai baru.
class AnimatedRupiah extends StatelessWidget {
  final double value;
  final TextStyle? style;
  final String prefix;

  const AnimatedRupiah({
    super.key,
    required this.value,
    this.style,
    this.prefix = '',
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, _) => Text(
        '$prefix${rupiah(animatedValue)}',
        overflow: TextOverflow.ellipsis,
        style: style,
      ),
    );
  }
}

/// Muncul fade + naik dari bawah, delay-nya berurutan sesuai [index]
/// biar list keliatan "ngalir" satu-satu.
class StaggeredItem extends StatelessWidget {
  final int index;
  final Widget child;

  const StaggeredItem({super.key, required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    final delayMs = index.clamp(0, 12) * 50;
    final totalMs = 350 + delayMs;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: totalMs),
      curve: Interval(delayMs / totalMs, 1, curve: Curves.easeOutCubic),
      child: child,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 20 * (1 - t)),
          child: child,
        ),
      ),
    );
  }
}

/// Kayak IndexedStack (semua tab tetap hidup, state-nya ga ke-reset),
/// tapi pindah tab-nya pake crossfade halus.
class FadeIndexedStack extends StatelessWidget {
  final int index;
  final List<Widget> children;

  const FadeIndexedStack({
    super.key,
    required this.index,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        for (var i = 0; i < children.length; i++)
          IgnorePointer(
            ignoring: i != index,
            child: AnimatedSlide(
              offset: i == index ? Offset.zero : const Offset(0, 0.015),
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              child: AnimatedOpacity(
                opacity: i == index ? 1 : 0,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                // TickerMode: animasi di tab yang lagi ga keliatan
                // dimatiin total biar ga makan frame budget.
                // RepaintBoundary: tab lain ga ikut ke-repaint.
                child: TickerMode(
                  enabled: i == index,
                  child: RepaintBoundary(child: children[i]),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
