import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/goal.dart';
import '../models/wallet.dart' show walletColors;
import '../providers/goal_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/wallet_provider.dart';
import '../utils/app_style.dart';
import '../utils/formatters.dart';
import '../widgets/theme_artwork.dart';

/// Isi tab "Target" (savings goals) di layar Budget.
class GoalsView extends StatelessWidget {
  const GoalsView({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GoalProvider>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        if (provider.goals.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Column(
              children: [
                const ThemeArtwork(tile: 11, size: 88),
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
          for (final goal in provider.goals) _GoalTile(goal: goal),
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
    );
  }
}

class _GoalTile extends StatelessWidget {
  final Goal goal;

  const _GoalTile({required this.goal});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showGoalSheet(context, existing: goal),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
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
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: categoryGradient(goal.color),
                  ),
                  child: const Icon(
                    Icons.savings,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '${rupiah(goal.saved)} dari ${rupiah(goal.target)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
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
          ],
        ),
      ),
    );
  }
}

/// Sheet nabung: nambahin nominal ke target.
Future<void> _showTopUpSheet(BuildContext context, Goal goal) {
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
  );
}

/// Sheet tambah/edit target.
Future<void> _showGoalSheet(BuildContext context, {Goal? existing}) {
  final nameController = TextEditingController(text: existing?.name ?? '');
  final targetController = TextEditingController(
    text: existing == null
        ? ''
        : groupRibuan(existing.target.toInt().toString()),
  );
  var color = existing?.color ?? walletColors.first;

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
              Wrap(
                spacing: 10,
                children: [
                  for (final c in walletColors)
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
                        if (name.isEmpty || target <= 0) return;
                        final provider = sheetContext.read<GoalProvider>();
                        if (existing == null) {
                          provider.addGoal(
                            Goal(name: name, target: target, color: color),
                          );
                        } else {
                          provider.updateGoal(
                            Goal(
                              id: existing.id,
                              name: name,
                              target: target,
                              saved: existing.saved,
                              color: color,
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
  );
}
