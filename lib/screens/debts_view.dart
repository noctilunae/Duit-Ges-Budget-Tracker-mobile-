import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/debt.dart';
import '../providers/debt_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/wallet_provider.dart';
import '../utils/app_style.dart';
import '../utils/formatters.dart';
import '../widgets/theme_artwork.dart';

/// Isi tab "Utang" (utang & piutang) di layar Budget.
class DebtsView extends StatelessWidget {
  const DebtsView({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DebtProvider>();
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        // Ringkasan atas: total utang vs piutang yang belum lunas
        Row(
          children: [
            Expanded(
              child: _SummaryBox(
                label: 'Utangku',
                amount: provider.totalOwed,
                color: expenseColor,
                icon: Icons.arrow_circle_up,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SummaryBox(
                label: 'Piutang',
                amount: provider.totalReceivable,
                color: incomeColor,
                icon: Icons.arrow_circle_down,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (provider.debts.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Column(
              children: [
                const ThemeArtwork(tile: 7, size: 88, headerIndex: 1),
                const SizedBox(height: 10),
                Text(
                  'Belum ada catatan utang/piutang.\nAman... untuk sekarang.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: muted),
                ),
              ],
            ),
          )
        else
          for (final debt in provider.debts) _DebtTile(debt: debt),
        const SizedBox(height: 8),
        FilledButton.tonalIcon(
          onPressed: () => _showDebtSheet(context),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Catat Utang/Piutang'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ],
    );
  }
}

class _SummaryBox extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final IconData icon;

  const _SummaryBox({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: cardShadow(context),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
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
                  rupiah(amount),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: color,
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

class _DebtTile extends StatelessWidget {
  final Debt debt;

  const _DebtTile({required this.debt});

  @override
  Widget build(BuildContext context) {
    final color = debt.isReceivable ? incomeColor : expenseColor;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cardColor(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: cardShadow(context),
      ),
      child: Opacity(
        opacity: debt.settled ? 0.55 : 1,
        child: ListTile(
          onTap: () => _showDebtActions(context, debt),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.12),
            ),
            child: Icon(
              debt.settled ? Icons.check : Icons.person,
              color: color,
              size: 20,
            ),
          ),
          title: Text(
            debt.person,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              decoration: debt.settled ? TextDecoration.lineThrough : null,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                debt.settled
                    ? 'Lunas • ${tanggalPendek(debt.date)}'
                    : '${debt.isReceivable ? 'Utang ke aku' : 'Aku yang utang'}'
                          ' • ${tanggalPendek(debt.date)}',
                style: TextStyle(fontSize: 12, color: muted),
              ),
              if (debt.paid > 0 && !debt.settled) ...[
                const SizedBox(height: 3),
                Text(
                  'Terbayar ${rupiah(debt.paid)} • Sisa ${rupiah(debt.remaining)}',
                  style: TextStyle(fontSize: 11, color: muted),
                ),
              ],
              if (debt.dueDate != null && !debt.settled)
                Text(
                  'Jatuh tempo ${tanggalPendek(debt.dueDate!)}',
                  style: TextStyle(fontSize: 11, color: muted),
                ),
              if (debt.note.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  debt.note,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: muted),
                ),
              ],
            ],
          ),
          trailing: Text(
            rupiah(debt.settled ? debt.amount : debt.remaining),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
              decoration: debt.settled ? TextDecoration.lineThrough : null,
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _showDebtActions(BuildContext context, Debt debt) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => Container(
      decoration: BoxDecoration(
        color: cardColor(sheetContext),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${debt.person} — ${rupiah(debt.amount)}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          if (debt.note.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              debt.note,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: debt.settled
                ? null
                : () {
                    Navigator.pop(sheetContext);
                    _showDebtPaymentSheet(context, debt);
                  },
            icon: const Icon(Icons.payments_outlined, size: 18),
            label: Text(
              debt.isReceivable ? 'Terima Pembayaran' : 'Bayar Utang',
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              final deleted = await sheetContext
                  .read<DebtProvider>()
                  .deleteDebt(debt.id!);
              if (!sheetContext.mounted) return;
              if (deleted) {
                Navigator.pop(sheetContext);
              } else {
                ScaffoldMessenger.of(sheetContext).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Hapus transaksi pembayarannya dulu dari halaman Transaksi',
                    ),
                  ),
                );
              }
            },
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('Hapus'),
            style: OutlinedButton.styleFrom(
              foregroundColor: expenseColor,
              side: BorderSide(color: expenseColor.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    ),
  );
}

Future<void> _showDebtPaymentSheet(BuildContext context, Debt debt) {
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
                debt.isReceivable
                    ? 'Pembayaran dari ${debt.person}'
                    : 'Bayar utang ke ${debt.person}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Sisa ${rupiah(debt.remaining)}',
                style: TextStyle(
                  color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
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
                decoration: InputDecoration(
                  labelText: debt.isReceivable
                      ? 'Masuk ke dompet'
                      : 'Bayar dari dompet',
                  prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                  border: const OutlineInputBorder(),
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
                          if (amount <= 0 || amount > debt.remaining) {
                            ScaffoldMessenger.of(sheetContext).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Nominal harus sesuai sisa utang/piutang',
                                ),
                              ),
                            );
                            return;
                          }
                          final walletProvider = sheetContext
                              .read<WalletProvider>();
                          final wallet = walletProvider.byId(walletId!);
                          if (!debt.isReceivable &&
                              (wallet == null ||
                                  amount > walletProvider.balanceOf(wallet))) {
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
                          final debtProvider = sheetContext
                              .read<DebtProvider>();
                          try {
                            await transactionProvider.payDebt(
                              debt: debt,
                              walletId: walletId!,
                              amount: amount,
                            );
                            await debtProvider.load();
                            if (sheetContext.mounted) {
                              Navigator.pop(sheetContext);
                            }
                          } catch (_) {
                            if (!sheetContext.mounted) return;
                            setSheetState(() => saving = false);
                            ScaffoldMessenger.of(sheetContext).showSnackBar(
                              const SnackBar(
                                content: Text('Pembayaran gagal disimpan'),
                              ),
                            );
                          }
                        },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(saving ? 'Menyimpan...' : 'Simpan Pembayaran'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> _showDebtSheet(BuildContext context) {
  final personController = TextEditingController();
  final amountController = TextEditingController();
  final noteController = TextEditingController();
  var isReceivable = false;
  DateTime? dueDate;

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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Catat Utang/Piutang',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              const SizedBox(height: 16),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Aku yang utang')),
                  ButtonSegment(value: true, label: Text('Orang utang ke aku')),
                ],
                selected: {isReceivable},
                onSelectionChanged: (selection) {
                  setSheetState(() => isReceivable = selection.first);
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: personController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nama orangnya',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  RibuanInputFormatter(),
                ],
                decoration: const InputDecoration(
                  labelText: 'Jumlah',
                  prefixText: 'Rp ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(
                  labelText: 'Catatan (opsional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: sheetContext,
                    initialDate: dueDate ?? DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                  );
                  if (picked != null) setSheetState(() => dueDate = picked);
                },
                icon: const Icon(Icons.event_outlined),
                label: Text(
                  dueDate == null
                      ? 'Tanggal jatuh tempo (opsional)'
                      : 'Jatuh tempo ${tanggalPendek(dueDate!)}',
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () {
                  final person = personController.text.trim();
                  final amount =
                      double.tryParse(
                        amountController.text.replaceAll('.', ''),
                      ) ??
                      0;
                  if (person.isEmpty || amount <= 0) return;
                  sheetContext.read<DebtProvider>().addDebt(
                    Debt(
                      person: person,
                      amount: amount,
                      isReceivable: isReceivable,
                      note: noteController.text.trim(),
                      date: DateTime.now(),
                      dueDate: dueDate,
                    ),
                  );
                  Navigator.pop(sheetContext);
                },
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Simpan'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
