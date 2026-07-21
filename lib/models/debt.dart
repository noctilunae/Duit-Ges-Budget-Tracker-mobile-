/// Catatan utang/piutang.
/// isReceivable true = piutang (orang utang ke kita),
/// false = utang (kita yang ngutang).
class Debt {
  final int? id;
  final String person;
  final double amount;
  final bool isReceivable;
  final String note;
  final DateTime date;
  final bool settled;
  final double paid;

  const Debt({
    this.id,
    required this.person,
    required this.amount,
    required this.isReceivable,
    this.note = '',
    required this.date,
    this.settled = false,
    this.paid = 0,
  });

  double get remaining => (amount - paid).clamp(0, amount);
  double get fraction => amount == 0 ? 0 : (paid / amount).clamp(0.0, 1.0);

  Map<String, dynamic> toMap() => {
    'id': id,
    'person': person,
    'amount': amount.round(),
    'is_receivable': isReceivable ? 1 : 0,
    'note': note,
    'date': date.toIso8601String(),
    'settled': settled ? 1 : 0,
    'paid': paid.round(),
  };

  factory Debt.fromMap(Map<String, dynamic> map) => Debt(
    id: map['id'] as int?,
    person: map['person'] as String,
    amount: (map['amount'] as num).toDouble(),
    isReceivable: (map['is_receivable'] as int) == 1,
    note: map['note'] as String? ?? '',
    date: DateTime.parse(map['date'] as String),
    settled: (map['settled'] as int? ?? 0) == 1,
    paid: (map['paid'] as num?)?.toDouble() ?? 0,
  );
}
