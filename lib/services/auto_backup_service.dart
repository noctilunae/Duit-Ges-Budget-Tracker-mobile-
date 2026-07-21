import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../db/database_helper.dart';

/// Backup database dan foto struk otomatis tiap minggu, tanpa user mikir.
///
/// File disimpan di storage eksternal app
/// (`Android/data/<package>/files/backup_otomatis`) — bisa diambil lewat
/// file manager, tapi ikut kehapus kalau app di-uninstall. Buat
/// pengaman betulan tetap pakai Export/Backup manual yang di-share
/// keluar (WA/Drive).
class AutoBackupService {
  AutoBackupService._();

  static const _keepCount = 4;
  static const _interval = Duration(days: 7);

  /// Jalanin backup kalau udah waktunya (dipanggil tiap app dibuka).
  /// Aman dipanggil kapan aja: kalau belum jatuh tempo, langsung balik.
  static Future<void> runIfDue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool('autoBackupEnabled') ?? false)) return;
      final lastRun = DateTime.tryParse(
        prefs.getString('lastAutoBackup') ?? '',
      );
      final now = DateTime.now();
      if (lastRun != null && now.difference(lastRun) < _interval) return;

      final dir = await _backupDir();
      final stamp =
          '${now.year}-${now.month.toString().padLeft(2, '0')}'
          '-${now.day.toString().padLeft(2, '0')}';
      await DatabaseHelper.instance.backupTo(
        '${dir.path}/duit_ges_auto_$stamp.duitges',
      );
      await _prune(dir);
      await prefs.setString('lastAutoBackup', now.toIso8601String());
    } catch (_) {
      // Backup otomatis gagal (storage penuh dll) jangan sampai
      // ganggu app — dicoba lagi di pembukaan berikutnya.
    }
  }

  static Future<Directory> _backupDir() async {
    final base =
        await getExternalStorageDirectory() ??
        await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/backup_otomatis');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Simpan [_keepCount] backup terbaru aja, sisanya dihapus.
  static Future<void> _prune(Directory dir) async {
    final files = <File>[];
    await for (final entity in dir.list()) {
      if (entity is File &&
          (entity.path.endsWith('.duitges') || entity.path.endsWith('.db'))) {
        files.add(entity);
      }
    }
    files.sort((a, b) => b.path.compareTo(a.path));
    for (final old in files.skip(_keepCount)) {
      await old.delete();
    }
  }

  static Future<String?> lastBackupLabel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('lastAutoBackup');
  }
}
