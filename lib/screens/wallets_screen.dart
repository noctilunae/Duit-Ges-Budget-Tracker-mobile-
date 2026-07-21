import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/wallet.dart';
import '../providers/wallet_provider.dart';
import '../utils/app_style.dart';
import '../utils/formatters.dart';

/// Layar kelola dompet: tambah, edit, hapus.
class WalletsScreen extends StatelessWidget {
  const WalletsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WalletProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Kelola Dompet')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final wallet in provider.wallets)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: cardColor(context),
                borderRadius: BorderRadius.circular(16),
                boxShadow: cardShadow(context),
              ),
              child: ListTile(
                onTap: () => _showWalletSheet(context, existing: wallet),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: categoryGradient(wallet.color),
                  ),
                  child: Icon(wallet.icon, color: Colors.white, size: 22),
                ),
                title: Text(
                  wallet.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  rupiah(provider.balanceOf(wallet)),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                trailing: const Icon(Icons.edit_outlined, size: 18),
              ),
            ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: () => _showWalletSheet(context),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Tambah Dompet'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _showWalletSheet(BuildContext context, {Wallet? existing}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _WalletSheet(existing: existing),
  );
}

class _WalletSheet extends StatefulWidget {
  final Wallet? existing;

  const _WalletSheet({this.existing});

  @override
  State<_WalletSheet> createState() => _WalletSheetState();
}

class _WalletSheetState extends State<_WalletSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _balanceController;
  late String _iconKey;
  late Color _color;

  @override
  void initState() {
    super.initState();
    final w = widget.existing;
    _nameController = TextEditingController(text: w?.name ?? '');
    _balanceController = TextEditingController(
      text: w == null || w.initialBalance == 0
          ? ''
          : groupRibuan(w.initialBalance.toInt().toString()),
    );
    _iconKey = w?.iconKey ?? 'cash';
    _color = w?.color ?? walletColors.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kasih nama dompetnya dulu ya')),
      );
      return;
    }
    final balance =
        double.tryParse(_balanceController.text.replaceAll('.', '')) ?? 0;
    final wallet = Wallet(
      id: widget.existing?.id,
      name: name,
      iconKey: _iconKey,
      color: _color,
      initialBalance: balance,
    );
    final provider = context.read<WalletProvider>();
    if (widget.existing == null) {
      await provider.addWallet(wallet);
    } else {
      await provider.updateWallet(wallet);
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final ok = await context.read<WalletProvider>().deleteWallet(
      widget.existing!.id!,
    );
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ga bisa dihapus: masih ada transaksinya, '
            'atau ini dompet terakhir.',
          ),
        ),
      );
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
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
            Text(
              isEdit ? 'Edit Dompet' : 'Dompet Baru',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              autofocus: !isEdit,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nama dompet',
                hintText: 'misal: BCA, GoPay, Celengan',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                for (final entry in walletIcons.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: InkWell(
                      onTap: () => setState(() => _iconKey = entry.key),
                      borderRadius: BorderRadius.circular(24),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _iconKey == entry.key
                              ? _color
                              : _color.withValues(alpha: 0.12),
                        ),
                        child: Icon(
                          entry.value,
                          size: 20,
                          color: _iconKey == entry.key ? Colors.white : _color,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              children: [
                for (final color in walletColors)
                  InkWell(
                    onTap: () => setState(() => _color = color),
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color,
                        border: Border.all(
                          color: _color == color
                              ? Theme.of(context).colorScheme.onSurface
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _balanceController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                RibuanInputFormatter(),
              ],
              decoration: const InputDecoration(
                labelText: 'Saldo awal',
                prefixText: 'Rp ',
                helperText: 'Saldo dompet ini saat mulai dicatet di app',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                if (isEdit) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _delete,
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
                    onPressed: _save,
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
    );
  }
}
