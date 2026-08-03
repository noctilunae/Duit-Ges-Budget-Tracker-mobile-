# Struktur dan peta perubahan program

Dokumen ini menjawab dua pertanyaan: **kode fitur berada di mana** dan **apa
yang harus ikut diperiksa ketika fitur tersebut berubah**. Detail perilaku
produk dan invariant panjang tetap berada di
[`PROJECT_CONTEXT.md`](../PROJECT_CONTEXT.md).

## 1. Batas sistem

Duit Ges adalah aplikasi Flutter untuk Android dengan data utama lokal.
Struktur runtime-nya sengaja pendek:

```text
lib/main.dart
  └─ Provider global
      ├─ screens/widgets ── membaca state dan mengirim aksi
      ├─ providers ──────── koordinasi state, cache, dan refresh
      ├─ DatabaseHelper ─── SQLite, transaksi atomik, migrasi, backup
      └─ services ───────── OCR, Excel, reminder, auto-backup, widget

SharedPreferences ───────── preferensi UI dan konfigurasi ringan
File aplikasi ───────────── foto struk, ikon custom, backup
Kode Kotlin/Android ─────── widget home, FLAG_SECURE, notifikasi
```

Tidak ada backend, akun, repository layer, atau domain layer terpisah.
`DatabaseHelper + Provider` adalah jalur utama yang harus ditelusuri.

Pengecualian penting: widget Android dapat menulis transaksi langsung ke
SQLite dari Kotlin. Perubahan kontrak tabel `transactions`, kategori, dompet,
atau key sinkronisasi widget wajib dicek di sisi Dart **dan** Kotlin.

## 2. Alur saat aplikasi berjalan

### Startup

1. [`lib/main.dart`](../lib/main.dart) memuat locale `id_ID`.
2. `MultiProvider` membuat settings, kategori, transaksi, budget, target,
   utang, recurring, dan dompet.
3. `TransactionProvider` menerima perubahan kategori dan tanggal awal periode.
4. `WalletProvider` menerima revision transaksi untuk menghitung ulang saldo.
5. Setelah settings siap, root menampilkan `LockScreen` bila PIN aktif atau
   `MainShell` bila sudah terbuka.
6. [`MainShell`](../lib/screens/main_shell.dart) mempertahankan empat tab:
   Transaksi, Budget, Statistik, dan Setelan.

### Mutasi transaksi biasa

```text
Screen
  → TransactionProvider
  → DatabaseHelper
  → SQLite
  → reload periode aktif + revision
  → WalletProvider menghitung saldo
  → WidgetService memperbarui widget Android
```

Transfer, setoran target, pembayaran utang/piutang, dan recurring memiliki
aturan tambahan di `DatabaseHelper`; jangan memindahkan atomisitasnya ke UI.

### Data yang tidak lewat TransactionProvider

- Budget dan rule gaji: `BudgetProvider → DatabaseHelper`.
- Target metadata: `GoalProvider → DatabaseHelper`; setoran tetap melalui
  `TransactionProvider`.
- Utang/piutang metadata: `DebtProvider → DatabaseHelper`; pembayaran tetap
  melalui `TransactionProvider`.
- Kategori dan dompet: provider masing-masing, lalu sinkron ke widget.
- Preferensi: `SettingsProvider → SharedPreferences`, sebagian diteruskan ke
  native Android melalui service/method channel.

## 3. Peta folder

| Lokasi | Tanggung jawab | Jangan diletakkan di sini |
| --- | --- | --- |
| `lib/main.dart` | Bootstrap, dependency state global, theme root, lock/root screen | Query SQL dan aturan bisnis fitur |
| `lib/models/` | Bentuk data, enum, konversi map SQLite | I/O, navigasi, dan state UI |
| `lib/db/database_helper.dart` | Skema v15, migrasi, query, transaksi atomik, backup/restore | Widget visual |
| `lib/providers/` | State yang dipakai lintas widget, cache, koordinasi refresh | SQL baru bila dapat menjadi satu API database |
| `lib/screens/` | Halaman, form, validasi interaksi, navigasi | Duplikasi invariant data yang harus berlaku untuk semua pemanggil |
| `lib/widgets/` | Komponen UI bersama dan renderer artwork | Akses database langsung |
| `lib/services/` | Integrasi yang bukan state layar: Excel, OCR, reminder, backup, widget | State UI jangka panjang |
| `lib/utils/` | Formatter dan helper kecil tanpa state fitur | Service atau abstraction layer baru |
| `android/app/src/main/` | Manifest, Kotlin, layout/resource widget Android | Logika Flutter yang tidak dibutuhkan native |
| `assets/` | Font, icon launcher, dan media tema | Data pengguna |
| `test/` | Regresi model, database, migrasi, import/export, OCR, tema/flavor | Test perangkat Android palsu |
| `scripts/` | Perintah rilis/build kecil yang dapat dijalankan ulang | Workflow kompleks yang tidak dipakai |

