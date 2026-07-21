import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../db/database_helper.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../providers/transaction_provider.dart';
import '../services/excel_exporter.dart';
import '../utils/app_style.dart';
import '../utils/formatters.dart';
import '../widgets/transaction_detail_sheet.dart';

enum RecapPeriod {
  daily('Harian'),
  weekly('Mingguan'),
  monthly('Bulanan'),
  yearly('Tahunan');

  final String label;
  const RecapPeriod(this.label);
}

class RecapScreen extends StatelessWidget {
  const RecapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const RecapView();
  }
}

class RecapView extends StatefulWidget {
  const RecapView({super.key});

  @override
  State<RecapView> createState() => _RecapViewState();
}

class _RecapViewState extends State<RecapView> {
  RecapPeriod _period = RecapPeriod.monthly;
  DateTimeRange? _range;
  final Set<String> _categoryIds = {};
  List<({DateTime start, double income, double expense, int count})> _reports =
      [];
  bool _loading = true;
  bool _exporting = false;
  int _loadToken = 0;
  int _lastRevision = -1;

  Future<void> _load() async {
    final token = ++_loadToken;
    setState(() => _loading = true);
    final range = _range;
    final result = await DatabaseHelper.instance.recapTotals(
      grouping: RecapGrouping.values.byName(_period.name),
      start: range?.start,
      end: range == null
          ? null
          : DateTime(range.end.year, range.end.month, range.end.day + 1),
      categoryIds: _categoryIds.isEmpty ? null : _categoryIds.toList(),
    );
    if (!mounted || token != _loadToken) return;
    setState(() {
      _reports = result;
      _loading = false;
    });
  }

