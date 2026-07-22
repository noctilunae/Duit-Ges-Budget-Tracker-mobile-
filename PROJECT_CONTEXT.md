# Duit Ges — konteks lengkap aplikasi

Dokumen ini adalah sumber konteks kanonis untuk pengembang dan agent yang akan
melanjutkan aplikasi. Perbarui dokumen ini ketika perilaku penting, skema data,
tema, integrasi Android, atau alur build berubah.

Terakhir diperbarui: **22 Juli 2026**. Audit penuh terakhir: 21 Juli 2026.

## 1. Identitas dan prinsip produk

- Nama produk dan label launcher: **Duit Ges**.
- Package Dart: `duit_ges`.
- Android application ID/namespace tetap `com.noctilune.duitnia`. Jangan ganti
  tanpa rencana migrasi karena Android akan menganggapnya aplikasi berbeda.
- Versi saat audit: `1.0.5+4007`.
- Target platform: Android. Tidak ada implementasi iOS/web/desktop produksi.
- Fungsi utama: pencatatan keuangan pribadi yang mudah dipakai, bertema, dan
  berjalan offline.
- Data utama disimpan lokal di SQLite. Tidak ada akun, server, sinkronisasi,
  analytics, atau cloud database.
- Bahasa UI dan komentar kode dominan bahasa Indonesia santai.
- Locale tanggal dan angka: `id_ID`; nominal ditampilkan dengan `rupiah()` atau
  `rupiahSingkat()` dari `lib/utils/formatters.dart`.

## 2. Peta fitur dan navigasi

`MainShell` memiliki empat tab bawah yang state-nya dipertahankan:

1. **Transaksi/Home**
   - Ringkasan saldo, pemasukan, dan pengeluaran pada periode aktif.
   - Periode bulanan dapat dimulai tanggal 1–28, bukan hanya bulan kalender.
   - Filter dompet, pindah bulan, cari, kalender, daftar transaksi per hari.
   - Tambah/edit/hapus transaksi dan lampiran foto struk.
   - Transfer antar dompet.
2. **Budget**
   - Subtab Pos Budget, Target tabungan, dan Utang/Piutang.
   - Pos budget berdiri sendiri dari kategori transaksi dan dapat diatur nama,
     ikon/emoji, warna, nominal, serta tipe kebutuhan/keinginan/tabungan.
   - Transaksi dapat ditambahkan dari detail pos budget. Relasi `budget_id`
     bersifat opsional dan tidak mengubah kategori transaksi aslinya.
   - Rule pembagian gaji di Setelan memilih pos budget tujuan, tanggal bulanan,
     serta persentase atau nominal. Setiap periode hanya diterapkan sekali.
   - Setoran target memotong saldo dompet dan membuat transaksi pengeluaran;
     menghapus transaksi tersebut mengurangi progres target kembali.
   - Utang/piutang mendukung pembayaran bertahap dari/ke dompet. Setiap
     pembayaran menjadi transaksi dan dapat dibatalkan dengan menghapusnya.
   - Catatan utang/piutang hanya dapat diselesaikan melalui **Bayar Utang** atau
     **Terima Pembayaran**. Nominal dibatasi sebesar sisa kewajiban/piutang.
3. **Statistik**
   - Distribusi kategori dan tren bulanan.
   - Rentang tren dapat diatur 1–12 bulan.
   - Label persentase pie di bawah 10% sengaja tidak ditampilkan.
   - Rekap keuangan dibuka dari halaman statistik.
   - Setiap periode pada Rekap dapat dibuka melalui dropdown untuk melihat dan
     membuka detail transaksi penyusunnya; transaksi baru dimuat saat dibuka.
4. **Setelan**
   - Tema, tone, warna, font, dark mode, gaya kartu saldo.
   - Tanggal awal periode, jumlah bulan tren, sembunyikan nominal.
   - Mode privasi Android untuk memblokir screenshot dan preview recent apps.
   - Reminder harian, PIN, transaksi berulang, kelola struk.
   - Import/export Excel, backup/restore lengkap, dan auto-backup.