## 4. Peta fitur ke source

| Area | UI utama | State/aturan | Penyimpanan/integrasi | Test utama |
| --- | --- | --- | --- | --- |
| Bootstrap, PIN, theme root | `main.dart`, `lock_screen.dart` | `settings_provider.dart` | SharedPreferences, method channel | `widget_test.dart` |
| Home dan transaksi | `home_screen.dart`, `add_transaction_screen.dart`, `transaction_detail_sheet.dart` | `transaction_provider.dart` | `transactions` | `export_import_test.dart`, `widget_test.dart` |
| Transfer dompet | `transfer_sheet.dart` | `transaction_provider.dart`, pasangan atomik di DB | Dua row `transactions` | `export_import_test.dart` |
| Dompet | `wallets_screen.dart` | `wallet_provider.dart`, `wallet.dart` | `wallets`, agregasi transaksi | `export_import_test.dart`, `widget_test.dart` |
| Kategori | manager di `add_transaction_screen.dart` | `category_provider.dart`, `category.dart` | `custom_categories`, SharedPreferences | `widget_test.dart`, `export_import_test.dart` |
| Budget dan rule gaji | `budget_screen.dart`, `salary_rule_screen.dart` | `budget_provider.dart`, `budget.dart` | `budgets`, `salary_allocations` | `export_import_test.dart`, `database_migration_test.dart` |
| Target tabungan | `goals_view.dart` | `goal_provider.dart`; mutasi saldo via transaction provider/DB | `goals`, transaksi `source_type=goal` | `export_import_test.dart` |
| Utang/piutang | `debts_view.dart` | `debt_provider.dart`; pembayaran via transaction provider/DB | `debts`, transaksi `source_type=debt` | `export_import_test.dart` |
| Statistik dan rekap | `stats_screen.dart`, `recap_screen.dart` | cache revision di provider/screen, agregasi DB | query agregat `transactions` | `export_import_test.dart`, `widget_test.dart` |
| Cari dan kalender | `search_screen.dart`, `calendar_screen.dart` | token/debounce di screen, query DB | `transactions` | cakupan tidak penuh; cek manual UI |
| Transaksi berulang | `recurrings_screen.dart` | `recurring_provider.dart`, catch-up/idempotensi di DB | `recurrings`, `transactions` | `export_import_test.dart`, `widget_test.dart` |
| Struk dan OCR | `receipts_screen.dart`, form transaksi | `receipt_ocr.dart` | file `struk/`, `receipt_path` | `receipt_ocr_test.dart`, `export_import_test.dart` |
| Export/import Excel | Setelan dan Rekap | `excel_exporter.dart`, `excel_importer.dart` | file `.xlsx`, batch SQLite | `export_import_test.dart` |
| Backup/restore | Setelan | `auto_backup_service.dart`, API backup DB | `.duitges`, DB, struk, ikon custom | `export_import_test.dart` |
| Tema dan aset | `settings_screen.dart`, `main_shell.dart`, `home_screen.dart` | `settings_provider.dart`, `theme_artwork.dart` | SharedPreferences, `assets/theme/` | `widget_test.dart`, `lite_flavor_test.dart` |
| Widget Android | home screen Android | `widget_service.dart` + Kotlin providers/activities | HomeWidget prefs + SQLite langsung | test source contract + perangkat fisik |
| Reminder dan privasi | Setelan/lock/root | `reminder_service.dart`, settings provider | notification plugin, `FLAG_SECURE` | perangkat fisik |

Nama file pada tabel relatif terhadap `lib/`, kecuali jika lokasi lain
disebutkan.

## 5. Peta penyimpanan

### SQLite

`DatabaseHelper.schemaVersion` pada source saat dokumen ini dibuat adalah
**15**.

