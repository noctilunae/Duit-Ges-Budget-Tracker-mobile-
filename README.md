# Duit Ges

Aplikasi pencatat keuangan pribadi untuk Android. Semua data disimpan lokal
di HP; backup dan export tersedia dari menu **Setelan**.

## Build Android

- Full: `fvm flutter build apk --release --flavor full`
- Lite: `fvm flutter build apk --release --flavor lite`

Full dan Lite memakai application ID serta data aplikasi yang sama. Jalankan
`scripts/bump_version.sh` sebelum menerbitkan update agar `versionCode` selalu
lebih tinggi dari APK yang sudah terpasang.
Lite memuat tema Kucing, Bebek, Call Duck, serta editor Custom penuh dengan
profil tema bernama dan berikon yang dapat ditambah berkali-kali. OCR dan model
ML Kit hanya dibundel pada flavor Full.
Ikon profil custom mendukung PNG/JPG, GIF transparan, dan video terkompresi
tanpa audio dengan preview 1–5 detik.
Empat ikon footer juga dapat memakai GIF/video custom per tema dan dikendalikan
bersama melalui tombol play/stop di bawah tombol tambah transaksi.

Peta dokumentasi untuk memahami struktur, batasan, dan dampak perubahan ada di
[docs/README.md](docs/README.md).

## Jalankan saat mengembangkan

```bash
fvm flutter pub get
fvm flutter run
```

## Siapkan kunci rilis sekali saja

```bash
keytool -genkeypair -v -keystore android/app/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias duitges
cp android/key.properties.example android/key.properties
```

Isi password yang tadi dibuat di `android/key.properties`. Simpan kedua file
itu di tempat aman; tanpa kunci yang sama, versi berikutnya tidak bisa
memperbarui aplikasi yang sudah terpasang.

## Buat APK untuk dibagikan

```bash
fvm flutter test
fvm flutter analyze
fvm flutter build apk --release --split-per-abi
```

Kebanyakan HP modern memakai file
`build/app/outputs/flutter-apk/app-arm64-v8a-full-release.apk`. Kirim lewat
WhatsApp, Google Drive, atau kabel data. Penerima membuka file tersebut lalu
mengizinkan instalasi dari sumber yang dipakai saat Android memintanya.

Setiap pembaruan perlu menaikkan `version` di `pubspec.yaml`, misalnya dari
`1.0.5+4007` menjadi `1.0.6+4008`.
