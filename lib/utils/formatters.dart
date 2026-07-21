import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

final _rupiah = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp ',
  decimalDigits: 0,
);

String rupiah(double amount) => _rupiah.format(amount);

String namaBulan(DateTime month) =>
    DateFormat('MMMM yyyy', 'id_ID').format(month);

String tanggalPendek(DateTime date) =>
    DateFormat('d MMM yyyy', 'id_ID').format(date);

String tanggalLengkap(DateTime date) =>
    DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(date);

String jamPendek(DateTime date) => DateFormat('HH:mm').format(date);

String bulanPendek(DateTime date) => DateFormat('MMM', 'id_ID').format(date);

/// Nyegat ketikan di TextField dan otomatis nyisipin titik ribuan
/// gaya Indonesia: ngetik 50000 → tampil 50.000.
class RibuanInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll('.', '');
    // Buang nol di depan (misal "0500" jadi "500"), sisain satu nol doang.
    digits = digits.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    if (digits.isEmpty) return const TextEditingValue(text: '');
    final formatted = groupRibuan(digits);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Sisipin titik tiap 3 digit dari belakang: "1250000" → "1.250.000".
String groupRibuan(String digits) {
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// Angka super singkat buat ruang sempit (cell kalender):
/// 50000 → "50rb", 1250000 → "1,2jt", 2000000000 → "2M".
String rupiahSingkat(double amount) {
  String trim(double value) {
    final rounded = (value * 10).round() / 10;
    return rounded == rounded.roundToDouble()
        ? '${rounded.round()}'
        : '$rounded'.replaceAll('.', ',');
  }

  if (amount >= 1e9) return '${trim(amount / 1e9)}M';
  if (amount >= 1e6) return '${trim(amount / 1e6)}jt';
  if (amount >= 1e3) return '${trim(amount / 1e3)}rb';
  return amount.round().toString();
}

/// "Hari Ini", "Kemarin", atau "Senin, 14 Jul 2026".
String labelHari(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final thatDay = DateTime(date.year, date.month, date.day);
  final diff = today.difference(thatDay).inDays;
  if (diff == 0) return 'Hari Ini';
  if (diff == 1) return 'Kemarin';
  return DateFormat('EEEE, d MMM yyyy', 'id_ID').format(date);
}
