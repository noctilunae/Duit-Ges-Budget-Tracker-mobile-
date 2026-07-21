import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Baca foto struk pake ML Kit (on-device, full offline) dan tebak
/// nominal totalnya dari teks yang kebaca.
class ReceiptOcr {
  ReceiptOcr._();

  /// Scan struk → nominal total. Null kalau ga nemu / gagal baca.
  static Future<double?> scanTotal(String imagePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final recognized = await recognizer.processImage(
        InputImage.fromFilePath(imagePath),
      );
      final allLines = [for (final block in recognized.blocks) ...block.lines];
      // Struk biasanya 2 kolom (label kiri, angka kanan) — urutan mentah
      // dari ML Kit ga selalu ngikutin baris fisik struk, makanya
      // disusun ulang pake posisi Y (tinggi) tiap baris di foto dulu.
      final rows = reconstructRows(allLines);
      debugPrint(
        '[ReceiptOcr] ${rows.length} baris (setelah rekonstruksi): $rows',
      );
      final total = parseTotal(rows);
      debugPrint('[ReceiptOcr] tebakan total: $total');
      return total;
    } catch (e, st) {
      debugPrint('[ReceiptOcr] GAGAL scan: $e\n$st');
      return null;
    } finally {
      await recognizer.close();
    }
  }

  /// Gabungin baris-baris teks yang posisinya sebaris secara fisik
  /// (pusat Y berdekatan), urut dari atas ke bawah, dan dalam satu
  /// baris disusun kiri ke kanan — biar label & angkanya nyambung
  /// walau ML Kit ngasihnya dalam blok terpisah.
  @visibleForTesting
  static List<String> reconstructRows(List<TextLine> lines) {
    if (lines.isEmpty) return [];
    final sorted = [...lines]
      ..sort((a, b) => a.boundingBox.top.compareTo(b.boundingBox.top));

    final rows = <List<TextLine>>[];
    for (final line in sorted) {
      final centerY = line.boundingBox.top + line.boundingBox.height / 2;
      final lastRow = rows.isEmpty ? null : rows.last;
      // Toleransi: satu baris dianggap "masih sebaris" kalau pusat-Y-nya
      // masih di dalam separuh tinggi baris terakhir yang udah dikumpulin.
      final threshold = lastRow == null
          ? 0.0
          : (lastRow
                    .map((l) => l.boundingBox.height)
                    .reduce((a, b) => a > b ? a : b)) /
                2;
      final lastCenterY = lastRow == null
          ? 0.0
          : lastRow
                    .map((l) => l.boundingBox.top + l.boundingBox.height / 2)
                    .reduce((a, b) => a + b) /
                lastRow.length;
      if (lastRow != null && (centerY - lastCenterY).abs() <= threshold) {
        lastRow.add(line);
      } else {
        rows.add([line]);
      }
    }

    return [
      for (final row in rows)
        (row..sort((a, b) => a.boundingBox.left.compareTo(b.boundingBox.left)))
            .map((l) => l.text)
            .join(' '),
    ];
  }

  /// Kata kunci baris total, makin spesifik makin tinggi skornya.
  /// (dicek dari yang paling panjang biar "grand total" ga ketangkep
  /// duluan sebagai "total" doang)
  static const _keywordScores = <String, int>{
    'grand total': 100,
    'total bayar': 95,
    'total belanja': 95,
    'total tagihan': 95,
    'harus dibayar': 90,
    'jumlah bayar': 90,
    'amount due': 90,
    'total': 80,
    'jumlah': 60,
    'tagihan': 60,
    'subtotal': 40,
    'sub total': 40,
  };

  /// Baris yang mengandung ini bukan total belanja — uang yang
  /// diserahkan/kembalian/info toko — jadi di-skip total.
  static const _skipWords = [
    'kembali',
    'kembalian',
    'change',
    'tunai',
    'cash',
    'debit',
    'npwp',
    'telp',
    'phone',
    'disc',
    'diskon',
  ];

  /// Versi baris tanpa spasi sama sekali — biar kata kunci tetep
  /// kecocok walau OCR nyisipin spasi nyasar di tengah kata
  /// (misal "Kembalian" kebaca jadi "Kemba lin").
  static String _compact(String line) =>
      line.toLowerCase().replaceAll(RegExp(r'\s+'), '');

  /// Struk dengan kandidat angka lebih banyak dari ini dianggap
  /// "banyak item" — fallback tanpa kata kunci ga dipakai lagi di sini,
  /// soalnya total struk banyak item = JUMLAH semua item, bukan item
  /// termahal (angka terbesar). Mending ngaku ga yakin (null) daripada
  /// pede ngasih tebakan yang keliru.
  static const _maxCandidatesForBlindFallback = 2;

  /// Tebak total dari kumpulan baris teks struk. Pure function biar
  /// gampang diuji. Strategi: baris berkata-kunci menang (skor
  /// tertinggi); kalau ga ada kata kunci sama sekali, fallback ke angka
  /// terbesar — tapi cuma buat struk simpel (sedikit baris berangka).
  static double? parseTotal(List<String> lines) {
    double? best;
    var bestScore = -1;
    var candidateLineCount = 0;

    for (var i = 0; i < lines.length; i++) {
      final compact = _compact(lines[i]);
      if (_skipWords.any(compact.contains)) continue;

      var score = 0;
      for (final entry in _keywordScores.entries) {
        if (compact.contains(entry.key.replaceAll(' ', ''))) {
          score = entry.value;
          break;
        }
      }

      var amounts = _amountsIn(lines[i]);
      // Struk sering misahin label dan angkanya beda baris:
      // "TOTAL" di satu baris, "25.000" di bawahnya.
      if (score > 0 && amounts.isEmpty && i + 1 < lines.length) {
        if (!_skipWords.any(_compact(lines[i + 1]).contains)) {
          amounts = _amountsIn(lines[i + 1]);
        }
      }
      if (amounts.isEmpty) continue;
      candidateLineCount++;

      // Dalam satu baris ambil angka terbesar (nominal biasanya
      // lebih gede dari qty/persen di baris yang sama).
      final candidate = amounts.reduce((a, b) => a > b ? a : b);
      if (score > bestScore ||
          (score == bestScore && candidate > (best ?? 0))) {
        bestScore = score;
        best = candidate;
      }
    }

    // bestScore tetep 0 artinya ga ada SATUPUN baris berkata-kunci total
    // yang ketemu — tebakannya murni "angka terbesar", cuma bisa
    // dipercaya kalau kandidatnya dikit (struk simpel 1-2 item).
    if (bestScore == 0 && candidateLineCount > _maxCandidatesForBlindFallback) {
      best = null;
    }

    // Pengaman silang: baris total sering rusak OCR-nya di struk yang
    // nunjukin tunai & kembalian (baris totalnya jadi ga ke-parse sama
    // sekali, atau lookahead-nya nyasar ke nominal kembalian). Kalau kita
    // gagal nemu tebakan (best null) ATAU tebakan kita ternyata sama
    // persis kayak nominal kembalian (tanda ketuker), hitung ulang dari
    // tunai - kembalian selama dua-duanya kebaca jelas.
    final kembalian = _findLabeledAmount(lines, ['kembali']);
    if (kembalian != null && (best == null || best == kembalian)) {
      final tunai = _findLabeledAmount(lines, ['tunai', 'cash']);
      if (tunai != null && tunai > kembalian) {
        return tunai - kembalian;
      }
    }
    return best;
  }

  /// Cari nominal yang berlabel salah satu [keywords] (misal 'tunai',
  /// 'kembali') — dicek di baris yang sama dulu, baru baris berikutnya.
  static double? _findLabeledAmount(List<String> lines, List<String> keywords) {
    for (var i = 0; i < lines.length; i++) {
      if (!keywords.any(_compact(lines[i]).contains)) continue;
      var amounts = _amountsIn(lines[i]);
      if (amounts.isEmpty && i + 1 < lines.length) {
        amounts = _amountsIn(lines[i + 1]);
      }
      if (amounts.isNotEmpty) return amounts.reduce((a, b) => a > b ? a : b);
    }
    return null;
  }

  /// Ambil semua angka bergaya nominal dari satu baris:
  /// "25.000", "25,000", "Rp 12.345,00", "125000".
  static List<double> _amountsIn(String line) {
    final matches = RegExp(
      r'\d{1,3}(?:[.,]\d{3})+(?:[.,]\d{2})?|\d{3,9}(?:[.,]\d{2})?',
    ).allMatches(line);
    final amounts = <double>[];
    for (final match in matches) {
      var token = match.group(0)!;
      // Buang desimal 2 digit di ujung (",00") terus buang pemisah ribuan
      token = token.replaceFirst(RegExp(r'[.,]\d{2}$'), '');
      token = token.replaceAll(RegExp(r'[.,]'), '');
      final value = int.tryParse(token);
      // < 100 biasanya qty/persen; > 999 juta pasti bukan belanjaan
      if (value != null && value >= 100 && value <= 999999999) {
        amounts.add(value.toDouble());
      }
    }
    return amounts;
  }
}
