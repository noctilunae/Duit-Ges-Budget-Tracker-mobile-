import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../widgets/theme_artwork.dart';

/// Layar kunci PIN — nongol duluan tiap app dibuka kalau PIN aktif.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String _input = '';
  bool _wrong = false;

  void _press(String digit) {
    if (_input.length >= 4) return;
    setState(() {
      _input += digit;
      _wrong = false;
    });
    if (_input.length == 4) {
      final ok = context.read<SettingsProvider>().verifyPin(_input);
      if (!ok) {
        setState(() {
          _input = '';
          _wrong = true;
        });
      }
    }
  }

  void _backspace() {
    if (_input.isEmpty) return;
    setState(() => _input = _input.substring(0, _input.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final preset = settings.preset;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [settings.accentBright, settings.accentDeep],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(),
              ThemeArtwork(
                preset: preset,
                tile: 0,
                size: 96,
                fallback: Icon(preset.icon, size: 56, color: Colors.white),
              ),
              const SizedBox(height: 12),
              const Text(
                'Duit Ges',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _wrong ? 'PIN salah, coba lagi' : 'Masukin PIN kamu',
                style: TextStyle(
                  color: _wrong ? const Color(0xFFFFCDD2) : Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              // 4 titik indikator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < 4; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 16,
                      height: 16,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < _input.length
                            ? Colors.white
                            : Colors.white24,
                      ),
                    ),
                ],
              ),
              const Spacer(),
              // Numpad
              for (final row in const [
                ['1', '2', '3'],
                ['4', '5', '6'],
                ['7', '8', '9'],
                ['', '0', '<'],
              ])
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final key in row)
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: key.isEmpty
                            ? const SizedBox(width: 72, height: 72)
                            : InkWell(
                                onTap: key == '<'
                                    ? _backspace
                                    : () => _press(key),
                                borderRadius: BorderRadius.circular(36),
                                child: Container(
                                  width: 72,
                                  height: 72,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white12,
                                  ),
                                  child: Center(
                                    child: key == '<'
                                        ? const Icon(
                                            Icons.backspace_outlined,
                                            color: Colors.white,
                                            size: 24,
                                          )
                                        : Text(
                                            key,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 26,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                      ),
                  ],
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