Layar pendukung berada di `lib/screens/`: pencarian, kalender, dompet,
transaksi berulang, struk, lock screen, tambah transaksi, dan rekap.

## 3. Arsitektur runtime

### Entry point dan state

`lib/main.dart` menginisialisasi data locale Indonesia lalu memasang Provider:

- `SettingsProvider`: preferensi dan tema.
- `CategoryProvider`: kategori custom dan kategori yang disorot.
- `TransactionProvider`: transaksi periode aktif, total, pengelompokan, revisi.
- `BudgetProvider`, `GoalProvider`, `DebtProvider`, `RecurringProvider`.
- `WalletProvider`: daftar dompet dan saldo setiap dompet.

`TransactionProvider` adalah `ChangeNotifierProxyProvider2` terhadap kategori
dan setelan agar nama kategori custom serta tanggal awal periode selalu sinkron.
`WalletProvider` adalah proxy terhadap revisi transaksi agar saldo diperbarui
sesudah mutasi transaksi.

`MainShell` memakai stack yang mempertahankan halaman. `TickerMode` mematikan
animasi pada tab yang tidak aktif; `LoopingAssetVideo` juga pause/resume mengikuti
status ini agar video kartu tidak terus memakai CPU/baterai di belakang layar.

### Lapisan kode

- `lib/models/`: model sederhana dan konversi map SQLite.
- `lib/db/database_helper.dart`: seluruh akses SQLite, transaksi atomik,
  migrasi, backup, dan restore.
- `lib/providers/`: state UI dan koordinasi database.
- `lib/screens/`: halaman dan bottom sheet.
- `lib/services/`: Excel, OCR, reminder, backup otomatis, widget Android.
- `lib/widgets/`: komponen visual bersama dan artwork tema.
- `lib/utils/`: format angka/tanggal dan style bersama.
- `android/app/src/main/`: integrasi launcher, widget, dan notifikasi Android.

Tidak ada repository/domain layer terpisah. Ini disengaja: aplikasi cukup kecil,
dan `DatabaseHelper + Provider` adalah jalur paling sederhana saat ini.

## 4. Database dan aturan data

Database: `duit_ges.db`, dikelola oleh `sqflite`.

`DatabaseHelper.schemaVersion` saat ini **13**. Aturan mutlak ketika mengubah
skema:

1. Naikkan `schemaVersion`.
2. Tambahkan blok `if (oldVersion < N)` baru di `onUpgrade`.
3. Sesuaikan `onCreate`.
4. Jangan mengubah arti migrasi lama.
5. Tambahkan test migrasi dari versi sebelumnya.

### Tabel

| Tabel | Fungsi dan kolom penting |
| --- | --- |
| `transactions` | `amount INTEGER`, kategori, catatan, waktu ISO, tipe, dompet, path struk, `source_type/source_id`, `budget_id` opsional |
| `budgets` | pos budget mandiri: nama, ikon, warna, tipe, dan nominal |
| `wallets` | nama, icon, warna, `initial_balance INTEGER` |
| `goals` | target tabungan, nilai terkumpul, warna, ikon/emoji custom |
| `debts` | utang/piutang, orang, nominal, `paid`, catatan, tanggal, jatuh tempo opsional, status lunas |
| `custom_categories` | nama, icon, warna, tipe pemasukan/pengeluaran |
| `recurrings` | template transaksi bulanan, hari, jatuh tempo berikut, status aktif |
| `salary_allocations` | rule bulanan per pos budget dan penanda periode terakhir |

Semua nominal database sejak v8 adalah integer rupiah. Model/UI masih memakai
`double` untuk kompatibilitas API, tetapi nilai ditulis dengan `round()`.

Index transaksi yang tersedia:

- `idx_tx_date`
- `idx_tx_wallet`
- `idx_tx_category`

### Invariant penting

- `TxType` hanya `income` atau `expense`.
- Transfer antar dompet ditulis atomik sebagai dua baris:
  `transfer_keluar` (expense) dan `transfer_masuk` (income).
