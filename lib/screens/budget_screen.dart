import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/category.dart';
import '../models/transaction.dart';
import '../providers/budget_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/transaction_provider.dart';
import '../utils/app_style.dart';
import '../utils/formatters.dart';
import '../widgets/animated_widgets.dart';
import '../widgets/month_selector.dart';
import '../widgets/page_header.dart';
import '../widgets/theme_artwork.dart';
import '../widgets/transaction_detail_sheet.dart';
import 'debts_view.dart';
import 'goals_view.dart';
import 'recap_screen.dart';

enum _BudgetTab { budget, target, utang }

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  _BudgetTab _tab = _BudgetTab.budget;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final headerArtworkTile = settings.preset.id == 'frieren' ? 7 : 7;
    final isLight = Theme.of(context).brightness == Brightness.light;
    // Ambil dari preset (budgetSubTabLightBackgrounds/DarkBackgrounds) —
    // null = tema itu ga punya sub-tab Budget beda warna, jadi ikutan
    // 1 background tab Budget yang biasa aja (di-set di main_shell).
    final subTabBgList = isLight
        ? settings.preset.budgetSubTabLightBackgrounds
        : settings.preset.budgetSubTabDarkBackgrounds;
    final subTabBg = subTabBgList?[_tab.index];
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: subTabBg == null
            ? null
            : LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: subTabBg,
              ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            PageHeader(
              title: 'Budget',
              artworkTile: headerArtworkTile,
              action: IconButton(
                icon: const Icon(Icons.summarize_outlined),
                tooltip: 'Rekap',
                onPressed: () {
                  Navigator.push(context, slideUpRoute(const RecapScreen()));
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SegmentedButton<_BudgetTab>(
                segments: const [
                  ButtonSegment(
                    value: _BudgetTab.budget,
                    label: Text('Budget'),
                  ),
                  ButtonSegment(
                    value: _BudgetTab.target,
                    label: Text('Target'),
                  ),
                  ButtonSegment(value: _BudgetTab.utang, label: Text('Utang')),
                ],
                selected: {_tab},
                onSelectionChanged: (selection) {
                  setState(() => _tab = selection.first);
                },
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: switch (_tab) {
                  _BudgetTab.budget => const _BudgetView(
                    key: ValueKey('budget'),
                  ),
                  _BudgetTab.target => const GoalsView(key: ValueKey('target')),
                  _BudgetTab.utang => const DebtsView(key: ValueKey('utang')),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Isi tab "Budget" (limit per kategori) — konten lama layar ini.
class _BudgetView extends StatelessWidget {
  const _BudgetView({super.key});

  @override
  Widget build(BuildContext context) {
    final txProvider = context.watch<TransactionProvider>();
    final budgetProvider = context.watch<BudgetProvider>();
    final budgets = budgetProvider.budgets;

    // Total pengeluaran bulan ini per kategori
    final spent = {
      for (final entry in txProvider.totalsByCategory(TxType.expense))
        entry.key.id: entry.value,
    };
    final transactionsByCategory = <String, List<TransactionModel>>{};
    for (final transaction in txProvider.transactions) {
      if (transaction.type != TxType.expense || transaction.isTransfer) {
        continue;
      }
      transactionsByCategory
          .putIfAbsent(transaction.categoryId, () => [])
          .add(transaction);
    }

    final withBudget = expenseCategories
        .where((c) => budgets.containsKey(c.id))
        .toList();
    final withoutBudget = expenseCategories
        .where((c) => !budgets.containsKey(c.id))
        .toList();

    return Column(
      children: [
        const MonthSelector(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
            children: [
              if (withBudget.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Column(
                    children: [
                      const ThemeArtwork(tile: 4, size: 88),
                      const SizedBox(height: 10),
                      Text(
                        'Belum ada budget yang diatur.\n'
                        'Pilih kategori di bawah buat mulai.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                )
              else
                for (var i = 0; i < withBudget.length; i++)
                  StaggeredItem(
                    key: ValueKey(
                      'budget-${txProvider.month}-${withBudget[i].id}',
                    ),
                    index: i,
                    child: _BudgetTile(
                      category: withBudget[i],
                      limit: budgets[withBudget[i].id]!,
                      spent: spent[withBudget[i].id] ?? 0,
                      transactions:
                          transactionsByCategory[withBudget[i].id] ?? const [],
                    ),
                  ),
              if (withoutBudget.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
                  child: Text(
                    'Belum diatur',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                for (final category in withoutBudget)
                  _UnsetTile(category: category),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Kategori yang udah punya budget: progress + status.
class _BudgetTile extends StatelessWidget {
  final Category category;
  final double limit;
  final double spent;
  final List<TransactionModel> transactions;

  const _BudgetTile({
    required this.category,
    required this.limit,
    required this.spent,
    required this.transactions,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = limit == 0 ? 0.0 : spent / limit;
    final over = spent > limit;
    final warning = !over && fraction >= 0.75;
    final statusColor = over
        ? expenseColor
        : warning
        ? const Color(0xFFFFA726)
        : incomeColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
                  gradient: categoryGradient(category.color),
                ),
                child: Icon(category.icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '${rupiah(spent)} dari ${rupiah(limit)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (over)
                const Icon(
                  Icons.warning_amber_rounded,
                  color: expenseColor,
                  size: 20,
                ),
              IconButton(
                tooltip: 'Atur budget',
                onPressed: () =>
                    _showSetBudgetSheet(context, category, existing: limit),
                icon: const Icon(Icons.tune, size: 19),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: fraction.clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: statusColor.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation(statusColor),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            over
                ? 'Jebol ${rupiah(spent - limit)}!'
                : 'Sisa ${rupiah(limit - spent)}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: statusColor,
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
                        'Belum ada pengeluaran di kategori ini.',
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
                        title: Text(
                          transaction.note.isEmpty
                              ? tanggalPendek(transaction.date)
                              : transaction.note,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: transaction.note.isEmpty
                            ? null
                            : Text(tanggalPendek(transaction.date)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              rupiah(transaction.amount),
                              style: const TextStyle(
                                color: expenseColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Hapus transaksi',
                              onPressed: () => confirmDeleteTransaction(
                                context,
                                transaction,
                              ),
                              icon: const Icon(Icons.delete_outline, size: 19),
                            ),
                          ],
                        ),
                      ),
                  ],
          ),
        ],
      ),
    );
  }
}

/// Kategori tanpa budget: tinggal tap buat atur.
class _UnsetTile extends StatelessWidget {
  final Category category;

  const _UnsetTile({required this.category});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cardColor(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: cardShadow(context),
      ),
      child: ListTile(
        onTap: () => _showSetBudgetSheet(context, category),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: category.color.withValues(alpha: 0.15),
          ),
          child: Icon(category.icon, color: category.color, size: 20),
        ),
        title: Text(
          category.name,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        trailing: Icon(
          Icons.add_circle_outline,
          color: Theme.of(context).colorScheme.primary,
          size: 22,
        ),
      ),
    );
  }
}

/// Bottom sheet buat atur/hapus limit budget satu kategori.
Future<void> _showSetBudgetSheet(
  BuildContext context,
  Category category, {
  double? existing,
}) {
  final controller = TextEditingController(
    text: existing == null ? '' : groupRibuan(existing.toInt().toString()),
  );
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => Padding(
      // Biar sheet naik pas keyboard muncul
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
            Row(
              children: [
                Icon(category.icon, color: category.color, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Budget ${category.name}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ],
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
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                prefixText: 'Rp ',
                hintText: '0',
                helperText: 'Limit pengeluaran per bulan',
                border: UnderlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                if (existing != null) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        sheetContext.read<BudgetProvider>().removeBudget(
                          category.id,
                        );
                        Navigator.pop(sheetContext);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: expenseColor,
                        side: BorderSide(
                          color: expenseColor.withValues(alpha: 0.5),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Hapus Budget'),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      final amount =
                          double.tryParse(
                            controller.text.replaceAll('.', ''),
                          ) ??
                          0;
                      if (amount <= 0) return;
                      sheetContext.read<BudgetProvider>().setBudget(
                        category.id,
                        amount,
                      );
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
  );
}
