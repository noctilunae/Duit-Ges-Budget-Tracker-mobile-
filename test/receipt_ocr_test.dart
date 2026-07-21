import 'dart:math';
import 'dart:ui';

import 'package:duit_ges/services/receipt_ocr.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter_test/flutter_test.dart';

/// Bikin TextLine sintetis dengan posisi (x, y, lebar, tinggi) tertentu
/// — biar reconstructRows bisa diuji tanpa perlu kamera/HP beneran.
TextLine _line(
  String text, {
  required double x,
  required double y,
  double w = 100,
  double h = 30,
}) {
  return TextLine(
    text: text,
    elements: const [],
    boundingBox: Rect.fromLTWH(x, y, w, h),
    recognizedLanguages: const [],
    cornerPoints: const [],
    confidence: null,
    angle: null,
  );
}

/// Uji parser nominal struk (bagian pure-nya OCR — tanpa ML Kit/HP).
void main() {
  group('parseTotal', () {
    test('struk standar: TOTAL sebaris sama angkanya', () {
      expect(
        ReceiptOcr.parseTotal([
          'INDOMARET',
          'AQUA 600ML 2 x 3.500 7.000',
          'ROTI TAWAR 15.500',
          'TOTAL 22.500',
          'TUNAI 50.000',
          'KEMBALI 27.500',
        ]),
        22500,
      );
    });

    test('uang tunai & kembalian ga boleh ketuker sama total', () {
      // Kembalian (27.500+50.000) lebih gede dari total belanja kecil
      expect(
        ReceiptOcr.parseTotal([
          'MIE INSTAN 3.200',
          'TOTAL 3.200',
          'CASH 100.000',
          'KEMBALIAN 96.800',
        ]),
        3200,
      );
    });

    test('label TOTAL terpisah baris dari angkanya', () {
      expect(
        ReceiptOcr.parseTotal(['KOPI SUSU 18.000', 'TOTAL', '18.000']),
        18000,
      );
    });

    test('grand total menang lawan subtotal', () {
      expect(
        ReceiptOcr.parseTotal([
          'SUBTOTAL 90.000',
          'PAJAK 9.900',
          'GRAND TOTAL 99.900',
        ]),
        99900,
      );
    });

    test(
      'tanpa kata kunci, struk simpel (≤2 item): fallback ke angka terbesar',
      () {
        expect(
          ReceiptOcr.parseTotal(['ES TEH 5.000', 'NASI GORENG 25.000']),
          25000,
        );
      },
    );

    test('banyak item TAPI ada baris TOTAL: baris TOTAL tetap menang '
        'walau item lebih mahal dari mana-mana', () {
      expect(
        ReceiptOcr.parseTotal([
          'NASI GORENG 25.000',
          'ES TEH 5.000',
          'AYAM GORENG 18.000',
          'SATE AYAM 22.000',
          'JUS ALPUKAT 15.000',
          'KERUPUK 3.000',
          'TOTAL 88.000',
        ]),
        88000,
      );
    });

    test('banyak item TANPA baris TOTAL: JANGAN nebak item termahal, '
        'lebih baik ngaku ga yakin (null) daripada salah', () {
      // Total asli = jumlah semua item (88.000), BUKAN item termahal
      // (25.000) — kalau di-fallback ke angka terbesar hasilnya
      // keliru jauh, jadi mendingan null (UI nyuruh isi manual).
      expect(
        ReceiptOcr.parseTotal([
          'NASI GORENG 25.000',
          'ES TEH 5.000',
          'AYAM GORENG 18.000',
          'SATE AYAM 22.000',
          'JUS ALPUKAT 15.000',
          'KERUPUK 3.000',
        ]),
        isNull,
      );
    });

    test('banyak item + baris TOTAL rusak, tapi tunai/kembalian kebaca: '
        'tetap ketolong cross-check walau item-nya banyak', () {
      expect(
        ReceiptOcr.parseTotal([
          'NASI GORENG 25.000',
          'ES TEH 5.000',
          'AYAM GORENG 18.000',
          'SATE AYAM 22.000',
          'JUS ALPUKAT 15.000',
          'KERUPUK 3.000',
          'CASH : 100.000',
          'Kemba lin : 12.000',
        ]),
        88000,
      );
    });

    test('format Rp dengan desimal ,00 kebaca bersih', () {
      expect(ReceiptOcr.parseTotal(['TOTAL BAYAR Rp 125.000,00']), 125000);
    });

    test('struk kosong / ga ada angka → null', () {
      expect(ReceiptOcr.parseTotal([]), isNull);
      expect(ReceiptOcr.parseTotal(['TERIMA KASIH', 'SELAMAT DATANG']), isNull);
    });

    test('kata "Kembalian" pecah spasi gara-gara OCR tetep ke-skip', () {
      // Bug asli yang ketemu: "Kembalian" kebaca ML Kit jadi "Kemba lin"
      // (ada spasi nyasar), dulu bikin baris ini lolos ga ke-skip.
      expect(
        ReceiptOcr.parseTotal([
          'TOTAL 23.000',
          'CASH 50.000',
          'Kemba lin :',
          '27.000',
        ]),
        23000,
      );
    });

    test(
      'pengaman silang: baris total rusak total → dihitung dari tunai-kembalian',
      () {
        // Kasus nyata yang ketemu: setelah reconstructRows berhasil
        // nyambungin label+angka sebaris (CASH:50.000, Kembalian:27.000),
        // baris "Grand Total"-nya sendiri tetap rusak OCR character-nya
        // ("irend Total : 7.0" — bukan salah urutan, tapi salah baca
        // huruf/angka) jadi parseTotal ga nemu kandidat sama sekali.
        // Cross-check tunai(50.000) - kembalian(27.000) = 23.000 nolongin.
        expect(
          ReceiptOcr.parseTotal([
            'CASH : 50.000',
            'Kemba lin : 27.000',
            'irend Total : 7.0',
          ]),
          23000,
        );
      },
    );

    test('pengaman silang: tebakan ketuker sama kembalian juga dibenerin', () {
      expect(
        ReceiptOcr.parseTotal([
          'CASH : 50.000',
          'Kemba lin : 27.000',
          'TOTAL 27.000', // parser salah nebak = kembalian
        ]),
        23000,
      );
    });

    test('cross-check ga dipaksain kalau tunai ga kebaca jelas', () {
      // Ga ada baris cash/tunai sama sekali → tetep pakai tebakan asli
      // walau kebetulan match kata kembali di tempat lain (ga ke-skip
      // karena ga ada match kata kunci total di situ, jadi ga masalah).
      expect(ReceiptOcr.parseTotal(['TOTAL 15.000']), 15000);
    });
  });

  group('reconstructRows', () {
    test('baris yang sejajar horizontal digabung, urut kiri ke kanan', () {
      final rows = ReceiptOcr.reconstructRows([
        _line('CASH', x: 0, y: 100),
        _line('50.000', x: 250, y: 102), // Y hampir sama = sebaris
        _line('Subtotal', x: 0, y: 50),
      ]);
      expect(rows, ['Subtotal', 'CASH 50.000']);
    });

    test('baris beda tinggi (Y jauh) tetep dipisah, bukan digabung', () {
      final rows = ReceiptOcr.reconstructRows([
        _line('TOTAL', x: 0, y: 100),
        _line('50.000', x: 250, y: 300), // jauh banget, bukan sebaris
      ]);
      expect(rows, ['TOTAL', '50.000']);
    });

    test('list kosong → list kosong', () {
      expect(ReceiptOcr.reconstructRows([]), isEmpty);
    });

    test('rekonstruksi struk 2 kolom (label kiri, angka kanan berjauhan) '
        'bikin parseTotal nemu angka yang bener', () {
      // Label & nilainya di X jauh beda (kolom kiri vs kanan) tapi
      // tetep satu baris fisik (Y sama) — kasus umum struk kasir.
      final rows = ReceiptOcr.reconstructRows([
        _line('Subtotal :', x: 0, y: 0),
        _line('CASH :', x: 0, y: 40),
        _line('50.000', x: 300, y: 41),
        _line('Kembalian :', x: 0, y: 80),
        _line('27.000', x: 300, y: 81),
        _line('Grand Total :', x: 0, y: 120),
        _line('23.000', x: 300, y: 121),
      ]);
      expect(ReceiptOcr.parseTotal(rows), 23000);
    });
  });

  group('round-trip parseTotal reproducibility', () {
    test('urutan baris acak ga ngubah hasil kalau kata kunci jelas', () {
      final rnd = Random(7);
      final lines = ['TOTAL 45.000', 'AIR MINERAL 5.000', 'TUNAI 50.000']
        ..shuffle(rnd);
      expect(ReceiptOcr.parseTotal(lines), 45000);
    });
  });
}
