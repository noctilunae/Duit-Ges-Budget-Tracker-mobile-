import 'category.dart';

class TransactionModel {
  final int? id;
  final double amount;
  final String categoryId;
  final String note;
  final DateTime date;
  final TxType type;
  final int walletId;

  /// Path file foto struk di storage app (null = ga ada foto).
  final String? receiptPath;
  final String? sourceType;
  final int? sourceId;
  final String? budgetId;

  const TransactionModel({
    this.id,
    required this.amount,
    required this.categoryId,
    this.note = '',
    required this.date,
    required this.type,
    this.walletId = 1,
    this.receiptPath,
    this.sourceType,
    this.sourceId,
    this.budgetId,
  });

  Category get category => categoryById(categoryId);

  bool get isTransfer => isTransferCategory(categoryId);
  bool get isGoalSaving => categoryId == 'tabungan_target';
  bool get isManagedPayment => isGoalSaving || sourceType != null;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount.round(),
      'category_id': categoryId,
      'note': note,
      'date': date.toIso8601String(),
      'type': type.name,
      'wallet_id': walletId,
      'receipt_path': receiptPath,
      'source_type': sourceType,
      'source_id': sourceId,
      'budget_id': budgetId,
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'] as int?,
      amount: (map['amount'] as num).toDouble(),
      categoryId: map['category_id'] as String,
      note: map['note'] as String? ?? '',
      date: DateTime.parse(map['date'] as String),
      type: TxType.values.byName(map['type'] as String),
      walletId: map['wallet_id'] as int? ?? 1,
      receiptPath: map['receipt_path'] as String?,
      sourceType: map['source_type'] as String?,
      sourceId: map['source_id'] as int?,
      budgetId: map['budget_id'] as String?,
    );
  }
}