| Tabel | Pemilik utama | Hubungan penting |
| --- | --- | --- |
| `transactions` | TransactionProvider/DatabaseHelper | `wallet_id`, kategori, `budget_id`, `source_type/source_id`, path struk |
| `budgets` | BudgetProvider | Scope tipe atau satu kategori; dapat menjadi tujuan rule gaji |
| `salary_allocations` | DatabaseHelper/salary rule screen | Satu rule per `budget_id`, menyimpan periode terakhir |
| `wallets` | WalletProvider | Saldo = saldo awal + seluruh arus transaksi |
| `goals` | GoalProvider | Progres disinkronkan dengan transaksi setoran |
| `debts` | DebtProvider | Nilai `paid/settled` disinkronkan dengan transaksi pembayaran |
| `custom_categories` | CategoryProvider | Digabung dengan kategori bawaan dari source |
| `recurrings` | RecurringProvider/DatabaseHelper | Template bulanan dan `next_due` |

Nominal disimpan sebagai integer rupiah. Model masih mengekspos `double`,
kemudian membulatkan saat menulis.

### SharedPreferences

Pemilik utama adalah `SettingsProvider` dan `CategoryProvider`. Key yang
tersimpan merupakan kontrak kompatibilitas. Contoh: tema/tone, accent, font,
dark mode, tanggal awal periode, tren, PIN, privasi, reminder, auto-backup,
kategori favorit, dan kategori bawaan yang disembunyikan.

### File dan data native

- `struk/`: foto yang direferensikan transaksi.
- `custom_icons/`: ikon hasil crop untuk kategori, dompet, budget, dan target.
- `.duitges`: ZIP berisi database, ikon custom, dan foto bila dipilih.
- `backup_otomatis/`: backup lokal berkala milik aplikasi.
- HomeWidget SharedPreferences: ringkasan dan opsi untuk widget Android.

## 6. Matriks dampak perubahan

Gunakan baris yang sesuai sebelum mulai. Ini checklist dampak, bukan perintah
untuk mengubah semua file.

| Jika mengubah | Minimal telusuri | Verifikasi |
| --- | --- | --- |
| Bentuk transaksi/aturan saldo | model transaksi, TransactionProvider, seluruh API transaksi DB, form/detail, WidgetService, Kotlin widget | test DB/import/export + tambah/edit/hapus/transfer di HP |
| Skema database | `onCreate`, blok `oldVersion < N`, model map, backup/restore, query Kotlin yang menyentuh tabel | naikkan schema, test migrasi versi sebelumnya, seluruh test |
| Kategori atau dompet | model/provider, guard delete, importer, WidgetService, parser/render Kotlin | test kategori/dompet + quick-add widget |
| Budget/rule gaji | model budget, screen, provider, API/migrasi DB | test duplikasi, nominal/persentase, idempotensi periode |
| Target atau utang | metadata provider dan transaksi atomik DB | saldo, progres, hapus transaksi, rollback kegagalan |
| Key atau enum tersimpan | semua reader/writer dan fallback nilai lama | test load data lama; perubahan harus aditif |
| Tema/aset | settings provider, ThemeArtwork, MainShell/Home/Settings, `pubspec.yaml` | full + lite test/build, light/dark, restart penuh |
| Backup/import/export | format file, pemetaan path, validasi restore, fallback format lama | round-trip ribuan data dan restore gagal |
| Widget Android | WidgetService, seluruh Kotlin widget, layout XML, manifest | build Android dan uji tiga ukuran widget di HP |
| Reminder/privasi | SettingsProvider, service, manifest, AppActivity | izin, reboot, timezone, screenshot/recent apps di HP |
| Flavor/version/signing | `pubspec.yaml`, Gradle, scripts, README | build Full/Lite dengan application ID dan signing yang benar |

## 7. Alur tracking perubahan

1. Mulai dari fitur pada tabel bagian 4.
2. Cari semua caller dan format tersimpan dengan `rg`, bukan hanya file UI yang
   terlihat bermasalah.
3. Catat invariant yang terkena dari `PROJECT_CONTEXT.md` dan
   [`LIMITATIONS.md`](LIMITATIONS.md).
4. Ubah lokasi pemilik aturan. Aturan konsistensi data umumnya berada di
   `DatabaseHelper`, bukan disalin ke beberapa screen.
5. Tambah satu regresi terkecil yang membuktikan aturan non-trivial.
6. Jalankan formatter, analyzer, test, lalu build/perangkat fisik sesuai
   matriks dampak.
7. Perbarui hanya dokumen yang memiliki fakta yang berubah.

Perintah baseline:

```bash
fvm dart format lib test
fvm flutter analyze
fvm flutter test
```

Perubahan Android, dependency, flavor, atau aset juga memerlukan build APK.
