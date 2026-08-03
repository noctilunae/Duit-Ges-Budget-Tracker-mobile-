import 'package:flutter/material.dart';

import '../models/budget.dart';

String budgetTypeLabel(String type) => type
    .trim()
    .split(RegExp(r'\s+'))
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');

class BudgetTypeField extends StatelessWidget {
  const BudgetTypeField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    const options = BudgetType.values;
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Tipe Budget'),
      items: [
        for (final type in options)
          DropdownMenuItem(
            value: type,
            child: Text(
              budgetTypeLabel(type),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (type) {
        if (type != null) onChanged(type);
      },
    );
  }
}
