import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/budget.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../providers/budget_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/transaction_provider.dart';
import '../utils/app_style.dart';
import '../utils/formatters.dart';
import '../widgets/animated_widgets.dart';
import '../widgets/page_header.dart';
import '../widgets/theme_artwork.dart';
import '../widgets/month_selector.dart';
import '../widgets/transaction_detail_sheet.dart';
import 'add_transaction_screen.dart';
import 'debts_view.dart';
import 'goals_view.dart';
import 'recap_screen.dart';

enum _BudgetTab { budget, target, utang }

bool _budgetSheetOpen = false;

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
    final isLight = Theme.of(context).brightness == Brightness.light;
    final backgrounds = isLight
        ? settings.preset.budgetSubTabLightBackgrounds
        : settings.preset.budgetSubTabDarkBackgrounds;
    final background = backgrounds?[_tab.index];
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: background == null
            ? null
            : LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: background,
              ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            PageHeader(
              title: 'Budget',
              artworkTile: 7,
              action: IconButton(
                icon: const Icon(Icons.summarize_outlined),
                tooltip: 'Rekap',
                onPressed: () =>
                    Navigator.push(context, slideUpRoute(const RecapScreen())),
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
                onSelectionChanged: (value) =>
                    setState(() => _tab = value.first),
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
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

class _BudgetView extends StatelessWidget {
  const _BudgetView({super.key});

  @override
  Widget build(BuildContext context) {
    final budgets = context.watch<BudgetProvider>().budgets;
    final transactions = context.watch<TransactionProvider>().transactions;
    return Column(
      children: [
        const MonthSelector(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
            children: [
              if (budgets.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 36),
                  child: Column(
                    children: [
                      const ThemeArtwork(tile: 4, size: 88),
                      const SizedBox(height: 12),
                      Text(
                        'Belum ada budget.\nBuat sesuai kebutuhanmu sendiri.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              for (final type in BudgetType.values)
                if (budgets.any((budget) => budget.type == type))
                  Theme(
                    data: Theme.of(
                      context,
                    ).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                      initiallyExpanded: true,
                      title: Text(
                        _typeLabel(type),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${budgets.where((item) => item.type == type).length} budget',
                        style: const TextStyle(fontSize: 11),
                      ),
                      children: [
                        for (final budget in budgets.where(
                          (item) => item.type == type,
                        ))
                          _BudgetCard(
                            budget: budget,
                            transactions: transactions
                                .where(
                                  (transaction) =>
                                      transaction.budgetId == budget.id,
                                )
                                .toList(),
                          ),
                      ],
                    ),
                  ),
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                onPressed: () => _showBudgetSheet(context),
                icon: const Icon(Icons.add),
                label: const Text('Tambah Budget'),
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

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({required this.budget, required this.transactions});

  final Budget budget;
  final List<TransactionModel> transactions;

  @override
  Widget build(BuildContext context) {
    final spent = transactions
        .where((transaction) => transaction.type == TxType.expense)
        .fold<double>(0, (sum, transaction) => sum + transaction.amount);
    final fraction = budget.amount == 0 ? 0.0 : spent / budget.amount;
    final over = spent > budget.amount;
    final statusColor = over ? expenseColor : budget.color;
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
                onTap: () => _showBudgetSheet(context, existing: budget),
                customBorder: const CircleBorder(),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: categoryGradient(budget.color),
                  ),
                  child: Center(
                    child: budget.iconWidget(color: Colors.white, size: 20),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () => _showBudgetSheet(context, existing: budget),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        budget.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '${rupiah(spent)} dari ${rupiah(budget.amount)}',
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
              IconButton(
                tooltip: 'Tambah transaksi',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddTransactionScreen(budgetId: budget.id),
                  ),
                ),
                icon: Icon(
                  Icons.add_circle_outline,
                  color: budget.color,
                  size: 24,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction.clamp(0, 1),
              minHeight: 8,
              backgroundColor: statusColor.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation(statusColor),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            over
                ? 'Jebol ${rupiah(spent - budget.amount)}'
                : 'Sisa ${rupiah(budget.amount - spent)}',
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
                        'Belum ada transaksi di budget ini.',
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
                        leading: transaction.category.iconWidget(
                          color: transaction.category.color,
                          size: 20,
                        ),
                        title: Text(
                          transaction.note.isEmpty
                              ? transaction.category.name
                              : transaction.note,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(tanggalPendek(transaction.date)),
                        trailing: Text(
                          rupiah(transaction.amount),
                          style: TextStyle(
                            color: transaction.type == TxType.expense
                                ? expenseColor
                                : incomeColor,
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

Future<void> _showBudgetSheet(BuildContext context, {Budget? existing}) async {
  if (_budgetSheetOpen) return;
  _budgetSheetOpen = true;
  try {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BudgetSheet(existing: existing),
    );
  } finally {
    _budgetSheetOpen = false;
  }
}

class _BudgetSheet extends StatefulWidget {
  const _BudgetSheet({this.existing});

  final Budget? existing;

  @override
  State<_BudgetSheet> createState() => _BudgetSheetState();
}

class _BudgetSheetState extends State<_BudgetSheet> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _amount = TextEditingController(
    text: widget.existing == null
        ? ''
        : groupRibuan(widget.existing!.amount.round().toString()),
  );
  late final _emoji = TextEditingController(text: widget.existing?.emoji ?? '');
  late String _iconKey = widget.existing?.iconKey ?? 'savings';
  late Color _color = widget.existing?.color ?? categoryColorChoices.first;
  late BudgetType _type = widget.existing?.type ?? BudgetType.kebutuhan;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _emoji.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final amount = double.tryParse(_amount.text.replaceAll('.', '')) ?? 0;
    final emoji = _emoji.text.trim();
    if (name.isEmpty ||
        amount <= 0 ||
        (_iconKey.startsWith('emoji:') && emoji.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lengkapi nama, ikon, dan nominal budget'),
        ),
      );
      return;
    }
    await context.read<BudgetProvider>().saveBudget(
      Budget(
        id:
            widget.existing?.id ??
            'budget_${DateTime.now().microsecondsSinceEpoch}',
        name: name,
        iconKey: _iconKey.startsWith('emoji:') ? 'emoji:$emoji' : _iconKey,
        color: _color,
        type: _type,
        amount: amount,
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.existing == null ? 'Budget Baru' : 'Edit Budget',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _name,
                autofocus: widget.existing == null,
                decoration: const InputDecoration(labelText: 'Nama budget'),
              ),
              const SizedBox(height: 12),
              InputDecorator(
                decoration: const InputDecoration(labelText: 'Tipe budget'),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<BudgetType>(
                    value: _type,
                    isExpanded: true,
                    isDense: true,
                    items: [
                      for (final type in BudgetType.values)
                        DropdownMenuItem(
                          value: type,
                          child: Text(
                            _typeLabel(type),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) =>
                        setState(() => _type = value ?? _type),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _amount,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  RibuanInputFormatter(),
                ],
                decoration: const InputDecoration(
                  labelText: 'Nominal budget',
                  prefixText: 'Rp ',
                ),
              ),
              const SizedBox(height: 16),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Ikon warna')),
                  ButtonSegment(value: true, label: Text('Emoji')),
                ],
                selected: {_iconKey.startsWith('emoji:')},
                onSelectionChanged: (value) => setState(
                  () => _iconKey = value.first ? 'emoji:' : 'savings',
                ),
              ),
              const SizedBox(height: 8),
              if (_iconKey.startsWith('emoji:'))
                TextField(
                  controller: _emoji,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 32),
                  decoration: const InputDecoration(
                    labelText: 'Emoji budget',
                    hintText: '🦆',
                  ),
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
                        onTap: () => setState(() => _iconKey = entry.key),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: _iconKey == entry.key
                                ? _color.withValues(alpha: 0.18)
                                : Colors.transparent,
                            border: Border.all(
                              color: _iconKey == entry.key
                                  ? _color
                                  : Theme.of(
                                      context,
                                    ).colorScheme.outlineVariant,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(entry.value, color: _color),
                        ),
                      ),
                  ],
                ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 9,
                runSpacing: 9,
                children: [
                  for (final color in categoryColorChoices)
                    InkWell(
                      onTap: () => setState(() => _color = color),
                      customBorder: const CircleBorder(),
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: color,
                        child: color == _color
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 17,
                              )
                            : null,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  if (widget.existing != null) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          await context.read<BudgetProvider>().removeBudget(
                            widget.existing!.id,
                          );
                          if (context.mounted) Navigator.pop(context);
                        },
                        child: const Text('Hapus'),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: FilledButton(
                      onPressed: _save,
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
}

String _typeLabel(BudgetType type) => switch (type) {
  BudgetType.kebutuhan => 'Kebutuhan',
  BudgetType.keinginan => 'Keinginan',
  BudgetType.tabungan => 'Tabungan',
};
