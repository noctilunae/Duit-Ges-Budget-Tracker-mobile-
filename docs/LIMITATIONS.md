# Batasan dan risiko yang diketahui

Dokumen ini memisahkan **kontrak yang sengaja dipertahankan** dari
**keterbatasan yang dapat ditingkatkan nanti**. Sesuatu yang tercantum di sini
tidak otomatis menjadi pekerjaan; ubah ketika ada kebutuhan nyata, data
pengguna tetap aman, dan test migrasinya tersedia.

## 1. Kontrak keras

| Area | Batas saat ini | Konsekuensi perubahan |
| --- | --- | --- |
| Platform | Produk produksi hanya Android | iOS/web/desktop memerlukan audit plugin, file system, notifikasi, widget, privasi, dan UI |
| Penyimpanan | Data utama lokal; tidak ada akun, server, atau sinkronisasi | Sinkronisasi bukan sekadar menambah API: perlu identitas, konflik, auth, enkripsi, dan migrasi |
| Identitas aplikasi | Package/application ID `com.noctilune.duitges` | Mengganti ID membuat Android menganggapnya aplikasi lain dan tidak memakai data instalasi lama |
| Kompatibilitas | ID kategori/tema, enum tersimpan, key SharedPreferences, kolom DB, serta format import/backup harus tetap terbaca | Perubahan harus aditif atau memiliki migrasi/fallback dan test data lama |
| Database | Skema berjalan saat ini v15; migrasi lama tidak boleh diubah artinya | Setiap skema baru menaikkan versi, memperbarui `onCreate`, dan menambah blok upgrade baru |
| Uang | Satu mata uang: rupiah integer tanpa pecahan | Multi-currency memerlukan currency per transaksi dan aturan konversi; jangan memakai `double` sebagai nilai simpan |
| Transaksi sistem | Transfer, setoran target, dan pembayaran utang/piutang mempunyai efek lintas row/tabel | Mutasi harus tetap atomik di DatabaseHelper |
| Full/Lite | Keduanya memakai application ID dan data yang sama; Lite hanya membawa tema `kucing`, `bebek`, dan `call_duck` | Tidak dapat dipasang berdampingan sebagai dua aplikasi; tema Full yang tersimpan harus fallback aman di Lite |
| Arsitektur | Provider + DatabaseHelper, tanpa repository/domain layer terpisah | Tambah layer hanya jika duplikasi atau kebutuhan test benar-benar muncul |

## 2. Keamanan dan pemulihan data

### Database, foto, dan backup tidak terenkripsi

SQLite, foto struk, ikon custom, dan file `.duitges` dapat dibaca oleh pihak
yang sudah mendapatkan file atau menguasai perangkat. PIN hanya mengunci UI.
Hash PIN memakai SHA-256 dengan prefix aplikasi, bukan password-hardening.

`FLAG_SECURE` membantu memblokir screenshot, screen recording, dan preview
recent apps pada Android, tetapi tidak mengenkripsi data dan tidak melindungi
perangkat yang sudah di-root/dikuasai.

Pertimbangkan enkripsi hanya bila threat model produk memang membutuhkannya;
pekerjaan tersebut harus mencakup migrasi data, backup, pemulihan kunci, dan
kehilangan akses.

### Auto-backup bukan backup eksternal

Auto-backup:

- baru diperiksa ketika aplikasi dibuka;
- berjalan paling cepat tujuh hari sekali;
- menyimpan empat file terbaru;
- berada di direktori eksternal milik aplikasi;
- dapat ikut hilang ketika aplikasi di-uninstall.

Backup manual yang dibagikan ke penyimpanan di luar aplikasi tetap menjadi
jalur pemulihan utama. File backup juga tidak terenkripsi.

### Restore hanya menerima skema yang dikenal

Restore memeriksa integritas SQLite, keberadaan tabel transaksi, dan
`user_version <= schemaVersion`. Backup dari versi aplikasi yang lebih baru
ditolak oleh versi lama. Foto yang tidak ada di archive akan kehilangan
referensi saat pemetaan ulang.

## 3. Integritas data

### Relasi dijaga oleh kode, bukan foreign key SQLite

Skema saat ini tidak mendeklarasikan `FOREIGN KEY`. Guard provider/database
mencegah penghapusan dompet atau kategori yang masih dipakai, dan operasi
lintas tabel penting memakai transaksi SQLite. Namun penulis baru yang melewati
jalur tersebut—terutama kode native—harus menjaga kontrak sendiri.

Jangan menambah write path langsung baru. Jika relasi SQL akan diperketat,
audit dahulu data lama/orphan dan perilaku restore/import.

### Transfer lama dipasangkan dengan heuristik

Transfer disimpan sebagai dua transaksi (`transfer_keluar` dan
`transfer_masuk`) tanpa `transfer_group_id`. Saat satu sisi dihapus, pasangan
dicari dari waktu, nominal, catatan, kategori lawan, dan ID terdekat. Data yang
sangat mirip dapat ambigu.

Tambahkan group ID hanya dengan kolom aditif, fallback untuk row lama, dan test
migrasi/penghapusan pasangan.

### Validasi saldo berada di alur aplikasi

UI mencegah pengeluaran/setoran/pembayaran di atas saldo dompet, tetapi skema
SQLite tidak memiliki constraint saldo non-negatif. Import, restore, atau
write path tingkat rendah dapat menghasilkan saldo negatif.

