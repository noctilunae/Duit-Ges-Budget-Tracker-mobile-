# Panduan Menghapus Tema per Folder Variant

Dokumen ini untuk agent yang ditugaskan bikin varian build lebih ringan dengan
menghapus satu atau lebih tema dari salinan folder project ini. **Baca sampai
habis sebelum eksekusi** — jangan cuma jalanin langkah 1 lalu berhenti.

## Membuat varian Lite hanya di komputer lokal

Versi utama tetap berada di folder `duit_ges`, branch `master`, dan itulah
satu-satunya versi yang dikirim ke GitHub. Versi Lite dibuat sebagai Git
worktree pada branch lokal agar perubahan kedua versi tidak tercampur.

Sebelum membuat Lite, pastikan perubahan versi utama yang ingin ikut ke Lite
sudah di-commit. Worktree dibuat dari commit, jadi perubahan yang masih
uncommitted di folder utama tidak ikut tersalin.

Dari root `duit_ges`, buat folder Lite sebagai sibling (jangan di dalam folder
project utama):

```bash
git worktree add ../duit_ges_lite -b local/duit-ges-lite
cd ../duit_ges_lite
```

Setelah itu, semua penghapusan tema dalam dokumen ini dilakukan hanya dari
`duit_ges_lite`. Commit perubahan Lite ke branch lokal tersebut supaya aman
dan mudah dibandingkan, tetapi **jangan push branch Lite**:

```bash
git add -A
git commit -m "Buat varian Lite tanpa tema berat"
```

Perintah `git push` biasa dari `master` tidak mengirim branch Lite. Tetap
hindari `git push --all` dan jangan pernah menjalankan:

```bash
git push noctilunae local/duit-ges-lite
```

Untuk mengecek pemisahannya:

```bash
git worktree list
git branch -vv
```

Hasil yang diharapkan:

- `duit_ges` memakai branch `master` dan boleh di-push ke GitHub.
- `duit_ges_lite` memakai branch `local/duit-ges-lite` tanpa upstream remote.

### Mengambil pembaruan versi utama ke Lite

Commit pembaruan di `master` terlebih dahulu. Lalu dari folder Lite:

```bash
git merge master
```

Selesaikan konflik bila kode tema yang sudah dibuang berubah di `master`, lalu
jalankan ulang analyze, test, dan build Lite. Jangan merge branch Lite kembali
ke `master`, karena itu akan membawa penghapusan tema ke versi GitHub.

### Menghapus varian Lite lokal

Pastikan tidak ada perubahan Lite yang belum di-commit, lalu dari folder utama:

```bash
git worktree remove ../duit_ges_lite
git branch -D local/duit-ges-lite
```

Perintah terakhir menghapus branch Lite lokal beserta commit yang hanya ada di
branch itu. Jalankan hanya jika varian Lite memang sudah tidak diperlukan.

### Instalasi Android

Biarkan `applicationId` tetap `com.noctilune.duitges` bila APK Lite dimaksudkan
sebagai pengganti APK penuh di HP yang sama; data lokal dan backup tetap
kompatibel. Jika Full dan Lite harus terpasang bersamaan, gunakan
`applicationId` serta nama aplikasi berbeda dan perlakukan datanya sebagai dua
instalasi terpisah.

## Konteks penting

