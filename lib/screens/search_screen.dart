import 'dart:async';

import 'package:flutter/material.dart';

import '../db/database_helper.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../utils/app_style.dart';
import '../utils/formatters.dart';
import '../widgets/transaction_detail_sheet.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  List<TransactionModel> _results = [];
  bool _searched = false;
  Timer? _debounce;
  // Filter tambahan: rekap per kategori dan/atau rentang tanggal —
  // jalan juga tanpa kata kunci.
  Category? _filterCategory;
  DateTimeRange? _filterRange;
  // Nomor urut tiap query — jaga-jaga hasil query lama (lambat) numpuk
  // nimpa hasil query baru yang udah lebih dulu selesai.
  int _searchSeq = 0;

  bool get _hasFilter => _filterCategory != null || _filterRange != null;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String query) {
    _debounce?.cancel();
    final q = query.trim();
    if (q.isEmpty && !_hasFilter) {
      _searchSeq++;
      setState(() {
        _results = [];
        _searched = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), _search);
  }

  Future<void> _search() async {
    final q = _controller.text.trim();
    if (q.isEmpty && !_hasFilter) return;
    final seq = ++_searchSeq;
    // Kategori yang namanya nyocok sama kata kunci ikut kena —
    // termasuk kategori custom, bukan cuma yang bawaan.
    final matchingIds = [...allCategories, ...customCategoryRegistry.values]
        .where((c) => c.name.toLowerCase().contains(q.toLowerCase()))
        .map((c) => c.id)
        .toList();
    final range = _filterRange;
    final results = await DatabaseHelper.instance.search(
      q,
      matchingIds,
      categoryId: _filterCategory?.id,
      start: range?.start,
      // end dari picker itu inklusif (sampe akhir hari itu) → geser sehari.
      end: range == null
          ? null
          : DateTime(range.end.year, range.end.month, range.end.day + 1),
    );
    if (!mounted || seq != _searchSeq) return;
    setState(() {
      _results = results;
      _searched = true;
    });
  }

  Future<void> _pickCategory() async {
    final all = [
      ...expenseCategories,
      ...incomeCategories,
      ...customCategoryRegistry.values,
    ];
    final picked = await showModalBottomSheet<Category>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          for (final category in all)
            ListTile(
              leading: Icon(category.icon, color: category.color),
              title: Text(category.name),
              trailing: Text(
                category.type == TxType.income ? 'Masuk' : 'Keluar',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                ),
              ),
              onTap: () => Navigator.pop(sheetContext, category),
            ),
        ],
      ),
    );
    if (picked == null) return;
    setState(() => _filterCategory = picked);
    _search();
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _filterRange,
    );
    if (picked == null) return;
    setState(() => _filterRange = picked);
    _search();
  }

  void _clearFilter({bool category = false, bool range = false}) {
    setState(() {
      if (category) _filterCategory = null;
      if (range) _filterRange = null;
    });
    _onChanged(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          onChanged: _onChanged,
          decoration: const InputDecoration(
            hintText: 'Cari catatan atau kategori...',
            border: InputBorder.none,
          ),
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _controller.clear();
                _onChanged('');
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                _FilterChip(
                  icon: Icons.category_outlined,
                  label: _filterCategory?.name ?? 'Kategori',
                  active: _filterCategory != null,
                  onTap: _pickCategory,
                  onClear: () => _clearFilter(category: true),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  icon: Icons.date_range,
                  label: _filterRange == null
                      ? 'Tanggal'
                      : '${tanggalPendek(_filterRange!.start)} — '
                            '${tanggalPendek(_filterRange!.end)}',
                  active: _filterRange != null,
                  onTap: _pickRange,
                  onClear: () => _clearFilter(range: true),
                ),
              ],
            ),
          ),
          Expanded(child: _buildResults(context)),
        ],
      ),
    );
  }

  Widget _buildResults(BuildContext context) {
    return !_searched
        ? Center(
            child: Text(
              'Ketik buat nyari transaksi',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          )
        : _results.isEmpty
        ? Center(
            child: Text(
              'Ga ketemu :(',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _results.length,
            itemBuilder: (context, index) {
              final tx = _results[index];
              final category = tx.category;
              final isIncome = tx.type == TxType.income;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: cardColor(context),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: cardShadow(context),
                ),
                child: ListTile(
                  onTap: () => showTransactionDetailSheet(
                    context,
                    tx,
                  ).then((_) => _search()),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: categoryGradient(category.color),
                    ),
                    child: Icon(category.icon, color: Colors.white, size: 20),
                  ),
                  title: Text(
                    category.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    tx.note.isEmpty
                        ? tanggalPendek(tx.date)
                        : '${tx.note} • ${tanggalPendek(tx.date)}',
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
                ),
              );
            },
          );
  }
}

/// Chip filter di bawah kolom cari: tap buat milih, tap X buat ngehapus.
class _FilterChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const _FilterChip({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: InputChip(
        avatar: Icon(icon, size: 16),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        selected: active,
        showCheckmark: false,
        onPressed: onTap,
        onDeleted: active ? onClear : null,
      ),
    );
  }
}
