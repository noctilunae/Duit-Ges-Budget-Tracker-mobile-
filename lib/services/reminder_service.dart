import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Notifikasi pengingat harian "jangan lupa catat pengeluaran".
class ReminderService {
  ReminderService._();

  static const _id = 1001;
  static const _backupId = 1002;
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> _ensureInit() async {
    if (_initialized) return;
    // Timezone perlu di-set biar jadwal "jam 20:00" beneran jam lokal HP
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // Gagal deteksi timezone: fallback WIB (mayoritas user Indonesia)
      tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    _initialized = true;
  }

  /// Minta izin notifikasi (Android 13+ wajib nanya dulu).
  /// Balikin false kalau user nolak.
  static Future<bool> requestPermission() async {
    await _ensureInit();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.requestNotificationsPermission() ?? true;
  }

  /// Jadwalin notifikasi tiap hari di jam [time]. Jadwal lama otomatis
  /// diganti (id-nya sama).
  static Future<void> scheduleDaily(TimeOfDay time) async {
    await _ensureInit();
    final now = tz.TZDateTime.now(tz.local);
    var first = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (!first.isAfter(now)) first = first.add(const Duration(days: 1));
    await _plugin.zonedSchedule(
      id: _id,
      title: 'Duit Ges',
      body: 'Udah catat pengeluaran hari ini belum? 📝',
      scheduledDate: first,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'reminder_harian',
          'Reminder Harian',
          channelDescription: 'Pengingat nyatet transaksi tiap hari',
          playSound: false,
        ),
      ),
      // Inexact: ga butuh izin alarm khusus, meleset paling beberapa
      // menit — buat reminder harian ga masalah dan lebih hemat baterai.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> cancel() async {
    await _ensureInit();
    await _plugin.cancel(id: _id);
  }

  static Future<void> scheduleWeeklyBackup() async {
    await _ensureInit();
    final now = tz.TZDateTime.now(tz.local);
    var first = tz.TZDateTime(tz.local, now.year, now.month, now.day, 19);
    while (first.weekday != DateTime.sunday || !first.isAfter(now)) {
      first = first.add(const Duration(days: 1));
    }
    await _plugin.zonedSchedule(
      id: _backupId,
      title: 'Amankan backup Duit Ges',
      body: 'Bagikan file backup ke Drive atau penyimpanan di luar aplikasi.',
      scheduledDate: first,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'reminder_backup',
          'Reminder Backup',
          channelDescription: 'Pengingat menyimpan backup di luar aplikasi',
          playSound: false,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  static Future<void> cancelWeeklyBackup() async {
    await _ensureInit();
    await _plugin.cancel(id: _backupId);
  }
}
