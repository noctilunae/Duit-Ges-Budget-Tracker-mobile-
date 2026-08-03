# Duit Ges — konteks agent

Baca [PROJECT_CONTEXT.md](PROJECT_CONTEXT.md) sebelum mengubah aplikasi. File
tersebut adalah sumber konteks kanonis untuk produk, arsitektur, database, tema,
performa, pengujian, batasan, dan keputusan UI.

Aturan paling penting:

- **LOCK kompatibilitas update:** semua perubahan mulai sekarang wajib
  kompatibel dengan data versi lama. Jangan menghapus, mengganti arti, atau
  mengurutkan ulang ID, key `SharedPreferences`, nilai enum/warna tersimpan,
  kolom database, maupun format export. Perubahan harus aditif; jika format
  lama perlu berubah, sediakan migrasi/fallback dan test upgrade yang menjaga
  data serta preferensi pengguna tetap utuh.
- Target hanya Android dan semua data utama lokal di SQLite.
- Perubahan skema wajib menaikkan `DatabaseHelper.schemaVersion`, menambah
  migrasi baru, dan tidak mengubah blok migrasi lama.
- Transfer adalah dua transaksi sistem dan harus tetap atomik serta tidak masuk
  statistik, budget, maupun rekap.
- Jalankan formatter, `flutter analyze`, dan seluruh `flutter test` setelah
  perubahan. Perubahan Android/asset juga perlu build dan restart penuh.
- Jangan menghapus atau mengganti aset tema hanya karena tampak duplikat;
  beberapa sengaja dipisah agar tema bisa dikustomisasi secara independen.
- **LOCK ikon tema custom:** semua impor PNG/JPG/GIF/video memakai kanvas
  160×160, preview crop yang sama, serta format key lama tetap wajib terbaca
  dengan crop tengah default. Slot stabilnya hanya 4 header, 4 footer, maskot
  kartu saldo, dan tombol tambah transaksi. Jangan membuat ukuran/picker
  khusus per tema atau menghapus map artwork/footer versi lama.
