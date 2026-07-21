import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/category.dart';
import '../models/recurring.dart';
import '../providers/category_provider.dart';
import '../providers/recurring_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/wallet_provider.dart';
import '../utils/app_style.dart';
import '../utils/formatters.dart';

/// Kelola transaksi berulang bulanan: gaji, tagihan, cicilan.
class RecurringsScreen extends StatelessWidget {
  const RecurringsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RecurringProvider>();
    final items = provider.items;

    return Scaffold(
      appBar: AppBar(title: const Text('Transaksi Berulang')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Tambah'),
      ),
      body: items.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Belum ada transaksi berulang.\n\n'
                  'Cocok buat gaji, tagihan wifi, atau cicilan — '
                  'tiap bulan otomatis dicatat tanpa perlu ngetik ulang.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: items.length,
              itemBuilder: (context, index) =>
                  _RecurringTile(recurring: items[index]),
            ),
    );
  }
}

Future<void> _showForm(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _RecurringForm(),
  );
}

class _RecurringTile extends StatelessWidget {
  final Recurring recurring;

  const _RecurringTile({required this.recurring});

  @override
  Widget build(BuildContext context) {
    final category = recurring.category;
    final isIncome = recurring.type == TxType.income;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final wallet = context.watch<WalletProvider>().byId(recurring.walletId);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: cardShadow(context),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: categoryGradient(category.color),
            ),
            child: Icon(category.icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recurring.note.isEmpty ? category.name : recurring.note,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Tiap tanggal ${recurring.day}'
                  '${wallet == null ? '' : ' • ${wallet.name}'}',
                  style: TextStyle(fontSize: 12, color: muted),
                ),
                Text(
                  '${isIncome ? '+' : '-'}${rupiah(recurring.amount)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isIncome ? incomeColor : expenseColor,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: recurring.active,
            onChanged: (value) =>
                context.read<RecurringProvider>().setActive(recurring, value),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            color: expenseColor,
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus transaksi berulang?'),
        content: Text(
          '${recurring.category.name} — ${rupiah(recurring.amount)} '
          'tiap tanggal ${recurring.day}.\n\n'
          'Transaksi yang udah tercatat ga ikut kehapus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<RecurringProvider>().remove(recurring.id!);
    }
  }
}

/// Form tambah transaksi berulang (bottom sheet).
class _RecurringForm extends StatefulWidget {
  const _RecurringForm();

  @override
  State<_RecurringForm> createState() => _RecurringFormState();
}

class _RecurringFormState extends State<_RecurringForm> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  TxType _type = TxType.expense;
  String? _categoryId;
  int? _walletId;
  int _day = 1;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  double get _amount =>
      double.tryParse(_amountController.text.replaceAll('.', '')) ?? 0;

  Future<void> _save() async {
    if (_amount <= 0 || _categoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Isi nominal sama kategorinya dulu ya')),
      );
      return;
    }
    final provider = context.read<RecurringProvider>();
    final txProvider = context.read<TransactionProvider>();
    await provider.add(
      Recurring(
        amount: _amount,
        categoryId: _categoryId!,
        walletId: _walletId ?? 1,
        note: _noteController.text.trim(),
        type: _type,
        day: _day,
        nextDue: Recurring.firstDue(_day),
      ),
    );
    // Kalau jatuh temponya hari ini, langsung dicatat sekarang juga
    await txProvider.load(applyRecurrings: true);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final categoryProvider = context.watch<CategoryProvider>();
    final categories = _type == TxType.expense
        ? categoryProvider.expenseAll
        : categoryProvider.incomeAll;
    if (_categoryId != null && !categories.any((c) => c.id == _categoryId)) {
      _categoryId = null;
    }
    final wallets = context.watch<WalletProvider>().wallets;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return Container(
      decoration: BoxDecoration(
        color: cardColor(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: muted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Transaksi Berulang Baru',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SegmentedButton<TxType>(
              segments: const [
                ButtonSegment(
                  value: TxType.expense,
                  label: Text('Pengeluaran'),
                ),
                ButtonSegment(value: TxType.income, label: Text('Pemasukan')),
              ],
              selected: {_type},
              onSelectionChanged: (selection) {
                setState(() => _type = selection.first);
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                RibuanInputFormatter(),
              ],
              decoration: const InputDecoration(
                labelText: 'Nominal',
                prefixText: 'Rp ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _categoryId,
              decoration: const InputDecoration(
                labelText: 'Kategori',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final category in categories)
                  DropdownMenuItem(
                    value: category.id,
                    child: Row(
                      children: [
                        Icon(category.icon, size: 18, color: category.color),
                        const SizedBox(width: 8),
                        Text(category.name),
                      ],
                    ),
                  ),
              ],
              onChanged: (value) => setState(() => _categoryId = value),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue:
                        _walletId ??
                        (wallets.isEmpty ? null : wallets.first.id),
                    decoration: const InputDecoration(
                      labelText: 'Dompet',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final wallet in wallets)
                        DropdownMenuItem(
                          value: wallet.id,
                          child: Text(wallet.name),
                        ),
                    ],
                    onChanged: (value) => setState(() => _walletId = value),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _day,
                    decoration: const InputDecoration(
                      labelText: 'Tiap tanggal',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (var d = 1; d <= 31; d++)
                        DropdownMenuItem(value: d, child: Text('$d')),
                    ],
                    onChanged: (value) => setState(() => _day = value ?? 1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Catatan (misal: Gaji kantor)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Buat bulan yang lebih pendek, tanggal 29-31 otomatis '
              'jadi tanggal terakhir bulan itu.',
              style: TextStyle(fontSize: 12, color: muted),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Simpan'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
