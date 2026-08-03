# Peta dokumentasi Duit Ges

Mulai dari file ini saat ingin memahami atau mengubah program.

## Dokumen dan tanggung jawabnya

| Kebutuhan | Baca | Perbarui ketika |
| --- | --- | --- |
| Menjalankan, build, dan membagikan APK | [`README.md`](../README.md) | Perintah build, flavor, signing, atau versioning berubah |
| Memahami produk, invariant, keputusan UI, dan riwayat teknis | [`PROJECT_CONTEXT.md`](../PROJECT_CONTEXT.md) | Perilaku penting, skema, tema, atau keputusan teknis berubah |
| Menemukan lokasi kode dan dampak perubahan | [`PROGRAM_STRUCTURE.md`](PROGRAM_STRUCTURE.md) | Folder, pemilik fitur, alur data, atau cakupan test berubah |
| Mengetahui batas sistem dan risiko yang masih diterima | [`LIMITATIONS.md`](LIMITATIONS.md) | Batas diatasi, bertambah, atau dampaknya berubah |
| Menghapus tema untuk varian lokal | [`THEME_REMOVAL.md`](../THEME_REMOVAL.md) | Daftar tema atau mekanisme flavor/aset berubah |
| Memberi konteks singkat kepada coding agent | [`CLAUDE.md`](../CLAUDE.md) | Aturan kompatibilitas atau verifikasi global berubah |

Jangan menyalin detail yang sama ke banyak file. Tulis detail di dokumen yang
menjadi pemiliknya, lalu tautkan dari dokumen lain.

## Urutan kepercayaan

Jika dokumentasi berbeda dengan implementasi, gunakan urutan berikut:

1. Source code dan konfigurasi yang sedang aktif.
2. Test regresi yang lulus.
3. `PROJECT_CONTEXT.md` sebagai narasi kanonis.
4. Dokumen peta di folder ini.

Perbedaan tersebut tetap harus diperbaiki pada perubahan yang sama agar agent
berikutnya tidak meneruskan informasi lama.

## Pemeriksaan cepat sebelum mulai

```bash
git status --short
rg "schemaVersion" lib/db/database_helper.dart
rg "^version:" pubspec.yaml
rg "id: '" lib/providers/settings_provider.dart
rg "testWidgets?\\(|group\\(" test
```

Tujuannya bukan mengaudit seluruh repo setiap saat, tetapi memastikan fakta
yang mudah berubah tidak diambil dari angka lama di dokumentasi.
