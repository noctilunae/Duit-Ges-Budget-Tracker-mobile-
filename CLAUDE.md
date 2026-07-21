# Duit Ges — konteks agent

Baca [PROJECT_CONTEXT.md](PROJECT_CONTEXT.md) sebelum mengubah aplikasi. File
tersebut adalah sumber konteks kanonis untuk produk, arsitektur, database, tema,
performa, pengujian, batasan, dan keputusan UI.

Aturan paling penting:

- Target hanya Android dan semua data utama lokal di SQLite.
- Perubahan skema wajib menaikkan `DatabaseHelper.schemaVersion`, menambah
  migrasi baru, dan tidak mengubah blok migrasi lama.
- Transfer adalah dua transaksi sistem dan harus tetap atomik serta tidak masuk
  statistik, budget, maupun rekap.
- Jalankan formatter, `flutter analyze`, dan seluruh `flutter test` setelah
  perubahan. Perubahan Android/asset juga perlu build dan restart penuh.
- Jangan menghapus atau mengganti aset tema hanya karena tampak duplikat;
  beberapa sengaja dipisah agar tema bisa dikustomisasi secara independen.