- Kategori transfer tidak masuk statistik global, budget, tren, maupun rekap.
- Menghapus satu sisi transfer ikut menghapus pasangan terdekat dalam transaksi
  database yang sama.
- Data transfer lama belum memiliki `transfer_group_id`; pasangan saat ini
  dicari melalui waktu, nominal, catatan, kategori lawan, dan ID terdekat. Ini
  adalah batasan kompatibilitas yang diketahui.
- Menghapus dompet/kategori ditolak bila masih dipakai oleh transaksi **atau
  transaksi berulang**.
- Setoran target memakai transaksi SQLite atomik: `goals.saved` bertambah dan
  transaksi kategori `tabungan_target` dibuat. Pembayaran utang/piutang juga
  atomik terhadap `debts.paid`. Keduanya memakai `source_type/source_id`, tidak
  dapat diedit biasa, dan saat dihapus progres terkait dikurangi dalam transaksi
  database yang sama. Menghapus target menghapus transaksi setorannya dalam
  operasi atomik agar saldo dompet kembali konsisten. UI menolak pengeluaran di
  atas saldo dompet.
- Penerapan transaksi berulang idempoten. `next_due` maju dalam transaksi DB
  yang sama dan ada lock Future agar dua pemanggilan paralel tidak menduplikasi.
- Bila aplikasi lama tidak dibuka, transaksi berulang melakukan catch-up untuk
  semua bulan yang terlewat.
- Rule pembagian gaji memakai `last_period` dan transaksi SQLite agar setiap
  periode hanya diterapkan sekali. Rule hanya menyentuh kategori yang diatur.
- Penghapusan/update transaksi membersihkan file struk hanya jika file tersebut
  tidak lagi direferensikan transaksi lain.

## 5. Query dan strategi performa

Keputusan performa yang sudah diterapkan:

- Daftar home hanya memuat satu periode aktif, bukan seluruh riwayat.
- Pencarian SQLite dibatasi 200 hasil, memakai debounce dan sequence token agar
  hasil query lama tidak menimpa query/filter terbaru.
- `TransactionProvider` memakai revision dan cache untuk pengelompokan per hari
  serta total kategori.
- Request load memakai token agar respons async usang diabaikan.
- `WalletProvider` mengabaikan revisi lama dan tidak menghitung ulang jika tidak
  perlu.
- Statistik tren memakai agregasi SQL dan cache Future sesuai revisi/rentang.
- Rekap layar memakai `SUM/COUNT/GROUP BY` di SQLite melalui `recapTotals()`;
  row mentah hanya dimuat ketika pengguna menekan export.
- Widget Android memperoleh saldo/pemasukan/pengeluaran melalui satu query
  `widgetSummary()`, dan menghormati `monthStartDay`.
- GIF dibungkus `RepaintBoundary` agar frame tidak mengecat ulang seluruh layar.
- Video dekoratif di-pause saat tab tidak aktif dan selalu mute.
- Foto struk memakai ukuran decode yang dibatasi pada tampilan daftar.

Jangan mengganti agregasi SQL menjadi load semua row + loop Dart tanpa alasan
dan benchmark. Untuk operasi massal, gunakan batch atau transaksi SQLite.

### Batas performa yang masih diketahui

- Export Excel harus memuat transaksi yang dipilih dan membangun workbook di
  proses Flutter; riwayat yang sangat besar masih dapat menyebabkan jeda.
- Perubahan transaksi memicu agregasi `walletFlows()` sepanjang tabel. Query ini
  sudah ringkas (`GROUP BY`), tetapi tetap bertambah biaya sesuai ukuran tabel.
- Asset tema sekitar puluhan MB dan sebagian GIF/video besar. Jangan autoplay
  animasi yang tidak terlihat.
- Beberapa PNG identik sengaja dipertahankan di folder tema berbeda agar aset
  tiap tema bisa diganti independen. Hapus hanya jika terbukti tidak direferensi.

## 6. Rekap, statistik, export, dan import

### Rekap

- UI rekap memakai komponen Material standar agar konsisten di semua tema;
  tidak memakai mascot/dekorasi custom.
