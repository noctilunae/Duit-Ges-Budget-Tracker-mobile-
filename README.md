# Duit Ges

Aplikasi pencatat keuangan pribadi untuk Android. Semua data disimpan lokal
di HP; backup dan export tersedia dari menu **Setelan**.

Dokumentasi teknis dan konteks produk lengkap untuk pengembang/agent ada di
[PROJECT_CONTEXT.md](PROJECT_CONTEXT.md).

## Jalankan saat mengembangkan

```bash
fvm flutter pub get
fvm flutter run
```

## Siapkan kunci rilis sekali saja

```bash
keytool -genkeypair -v -keystore android/app/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias duit-nia
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
`build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`. Kirim lewat
WhatsApp, Google Drive, atau kabel data. Penerima membuka file tersebut lalu
mengizinkan instalasi dari sumber yang dipakai saat Android memintanya.

Untuk Google Play, buat Android App Bundle:

```bash
fvm flutter build appbundle --release
```

Setiap pembaruan perlu menaikkan `version` di `pubspec.yaml`, misalnya dari
`1.0.5+4007` menjadi `1.0.6+4008`.
