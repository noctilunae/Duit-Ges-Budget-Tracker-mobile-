import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/category.dart';
import '../models/transaction.dart';
import '../providers/transaction_provider.dart';
import '../providers/debt_provider.dart';
import '../providers/goal_provider.dart';
import '../providers/wallet_provider.dart';
import '../screens/add_transaction_screen.dart';
import '../utils/app_style.dart';
import '../utils/formatters.dart';
import 'animated_widgets.dart';

/// Buka detail transaksi sebagai bottom sheet (modal slide dari bawah).
Future<void> showTransactionDetailSheet(
  BuildContext context,
  TransactionModel transaction,
) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => TransactionDetailSheet(transaction: transaction),
  );
}

/// Satu jalur hapus buat home, budget, dan detail transaksi.
Future<bool> confirmDeleteTransaction(
  BuildContext context,
  TransactionModel transaction,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Hapus transaksi?'),
      content: Text(
        '${transaction.category.name} — ${rupiah(transaction.amount)}',
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
  if (confirmed != true || !context.mounted) return false;
  final transactionProvider = context.read<TransactionProvider>();
  final goalProvider = transaction.isGoalSaving
      ? context.read<GoalProvider>()
      : null;
  final debtProvider = transaction.sourceType == 'debt'
      ? context.read<DebtProvider>()
      : null;
  try {
    await transactionProvider.deleteTransaction(transaction.id!);
    await goalProvider?.load();
    await debtProvider?.load();
    return true;
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Transaksi gagal dihapus')));
    }
    return false;
  }
}

class TransactionDetailSheet extends StatelessWidget {
  final TransactionModel transaction;

  const TransactionDetailSheet({super.key, required this.transaction});

  Future<void> _delete(BuildContext context) async {
    if (await confirmDeleteTransaction(context, transaction) &&
        context.mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final category = transaction.category;
    final isIncome = transaction.type == TxType.income;
    final amountColor = isIncome ? incomeColor : expenseColor;

    return Container(
      decoration: BoxDecoration(
        color: cardColor(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        12,
        24,
        24 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: categoryGradient(category.color),
              boxShadow: [
                BoxShadow(
                  color: category.color.withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(category.icon, color: Colors.white, size: 34),
          ),
          const SizedBox(height: 12),
          Text(
            category.name,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: amountColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isIncome ? 'Pemasukan' : 'Pengeluaran',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: amountColor,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${isIncome ? '+' : '-'}${rupiah(transaction.amount)}',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: amountColor,
            ),
          ),
          if (transaction.receiptPath != null) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(
                File(transaction.receiptPath!),
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
                // Decode secukupnya buat preview, jangan full resolusi
                cacheWidth: 800,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _DetailRow(
                  icon: Icons.calendar_today,
                  label: 'Tanggal',
                  value: tanggalLengkap(transaction.date),
                ),
                _DetailRow(
                  icon: Icons.schedule,
                  label: 'Jam',
                  value: jamPendek(transaction.date),
                ),
                _DetailRow(
                  icon: Icons.wallet,
                  label: 'Dompet',
                  value:
                      context
                          .watch<WalletProvider>()
                          .byId(transaction.walletId)
                          ?.name ??
                      '—',
                ),
                _DetailRow(
                  icon: Icons.notes,
                  label: 'Catatan',
                  value: transaction.note.isEmpty ? '—' : transaction.note,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (transaction.isManagedPayment)
            Text(
              transaction.isGoalSaving
                  ? 'Menghapus transaksi ini juga mengurangi progres target.'
                  : 'Menghapus transaksi ini juga membatalkan pembayaran utang/piutang.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _delete(context),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Hapus'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: expenseColor,
                    side: BorderSide(
                      color: expenseColor.withValues(alpha: 0.5),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              // Transfer ga bisa diedit satuan (dia sepasang keluar-masuk),
              // cuma bisa dihapus terus dibikin ulang.
              if (!transaction.isTransfer && !transaction.isManagedPayment) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        slideUpRoute(
                          AddTransactionScreen(existing: transaction),
                        ),
                      );
                    },
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: muted),
          const SizedBox(width: 12),
          // Lebar label disamain semua baris (Tanggal/Jam/Dompet/Catatan)
          // biar kolom value mulai sejajar, ga geser-geser per baris.
          SizedBox(
            width: 64,
            child: Text(label, style: TextStyle(fontSize: 13, color: muted)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