- Pilihan: Harian, Mingguan, Bulanan, Tahunan.
- Filter: rentang tanggal dan satu atau lebih kategori.
- Ringkasan: saldo bersih, pemasukan, pengeluaran, jumlah transaksi.
- Pengelompokan dilakukan SQLite; minggu dimulai Senin.
- Tombol export memakai filter aktif dan membagikan file `.xlsx`.

### Excel

`ExcelExporter` menghasilkan sheet:

- `Transaksi`
- `Harian`
- `Mingguan`
- `Bulanan`
- `Tahunan`

Kolom transaksi: Tanggal, Jam, Tipe, Kategori, Dompet, Jumlah, Catatan.

`ExcelImporter` mengimpor sheet `Transaksi` (atau sheet pertama sebagai
fallback), mendukung format lama tanpa kolom Dompet, mencocokkan nama kategori
dan dompet, lalu menggunakan fallback kategori “Lainnya”/dompet pertama jika
tidak cocok. Import hanya menambah transaksi; tidak mengimpor budget, target,
utang, preferensi, atau struk.

## 7. Backup, restore, struk, dan keamanan

- Backup lengkap memakai ZIP berekstensi `.duitges` yang berisi `duit_ges.db`
  dan file `struk/` yang masih direferensikan.
- Restore menerima backup ZIP baru atau file database SQLite lama.
- Sebelum mengganti database, restore memeriksa ZIP, SQLite integrity, tabel
  transaksi, dan versi schema. Database lama disimpan sementara agar kegagalan
  dapat dipulihkan.
- Auto-backup berjalan paling cepat setiap 7 hari dan mempertahankan 4 backup.
- Foto struk dapat diambil dari kamera/galeri. OCR lokal memakai Google ML Kit
  text recognition untuk menebak total; hasil tetap harus dikonfirmasi user.
- Kategori custom dan dompet dapat memakai ikon Material berwarna atau emoji
  full-color dari keyboard HP. Emoji disimpan di kolom `icon` dengan prefix
  `emoji:` dan ikut disinkronkan ke pilihan pada widget Android.
- `android:allowBackup="false"` mencegah backup Android otomatis.
- Mode privasi memanggil channel native `duit_ges/privacy` untuk memasang
  `FLAG_SECURE`. Fitur ini memblokir screenshot/screen recording dan preview
  recent apps selama aktif, tetapi hanya diterapkan pada build Android.
- PIN disimpan sebagai SHA-256 dengan prefix aplikasi, bukan teks polos. Namun
  database tidak terenkripsi dan hash PIN bukan password-hardening. PIN adalah
  pengunci kenyamanan UI, bukan perlindungan forensik terhadap perangkat yang
  sudah dikuasai pihak lain.

## 8. Integrasi Android

- Label launcher: `Duit Ges` di `AndroidManifest.xml`.
- Namespace/application ID: `com.noctilune.duitnia`; source Kotlin berada di
  `android/app/src/main/kotlin/com/noctilune/duitnia/` agar path dan package
  tidak berbeda.
- Toolchain Android memakai Java/Kotlin 17. Nilai compile/target/min SDK
  mengikuti versi yang disediakan Flutter di Gradle.
- Launcher icon: `@mipmap/ic_launcher`, sumber generator
  `assets/icon/icon.png` melalui `flutter_launcher_icons`.
- Widget native: `SaldoWidgetProvider.kt`, dipasok data oleh
  `lib/services/widget_service.dart` melalui `home_widget`.
- Widget mengikuti hide balance, aksen tema, dan periode gajian
  `monthStartDay`.
- Widget berukuran sekitar 4×6 dan bersifat interaktif: tipe pengeluaran/
  pemasukan, kategori favorit/halaman kategori, dompet, keypad nominal, hapus,
  reset, dan Simpan tersedia tanpa membuka aplikasi.
- Keypad memakai tombol `RemoteViews`, bukan `EditText`. Tombol Simpan menulis
  row transaksi langsung ke database SQLite dan menghitung ulang ringkasan
  widget. Aplikasi melakukan reload saat kembali ke foreground.
