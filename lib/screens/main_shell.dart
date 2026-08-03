import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../providers/transaction_provider.dart';
import '../services/auto_backup_service.dart';
import '../services/reminder_service.dart';
import '../widgets/animated_widgets.dart';
import '../widgets/theme_artwork.dart';
import '../widgets/theme_icon_view.dart';
import '../widgets/custom_template_view.dart';
import 'add_transaction_screen.dart';
import 'budget_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int _index = 0;

  // Toggle global JJK 2: footer dan FAB ganti bareng antara diam dan muter.
  bool _footerGifsPlaying = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Backup mingguan jalan di belakang layar kalau udah waktunya
    AutoBackupService.runIfDue();
    // Pasang ulang jadwal reminder (idempoten) — jaga-jaga jadwalnya
    // ilang karena force stop / update app.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = context.read<SettingsProvider>();
      if (settings.reminderEnabled) {
        ReminderService.scheduleDaily(settings.reminderTime);
      }
      if (settings.externalBackupReminderEnabled) {
        ReminderService.scheduleWeeklyBackup();
      }
    });
  }

  void _selectTab(int index) {
    setState(() => _index = index);
    context.read<SettingsProvider>().setActiveTab(index);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Balik dari background: reload biar transaksi berulang yang jatuh
    // tempo selama app "tidur" langsung tercatat.
    if (state == AppLifecycleState.resumed) {
      context.read<TransactionProvider>().load(applyRecurrings: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isLight = Theme.of(context).brightness == Brightness.light;
    final pageBackground = isLight
        ? settings.lightBackground
        : settings.darkBackground;
    final isFrierenRial = settings.preset.id == 'frieren_rial';
    final backgroundAsset = isFrierenRial
        ? settings.frierenRialBackground.asset
        : null;
    final customBackground = settings.customBackground;
    final footerColor = pageBackground.last;
    final idleFabAsset = switch (settings.preset.id) {
      'jjk2' => 'assets/theme/jjk2/add_transaction_idle.gif',
      'call_duck' => 'assets/theme/call_duck/add_transaction_static.png',
      _ => null,
    };
    final fabAsset = settings.addTransactionArtwork != null
        ? null
        : idleFabAsset != null && !_footerGifsPlaying
        ? idleFabAsset
        : settings.preset.fabGif;
    final fabImageSize = switch (settings.preset.id) {
      'frieren' => 50.0,
      'spongebob' => 60.0,
      _ => 54.0,
    };
    return Scaffold(
      backgroundColor: footerColor,
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: customBackground != null || backgroundAsset != null
              ? Colors.black
              : null,
          gradient: customBackground == null && backgroundAsset == null
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: pageBackground,
                )
              : null,
          image: customBackground != null || backgroundAsset == null
              ? null
              : DecorationImage(
                  image: AssetImage(backgroundAsset),
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                ),
        ),
        child: Stack(
          children: [
            if (customBackground != null)
              Positioned.fill(
                child: CustomTemplateView(template: customBackground),
              ),
            if (backgroundAsset != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.55, 1],
                        colors: [
                          Colors.transparent,
                          settings.frierenRialBackground.cardTone.withValues(
                            alpha: 0.42,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            FadeIndexedStack(
              index: _index,
              children: const [
                HomeScreen(),
                BudgetScreen(),
                StatsScreen(),
                SettingsScreen(),
              ],
            ),
          ],
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [settings.accentBright, settings.accent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: settings.accent.withValues(alpha: 0.45),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          clipBehavior: Clip.antiAlias,
          elevation: 0,
          highlightElevation: 0,
          onPressed: () {
            Navigator.push(context, slideUpRoute(const AddTransactionScreen()));
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (fabAsset != null)
                Transform.translate(
                  offset: settings.preset.fabGifOffset,
                  child: RepaintBoundary(
                    child: Image.asset(
                      fabAsset,
                      width: fabImageSize,
                      height: fabImageSize,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                    ),
                  ),
                )
              else
                const ThemeArtwork(tile: 0, size: 48, addTransaction: true),
              Positioned(
                right: isFrierenRial ? 5 : 1,
                top: isFrierenRial ? 5 : null,
                bottom: isFrierenRial ? null : 1,
                child: Transform.translate(
                  offset: settings.fabPlusOffset,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: settings.accent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add, size: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: Stack(
        clipBehavior: Clip.none,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: BottomAppBar(
              color: footerColor,
              shape: const CircularNotchedRectangle(),
              notchMargin: 6,
              clipBehavior: Clip.antiAlias,
              elevation: 0,
              child: Row(
                children: [
                  _NavItem(
                    navIndex: 0,
                    icon: Icons.receipt_long,
                    artworkTile: settings.preset.id == 'frieren'
                        ? 2
                        : settings.preset.id == 'jjk'
                        ? 10
                        : 6,
                    gifAsset: settings.preset.footerTransaksiGif,
                    label: 'Transaksi',
                    selected: _index == 0,
                    footerGifsPlaying: _footerGifsPlaying,
                    onTap: () => _selectTab(0),
                  ),
                  _NavItem(
                    navIndex: 1,
                    icon: Icons.savings_outlined,
                    artworkTile:
                        const {
                          'frieren',
                          'jjk',
                          'spongebob',
                          'jjk2',
                        }.contains(settings.preset.id)
                        ? 5
                        : 7,
                    label: 'Budget',
                    selected: _index == 1,
                    footerGifsPlaying: _footerGifsPlaying,
                    onTap: () => _selectTab(1),
                  ),
                  const SizedBox(width: 72),
                  _NavItem(
                    navIndex: 2,
                    icon: Icons.pie_chart,
                    artworkTile:
                        const {
                          'frieren',
                          'jjk',
                          'spongebob',
                          'jjk2',
                        }.contains(settings.preset.id)
                        ? 9
                        : 8,
                    label: 'Statistik',
                    selected: _index == 2,
                    footerGifsPlaying: _footerGifsPlaying,
                    onTap: () => _selectTab(2),
                  ),
                  _NavItem(
                    navIndex: 3,
                    icon: Icons.tune,
                    artworkTile: settings.preset.id == 'frieren'
                        ? 12
                        : settings.preset.id == 'jjk'
                        ? 13
                        : settings.preset.id == 'spongebob'
                        ? 14
                        : settings.preset.id == 'jjk2'
                        ? 15
                        : 3,
                    label: 'Setelan',
                    selected: _index == 3,
                    footerGifsPlaying: _footerGifsPlaying,
                    onTap: () => _selectTab(3),
                  ),
                ],
              ),
            ),
          ),
          if (settings.preset.footerGifManualControl ||
              settings.hasAnimatedCustomFooter)
            Positioned(
              top: 34,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: footerColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: IconButton(
                    tooltip: _footerGifsPlaying
                        ? 'Hentikan animasi ikon'
                        : 'Putar animasi ikon',
                    onPressed: () => setState(
                      () => _footerGifsPlaying = !_footerGifsPlaying,
                    ),
                    padding: EdgeInsets.zero,
                    iconSize: 16,
                    icon: Icon(
                      _footerGifsPlaying ? Icons.stop : Icons.play_arrow,
                      color: settings.accent,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final int navIndex;
  final IconData icon;
  final int artworkTile;
  final String? gifAsset;
  final String label;
  final bool selected;
  final bool footerGifsPlaying;
  final VoidCallback onTap;

  const _NavItem({
    required this.navIndex,
    required this.icon,
    required this.artworkTile,
    this.gifAsset,
    required this.label,
    required this.selected,
    this.footerGifsPlaying = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;
    final color = selected ? theme.primary : theme.onSurfaceVariant;
    final settings = context.watch<SettingsProvider>();
    final customFooterKey = settings.footerArtwork(navIndex);
    // Icon GIF dikasih ukuran lebih gede dari PNG statis (26px) — detail
    // animasinya baru kebaca jelas kalau agak besar dikit, 26px kekecilan.
    final resolvedGif = customFooterKey == null
        ? gifAsset ?? settings.preset.tileGifs[artworkTile]
        : null;
    final isAnimated = customFooterKey != null || resolvedGif != null;
    final iconSize = isAnimated ? 36.0 : 26.0;
    // Tema footerGifManualControl: PNG statis sampai tombol play di bawah
    // FAB dipencet, lalu semua footer beralih ke GIF.
    final manualControl = settings.preset.footerGifManualControl;
    final displayPath =
        resolvedGif != null && manualControl && !footerGifsPlaying
        ? resolvedGif.replaceFirst('.gif', '_static.png')
        : resolvedGif;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        child: Center(
          child: AnimatedOpacity(
            opacity: selected ? 1 : 0.68,
            duration: const Duration(milliseconds: 200),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  transform: Matrix4.diagonal3Values(
                    selected ? 1.06 : 1,
                    selected ? 1.06 : 1,
                    1,
                  ),
                  transformAlignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? theme.primary.withValues(alpha: 0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: customFooterKey != null
                      ? RepaintBoundary(
                          child: ThemeIconView(
                            iconKey: customFooterKey,
                            size: iconSize,
                            previewSeconds: 3,
                            animate: footerGifsPlaying,
                            continuous: true,
                            fallback: Icon(icon, color: color, size: 22),
                          ),
                        )
                      : displayPath != null
                      ? RepaintBoundary(
                          child: ClipRect(
                            child: Transform.scale(
                              // Crop tipis border GIF JJK 2 yang punya garis
                              // transparan/putih di tepi beberapa frame.
                              scale: manualControl && footerGifsPlaying
                                  ? 1.08
                                  : 1,
                              child: Image.asset(
                                displayPath,
                                width: iconSize,
                                height: iconSize,
                                fit: BoxFit.contain,
                                gaplessPlayback: true,
                              ),
                            ),
                          ),
                        )
                      : ThemeArtwork(
                          tile: artworkTile,
                          size: iconSize,
                          ignoreCustomization: true,
                          fallback: Icon(icon, color: color, size: 22),
                        ),
                ),
                const SizedBox(height: 2),
                // FittedBox ngecilin teks otomatis kalau slotnya sempit,
                // jadi ga bakal overflow/bocor di layar kecil.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 10,
                      color: color,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