  Future<void> _chooseRange() async {
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _range,
    );
    if (result == null) return;
    setState(() => _range = result);
    _load();
  }

  Future<void> _chooseCategories() async {
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _CategoryFilter(
        categories: [
          ...expenseCategories,
          ...incomeCategories,
          ...customCategoryRegistry.values,
        ],
        selected: _categoryIds,
      ),
    );
    if (result == null) return;
    setState(() {
      _categoryIds
        ..clear()
        ..addAll(result);
    });
    _load();
  }

  Future<void> _export() async {
    if (_reports.isEmpty || _exporting) return;
    setState(() => _exporting = true);
    try {
      final range = _range;
      final transactions = await DatabaseHelper.instance.recapTransactions(
        start: range?.start,
        end: range == null
            ? null
            : DateTime(range.end.year, range.end.month, range.end.day + 1),
        categoryIds: _categoryIds.isEmpty ? null : _categoryIds.toList(),
      );
      final file = await ExcelExporter.exportTransactions(transactions);
      if (!mounted || file == null) return;
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], text: 'Rekap keuangan Duit Ges'),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Rekap gagal diexport')));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  String _periodName(DateTime start) {
    if (_period == RecapPeriod.daily) return tanggalPendek(start);
    if (_period == RecapPeriod.monthly) return namaBulan(start);
    if (_period == RecapPeriod.yearly) return '${start.year}';
    final end = start.add(const Duration(days: 6));
    return '${start.day} ${bulanPendek(start)} – '
        '${end.day} ${bulanPendek(end)} ${end.year}';
  }

  @override
  Widget build(BuildContext context) {
    final revision = context.watch<TransactionProvider>().revision;
    if (revision != _lastRevision) {
      _lastRevision = revision;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    }

    final income = _reports.fold<double>(
      0,
      (sum, report) => sum + report.income,
    );
    final expense = _reports.fold<double>(
      0,
      (sum, report) => sum + report.expense,
    );
    final transactionCount = _reports.fold<int>(
      0,
      (sum, report) => sum + report.count,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rekap Keuangan'),
        actions: [
          IconButton(
            tooltip: 'Export ke Excel',
            onPressed: _loading || _reports.isEmpty ? null : _export,
            icon: _exporting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.file_download_outlined),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            SegmentedButton<RecapPeriod>(
              expandedInsets: EdgeInsets.zero,
              segments: [
                for (final period in RecapPeriod.values)
                  ButtonSegment(
                    value: period,
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(period.label, maxLines: 1, softWrap: false),
                    ),
                  ),
              ],
              selected: {_period},
              showSelectedIcon: false,
              onSelectionChanged: (selection) {
                setState(() => _period = selection.first);
                _load();
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _FilterField(
                    icon: Icons.calendar_today_outlined,
                    label: _range == null
                        ? 'Semua tanggal'
                        : '${tanggalPendek(_range!.start)} – '
                              '${tanggalPendek(_range!.end)}',
                    onTap: _chooseRange,
                    onClear: _range == null
                        ? null
                        : () {
                            setState(() => _range = null);
                            _load();
                          },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _FilterField(
                    icon: Icons.category_outlined,
                    label: _categoryIds.isEmpty
                        ? 'Semua kategori'
                        : '${_categoryIds.length} kategori',
                    onTap: _chooseCategories,
                    onClear: _categoryIds.isEmpty
                        ? null
                        : () {
                            setState(_categoryIds.clear);
                            _load();
                          },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_loading)
              const SizedBox(
                height: 240,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_reports.isEmpty)
              const _NoData()
            else ...[
              _Summary(
                income: income,
                expense: expense,
                transactionCount: transactionCount,
              ),
              const SizedBox(height: 24),
              const Text(
                'Rincian',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Card(
                margin: EdgeInsets.zero,
                elevation: 0,
                color: cardColor(context),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      for (var index = 0; index < _reports.length; index++) ...[
                        _ReportRow(
                          key: ValueKey(
                            '${_reports[index].start.toIso8601String()}-$_loadToken',
                          ),
                          label: _periodName(_reports[index].start),
                          start: _reports[index].start,
                          end: _periodEnd(_reports[index].start),
                          count: _reports[index].count,
                          income: _reports[index].income,
                          expense: _reports[index].expense,
                          filterStart: _range?.start,
                          filterEnd: _range == null
                              ? null
                              : DateTime(
                                  _range!.end.year,
                                  _range!.end.month,
                                  _range!.end.day + 1,
                                ),
                          categoryIds: _categoryIds.toList(),
                        ),
                        if (index != _reports.length - 1)
                          const Divider(height: 1),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  DateTime _periodEnd(DateTime start) => switch (_period) {
    RecapPeriod.daily => start.add(const Duration(days: 1)),
    RecapPeriod.weekly => start.add(const Duration(days: 7)),
    RecapPeriod.monthly => DateTime(start.year, start.month + 1),
    RecapPeriod.yearly => DateTime(start.year + 1),
  };
}

class _FilterField extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _FilterField({
    required this.icon,
    required this.label,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: cardColor(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Row(
            children: [
              const SizedBox(width: 12),
              Icon(icon, size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              if (onClear != null)
                IconButton(
                  tooltip: 'Hapus filter',
                  onPressed: onClear,
                  icon: const Icon(Icons.close, size: 16),
                )
              else
                const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  final double income;
  final double expense;
  final int transactionCount;

  const _Summary({
    required this.income,
    required this.expense,
    required this.transactionCount,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final net = income - expense;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: cardColor(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Saldo bersih',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Text(
                  '$transactionCount transaksi',
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                rupiah(net),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: net >= 0 ? incomeColor : expenseColor,
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Divider(height: 1),
            const SizedBox(height: 14),
            Row(
              children: [
                _SummaryValue(
                  label: 'Pemasukan',
                  amount: income,
                  color: incomeColor,
                ),
                const SizedBox(width: 16),
                _SummaryValue(
                  label: 'Pengeluaran',
                  amount: expense,
                  color: expenseColor,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;

  const _SummaryValue({
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
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
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              rupiah(amount),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportRow extends StatefulWidget {
  final String label;
  final DateTime start;
  final DateTime end;
  final DateTime? filterStart;
  final DateTime? filterEnd;
  final List<String> categoryIds;
  final int count;
  final double income;
  final double expense;

  const _ReportRow({
    super.key,
    required this.label,
    required this.start,
    required this.end,
    required this.filterStart,
    required this.filterEnd,
    required this.categoryIds,
    required this.count,
    required this.income,
    required this.expense,
  });

  @override
  State<_ReportRow> createState() => _ReportRowState();
}

class _ReportRowState extends State<_ReportRow> {
  bool _expanded = false;
  Future<List<TransactionModel>>? _transactions;

  void _toggle() {
    if (!_expanded) {
      final start = widget.filterStart?.isAfter(widget.start) == true
          ? widget.filterStart!
          : widget.start;
      final end = widget.filterEnd?.isBefore(widget.end) == true
          ? widget.filterEnd!
          : widget.end;
      _transactions ??= DatabaseHelper.instance.recapTransactions(
        start: start,
        end: end,
        categoryIds: widget.categoryIds.isEmpty ? null : widget.categoryIds,
      );
    }
    setState(() => _expanded = !_expanded);
  }

  @override
  Widget build(BuildContext context) {
    final net = widget.income - widget.expense;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            button: true,
            label: _expanded ? 'Tutup detail' : 'Tampilkan detail',
            child: InkWell(
              onTap: _toggle,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    Row(
                      children: [
                        AnimatedRotation(
                          turns: _expanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: const Icon(Icons.expand_more, size: 20),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            widget.label,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          rupiah(net),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: net >= 0 ? incomeColor : expenseColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        const SizedBox(width: 26),
                        Expanded(
                          child: Text(
                            'Masuk  ${rupiahSingkat(widget.income)}',
                            style: TextStyle(fontSize: 11, color: muted),
                          ),
                        ),
                        Text(
                          'Keluar  ${rupiahSingkat(widget.expense)}',
                          style: TextStyle(fontSize: 11, color: muted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            alignment: Alignment.topCenter,
            child: _expanded
                ? FutureBuilder<List<TransactionModel>>(
                    future: _transactions,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: Text('Detail gagal dimuat')),
                        );
                      }
                      if (!snapshot.hasData) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      }
                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(26, 8, 0, 4),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '${widget.count} transaksi',
                                style: TextStyle(fontSize: 11, color: muted),
                              ),
                            ),
                          ),
                          for (final transaction in snapshot.data!)
                            ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.only(left: 20),
                              onTap: () => showTransactionDetailSheet(
                                context,
                                transaction,
                              ),
                              leading: CircleAvatar(
                                radius: 15,
                                backgroundColor: transaction.category.color
                                    .withValues(alpha: 0.15),
                                child: Icon(
                                  transaction.category.icon,
                                  size: 16,
                                  color: transaction.category.color,
                                ),
                              ),
                              title: Text(
                                transaction.note.isEmpty
                                    ? transaction.category.name
                                    : transaction.note,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
                              ),
                              subtitle: Text(
                                '${transaction.category.name} • ${tanggalPendek(transaction.date)}',
                                style: const TextStyle(fontSize: 10),
                              ),
                              trailing: Text(
                                '${transaction.type == TxType.income ? '+' : '-'}${rupiahSingkat(transaction.amount)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: transaction.type == TxType.income
                                      ? incomeColor
                                      : expenseColor,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _NoData extends StatelessWidget {
  const _NoData();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 56),
      child: Column(
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 44,
            color: scheme.primary,
          ),
          const SizedBox(height: 12),
          const Text(
            'Belum ada transaksi',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Ubah filter atau tambahkan transaksi baru.',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _CategoryFilter extends StatefulWidget {
  final List<Category> categories;
  final Set<String> selected;

  const _CategoryFilter({required this.categories, required this.selected});

  @override
  State<_CategoryFilter> createState() => _CategoryFilterState();
}

class _CategoryFilterState extends State<_CategoryFilter> {
  late final Set<String> _selected = {...widget.selected};

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.85,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Pilih Kategori',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(_selected.clear),
                  child: const Text('Reset'),
                ),
                IconButton(
                  tooltip: 'Terapkan',
                  onPressed: () => Navigator.pop(context, _selected),
                  icon: const Icon(Icons.check),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: widget.categories.length,
              itemBuilder: (context, index) {
                final category = widget.categories[index];
                return CheckboxListTile(
                  value: _selected.contains(category.id),
                  secondary: Icon(category.icon, color: category.color),
                  title: Text(category.name),
                  onChanged: (selected) => setState(() {
                    if (selected ?? false) {
                      _selected.add(category.id);
                    } else {
                      _selected.remove(category.id);
                    }
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
