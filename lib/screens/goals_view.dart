import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/goal.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../providers/goal_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/wallet_provider.dart';
import '../utils/app_style.dart';
import '../utils/formatters.dart';
import '../utils/stored_icon.dart';
import '../widgets/theme_artwork.dart';
import '../widgets/custom_image_icon_picker.dart';
import '../widgets/month_selector.dart';
import '../widgets/transaction_detail_sheet.dart';

bool _goalModalOpen = false;

/// Isi tab "Target" (savings goals) di layar Budget.
class GoalsView extends StatelessWidget {
  const GoalsView({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GoalProvider>();
    final transactions = context.watch<TransactionProvider>().transactions;
    return Column(
      children: [
        const MonthSelector(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
            children: [
              if (provider.goals.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Column(
                    children: [
                      const ThemeArtwork(tile: 7, size: 88, headerIndex: 1),
                      const SizedBox(height: 10),
                      Text(
                        'Belum ada target nabung.\n'
                        'Bikin target biar nabungnya keukur!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                )
              else
                for (final goal in provider.goals)
                  _GoalTile(
                    goal: goal,
                    transactions: transactions
                        .where(
                          (transaction) =>
                              transaction.sourceType == 'goal' &&
                              transaction.sourceId == goal.id,
                        )
                        .toList(),
                  ),
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                onPressed: () => _showGoalSheet(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Tambah Target'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GoalTile extends StatelessWidget {
  final Goal goal;
  final List<TransactionModel> transactions;

  const _GoalTile({required this.goal, required this.transactions});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      decoration: BoxDecoration(
        color: cardColor(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: cardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                onTap: () => _showGoalSheet(context, existing: goal),
                customBorder: const CircleBorder(),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: categoryGradient(goal.color),
                  ),
                  child: Center(
                    child: goal.iconWidget(color: Colors.white, size: 20),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () => _showGoalSheet(context, existing: goal),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '${rupiah(goal.saved)} dari ${rupiah(goal.target)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (goal.achieved)
                const Icon(Icons.check_circle, color: incomeColor, size: 22)
              else
                IconButton(
                  onPressed: () => _showTopUpSheet(context, goal),
                  icon: Icon(
                    Icons.add_circle_outline,
                    color: goal.color,
                    size: 24,
                  ),
                  tooltip: 'Nabung',
                ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: goal.fraction),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: goal.color.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation(
                  goal.achieved ? incomeColor : goal.color,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            goal.achieved
                ? 'Tercapai! Mantap!'
                : 'Kurang ${rupiah(goal.target - goal.saved)} lagi',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: goal.achieved ? incomeColor : goal.color,
            ),
          ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            dense: true,
            title: Text(
              '${transactions.length} transaksi bulan ini',
              style: const TextStyle(fontSize: 12),
            ),
            children: transactions.isEmpty
                ? [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        'Belum ada setoran bulan ini.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ]
                : [
                    for (final transaction in transactions)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        onTap: () =>
                            showTransactionDetailSheet(context, transaction),
                        title: Text(tanggalPendek(transaction.date)),
                        trailing: Text(
                          rupiah(transaction.amount),
                          style: const TextStyle(
                            color: expenseColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
          ),
        ],
      ),
    );
  }
}

/// Sheet nabung: nambahin nominal ke target.
Future<void> _showTopUpSheet(BuildContext context, Goal goal) {
  if (_goalModalOpen) return Future.value();
  _goalModalOpen = true;
  return _showTopUpSheetOnce(
    context,
    goal,
  ).whenComplete(() => _goalModalOpen = false);
}

Future<void> _showTopUpSheetOnce(BuildContext context, Goal goal) {
  final controller = TextEditingController();
  final wallets = context.read<WalletProvider>().wallets;
  int? walletId = wallets.firstOrNull?.id;
  var saving = false;
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: cardColor(sheetContext),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nabung ke "${goal.name}"',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    RibuanInputFormatter(),
                  ],
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: const InputDecoration(
                    prefixText: 'Rp ',
                    hintText: '0',
                    border: UnderlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: walletId,
                  decoration: const InputDecoration(
                    labelText: 'Ambil dari dompet',
                    prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final wallet in wallets)
                      DropdownMenuItem(
                        value: wallet.id,
                        child: Text(
                          '${wallet.name} · ${rupiah(context.read<WalletProvider>().balanceOf(wallet))}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: saving
                      ? null
                      : (value) => setSheetState(() => walletId = value),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: saving || walletId == null
                        ? null
                        : () async {
                            final amount =
                                double.tryParse(
                                  controller.text.replaceAll('.', ''),
                                ) ??
                                0;
                            if (amount <= 0) return;
                            final walletProvider = sheetContext
                                .read<WalletProvider>();
                            final wallet = walletProvider.byId(walletId!);
                            if (wallet == null ||
                                amount > walletProvider.balanceOf(wallet)) {
                              ScaffoldMessenger.of(sheetContext).showSnackBar(
                                const SnackBar(
                                  content: Text('Saldo dompet tidak cukup'),
                                ),
                              );
                              return;
                            }
                            setSheetState(() => saving = true);
                            final transactionProvider = sheetContext
                                .read<TransactionProvider>();
                            final goalProvider = sheetContext
                                .read<GoalProvider>();
                            try {
                              await transactionProvider.topUpGoal(
                                goal: goal,
                                walletId: walletId!,
                                amount: amount,
                              );
                              await goalProvider.load();
                              if (!sheetContext.mounted) return;
                              Navigator.pop(sheetContext);
                            } catch (_) {
                              if (!sheetContext.mounted) return;
                              setSheetState(() => saving = false);
                              ScaffoldMessenger.of(sheetContext).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Gagal mengisi target, coba lagi',
                                  ),
                                ),
                              );
                            }
                          },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(saving ? 'Menyimpan...' : 'Nabung'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Sheet tambah/edit target.
Future<void> _showGoalSheet(BuildContext context, {Goal? existing}) {
  if (_goalModalOpen) return Future.value();
  _goalModalOpen = true;
  return _showGoalSheetOnce(
    context,
    existing: existing,
  ).whenComplete(() => _goalModalOpen = false);
}

Future<void> _showGoalSheetOnce(BuildContext context, {Goal? existing}) {
  final nameController = TextEditingController(text: existing?.name ?? '');
  final targetController = TextEditingController(
    text: existing == null
        ? ''
        : groupRibuan(existing.target.toInt().toString()),
  );
  final emojiController = TextEditingController(text: existing?.emoji ?? '');
  var iconKey = existing?.iconKey ?? 'savings';
  var color = existing?.color ?? categoryColorChoices.first;

  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: cardColor(sheetContext),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  existing == null ? 'Target Baru' : 'Edit Target',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  autofocus: existing == null,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Nama target',
                    hintText: 'misal: Laptop baru, Dana darurat',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: targetController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    RibuanInputFormatter(),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Nominal target',
                    prefixText: 'Rp ',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'icon', label: Text('Ikon')),
                    ButtonSegment(value: 'emoji', label: Text('Emoji')),
                    ButtonSegment(value: 'image', label: Text('PNG/JPG')),
                  ],
                  selected: {
                    iconKey.startsWith('emoji:')
                        ? 'emoji'
                        : iconKey.startsWith('image:')
                        ? 'image'
                        : 'icon',
                  },
                  onSelectionChanged: (value) => setSheetState(
                    () => iconKey = switch (value.first) {
                      'emoji' => 'emoji:',
                      'image' =>
                        iconKey.startsWith('image:') ? iconKey : 'image:',
                      _ => 'savings',
                    },
                  ),
                ),
                const SizedBox(height: 8),
                if (iconKey.startsWith('emoji:'))
                  TextField(
                    controller: emojiController,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 32),
                    decoration: const InputDecoration(
                      labelText: 'Emoji target',
                      hintText: '🎯',
                    ),
                  )
                else if (iconKey.startsWith('image:'))
                  CustomImageIconPicker(
                    iconKey: iconKey,
                    fallbackKey: 'savings',
                    onChanged: (value) => setSheetState(() => iconKey = value),
                  )
                else
                  GridView.count(
                    crossAxisCount: 7,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    children: [
                      for (final entry in categoryIconChoices.entries)
                        InkWell(
                          onTap: () => setSheetState(() => iconKey = entry.key),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            decoration: BoxDecoration(
                              color: iconKey == entry.key
                                  ? color.withValues(alpha: 0.18)
                                  : Colors.transparent,
                              border: Border.all(
                                color: iconKey == entry.key
                                    ? color
                                    : Theme.of(
                                        sheetContext,
                                      ).colorScheme.outlineVariant,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(entry.value, color: color),
                          ),
                        ),
                    ],
                  ),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: 7,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  children: [
                    for (final c in categoryColorChoices)
                      InkWell(
                        onTap: () => setSheetState(() => color = c),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: c,
                            border: Border.all(
                              color: color == c
                                  ? Theme.of(sheetContext).colorScheme.onSurface
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    if (existing != null) ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final transactionProvider = sheetContext
                                .read<TransactionProvider>();
                            final goalProvider = sheetContext
                                .read<GoalProvider>();
                            await transactionProvider.deleteGoal(existing);
                            await goalProvider.load();
                            if (!sheetContext.mounted) return;
                            Navigator.pop(sheetContext);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: expenseColor,
                            side: BorderSide(
                              color: expenseColor.withValues(alpha: 0.5),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Hapus'),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          final name = nameController.text.trim();
                          final target =
                              double.tryParse(
                                targetController.text.replaceAll('.', ''),
                              ) ??
                              0;
                          final emoji = emojiController.text.trim();
                          if (name.isEmpty ||
                              target <= 0 ||
                              (iconKey.startsWith('image:') &&
                                  !isValidStoredImageIcon(iconKey)) ||
                              (iconKey.startsWith('emoji:') && emoji.isEmpty)) {
                            return;
                          }
                          final savedIcon = iconKey.startsWith('emoji:')
                              ? 'emoji:$emoji'
                              : iconKey;
                          final provider = sheetContext.read<GoalProvider>();
                          if (existing == null) {
                            provider.addGoal(
                              Goal(
                                name: name,
                                target: target,
                                color: color,
                                iconKey: savedIcon,
                              ),
                            );
                          } else {
                            provider.updateGoal(
                              Goal(
                                id: existing.id,
                                name: name,
                                target: target,
                                saved: existing.saved,
                                color: color,
                                iconKey: savedIcon,
                              ),
                            );
                          }
                          Navigator.pop(sheetContext);
                        },
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Simpan'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
