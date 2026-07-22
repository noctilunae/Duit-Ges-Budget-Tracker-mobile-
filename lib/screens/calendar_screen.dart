import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/category.dart';
import '../models/transaction.dart';
import '../providers/transaction_provider.dart';
import '../utils/app_style.dart';
import '../utils/formatters.dart';
import '../widgets/month_selector.dart';
import '../widgets/transaction_detail_sheet.dart';

/// Kalender bulanan: sekilas keliatan tanggal mana yang boros.
class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final month = provider.month;
    final grouped = provider.groupedByDay;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // weekday: 1 = Senin ... 7 = Minggu → jumlah slot kosong di awal
    final leadingBlanks = DateTime(month.year, month.month, 1).weekday - 1;
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(title: const Text('Kalender')),
      body: Column(
        children: [
          const MonthSelector(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                for (final label in const [
                  'Sen',
                  'Sel',
                  'Rab',
                  'Kam',
                  'Jum',
                  'Sab',
                  'Min',
                ])
                  Expanded(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 0.72,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
              ),
              itemCount: leadingBlanks + daysInMonth,
              itemBuilder: (context, index) {
                if (index < leadingBlanks) return const SizedBox.shrink();
                final day = index - leadingBlanks + 1;
                final date = DateTime(month.year, month.month, day);
                final txs = grouped[date] ?? const <TransactionModel>[];
                final isToday =
                    date.year == now.year &&
                    date.month == now.month &&
                    date.day == now.day;
                return _DayCell(
                  date: date,
                  transactions: txs,
                  isToday: isToday,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final DateTime date;
  final List<TransactionModel> transactions;
  final bool isToday;

  const _DayCell({
    required this.date,
    required this.transactions,
    required this.isToday,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    // Transfer ga dihitung: itu cuma mindahin duit antar dompet
    double sum(TxType type) => transactions
        .where((t) => t.type == type && !t.isTransfer)
        .fold(0, (total, t) => total + t.amount);
    final expense = sum(TxType.expense);
    final income = sum(TxType.income);

    return InkWell(
      onTap: transactions.isEmpty ? null : () => _showDaySheet(context),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: transactions.isEmpty ? Colors.transparent : cardColor(context),
          borderRadius: BorderRadius.circular(10),
          border: isToday ? Border.all(color: accent, width: 1.5) : null,
        ),
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${date.day}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                color: isToday ? accent : null,
              ),
            ),
            if (expense > 0)
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '-${rupiahSingkat(expense)}',
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: expenseColor,
                  ),
                ),
              ),
            if (income > 0)
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '+${rupiahSingkat(income)}',
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: incomeColor,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showDaySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _DaySheet(date: date, transactions: transactions),
    );
  }
}

/// Daftar transaksi satu hari (muncul pas tanggal di kalender di-tap).
class _DaySheet extends StatelessWidget {
  final DateTime date;
  final List<TransactionModel> transactions;

  const _DaySheet({required this.date, required this.transactions});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return Container(
      decoration: BoxDecoration(
        color: cardColor(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        16 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: muted.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            labelHari(date),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: transactions.length,
              itemBuilder: (context, index) {
                final tx = transactions[index];
                final category = tx.category;
                final isIncome = tx.type == TxType.income;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  onTap: () {
                    Navigator.pop(context);
                    showTransactionDetailSheet(context, tx);
                  },
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: categoryGradient(category.color),
                    ),
                    child: Center(
                      child: category.iconWidget(color: Colors.white, size: 20),
                    ),
                  ),
                  title: Text(
                    category.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: tx.note.isEmpty
                      ? null
                      : Text(
                          tx.note,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                  trailing: Text(
                    '${isIncome ? '+' : '-'}${rupiah(tx.amount)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isIncome ? incomeColor : expenseColor,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
