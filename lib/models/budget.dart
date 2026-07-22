import 'package:flutter/material.dart';

import 'category.dart';

enum BudgetType { kebutuhan, keinginan, tabungan }

class Budget {
  const Budget({
    required this.id,
    required this.name,
    required this.iconKey,
    required this.color,
    required this.type,
    required this.amount,
  });

  final String id;
  final String name;
  final String iconKey;
  final Color color;
  final BudgetType type;
  final double amount;

  String? get emoji =>
      iconKey.startsWith('emoji:') ? iconKey.substring(6) : null;
  IconData get icon => categoryIconChoices[iconKey] ?? Icons.savings_outlined;

  Widget iconWidget({Color? color, double? size}) => emoji == null
      ? Icon(icon, color: color, size: size)
      : Text(emoji!, style: TextStyle(fontSize: size));

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'icon': iconKey,
    'color': color.toARGB32(),
    'budget_type': type.name,
    'amount': amount.round(),
  };

  factory Budget.fromMap(Map<String, Object?> map) => Budget(
    id: map['id'] as String,
    name: map['name'] as String,
    iconKey: map['icon'] as String,
    color: Color(map['color'] as int),
    type:
        BudgetType.values.asNameMap()[map['budget_type']] ??
        BudgetType.kebutuhan,
    amount: (map['amount'] as num).toDouble(),
  );
}
