import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../db/database_helper.dart';
import '../models/budget.dart';
import '../providers/budget_provider.dart';
import '../utils/app_style.dart';
import '../utils/formatters.dart';

class SalaryRuleScreen extends StatefulWidget {
  const SalaryRuleScreen({super.key});

  @override
  State<SalaryRuleScreen> createState() => _SalaryRuleScreenState();
}

class _SalaryRuleScreenState extends State<SalaryRuleScreen> {
  final _db = DatabaseHelper.instance;
  final _salary = TextEditingController();
  final List<_Allocation> _allocations = [];
  DateTime _date = DateTime.now();
  bool _loading = true;
  bool _datePickerOpen = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _salary.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final rows = await _db.salaryAllocations();
    final budgets = {
      for (final budget in await _db.budgets()) budget.id: budget,
    };
    if (rows.isNotEmpty) {
      final now = DateTime.now();
      _date = DateTime(now.year, now.month, rows.first['day'] as int);
      _salary.text = groupRibuan((rows.first['salary'] as int).toString());
      _allocations.addAll(
        rows
            .where((row) => budgets.containsKey(row['budget_id']))
            .map((row) => _Allocation.fromMap(row, budgets[row['budget_id']]!)),
      );
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickDate() async {
    if (_datePickerOpen) return;
    _datePickerOpen = true;
    try {
      final picked = await showDatePicker(
        context: context,
        initialDate: _date,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
        selectableDayPredicate: (date) => date.day <= 28,
        helpText: 'Pilih tanggal pembagian tiap bulan',
      );
      if (picked != null && mounted) setState(() => _date = picked);
    } finally {
      _datePickerOpen = false;
    }
  }

  Future<bool> _saveRule({required bool close}) async {
    final salary = int.tryParse(_salary.text.replaceAll('.', '')) ?? 0;
    final valid = _allocations
        .where((item) => item.value > 0 && item.name.trim().isNotEmpty)
        .toList();
    if (valid.length != _allocations.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lengkapi nama dan jumlah setiap Budget')),
      );
      return false;
    }
    if (valid.any((item) => item.percentage && item.value > 100) ||
        valid.map((item) => item.name.trim().toLowerCase()).toSet().length !=
            valid.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Budget harus unik dan persen maksimal 100'),
        ),
      );
      return false;
    }
    if (valid.any((item) => item.percentage) && salary <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Isi nominal gaji untuk pembagian persen'),
        ),
      );
      return false;
    }
    try {
      final savedBudgets = {
        for (final budget in await _db.budgets()) budget.id: budget,
      };
      for (final item in valid) {
        await _db.saveBudget(
          Budget(
            id: item.budgetId,
            name: item.name.trim(),
            iconKey: item.iconKey,
            color: item.color,
            type: item.type,
            amount: savedBudgets[item.budgetId]?.amount ?? 0,
          ),
        );
      }
      await _db.saveSalaryAllocations([
        for (final item in valid)
          {
            'budget_id': item.budgetId,
            'amount': item.percentage ? null : item.value.round(),
            'percentage': item.percentage ? item.value : null,
            'salary': salary,
            'day': _date.day,
          },
      ]);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pembagian gaji gagal disimpan')),
        );
      }
      return false;
    }
    if (!mounted) return false;
    await context.read<BudgetProvider>().load(applyRules: false);
    if (mounted && close) Navigator.pop(context);
    return mounted;
  }

  Future<void> _save() async {
    await _saveRule(close: true);
  }

  Future<void> _testRule() async {
    final budgetProvider = context.read<BudgetProvider>();
    if (!await _saveRule(close: false) || !mounted) return;
    final applied = await _db.applySalaryAllocations(DateTime.now(), true);
    await budgetProvider.load(applyRules: false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          applied
              ? 'Rule berhasil diterapkan sekarang'
              : 'Belum ada pembagian untuk dites',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pembagian Gaji Bulanan')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardColor(context),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: cardShadow(context),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.calendar_month_outlined),
                        title: const Text('Tanggal penerapan'),
                        subtitle: Text(
                          'Setiap tanggal ${_date.day}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _pickDate,
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _salary,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          RibuanInputFormatter(),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Nominal gaji',
                          prefixText: 'Rp ',
                          helperText: 'Dasar perhitungan pembagian persen',
                        ),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(4, 20, 4, 10),
                  child: Text(
                    'Budget Tujuan',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                for (var i = 0; i < _allocations.length; i++)
                  _AllocationCard(
                    key: ObjectKey(_allocations[i]),
                    item: _allocations[i],
                    onChanged: () => setState(() {}),
                    onDelete: () => setState(() => _allocations.removeAt(i)),
                  ),
                const SizedBox(height: 4),
                OutlinedButton.icon(
                  onPressed: () =>
                      setState(() => _allocations.add(_Allocation())),
                  icon: const Icon(Icons.add),
                  label: const Text('Tambah Pembagian'),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _testRule,
                  icon: const Icon(Icons.science_outlined),
                  label: const Text('Terapkan Sekarang (Testing)'),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _save,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: const Text('Simpan Rule'),
                ),
                const SizedBox(height: 8),
                Text(
                  'Budget dibuat langsung dari pembagian ini dan diterapkan sekali setiap bulan.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
    );
  }
}

class _Allocation {
  _Allocation()
    : budgetId = 'salary_${DateTime.now().microsecondsSinceEpoch}',
      color = const Color(0xFF2E5BFF);

  String budgetId;
  String name = '';
  BudgetType type = BudgetType.kebutuhan;
  String iconKey = 'savings';
  Color color;
  bool percentage = true;
  double value = 0;

  factory _Allocation.fromMap(Map<String, Object?> map, Budget budget) =>
      _Allocation()
        ..budgetId = budget.id
        ..name = budget.name
        ..type = budget.type
        ..iconKey = budget.iconKey
        ..color = budget.color
        ..percentage = map['percentage'] != null
        ..value = ((map['percentage'] ?? map['amount']) as num).toDouble();
}

class _AllocationCard extends StatelessWidget {
  const _AllocationCard({
    super.key,
    required this.item,
    required this.onChanged,
    required this.onDelete,
  });

  final _Allocation item;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: cardShadow(context),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: item.name,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Nama Budget'),
                  onChanged: (value) => item.name = value,
                ),
              ),
              IconButton(
                tooltip: 'Hapus pembagian',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<BudgetType>(
            initialValue: item.type,
            decoration: const InputDecoration(labelText: 'Tipe Budget'),
            items: [
              for (final type in BudgetType.values)
                DropdownMenuItem(value: type, child: Text(_typeLabel(type))),
            ],
            onChanged: (value) {
              if (value == null) return;
              item.type = value;
              item.iconKey = value == BudgetType.tabungan
                  ? 'savings'
                  : 'wallet';
              onChanged();
            },
          ),
          Row(
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('%')),
                  ButtonSegment(value: false, label: Text('Rp')),
                ],
                selected: {item.percentage},
                onSelectionChanged: (value) {
                  item.percentage = value.first;
                  item.value = 0;
                  onChanged();
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  key: ValueKey('${item.percentage}-${item.value}'),
                  initialValue: item.value == 0
                      ? ''
                      : item.percentage
                      ? '${item.value.round()}'
                      : groupRibuan(item.value.round().toString()),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    if (!item.percentage) RibuanInputFormatter(),
                  ],
                  decoration: InputDecoration(
                    labelText: item.percentage ? 'Persentase' : 'Nominal',
                    suffixText: item.percentage ? '%' : null,
                    prefixText: item.percentage ? null : 'Rp ',
                  ),
                  onChanged: (value) => item.value =
                      double.tryParse(value.replaceAll('.', '')) ?? 0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _typeLabel(BudgetType type) => switch (type) {
  BudgetType.kebutuhan => 'Kebutuhan',
  BudgetType.keinginan => 'Keinginan',
  BudgetType.tabungan => 'Tabungan',
};