Jika saldo negatif harus mustahil pada semua jalur, validasi perlu dipusatkan
di boundary database/import tanpa memblokir data lama yang sudah valid menurut
perilaku sebelumnya.

### Nominal model masih `double`

Database menyimpan integer rupiah sejak migrasi v8, tetapi model/API Dart masih
memakai `double` untuk kompatibilitas dan membulatkan saat menulis. Jangan
melakukan perhitungan pecahan yang diasumsikan akan bertahan di database.

## 4. Batas fitur

| Fitur | Batas saat ini |
| --- | --- |
| Mata uang/locale | Hanya rupiah dan tampilan `id_ID`; transaksi tidak menyimpan currency atau timezone asal |
| Periode bulanan | Tanggal awal dibatasi 1–28 agar valid di setiap bulan |
| Tren statistik | Rentang 1–12 bulan |
| Pencarian | Maksimal 200 hasil per query; cocokkan catatan/kategori, bukan full-text index |
| Recurring | Template bulanan berbasis tanggal; tidak ada pola mingguan/tahunan atau rule kalender kompleks |
| Budget kategori | Satu kategori hanya boleh memiliki satu budget berscope kategori |
| Rule gaji | Satu rule per budget, satu nominal gaji/tanggal bersama, diterapkan sekali per periode |
| Target | Target nominal dan progres; tidak ada deadline, bunga, atau proyeksi otomatis |
| Utang/piutang | Pembayaran bertahap dan jatuh tempo opsional; tidak ada bunga, cicilan terjadwal, atau multi-pihak |
| Import Excel | Menambah transaksi saja; tidak mengimpor preferensi, budget, target, utang, struk, atau seluruh metadata backup |
| OCR | Heuristik lokal untuk menyarankan total; hasil wajib dikonfirmasi pengguna |
| Widget Android | Quick-add dasar; tanpa struk, catatan bebas, tanggal custom, transfer, atau utang/piutang |

Fitur yang belum ada—cloud sync, bank integration, multi-user, multi-currency,
dan platform non-Android—adalah di luar scope saat ini, bukan bug tersembunyi.

## 5. Performa dan ukuran

### Export Excel berjalan di proses Flutter

Export memuat transaksi terpilih dan membangun workbook di proses Flutter.
Riwayat sangat besar dapat menahan UI. Pindahkan ke isolate/chunking hanya
setelah ada ukuran data dan waktu tunggu yang terukur.

### Saldo dompet mengagregasi seluruh transaksi

Setiap revision transaksi dapat memicu `walletFlows()` dengan `GROUP BY`
sepanjang tabel. Query tidak membuat semua object Dart, tetapi biayanya tetap
bertambah mengikuti jumlah transaksi.

Pertimbangkan ledger/materialized balance hanya jika profiling menunjukkan
masalah; solusi itu menambah risiko konsistensi dan migrasi.

### Search sengaja dibatasi

Pencarian mengembalikan maksimal 200 row serta memakai debounce/token agar hasil
lama tidak menimpa filter baru. Pengguna dengan banyak hasil sama tidak melihat
semua row sekaligus.

### Media tema memperbesar APK

GIF, video, dan gambar tema menyumbang ukuran serta penggunaan decode/CPU.
Animasi yang tidak terlihat dipause, tetapi kualitas, alpha, codec, dan frame
rate tetap harus dibandingkan di perangkat sebelum kompresi/penghapusan.
Beberapa aset identik antar-folder sengaja terpisah agar tiap tema dapat diganti
sendiri.

Flavor Lite mengurangi tema berat pada build, bukan menghapus tema saat runtime.

## 6. Batas integrasi Android

- Widget native menulis quick-add langsung ke SQLite. Ia hanya melakukan
  validasi dasar dan harus ikut diperbarui bila kontrak tabel berubah.
- Quick-add widget dinonaktifkan saat PIN aktif agar tidak melewati lock screen.
- Reminder memakai alarm inexact; waktu dapat meleset beberapa menit demi
  hemat baterai/tanpa izin exact alarm.
- Jika timezone perangkat gagal dideteksi, reminder fallback ke
  `Asia/Jakarta`, yang dapat salah di zona Indonesia lain.
- Widget, notifikasi setelah reboot, kamera/OCR, share sheet, codec video,
  launcher icon, dan `FLAG_SECURE` tidak tervalidasi penuh oleh host test.
  Semuanya memerlukan perangkat Android fisik.

## 7. Batas pengujian dan maintenance

- Test host kuat pada migrasi, query/agregasi, import/export, backup, OCR,
  model, tema, dan kontrak source tertentu.
- Interaksi visual kompleks, layout berbagai ukuran, performa media, serta
  lifecycle Android masih membutuhkan checklist manual.
- Warning/plugin/toolchain dapat berubah saat Flutter atau Android Gradle
  Plugin naik; upgrade dependency harus disertai build Full dan Lite.
- Riwayat Git lama pernah membawa blob hasil build besar. Mengecilkan `.git`
  memerlukan rewrite history dan koordinasi semua clone; jangan dilakukan
  sebagai cleanup biasa.

## 8. Kapan dokumen ini diperbarui

Perbarui satu baris/section ketika:

- batas sudah dihapus oleh implementasi dan test;
- ada fallback/migrasi baru yang mengubah dampaknya;
- ada limit baru yang sengaja diterima;
- hasil profiling atau uji perangkat membuktikan asumsi lama salah.

Jangan menghapus catatan kompatibilitas hanya karena jalur baru sudah benar;
pastikan data dan versi aplikasi lama juga sudah tercakup.
