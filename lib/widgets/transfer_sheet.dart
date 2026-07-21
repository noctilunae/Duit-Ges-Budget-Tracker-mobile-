import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/wallet.dart';
import '../providers/transaction_provider.dart';
import '../providers/wallet_provider.dart';
import '../utils/app_style.dart';
import '../utils/formatters.dart';

/// Bottom sheet transfer duit antar dompet.
Future<void> showTransferSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _TransferSheet(),
  );
}

class _TransferSheet extends StatefulWidget {
  const _TransferSheet();

  @override
  State<_TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends State<_TransferSheet> {
  int? _fromId;
  int? _toId;
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save(List<Wallet> wallets) async {
    final amount =
        double.tryParse(_amountController.text.replaceAll('.', '')) ?? 0;
    final from = _fromId ?? wallets.first.id;
    final to = _toId ?? (wallets.length > 1 ? wallets[1].id : null);
    if (amount <= 0) {
      _showError('Isi jumlahnya dulu ya');
      return;
    }
    if (from == null || to == null || from == to) {
      _showError('Dompet asal dan tujuan harus beda');
      return;
    }
    await context.read<TransactionProvider>().addTransfer(
      fromWalletId: from,
      toWalletId: to,
      amount: amount,
      note: _noteController.text.trim(),
    );
    if (!mounted) return;
    Navigator.pop(context);
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
    final fromId = _fromId ?? wallets.first.id!;
    final toId = _toId ?? wallets.firstWhere((w) => w.id != fromId).id!;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.swap_horiz, size: 20),
                SizedBox(width: 8),
                Text(
                  'Transfer Antar Dompet',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _WalletDropdown(
                    label: 'Dari',
                    wallets: wallets,
                    value: fromId,
                    onChanged: (id) => setState(() => _fromId = id),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_forward, size: 18),
                ),
                Expanded(
                  child: _WalletDropdown(
                    label: 'Ke',
                    wallets: wallets,
                    value: toId,
                    onChanged: (id) => setState(() => _toId = id),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
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
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => _save(wallets),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Transfer'),
              ),
            ),
          ],
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
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: [
        for (final wallet in wallets)
          DropdownMenuItem(
            value: wallet.id,
            child: Row(
              children: [
                Icon(wallet.icon, size: 16, color: wallet.color),
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
