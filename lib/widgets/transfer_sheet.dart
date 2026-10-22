import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../db/database_helper.dart';
import '../models/transaction.dart';
import '../models/wallet.dart';
import '../providers/transaction_provider.dart';
import '../providers/wallet_provider.dart';
import '../utils/app_style.dart';
import '../utils/formatters.dart';

/// Bottom sheet transfer duit antar dompet.
Future<void> showTransferSheet(
  BuildContext context, {
  TransactionModel? existing,
}) async {
  List<TransactionModel>? pair;
  if (existing != null) {
    try {
      pair = await DatabaseHelper.instance.transferTransactions(existing.id!);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pasangan transfer tidak ditemukan, edit dibatalkan'),
          ),
        );
      }
      return;
    }
  }
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _TransferSheet(pair: pair),
  );
}

class _TransferSheet extends StatefulWidget {
  const _TransferSheet({this.pair});
  final List<TransactionModel>? pair;

  @override
  State<_TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends State<_TransferSheet> {
  int? _fromId;
  int? _toId;
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final pair = widget.pair;
    if (pair != null) {
      _fromId = pair.first.walletId;
      _toId = pair.last.walletId;
      _date = pair.first.date;
      _amountController.text = groupRibuan(
        pair.first.amount.round().toString(),
      );
      _noteController.text = pair.first.note;
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: _date.isBefore(DateTime(2020)) ? _date : DateTime(2020),
      lastDate: _date.isAfter(DateTime.now()) ? _date : DateTime.now(),
    );
    if (picked != null && mounted) {
      setState(
        () => _date = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _date.hour,
          _date.minute,
          _date.second,
          _date.millisecond,
          _date.microsecond,
        ),
      );
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save(List<Wallet> wallets) async {
    if (_saving) return;
    final amount =
        double.tryParse(_amountController.text.replaceAll('.', '')) ?? 0;
    final from = _fromId ?? context.read<WalletProvider>().defaultWalletId;
    final to = _toId ?? wallets.where((w) => w.id != from).firstOrNull?.id;
    if (amount <= 0) {
      _showError('Isi jumlahnya dulu ya');
      return;
    }
    if (from == null || to == null || from == to) {
      _showError('Dompet asal dan tujuan harus beda');
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<TransactionProvider>().addTransfer(
        fromWalletId: from,
        toWalletId: to,
        amount: amount,
        note: _noteController.text.trim(),
        date: _date,
        existingId: widget.pair?.first.id,
      );
      if (!mounted) return;
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showError('Transfer gagal disimpan, coba lagi ya');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final wallets = context.watch<WalletProvider>().wallets;
    if (wallets.length < 2) {
      return Container(
        decoration: BoxDecoration(
          color: cardColor(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.all(32),
        child: const Text(
          'Butuh minimal 2 dompet buat transfer.\n'
          'Tambahin dompet dulu lewat "Kelola".',
          textAlign: TextAlign.center,
        ),
      );
    }
    final fromId = _fromId ?? context.watch<WalletProvider>().defaultWalletId!;
    final toId = _toId ?? wallets.firstWhere((w) => w.id != fromId).id!;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Container(
            decoration: BoxDecoration(
              color: cardColor(context),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                const Row(
                  children: [
                    Icon(Icons.swap_horiz, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Transfer Antar Dompet',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('Pindahkan saldo tanpa menambah pengeluaran.'),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _WalletDropdown(
                        label: 'Dari',
                        wallets: wallets,
                        value: fromId,
                        onChanged: (id) => setState(() {
                          _fromId = id;
                          if (id == toId) _toId = fromId;
                        }),
                      ),
                    ),
                    IconButton.filledTonal(
                      tooltip: 'Tukar dompet',
                      onPressed: () => setState(() {
                        _fromId = toId;
                        _toId = fromId;
                      }),
                      icon: const Icon(Icons.swap_horiz_rounded),
                    ),
                    Expanded(
                      child: _WalletDropdown(
                        label: 'Ke',
                        wallets: wallets,
                        value: toId,
                        onChanged: (id) => setState(() {
                          _toId = id;
                          if (id == fromId) _fromId = toId;
                        }),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _amountController,
                  autofocus: false,
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
                    labelText: 'Nominal transfer',
                    hintText: '0',
                    border: UnderlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _noteController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Catatan (opsional)',
                    prefixIcon: Icon(Icons.notes, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(18)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Material(
                  color: Colors.transparent,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      child: Icon(Icons.calendar_month_outlined),
                    ),
                    title: const Text('Tanggal transfer'),
                    subtitle: Text(tanggalLengkap(_date)),
                    trailing: const Icon(Icons.edit_calendar_outlined),
                    onTap: _saving ? null : _pickDate,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : () => _save(wallets),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      _saving
                          ? 'Menyimpan...'
                          : widget.pair == null
                          ? 'Transfer'
                          : 'Simpan perubahan',
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

class _WalletDropdown extends StatelessWidget {
  final String label;
  final List<Wallet> wallets;
  final int value;
  final ValueChanged<int?> onChanged;

  const _WalletDropdown({
    required this.label,
    required this.wallets,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      key: ValueKey('$label:$value'),
      isExpanded: true,
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Theme.of(
          context,
        ).colorScheme.primaryContainer.withValues(alpha: 0.35),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: [
        for (final wallet in wallets)
          DropdownMenuItem(
            value: wallet.id,
            child: Row(
              children: [
                wallet.iconWidget(size: 16, color: wallet.color),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    wallet.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
      ],
      onChanged: onChanged,
    );
  }
}