- Tema widget mengikuti gradient dan aksen tema Home. Ikon kategori dan dompet
  dirender dari code point, warna, dan font Material Icons yang sama dengan
  aplikasi; kategori, favorit, serta daftar dompet disinkronkan saat konfigurasi
  berubah.
- Favorit kategori widget mengikuti urutan favorit form transaksi. Kategori
  bawaan maupun custom dapat dihapus bila tidak sedang dipakai transaksi,
  atau transaksi berulang; kategori bawaan disembunyikan lewat
  preferensi agar riwayat lama tetap dapat menampilkan identitas kategorinya.
- Widget ringkas 4×1 memiliki tombol centang yang membuka daftar lima transaksi
  terakhir, mencakup pemasukan dan pengeluaran. Tombol tambah membuka aplikasi.
- Quick save dinonaktifkan ketika PIN aktif agar widget tidak melewati lock
  screen. Foto struk, catatan bebas, pengaturan tanggal, transfer, dan utang/
  piutang tetap dikerjakan di aplikasi karena membutuhkan input yang tidak
  didukung `RemoteViews`.
- Reminder harian memakai `flutter_local_notifications`, timezone perangkat,
  dan dijadwalkan ulang setelah reboot/update paket.
- Fitur widget, reminder, kamera/OCR, launcher icon, share sheet, dan codec video
  wajib diuji juga pada perangkat Android fisik; unit/widget test tidak cukup.

## 9. Sistem tema dan aset

Tema didefinisikan sebagai `ThemePreset`/`ThemeTone` di
`lib/providers/settings_provider.dart`.

Preset saat ini, sesuai urutan picker:

1. `klasik`
2. `kucing` (tone pink/biru/kuning)
3. `bebek` (tone kuning/biru/pink)
4. `call_duck`
5. `anya`
6. `jjk` / label JJK 1
7. `frieren`
8. `frieren_rial` / label Frieren Rial
9. `spongebob`
10. `jjk2` / label JJK 2
11. `matcha`

Font lokal: Jakarta Sans, Fredoka, Baloo 2, Quicksand.

Gaya kartu saldo: Gradient, Neon, Glass, Minimal, dua video JJK, empat video
Frieren Rial (135–138), dan Call Duck. Video Frieren Rial hanya tersedia serta dipilih otomatis
pada tema Frieren Rial; kartu video JJK hanya tersedia untuk JJK 2 dan kartu
Call Duck hanya untuk tema Call Duck. Provider mengembalikan gaya eksklusif ke
Gradient ketika tema tidak cocok.

Frieren Rial mempunyai enam template background eksklusif. Template `Default`
memakai gradient berbeda sesuai tone footer halaman aktif. Template `Eclipse`
memakai `assets/theme/frieren_rial/background_eclipse.jpg`, sedangkan `Journey`
memakai `background_journey.jpg`. Tiga template lain adalah `Meadow`, `Lotus`,
dan `Blue Sky`.
Foto background memakai gradient bawah ringan. Surface kartu dan footer tetap
memakai formula `ColorScheme` serta background preset yang sama dengan tema
lain agar seimbang pada mode terang maupun gelap. Pilihan
disimpan sebagai `frierenRialBackground` dan aset background baru dimuat oleh
`MainShell` saat tema tersebut aktif.
Footer Frieren Rial memakai PNG statis `footer_transaksi`, `footer_budget`,
`footer_statistik`, dan `footer_setelan`; kartu saldo memakai video eksklusif,
kontrol nominal memakai `visibility.png`, dan FAB memakai `add_transaction.gif`
dengan badge plus tone halaman di kanan atas.
Tema Frieren dan Frieren Rial mempunyai panah di samping judul Dompet untuk
slide-collapse strip dompet tanpa menghapus data atau memengaruhi tema lain.
Mode privasi memakai channel native `duit_ges/privacy` dan Android
`FLAG_SECURE` untuk memblokir screenshot serta preview aplikasi di recent apps.

### Kontrak `ThemeArtwork`

Nomor tile adalah API internal dan jangan ditukar sembarangan:

