# Duit Ges

Duit Ges adalah aplikasi pencatat keuangan pribadi untuk Android. Transaksi,
budget, target tabungan, utang-piutang, dan pengaturan disimpan lokal di
perangkat tanpa memerlukan akun atau server.

## Fitur utama

- Catatan pemasukan, pengeluaran, dan transfer antar-dompet.
- Budget kategori, pembagian gaji, target tabungan, serta utang-piutang.
- Statistik, pencarian, rekap, ekspor, backup, dan restore data.
- Widget saldo dan riwayat transaksi di layar utama Android.
- Tema bawaan: Klasik 1–5, Kucing, Bebek, dan Call Duck.
- Editor tema untuk warna, background, kartu saldo, serta ikon PNG, JPG, GIF,
  dan video.
- Mode gelap, PIN aplikasi, dan mode privasi yang memblokir screenshot.

## Flavor aplikasi

| Flavor | Isi |
| --- | --- |
| `full` | Seluruh fitur dan tema bawaan. |
| `lite` | Fitur keuangan yang sama dengan pilihan tema bawaan lebih ringkas. |

Kedua flavor memakai application ID dan penyimpanan aplikasi yang sama,
sehingga pengguna dapat memperbarui Full ke Lite atau sebaliknya tanpa
menghapus data.

## Teknologi

- Flutter dan Dart
- Android/Kotlin
- SQLite untuk data utama
- SharedPreferences untuk pengaturan
- FVM untuk mengunci versi Flutter proyek

## Menjalankan proyek

```bash
fvm flutter pub get
fvm flutter run --flavor full
```

Pemeriksaan sebelum commit atau rilis:

```bash
fvm dart format .
fvm flutter analyze
fvm flutter test
fvm flutter test --flavor lite test/lite_flavor_test.dart
```

## Build APK

```bash
fvm flutter build apk --release --flavor full
fvm flutter build apk --release --flavor lite
```

Hasil build tersedia di `build/app/outputs/flutter-apk/`.

## Penandatanganan rilis

Buat upload key satu kali:

```bash
keytool -genkeypair -v -keystore android/app/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias duitges
cp android/key.properties.example android/key.properties
```

Isi `android/key.properties`, lalu simpan keystore dan password di tempat aman.
File signing sudah dikecualikan dari Git. Tanpa keystore yang sama, APK baru
tidak dapat memperbarui instalasi lama.

Sebelum menerbitkan pembaruan, naikkan `version` di `pubspec.yaml` atau gunakan
`scripts/bump_version.sh`. Nilai build number harus selalu lebih tinggi dari
versi yang sudah terpasang.

## Struktur ringkas

```text
lib/                  kode aplikasi Flutter
assets/theme/         aset seluruh tema
android/              integrasi native dan konfigurasi Android
test/                 unit, widget, serta pengujian flavor
scripts/              utilitas pengembangan dan rilis
```

## Privasi data

Data utama tetap berada di perangkat. Aplikasi tidak menyediakan sinkronisasi
cloud otomatis; pengguna mengendalikan sendiri file ekspor dan backup dari
menu Setelan.
