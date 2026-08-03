import 'package:flutter/material.dart';

import 'category.dart';
import '../utils/stored_icon.dart';

abstract final class BudgetType {
  static const kebutuhan = 'kebutuhan';
  static const keinginan = 'keinginan';
  static const tabungan = 'tabungan';
  static const values = [kebutuhan, keinginan, tabungan];
}

enum BudgetScope { type, category }

class Budget {
  const Budget({
    required this.id,
    required this.name,
    required this.iconKey,
    required this.color,
    required this.type,
    required this.amount,
    this.scope = BudgetScope.type,
    this.categoryId,
  });

  final String id;
  final String name;
  final String iconKey;
  final Color color;
  final String type;
  final double amount;
  final BudgetScope scope;
  final String? categoryId;

  TxType get transactionType => scope == BudgetScope.category
      ? categoryById(categoryId!).type
      : type == BudgetType.tabungan
      ? TxType.income
      : TxType.expense;

  String? get emoji =>
      iconKey.startsWith('emoji:') ? iconKey.substring(6) : null;
  IconData get icon => categoryIconChoices[iconKey] ?? Icons.savings_outlined;

  Widget iconWidget({Color? color, double? size}) => storedIconWidget(
    iconKey,
    size: size,
    fallback: emoji == null
        ? Icon(icon, color: color, size: size)
        : Text(emoji!, style: TextStyle(fontSize: size)),
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'icon': iconKey,
    'color': color.toARGB32(),
    'budget_type': type,
    'amount': amount.round(),
    'scope': scope.name,
    'category_id': categoryId,
  };

  factory Budget.fromMap(Map<String, Object?> map) {
    final storedType = map['budget_type'] as String?;
    return Budget(
      id: map['id'] as String,
      name: map['name'] as String,
      iconKey: map['icon'] as String,
      color: Color(map['color'] as int),
      type: BudgetType.values.contains(storedType)
          ? storedType!
          : BudgetType.kebutuhan,
      amount: (map['amount'] as num).toDouble(),
      scope: BudgetScope.values.byName(map['scope'] as String? ?? 'type'),
      categoryId: map['category_id'] as String?,
    );
  }
}