| Tile | Nama aset |
| ---: | --- |
| 0 | `mascot_utama` |
| 1 | `header_home` |
| 2 | `footer_transaksi_frieren` |
| 3 | `header_setelan` |
| 4 | `konten_budget` |
| 5 | `footer_budget` |
| 6 | `footer_transaksi_default` |
| 7 | `header_budget` |
| 8 | `header_statistik` |
| 9 | `footer_statistik` |
| 10 | `footer_transaksi_jjk` |
| 11 | `konten_target` |
| 12 | `footer_setelan_frieren` |
| 13 | `footer_setelan_jjk` |
| 14 | `footer_setelan` |
| 15 | `footer_setelan_jjk2` |

`tileGifs` dapat menimpa tile tertentu. `footerGifManualControl` membuat footer
memakai PNG statis sampai tombol play di bawah FAB ditekan. GIF diberi
`RepaintBoundary`; PNG statis memiliki fallback khusus di `ThemeArtwork`.

### Keputusan visual yang harus dipertahankan

- JJK 1 dan JJK 2 berdampingan di picker.
- JJK 2 memakai aksen per tab: Gojo biru, Sukuna merah, Yuta ungu, Yuji oranye.
- Frieren dan SpongeBob juga mempunyai warna per tab/subtab sesuai karakter.
- Call Duck tidak memakai `mascot_utama` pada empty state/home. File GIF mascot
  duplikat yang tidak terpakai sudah dihapus pada audit 19 Juli 2026.
- Add transaction Call Duck memakai aset statis ketika animasi belum dimainkan.
- Kartu saldo Call Duck memiliki overlay tambahan agar tulisan tetap terbaca.
- Footer dibuat menyatu ke tengah dengan transisi/garis yang lembut.
- UI utang/piutang menaruh deskripsi di baris terpisah.
- Rekap sengaja bersih dan netral supaya tidak rusak di tema/font berbeda.

Ketika menambah/mengganti asset:

- Daftarkan folder/file melalui `pubspec.yaml` bila belum tercakup.
- Pertahankan transparansi dan hilangkan garis/background putih dari sumber.
- Gunakan PNG terkompres/quantized untuk gambar statis jika kualitas memadai.
- Jangan mengubah GIF menjadi autoplay global tanpa mempertimbangkan baterai.
- Perubahan aset memerlukan stop dan run/build ulang; hot reload tidak selalu
  memperbarui cache asset atau launcher icon.

## 10. Preferensi tersimpan

`SettingsProvider` memakai `SharedPreferences`. Key penting mencakup:

- `themeId`, `themeTone_<themeId>`, `accent`, `darkMode`
- `cardStyle`, `font`, `monthStartDay`, `trendMonths`
- `hideBalance`, `hideWallets`, `privacyMode`
- `frierenRialBackground`
- `pinHash`
- `reminderEnabled`, `reminderHour`, `reminderMinute`
- `autoBackupEnabled`

Jangan mengganti nama key tanpa fallback/migrasi karena pengguna lama akan
kehilangan konfigurasi.

## 11. Dependency utama

- State/database: `provider`, `sqflite`, `path`, `path_provider`.
- Format/chart: `intl`, `fl_chart`.
- Preferensi/keamanan lokal: `shared_preferences`, `crypto`.
- Data portabel: `excel`, `archive`, `share_plus`, `file_selector`.
- Media: `image_picker`, `google_mlkit_text_recognition`, `video_player`.
- Android: `flutter_local_notifications`, `timezone`, `flutter_timezone`,
  `home_widget`.

Audit 21 Juli 2026 tidak menemukan dependency `pubspec.yaml` yang benar-benar
tidak dipakai. Jangan menambah package bila SDK/Dart/Flutter sudah cukup.

## 12. Test dan verifikasi

Test berada di `test/`:

- `widget_test.dart`: model, formatter, setting/theme, aset, decode GIF, dan
  perhitungan tanggal recurring.
- `receipt_ocr_test.dart`: banyak variasi teks struk dan pemilihan total.
- `export_import_test.dart`: database skala ribuan transaksi, import/export,
  agregasi rekap/widget, transfer, setoran target, guard recurring, backup.