- Tema di app ini **bukan data di database**, semua preset statis di kode +
  aset di `assets/theme/`. Lihat `PROJECT_CONTEXT.md` section 9 ("Sistem tema
  dan aset") untuk kontrak lengkap sebelum mengubah apapun di area ini.
- Tujuan penghapusan ini murni **mengurangi ukuran APK** (build-time), bukan
  fitur runtime "hapus tema" — jangan tambah UI/tombol apapun buat user.
- Setiap folder variant menghapus tema yang berbeda-beda sesuai kebutuhan.
  Jalankan checklist ini per tema yang mau dihapus di folder itu.
- Setelah selesai, WAJIB jalankan `flutter analyze` dan `flutter test` di
  root folder variant tsb. Perubahan UI/asset di project ini juga butuh
  build + restart penuh sebelum dianggap valid (lihat `CLAUDE.md`).

## Daftar tema saat ini (11 total)

| id | punya tone? | kategori |
|---|---|---|
| `klasik` | tidak | A (simple) |
| `kucing` | ya (pink/blue/yellow → 3 folder aset) | A (simple) |
| `bebek` | ya (yellow/blue/pink → 3 folder aset) | A (simple) |
| `call_duck` | tidak | **B (exclusive)** |
| `anya` | tidak | A (simple) |
| `jjk` | tidak | A (simple) |
| `frieren` | tidak | A (simple) |
| `frieren_rial` | tidak | **B (exclusive)** |
| `spongebob` | tidak | A (simple) |
| `jjk2` | tidak | **B (exclusive)** |
| `matcha` | tidak | A (simple) |

Kategori B = punya logic khusus per-`theme.id` di banyak file (video/gif
khusus, background khusus, dsb). Kategori A = preset biasa, tanpa
percabangan khusus di luar `settings_provider.dart`.

**Jangan asumsikan daftar/kategori di atas masih akurat kalau dokumen ini
sudah lama** — selalu verifikasi ulang dengan langkah 0 di bawah sebelum
eksekusi, soalnya kode bisa berubah setelah dokumen ini ditulis.

## Langkah 0 — Verifikasi ulang sebelum eksekusi

Sebelum ubah apapun, jalankan (dari root project):

```bash
grep -n "id: '<theme_id>'" lib/providers/settings_provider.dart
grep -rn "'<theme_id>'" lib/ PROJECT_CONTEXT.md
```

Ini kasih tau kamu semua lokasi referensi yang sebenarnya saat ini — jangan
cuma percaya tabel/nomor baris di dokumen ini, karena kode bisa udah
berubah. Kalau grep nemu file yang gak disebut di checklist bawah, baca
konteksnya dulu sebelum lanjut.

## Kategori A — tema simple

Langkah untuk hapus satu tema `<theme_id>`:

1. **`pubspec.yaml`** — hapus baris `- assets/theme/<folder_aset>/` di
   section `assets:`. Kalau tema itu punya tone (`kucing`, `bebek`), hapus
   SEMUA folder aset varian tone-nya (misal `kucing` → hapus `cat/`,
   `cat_blue/`, `cat_yellow/` sekaligus, plus `paw_cat.png` kalau memang
   cuma dipakai tema itu).
2. **`lib/providers/settings_provider.dart`** — hapus satu entry
   `ThemePreset(id: '<theme_id>', ...)` beserta isi block-nya (termasuk
   list `tones:` di dalamnya kalau ada) dari `final themePresets = [...]`.
3. **`assets/theme/<folder_aset>/`** — hapus folder fisiknya (dan semua
   folder tone terkait, lihat poin 1).
4. **`PROJECT_CONTEXT.md`** — update daftar urutan preset yang
   didokumentasikan di section 9, hapus baris tema yang bersangkutan.
5. Jalankan `flutter analyze` — kalau ada import/reference yang jadi
   dangling, ketauan di sini.
6. Jalankan `flutter test` — kalau ada test yang assert jumlah tema atau
   nyebut id tema ini spesifik, akan gagal dan perlu disesuaikan.

## Kategori B — tema exclusive (`jjk2`, `call_duck`, `frieren_rial`)

Selain 6 langkah di atas, tema-tema ini punya percabangan `if (theme.id ==
'<id>')` tersebar di **5 file tambahan** (per kondisi saat dokumen ini
ditulis — cek ulang pakai Langkah 0):

- `lib/screens/settings_screen.dart`
- `lib/screens/main_shell.dart`
- `lib/screens/home_screen.dart`
- `lib/widgets/theme_artwork.dart`
- `lib/providers/settings_provider.dart` (selain entry preset-nya sendiri)

Untuk tiap file itu:

1. `grep -n "'<theme_id>'" <file>` untuk nemu semua baris yang match.
2. Baca tiap match — polanya biasanya:
   ```dart
   if (theme.id == '<theme_id>') {
     // style/asset eksklusif
   } else {
     // fallback generic
   }
   ```
3. Hapus branch `if` yang spesifik ke tema itu, sisakan cuma jalur
   `else` (fallback). **Jangan** cuma hapus preset dari `themePresets` dan
   biarin branch `if theme.id == '<id>'` nganggur sebagai dead code —
   itu bikin kode susah dibaca dan menyesatkan pembaca berikutnya.
4. Kalau ketemu referensi ke asset spesifik (path `assets/theme/<id>/...`)
   di luar `settings_provider.dart` (misal path gif/mp4 hardcoded di
   `settings_screen.dart` atau `home_screen.dart`), itu juga harus ikut
   kehapus di langkah ini, bukan cuma pas hapus folder aset di langkah A.1.

Lanjutkan dengan langkah 4-6 kategori A (update `PROJECT_CONTEXT.md`,
`flutter analyze`, `flutter test`).

## Yang HARUS diperhatikan (aturan dari `PROJECT_CONTEXT.md` & `CLAUDE.md`)

- **Jangan hapus aset yang dipakai bareng tema lain.** Beberapa PNG sengaja
  disimpan duplikat di folder tema berbeda supaya tema bisa dikustomisasi
  independen — sebelum hapus file aset, pastikan dulu file itu memang HANYA
  dipakai tema yang sedang dihapus (`grep -rn "<nama_file>"` di `lib/`).
- **Kontrak `ThemeArtwork`**: index tile 0-15 di `ThemeArtwork` adalah "API
  internal" tema dan gak boleh ditukar sembarangan (lihat
  `PROJECT_CONTEXT.md` section 9). Kalau tema yang dihapus override
  beberapa index tile itu, pastikan fallback-nya balik ke default, bukan
  index kosong/null yang bikin crash.
- **Fallback tema aktif**: getter `preset` di
  `settings_provider.dart` (`themePresets.firstWhere(..., orElse: () =>
  themePresets.first)`) sudah otomatis fallback ke tema pertama kalau
  `themeId` tersimpan user gak ketemu lagi di list. Ini sudah cukup — TIDAK
  perlu migrasi SharedPreferences tambahan buat handle user lama yang
  `themeId`-nya kehapus.
- **Tidak ada migrasi database** yang diperlukan — tema gak pernah masuk
  SQLite, jadi `DatabaseHelper.schemaVersion` tidak perlu naik untuk
  perubahan ini.
- Setelah selesai satu folder variant, commit terpisah per variant supaya
  gampang di-diff balik ke versi lengkap kalau perlu.
