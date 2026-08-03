import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../db/database_helper.dart';
import '../models/budget.dart';
import '../models/category.dart' show categoryColorChoices, categoryIconChoices;
import '../providers/budget_provider.dart';
import '../utils/app_style.dart';
import '../utils/formatters.dart';
import '../utils/stored_icon.dart';
import '../widgets/budget_type_field.dart';
import '../widgets/custom_image_icon_picker.dart';

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
        .where(
          (item) =>
              item.value > 0 &&
              item.name.trim().isNotEmpty &&
              item.iconKey != 'emoji:' &&
              (!item.iconKey.startsWith('image:') ||
                  isValidStoredImageIcon(item.iconKey)),
        )
        .toList();
    if (valid.length != _allocations.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lengkapi nama, ikon, dan jumlah setiap Budget'),
        ),
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
    final allocated = valid.fold<int>(0, (total, item) {
      final amount = item.percentage
          ? (salary * item.value / 100).round()
          : item.value.round();
      return total + amount;
    });
    if (salary <= 0 || allocated > salary) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            salary <= 0
                ? 'Isi nominal gaji terlebih dahulu'
                : 'Total pembagian tidak boleh melebihi nominal gaji',
          ),
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
    await context.read<BudgetProvider>().load();
    if (mounted && close) Navigator.pop(context);
    return mounted;
  }

  Future<void> _save() async {
    await _saveRule(close: true);
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
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                          prefixText: 'Rp ',
                          hintText: '0',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 16,
                          ),
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
  String type = BudgetType.kebutuhan;
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
          BudgetTypeField(
            value: item.type,
            onChanged: (value) {
              item.type = value;
              onChanged();
            },
          ),
          const SizedBox(height: 8),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Ikon Budget'),
            leading: Budget(
              id: '',
              name: '',
              iconKey: item.iconKey,
              color: item.color,
              type: item.type,
              amount: 0,
            ).iconWidget(color: item.color, size: 24),
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'icon', label: Text('Ikon')),
                  ButtonSegment(value: 'emoji', label: Text('Emoji')),
                  ButtonSegment(value: 'image', label: Text('PNG/JPG')),
                ],
                selected: {
                  item.iconKey.startsWith('emoji:')
                      ? 'emoji'
                      : item.iconKey.startsWith('image:')
                      ? 'image'
                      : 'icon',
                },
                onSelectionChanged: (value) {
                  item.iconKey = switch (value.first) {
                    'emoji' => 'emoji:',
                    'image' =>
                      item.iconKey.startsWith('image:')
                          ? item.iconKey
                          : 'image:',
                    _ => 'savings',
                  };
                  onChanged();
                },
              ),
              const SizedBox(height: 8),
              if (item.iconKey.startsWith('emoji:'))
                TextFormField(
                  key: ValueKey('${item.budgetId}-emoji'),
                  initialValue: item.iconKey.substring(6),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 30),
                  decoration: const InputDecoration(
                    labelText: 'Emoji budget',
                    hintText: '🦆',
                  ),
                  onChanged: (value) => item.iconKey = 'emoji:${value.trim()}',
                )
              else if (item.iconKey.startsWith('image:'))
                CustomImageIconPicker(
                  iconKey: item.iconKey,
                  fallbackKey: 'savings',
                  onChanged: (value) {
                    item.iconKey = value;
                    onChanged();
                  },
                )
              else ...[
                GridView.count(
                  crossAxisCount: 7,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  children: [
                    for (final entry in categoryIconChoices.entries)
                      InkWell(
                        onTap: () {
                          item.iconKey = entry.key;
                          onChanged();
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: item.iconKey == entry.key
                                ? item.color.withValues(alpha: .18)
                                : Colors.transparent,
                            border: Border.all(
                              color: item.iconKey == entry.key
                                  ? item.color
                                  : Theme.of(
                                      context,
                                    ).colorScheme.outlineVariant,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(entry.value, color: item.color),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                GridView.count(
                  crossAxisCount: 7,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  children: [
                    for (final color in categoryColorChoices)
                      InkWell(
                        onTap: () {
                          item.color = color;
                          onChanged();
                        },
                        borderRadius: BorderRadius.circular(18),
                        child: CircleAvatar(
                          radius: 15,
                          backgroundColor: color,
                          child: item.color == color
                              ? const Icon(
                                  Icons.check,
                                  size: 17,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: SegmentedButton<bool>(
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
          ),
          const SizedBox(height: 10),
          TextFormField(
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
              labelText: item.percentage
                  ? 'Persentase pembagian'
                  : 'Nominal pembagian',
              suffixText: item.percentage ? '%' : null,
              prefixText: item.percentage ? null : 'Rp ',
            ),
            onChanged: (value) =>
                item.value = double.tryParse(value.replaceAll('.', '')) ?? 0,
          ),
        ],
      ),
    );
  }
}
