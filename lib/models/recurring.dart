import 'category.dart';

/// Transaksi berulang bulanan (gaji, tagihan, cicilan).
/// Tiap tanggal [day], transaksi otomatis dibikin dari template ini.
class Recurring {
  final int? id;
  final double amount;
  final String categoryId;
  final int walletId;
  final String note;
  final TxType type;

  /// Tanggal jatuh tempo tiap bulan (1-31, otomatis mentok ke
  /// tanggal terakhir buat bulan yang lebih pendek).
  final int day;

  /// Kapan berikutnya transaksi harus dibikin.
  final DateTime nextDue;
  final bool active;

  const Recurring({
    this.id,
    required this.amount,
    required this.categoryId,
    this.walletId = 1,
    this.note = '',
    required this.type,
    required this.day,
    required this.nextDue,
    this.active = true,
  });

  Category get category => categoryById(categoryId);

  /// Jatuh tempo pertama dari sekarang: bulan ini kalau tanggalnya
  /// belum lewat, kalau udah lewat berarti bulan depan.
  static DateTime firstDue(int day) {
    final now = DateTime.now();
    final thisMonth = _clampedDate(now.year, now.month, day);
    final today = DateTime(now.year, now.month, now.day);
    if (!thisMonth.isBefore(today)) return thisMonth;
    return _clampedDate(now.year, now.month + 1, day);
  }

  /// Jatuh tempo berikutnya setelah [current]: bulan depannya,
  /// selalu dihitung dari [day] asli (biar tanggal 31 balik lagi
  /// ke 31 setelah lewat Februari).
  static DateTime nextDueAfter(DateTime current, int day) {
    return _clampedDate(current.year, current.month + 1, day);
  }

  static DateTime _clampedDate(int year, int month, int day) {
    // Hari terakhir bulan itu = hari ke-0 bulan berikutnya
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, day > lastDay ? lastDay : day);
  }

  Recurring copyWith({bool? active, DateTime? nextDue}) {
    return Recurring(
      id: id,
      amount: amount,
      categoryId: categoryId,
      walletId: walletId,
      note: note,
      type: type,
      day: day,
      nextDue: nextDue ?? this.nextDue,
      active: active ?? this.active,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount.round(),
      'category_id': categoryId,
      'wallet_id': walletId,
      'note': note,
      'type': type.name,
      'day': day,
      'next_due': nextDue.toIso8601String(),
      'active': active ? 1 : 0,
    };
  }

  factory Recurring.fromMap(Map<String, dynamic> map) {
    return Recurring(
      id: map['id'] as int?,
      amount: (map['amount'] as num).toDouble(),
      categoryId: map['category_id'] as String,
      walletId: map['wallet_id'] as int? ?? 1,
      note: map['note'] as String? ?? '',
      type: TxType.values.byName(map['type'] as String),
      day: map['day'] as int,
      nextDue: DateTime.parse(map['next_due'] as String),
      active: (map['active'] as int? ?? 1) == 1,
    );
  }
}