- `database_migration_test.dart`: migrasi v7 ke v9, pembulatan nominal, dan
  penambahan relasi pembayaran.

Checklist tiap perubahan kode:

```bash
/home/noctilune/fvm/versions/3.44.6/bin/dart format lib test
/home/noctilune/fvm/versions/3.44.6/bin/flutter analyze
/home/noctilune/fvm/versions/3.44.6/bin/flutter test
```

Build debug:

```bash
/home/noctilune/fvm/versions/3.44.6/bin/flutter build apk --debug
```

Build release terpisah per ABI:

```bash
/home/noctilune/fvm/versions/3.44.6/bin/flutter build apk --release --split-per-abi
```

APK modern biasanya
`build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.

Regenerasi launcher icon setelah mengubah `assets/icon/icon.png`:

```bash
/home/noctilune/fvm/versions/3.44.6/bin/flutter pub run flutter_launcher_icons
/home/noctilune/fvm/versions/3.44.6/bin/flutter clean
/home/noctilune/fvm/versions/3.44.6/bin/flutter pub get
/home/noctilune/fvm/versions/3.44.6/bin/flutter build apk --debug
```

Uninstall APK lama mungkin diperlukan bila launcher vendor masih menyimpan cache
icon. Jangan mengubah `applicationId` untuk memaksa icon berubah.

### Verifikasi manual perangkat fisik

1. Tambah/edit/hapus transaksi dan transfer; cek kedua saldo dompet.
2. Setor target; cek saldo dompet, progress target, dan riwayat transaksi.
3. Buat recurring jatuh tempo; tutup/buka app dan pastikan tidak dobel.
4. Ambil foto struk dan cek OCR serta penghapusan file.
5. Export/import Excel dan share sheet.
6. Backup, tambah data, restore, lalu cek data dan foto struk.
7. Reminder sebelum/sesudah reboot.
8. Widget setelah ganti tema, hide balance, transaksi, kategori favorit, dompet,
   dan tanggal awal periode; uji semua tombol keypad, pergantian kategori/dompet,
   Save saat app tertutup, serta penolakan Save ketika PIN aktif.
9. Semua tema light/dark; khususnya GIF manual dan video JJK 2.
10. Launcher icon pada home screen dan app drawer.
11. Panah Dompet pada Frieren/Frieren Rial; pastikan state tersimpan dan tema
    lain tidak ikut menyembunyikan strip dompet.
12. Mode privasi aktif/nonaktif; uji screenshot, screen recording, dan preview
    recent apps pada perangkat Android fisik.

## 13. Audit pemborosan dan ambiguitas 21 Juli 2026

Audit mencakup file Dart/Kotlin, query SQLite, dependency, aset, isi Git,
analyzer, test, dan build. Hasil terpenting:

- `build/`, `.dart_tool/`, metadata IDE, plugin registrant hasil generate, dan
  file lokal Android sebelumnya ikut terlacak Git. Sekitar **22.022 file hasil
  generate** sudah dilepas dari index Git tanpa menghapus cache lokal.
- `.gitignore` sekarang mencakup output Flutter/Dart, cache Gradle/Kotlin, file
  signing, metadata IDE/OS, log, dan konfigurasi agent lokal.
- Empat ikon di `assets/icon/` yang tidak direferensikan telah dihapus:
  `icon_fg.png`, `icon_pg.png`, `placeholder.png`, dan `placeholderan.png`.
  `assets/icon/icon.png` tetap menjadi satu-satunya sumber launcher icon.
- Lokasi source Kotlin dipindahkan dari path package lama
  `com/example/duit_ges` ke `com/noctilune/duitnia`; deklarasi package dan
  perilaku runtime tidak berubah.
- Semua dependency langsung di `pubspec.yaml` mempunyai import aktif. Tidak ada
  package yang aman dihapus hanya berdasarkan audit statis.
- Query utama sudah dibatasi atau diagregasi: home per periode, pencarian
  maksimal 200 hasil, rekap/tren/widget melalui SQL agregat. Tidak ditemukan
  query duplikat yang aman dihapus tanpa mengubah perilaku.

Perbaikan runtime dari audit sebelumnya yang tetap berlaku:

- Membatalkan hasil pencarian async lama ketika query/filter dikosongkan.
- Menghindari reload transaksi bila filter dompet dipilih ulang tanpa perubahan.
- Mencegah kategori/dompet dihapus ketika masih dipakai recurring.
- Mengganti rekap dari load seluruh transaksi menjadi agregasi SQL.
- Menunda load row mentah rekap sampai tombol export ditekan.
- Mengganti beberapa query widget menjadi satu query agregasi dan mengikuti
  `monthStartDay`.
- Pause video kartu pada tab yang tidak terlihat.
- Menghapus parameter/method recurring edit yang belum pernah digunakan.
- Menghapus satu GIF Call Duck besar yang byte-identik, tidak direferensikan,
  dan bertentangan dengan keputusan “tanpa mascot utama”.
- Menambah test regresi untuk agregasi rekap/widget dan guard recurring.

Setelah pembersihan, repository melacak sekitar **277 file sumber**. Folder aset
berisi 162 file dengan ukuran sekitar **37,4 MB**. Kontributor terbesar adalah
ML Kit OCR di binary native serta video/GIF aktif milik JJK 2, Frieren, Frieren
Rial, dan Call Duck. Media tidak dikompres secara buta karena perubahan codec,
alpha, frame rate, atau warna harus dibandingkan di perangkat fisik.

Baseline APK release arm64-v8a terakhir sekitar **72 MB**. APK debug/universal
lebih besar dan tidak boleh dipakai sebagai ukuran distribusi.

### Kebersihan Git

File sumber konfigurasi seperti `.fvmrc`, `pubspec.lock`, dan
`android/key.properties.example` harus tetap dilacak. Sebaliknya, jangan paksa
menambahkan file yang sudah diabaikan; semuanya dapat dibuat ulang oleh
`flutter pub get` atau proses build.

Pembersihan index di atas mencegah pemborosan baru setelah perubahan di-commit,
tetapi folder `.git` lokal masih sekitar **1,3 GB** karena blob build tersimpan
di riwayat lama. Mengecilkannya memerlukan rewrite history dengan
`git filter-repo`/BFG, backup, dan koordinasi ulang semua clone. Operasi
destruktif tersebut sengaja tidak dilakukan dalam audit ini.

## 14. Panduan aman untuk agent berikutnya

Sebelum mengubah kode:

1. Baca dokumen ini dan file yang benar-benar terkait.
2. Cari pemakaian dengan `rg`; jangan menilai aset “unused” hanya dari nama.
3. Catat invariant transfer, target, recurring, dan migrasi database.
4. Pilih perubahan terkecil yang menyelesaikan masalah.

Setelah mengubah kode:

1. Perbarui test regresi yang relevan.
2. Jalankan format, analyze, seluruh test, lalu build bila menyentuh Android,
   dependency, atau aset.
3. Perbarui dokumen ini bila kontrak atau perilaku penting berubah.
4. Laporkan apa yang tetap perlu diuji di HP fisik.

Known limitations yang jangan disembunyikan:

- Database dan foto struk tidak terenkripsi.
- `FLAG_SECURE` untuk mode privasi hanya tersedia pada Android.
- Transfer lama dipasangkan dengan heuristik, belum `group_id` eksplisit.
- Excel besar masih dapat menahan UI saat workbook dibangun.
- UI/media Android tertentu tidak dapat divalidasi penuh oleh test host.
- Ukuran APK dipengaruhi kuat oleh asset animasi/video tema.
- Riwayat Git lama masih membawa blob hasil build sampai dilakukan rewrite
  history terencana.
- Build Flutter 3.44.6 masih berhasil, tetapi mengeluarkan warning bahwa plugin
  `flutter_timezone`, `google_mlkit_*`, dan `home_widget` masih menerapkan Kotlin
  Gradle Plugin sendiri. Sebelum upgrade Flutter berikutnya, cek versi plugin
  yang mendukung Built-in Kotlin dan uji build Android kembali.
