import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/category.dart';
import '../models/transaction.dart';
import '../providers/settings_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/wallet_provider.dart';
import '../utils/app_style.dart';
import '../utils/formatters.dart';
import '../widgets/animated_widgets.dart';
import '../widgets/looping_asset_video.dart';
import '../widgets/custom_template_view.dart';
import '../widgets/month_selector.dart';
import '../widgets/page_header.dart';
import '../widgets/transaction_detail_sheet.dart';
import '../widgets/transfer_sheet.dart';
import '../widgets/theme_artwork.dart';
import 'calendar_screen.dart';
import 'search_screen.dart';
import 'wallets_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final grouped = provider.groupedByDay;
    final days = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return SafeArea(
      child: Column(
        children: [
          PageHeader(
            title: 'Duit Ges',
            artworkTile: 1,
            headerIndex: 0,
            action: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.calendar_month_outlined),
                  tooltip: 'Kalender',
                  onPressed: () {
                    Navigator.push(
                      context,
                      slideUpRoute(const CalendarScreen()),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.search),
                  tooltip: 'Cari transaksi',
                  onPressed: () {
                    Navigator.push(context, slideUpRoute(const SearchScreen()));
                  },
                ),
              ],
            ),
          ),
          const MonthSelector(),
          Expanded(
            child: provider.loading
                ? const Center(child: CircularProgressIndicator())
                // ListView.builder = lazy: item baru dibangun pas mau
                // keliatan di layar, jadi tetep enteng walau datanya banyak.
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                    itemCount: 3 + (days.isEmpty ? 1 : days.length),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return StaggeredItem(
                          index: 0,
                          child: _BalanceCard(provider: provider),
                        );
                      }
                      if (index == 1) return const _WalletStrip();
                      if (index == 2) return const SizedBox(height: 4);
                      if (days.isEmpty) {
                        return StaggeredItem(
                          key: ValueKey('empty-${provider.month}'),
                          index: 1,
                          child: const _EmptyState(),
                        );
                      }
                      final day = days[index - 3];
                      // RepaintBoundary: grup hari lain ga ikut ke-repaint
                      // pas satu grup animasi expand/collapse.
                      return RepaintBoundary(
                        child: StaggeredItem(
                          key: ValueKey('day-${provider.month}-$day'),
                          index: index - 2,
                          child: _DayGroup(
                            day: day,
                            transactions: grouped[day]!,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Kumpulan warna satu template kartu saldo.
class _CardPalette {
  final BoxDecoration decoration;
  final Color amount;
  final Color label;
  final Color chipBg;
  final Color chipIcon;
  final List<Shadow>? amountGlow;

  const _CardPalette({
    required this.decoration,
    required this.amount,
    required this.label,
    required this.chipBg,
    required this.chipIcon,
    this.amountGlow,
  });
}

class _BalanceCard extends StatelessWidget {
  final TransactionProvider provider;

  const _BalanceCard({required this.provider});

  _CardPalette _palette(BuildContext context, SettingsProvider settings) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(24);
    if (settings.customCard != null) {
      return _CardPalette(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: radius,
          boxShadow: cardShadow(context),
        ),
        amount: Colors.white,
        label: Colors.white70,
        chipBg: Colors.black38,
        chipIcon: Colors.white,
        amountGlow: const [Shadow(color: Colors.black, blurRadius: 10)],
      );
    }
    switch (settings.cardStyle) {
      case CardStyle.gradient:
        return _CardPalette(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: settings.preset.id == 'jjk2'
                  ? const [Color(0xFF4A8FBD), Color(0xFF1B4667)]
                  : [settings.accentBright, settings.accentDeep],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: settings.accent.withValues(
                  alpha: settings.preset.id == 'jjk2' ? 0.22 : 0.35,
                ),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          amount: Colors.white,
          label: Colors.white70,
          chipBg: Colors.white24,
          chipIcon: Colors.white,
        );
      case CardStyle.neon:
        return _CardPalette(
          decoration: BoxDecoration(
            color: const Color(0xFF0A0F1E),
            borderRadius: radius,
            border: Border.all(
              color: settings.accent.withValues(alpha: 0.8),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: settings.accent.withValues(alpha: 0.4),
                blurRadius: 28,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          amount: settings.accentBright,
          label: Colors.white60,
          chipBg: settings.accent.withValues(alpha: 0.15),
          chipIcon: settings.accentBright,
          amountGlow: [
            Shadow(
              color: settings.accent.withValues(alpha: 0.8),
              blurRadius: 18,
            ),
          ],
        );
      case CardStyle.glass:
        return _CardPalette(
          decoration: BoxDecoration(
            color: cardColor(context).withValues(alpha: 0.55),
            borderRadius: radius,
            border: Border.all(color: scheme.onSurface.withValues(alpha: 0.12)),
            boxShadow: cardShadow(context),
          ),
          amount: scheme.onSurface,
          label: scheme.onSurfaceVariant,
          chipBg: settings.accent.withValues(alpha: 0.12),
          chipIcon: settings.accent,
        );
      case CardStyle.minimal:
        return _CardPalette(
          decoration: BoxDecoration(
            color: cardColor(context),
            borderRadius: radius,
            boxShadow: cardShadow(context),
          ),
          amount: scheme.onSurface,
          label: scheme.onSurfaceVariant,
          chipBg: settings.accent.withValues(alpha: 0.1),
          chipIcon: settings.accent,
        );
      case CardStyle.jjkVideo1:
      case CardStyle.jjkVideo2:
      case CardStyle.frierenRialVideo135:
      case CardStyle.frierenRialVideo136:
      case CardStyle.frierenRialVideo137:
      case CardStyle.frierenRialVideo138:
        return _CardPalette(
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: radius,
            boxShadow: cardShadow(context),
          ),
          amount: Colors.white,
          label: Colors.white70,
          chipBg: Colors.black38,
          chipIcon: Colors.white,
          amountGlow: const [Shadow(color: Colors.black, blurRadius: 10)],
        );
      case CardStyle.callDuck:
        return _CardPalette(
          decoration: BoxDecoration(
            image: const DecorationImage(
              image: AssetImage('assets/theme/call_duck/kartu_saldo.png'),
              fit: BoxFit.cover,
            ),
            borderRadius: radius,
            boxShadow: cardShadow(context),
          ),
          amount: const Color(0xFF7A4318),
          label: const Color(0xFF9C6B36),
          chipBg: Colors.white.withValues(alpha: 0.55),
          chipIcon: const Color(0xFF7A4318),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final palette = _palette(context, settings);
    final isMinimal = settings.cardStyle == CardStyle.minimal;
    final videoAsset = switch (settings.cardStyle) {
      CardStyle.jjkVideo1 => 'assets/theme/jjk2/card_saldo_1.mp4',
      CardStyle.jjkVideo2 => 'assets/theme/jjk2/card_saldo_2.mp4',
      CardStyle.frierenRialVideo135 =>
        'assets/theme/frieren_rial/card_saldo_135.mp4',
      CardStyle.frierenRialVideo136 =>
        'assets/theme/frieren_rial/card_saldo_136.mp4',
      CardStyle.frierenRialVideo137 =>
        'assets/theme/frieren_rial/card_saldo_137.mp4',
      CardStyle.frierenRialVideo138 =>
        'assets/theme/frieren_rial/card_saldo_138.mp4',
      _ => null,
    };

    return Container(
      width: double.infinity,
      decoration: palette.decoration,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            if (settings.customCard != null) ...[
              Positioned.fill(
                child: CustomTemplateView(template: settings.customCard!),
              ),
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0x66000000), Color(0x22000000)],
                    ),
                  ),
                ),
              ),
            ],
            if (videoAsset != null) ...[
              Positioned.fill(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: LoopingAssetVideo(
                    key: ValueKey(videoAsset),
                    asset: videoAsset,
                    quarterTurns: settings.preset.id == 'frieren_rial' ? 0 : 3,
                  ),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors:
                          settings.cardStyle == CardStyle.frierenRialVideo137
                          ? const [Color(0x80000000), Color(0x30000000)]
                          : const [Color(0x66000000), Color(0x14000000)],
                    ),
                  ),
                ),
              ),
            ],
            if (settings.cardStyle == CardStyle.callDuck)
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      stops: [0, 0.58, 1],
                      colors: [
                        Color(0xE6FFF8EC),
                        Color(0x99FFF8EC),
                        Color(0x33FFF8EC),
                      ],
                    ),
                  ),
                ),
              ),
            // Di-center vertikal + margin 16 biar ga kepotong
            // lengkungan sudut kartu (radius 24).
            if ((settings.cardMascotArtwork != null ||
                    settings.artwork != null ||
                    settings.preset.tileGifs.containsKey(0)) &&
                (settings.hasCustomCardMascot ||
                    (settings.customCard == null &&
                        settings.preset.id != 'jjk2' &&
                        settings.cardStyle != CardStyle.callDuck)))
              Positioned(
                right: 16,
                top: 0,
                bottom: 0,
                // RepaintBoundary: mascot GIF yang muter ga maksa seluruh
                // kartu (angka saldo dkk) ikut repaint tiap frame.
                child: Center(
                  child: RepaintBoundary(
                    child: Opacity(
                      // Mascot GIF (foto-style, penuh warna) butuh opacity
                      // lebih tinggi dari watermark PNG line-art biasa —
                      // di 0.28 dia keliatan pudar/samar gara-gara detail
                      // warnanya kebanyakan buat opacity serendah itu.
                      opacity: settings.hasCustomCardMascot
                          ? 0.65
                          : settings.preset.tileGifs.containsKey(0)
                          ? 0.45
                          : 0.28,
                      child: ThemeArtwork(
                        tile: settings.preset.id == 'jjk' ? 7 : 0,
                        cardMascot: true,
                        size: settings.hasCustomCardMascot
                            ? 96
                            : settings.preset.tileGifs.containsKey(0)
                            ? 120
                            : const {
                                'jjk',
                                'frieren',
                              }.contains(settings.preset.id)
                            ? 116
                            : 84,
                      ),
                    ),
                  ),
                ),
              ),
            // Aksen garis kiri khusus template minimal.
            if (isMinimal)
              Positioned(
                left: 0,
                top: 20,
                bottom: 20,
                child: Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: settings.accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Saldo Bulan Ini',
                        style: TextStyle(color: palette.label, fontSize: 14),
                      ),
                      const Spacer(),
                      InkWell(
                        onTap: () =>
                            settings.setHideBalance(!settings.hideBalance),
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          // Tema bermaskot pakai tapak kaki (kucing/bebek),
                          // redup dikit pas saldo lagi disembunyiin.
                          child:
                              const {
                                'frieren',
                                'jjk',
                                'jjk2',
                                'anya',
                                'spongebob',
                                'call_duck',
                                'frieren_rial',
                              }.contains(settings.preset.id)
                              ? Opacity(
                                  opacity: settings.hideBalance ? 0.45 : 1,
                                  child: Image.asset(
                                    'assets/theme/${settings.preset.id}/'
                                    'visibility.${settings.preset.id == 'jjk2' ? 'gif' : 'png'}',
                                    width: 24,
                                    height: 24,
                                    fit: BoxFit.contain,
                                  ),
                                )
                              : settings.preset.pawAsset != null
                              ? Opacity(
                                  opacity: settings.hideBalance ? 0.45 : 1,
                                  child: Image.asset(
                                    settings.preset.pawAsset!,
                                    width: 18,
                                    height: 18,
                                    color: palette.label,
                                  ),
                                )
                              : Icon(
                                  settings.hideBalance
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 18,
                                  color: palette.label,
                                ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  settings.hideBalance
                      ? Text(
                          'Rp ••••••',
                          style: TextStyle(
                            color: palette.amount,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            shadows: palette.amountGlow,
                          ),
                        )
                      : AnimatedRupiah(
                          value: provider.balance,
                          style: TextStyle(
                            color: palette.amount,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            shadows: palette.amountGlow,
                          ),
                        ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _SummaryItem(
                        label: 'Pemasukan',
                        amount: provider.totalIncome,
                        icon: Icons.arrow_downward,
                        palette: palette,
                        hide: settings.hideBalance,
                      ),
                      const SizedBox(width: 24),
                      _SummaryItem(
                        label: 'Pengeluaran',
                        amount: provider.totalExpense,
                        icon: Icons.arrow_upward,
                        palette: palette,
                        hide: settings.hideBalance,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final double amount;
  final IconData icon;
  final _CardPalette palette;
  final bool hide;

  const _SummaryItem({
    required this.label,
    required this.amount,
    required this.icon,
    required this.palette,
    this.hide = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: palette.chipBg,
            child: Icon(icon, size: 16, color: palette.chipIcon),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: palette.label, fontSize: 12),
                ),
                hide
                    ? Text(
                        'Rp ••••',
                        style: TextStyle(
                          color: palette.amount,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    : AnimatedRupiah(
                        value: amount,
                        style: TextStyle(
                          color: palette.amount,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Deretan kartu dompet horizontal: tap buat filter transaksi per dompet,
/// plus tombol transfer & kelola.
class _WalletStrip extends StatelessWidget {
  const _WalletStrip();

  @override
  Widget build(BuildContext context) {
    final walletProvider = context.watch<WalletProvider>();
    final txProvider = context.watch<TransactionProvider>();
    final settings = context.watch<SettingsProvider>();
    final filter = txProvider.walletFilter;
    final accent = Theme.of(context).colorScheme.primary;
    final isFrieren = const {
      'frieren',
      'frieren_rial',
    }.contains(settings.preset.id);
    final collapsed = isFrieren && settings.hideWallets;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(
                      'Dompet',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (isFrieren)
                      IconButton(
                        tooltip: collapsed
                            ? 'Tampilkan dompet'
                            : 'Sembunyikan dompet',
                        onPressed: () => settings.setHideWallets(!collapsed),
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints.tightFor(
                          width: 32,
                          height: 32,
                        ),
                        padding: EdgeInsets.zero,
                        icon: AnimatedRotation(
                          turns: collapsed ? 0.5 : 0,
                          duration: const Duration(milliseconds: 250),
                          child: Icon(
                            Icons.keyboard_arrow_up,
                            size: 20,
                            color: accent,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              InkWell(
                onTap: () => showTransferSheet(context),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.swap_horiz, size: 16, color: accent),
                      const SizedBox(width: 4),
                      Text(
                        'Transfer',
                        style: TextStyle(fontSize: 12, color: accent),
                      ),
                    ],
                  ),
                ),
              ),
              InkWell(
                onTap: () {
                  Navigator.push(context, slideUpRoute(const WalletsScreen()));
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Text(
                    'Kelola',
                    style: TextStyle(fontSize: 12, color: accent),
                  ),
                ),
              ),
            ],
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (child, animation) => SizeTransition(
            sizeFactor: animation,
            alignment: Alignment.topCenter,
            child: FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(-0.04, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
          ),
          child: collapsed
              ? const SizedBox.shrink(key: ValueKey('wallets-hidden'))
              : SizedBox(
                  key: const ValueKey('wallets-visible'),
                  height: 72,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _WalletCard(
                        label: 'Semua',
                        amount: walletProvider.totalBalance,
                        icon: const Icon(
                          Icons.wallet,
                          color: Colors.white,
                          size: 17,
                        ),
                        color: accent,
                        selected: filter == null,
                        onTap: () => txProvider.setWalletFilter(null),
                      ),
                      for (final wallet in walletProvider.wallets)
                        _WalletCard(
                          label: wallet.name,
                          amount: walletProvider.balanceOf(wallet),
                          icon: wallet.iconWidget(
                            color: Colors.white,
                            size: 17,
                          ),
                          color: wallet.color,
                          selected: filter == wallet.id,
                          onTap: () => txProvider.setWalletFilter(
                            filter == wallet.id ? null : wallet.id,
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _WalletCard extends StatelessWidget {
  final String label;
  final double amount;
  final Widget icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _WalletCard({
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        margin: const EdgeInsets.only(right: 8, bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: cardColor(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? color : Colors.transparent,
            width: 2,
          ),
          boxShadow: cardShadow(context),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: categoryGradient(color),
              ),
              child: Center(child: icon),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  context.select<SettingsProvider, bool>((s) => s.hideBalance)
                      ? 'Rp ••••'
                      : rupiah(amount),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Satu grup transaksi per hari: header bisa di-tap buat
/// collapse/expand (dropdown) dengan animasi.
class _DayGroup extends StatefulWidget {
  final DateTime day;
  final List<TransactionModel> transactions;

  const _DayGroup({required this.day, required this.transactions});

  @override
  State<_DayGroup> createState() => _DayGroupState();
}

class _DayGroupState extends State<_DayGroup> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final net = widget.transactions.fold<double>(
      0,
      (sum, t) => t.type == TxType.income ? sum + t.amount : sum - t.amount,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    labelHari(widget.day),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Text(
                  rupiah(net),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: net >= 0 ? incomeColor : expenseColor,
                  ),
                ),
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: _expanded ? 0 : -0.25,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  child: Icon(
                    Icons.expand_more,
                    size: 18,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        ClipRect(
          child: AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Column(
                    children: [
                      for (final tx in widget.transactions)
                        _TransactionTile(transaction: tx),
                    ],
                  )
                : const SizedBox(width: double.infinity),
          ),
        ),
      ],
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final TransactionModel transaction;

  const _TransactionTile({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final category = transaction.category;
    final isIncome = transaction.type == TxType.income;
    return Dismissible(
      key: ValueKey(transaction.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: expenseColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) => confirmDeleteTransaction(context, transaction),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: cardColor(context),
          borderRadius: BorderRadius.circular(16),
          boxShadow: cardShadow(context),
        ),
        child: ListTile(
          onTap: () => showTransactionDetailSheet(context, transaction),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: categoryGradient(category.color),
              boxShadow: [
                BoxShadow(
                  color: category.color.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: category.iconWidget(color: Colors.white, size: 22),
            ),
          ),
          title: Text(
            category.name,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: transaction.note.isEmpty
              ? null
              : Text(
                  transaction.note,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
          trailing: Text(
            '${isIncome ? '+' : '-'}${rupiah(transaction.amount)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isIncome ? incomeColor : expenseColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final preset = context.watch<SettingsProvider>().preset;
    return Padding(
      padding: const EdgeInsets.only(top: 64),
      child: Column(
        children: [
          ThemeArtwork(
            tile: 1,
            size: 104,
            headerIndex: 0,
            fallback: Icon(
              preset.emptyIcon ?? Icons.account_balance_wallet_outlined,
              size: 64,
              color: muted.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            preset.emptyText,
            textAlign: TextAlign.center,
            style: TextStyle(color: muted),
          ),
        ],
      ),
    );
  }
}
