import 'package:file_selector/file_selector.dart' show openFile;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../db/database_helper.dart';
import '../providers/budget_provider.dart';
import '../providers/category_provider.dart';
import '../providers/debt_provider.dart';
import '../providers/goal_provider.dart';
import '../providers/recurring_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/wallet_provider.dart';
import '../services/auto_backup_service.dart';
import '../services/excel_exporter.dart';
import '../services/excel_importer.dart';
import '../services/reminder_service.dart';
import '../utils/app_style.dart';
import '../utils/formatters.dart';
import '../widgets/page_header.dart';
import '../widgets/theme_artwork.dart';
import '../widgets/looping_asset_video.dart';
import 'receipts_screen.dart';
import 'recurrings_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final pickerThemes = [
      for (final theme in themePresets)
        if (theme.id != 'jjk2') ...[
          theme,
          if (theme.id == 'jjk')
            themePresets.firstWhere((theme) => theme.id == 'jjk2'),
        ],
    ];
    return SafeArea(
      child: Column(
        children: [
          const PageHeader(title: 'Kustomisasi', artworkTile: 3),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                _Section(
                  icon: Icons.auto_awesome,
                  title: 'Tema Aplikasi',
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final theme in pickerThemes)
                          SizedBox(
                            width: 76,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _ThemeOption(
                                theme: theme,
                                selected: theme.id == settings.preset.id,
                                onTap: () => settings.setTheme(theme),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (settings.preset.id == 'frieren_rial') ...[
                  _Section(
                    icon: Icons.wallpaper_outlined,
                    title: 'Template Background',
                    child: GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1.6,
                      children: [
                        for (final background in FrierenRialBackground.values)
                          _BackgroundTemplateOption(
                            background: background,
                            selected:
                                background == settings.frierenRialBackground,
                            accent: settings.accent,
                            onTap: () =>
                                settings.setFrierenRialBackground(background),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (settings.preset.tones.isNotEmpty) ...[
                  _Section(
                    icon: Icons.color_lens_outlined,
                    title: 'Warna Maskot',
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final tone in settings.preset.tones)
                          ChoiceChip(
                            selected: tone.id == settings.tone?.id,
                            showCheckmark: false,
                            avatar: CircleAvatar(backgroundColor: tone.accent),
                            label: Text(tone.label),
                            onSelected: (_) => settings.setTone(tone),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                // Tema yang warnanya udah otomatis ganti per tab
                // (tabAccents) ga butuh picker manual — bakal bingungin
                // soalnya milih warna di sini ga akan kelihatan ngefek.
                if (settings.preset.tabAccents == null) ...[
                  _Section(
                    icon: Icons.palette_outlined,
                    title: 'Warna Tema',
                    child: GridView.count(
                      crossAxisCount: 4,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 1,
                      children: [
                        for (final color in SettingsProvider.presetColors)
                          _ColorSwatch(
                            color: color,
                            selected: color == settings.accent,
                            onTap: () => settings.setAccent(color),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                _Section(
                  icon: Icons.text_fields,
                  title: 'Font Aplikasi',
                  child: Column(
                    children: [
                      for (final font in AppFont.values)
                        _FontOption(
                          font: font,
                          accent: settings.accent,
                          selected: font == settings.font,
                          onTap: () => settings.setFont(font),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _Section(
                  icon: Icons.credit_card,
                  title: 'Template Kartu Saldo',
                  child: Column(
                    children: [
                      for (final style in CardStyle.values)
                        // Card "Call Duck" eksklusif tema Call Duck —
                        // di tema lain opsinya disembunyiin sepenuhnya.
                        if ((style != CardStyle.callDuck ||
                                settings.preset.id == 'call_duck') &&
                            (!const {
                                  CardStyle.jjkVideo1,
                                  CardStyle.jjkVideo2,
                                }.contains(style) ||
                                settings.preset.id == 'jjk2') &&
                            (!style.isFrierenRial ||
                                settings.preset.id == 'frieren_rial'))
                          _CardStyleOption(
                            style: style,
                            accent: settings.accent,
                            selected: style == settings.cardStyle,
                            onTap: () => settings.setCardStyle(style),
                          ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _Section(
                  icon: Icons.dark_mode_outlined,
                  title: 'Tampilan',
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Mode Gelap'),
                    subtitle: const Text('Tampilan gelap biar adem di mata'),
                    value: settings.darkMode,
                    onChanged: settings.setDarkMode,
                  ),
                ),
                const SizedBox(height: 16),
                _Section(
                  icon: Icons.event_repeat,
                  title: 'Awal Periode Bulanan',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Mulai hitung dari tanggal'),
                    subtitle: const Text(
                      'Saldo, budget, & statistik ngikutin '
                      'periode ini (misal gajian tanggal 25)',
                    ),
                    trailing: DropdownButton<int>(
                      value: settings.monthStartDay,
                      items: [
                        for (var day = 1; day <= 28; day++)
                          DropdownMenuItem(value: day, child: Text('$day')),
                      ],
                      onChanged: (day) {
                        if (day != null) settings.setMonthStartDay(day);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _Section(
                  icon: Icons.show_chart,
                  title: 'Grafik Tren',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Rentang grafik tren'),
                    subtitle: const Text(
                      'Berapa bulan ke belakang yang ditampilin '
                      'di grafik Tren pada Statistik',
                    ),
                    trailing: DropdownButton<int>(
                      value: settings.trendMonths,
                      items: [
                        for (var months = 1; months <= 12; months++)
                          DropdownMenuItem(
                            value: months,
                            child: Text('$months'),
                          ),
                      ],
                      onChanged: (months) {
                        if (months != null) settings.setTrendMonths(months);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _Section(
                  icon: Icons.lock_outline,
                  title: 'Keamanan',
                  child: Column(
                    children: [
                      const _PinSetting(),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Mode Privasi Screenshot'),
                        subtitle: const Text(
                          'Blokir screenshot dan preview recent apps',
                        ),
                        value: settings.privacyMode,
                        onChanged: settings.setPrivacyMode,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _Section(
                  icon: Icons.autorenew,
                  title: 'Otomatisasi',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.event_repeat),
                        title: const Text('Transaksi Berulang'),
                        subtitle: const Text(
                          'Gaji, tagihan, cicilan — kecatat otomatis tiap bulan',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RecurringsScreen(),
                            ),
                          );
                        },
                      ),
                      const _ReminderSetting(),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        secondary: const Icon(Icons.backup_outlined),
                        title: const Text('Backup Otomatis Mingguan'),
                        subtitle: const Text(
                          'Salinan data disimpen di HP tiap 7 hari',
                        ),
                        value: settings.autoBackupEnabled,
                        onChanged: settings.setAutoBackup,
                      ),
                      FutureBuilder<List<String?>>(
                        future: Future.wait([
                          AutoBackupService.lastBackupLabel(),
                          AutoBackupService.lastBackupError(),
                        ]),
                        builder: (context, snapshot) {
                          final success = DateTime.tryParse(
                            snapshot.data?[0] ?? '',
                          );
                          final failed = DateTime.tryParse(
                            snapshot.data?[1] ?? '',
                          );
                          final text =
                              failed != null &&
                                  (success == null || failed.isAfter(success))
                              ? 'Backup terakhir gagal ${tanggalLengkap(failed)}'
                              : success == null
                              ? 'Belum pernah backup otomatis'
                              : 'Backup terakhir berhasil ${tanggalLengkap(success)}';
                          return Padding(
                            padding: const EdgeInsets.only(left: 16, bottom: 4),
                            child: Text(
                              text,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          );
                        },
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        secondary: const Icon(Icons.cloud_upload_outlined),
                        title: const Text('Ingatkan Backup ke Luar App'),
                        subtitle: const Text(
                          'Notifikasi tiap Minggu jam 19.00',
                        ),
                        value: settings.externalBackupReminderEnabled,
                        onChanged: (enabled) async {
                          if (enabled &&
                              !await ReminderService.requestPermission()) {
                            return;
                          }
                          await settings.setExternalBackupReminder(enabled);
                          if (enabled) {
                            await ReminderService.scheduleWeeklyBackup();
                          } else {
                            await ReminderService.cancelWeeklyBackup();
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _Section(
                  icon: Icons.table_view,
                  title: 'Data',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _ExportButton(),
                      const SizedBox(height: 12),
                      const _ImportButton(),
                      const SizedBox(height: 16),
                      const _BackupRestoreButtons(),
                      const SizedBox(height: 8),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.photo_library_outlined),
                        title: const Text('Kelola Foto Struk'),
                        subtitle: const Text(
                          'Liat semua foto + ukurannya, hapus yang ga perlu',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ReceiptsScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Semua perubahan otomatis kesimpen di HP.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Toggle reminder harian + pilih jamnya.
class _ReminderSetting extends StatelessWidget {
  const _ReminderSetting();

  Future<void> _enable(BuildContext context, SettingsProvider settings) async {
    // Android 13+ wajib minta izin notifikasi dulu
    final granted = await ReminderService.requestPermission();
    if (!granted) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Izin notifikasi ditolak. Aktifin dulu di setelan HP ya.',
            ),
          ),
        );
      }
      return;
    }
    await ReminderService.scheduleDaily(settings.reminderTime);
    await settings.setReminder(true, settings.reminderTime);
  }

  Future<void> _pickTime(
    BuildContext context,
    SettingsProvider settings,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: settings.reminderTime,
    );
    if (picked == null) return;
    await ReminderService.scheduleDaily(picked);
    await settings.setReminder(true, picked);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final time = settings.reminderTime;
    final label =
        '${time.hour.toString().padLeft(2, '0')}'
        ':${time.minute.toString().padLeft(2, '0')}';

    return Column(
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.notifications_active_outlined),
          title: const Text('Reminder Harian'),
          subtitle: const Text('Diingetin nyatet pengeluaran tiap hari'),
          value: settings.reminderEnabled,
          onChanged: (value) async {
            if (value) {
              await _enable(context, settings);
            } else {
              await ReminderService.cancel();
              await settings.setReminder(false, settings.reminderTime);
            }
          },
        ),
        if (settings.reminderEnabled)
          ListTile(
            contentPadding: const EdgeInsets.only(left: 40),
            leading: const Icon(Icons.schedule, size: 20),
            title: Text('Jam reminder: $label'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickTime(context, settings),
          ),
      ],
    );
  }
}

/// Import transaksi dari file Excel (format hasil export).
class _ImportButton extends StatefulWidget {
  const _ImportButton();

  @override
  State<_ImportButton> createState() => _ImportButtonState();
}

class _ImportButtonState extends State<_ImportButton> {
  bool _busy = false;

  Future<void> _import() async {
    final path = (await openFile())?.path;
    if (path == null || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import dari Excel?'),
        content: const Text(
          'Transaksi dari file bakal DITAMBAHKAN ke data sekarang '
          '(bukan menimpa). Kalau file yang sama diimport dua kali, '
          'transaksinya bakal dobel.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Import'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final result = await ExcelImporter.import(path);
      if (!mounted) return;
      await context.read<TransactionProvider>().load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.imported == 0
                ? 'Ga ada transaksi valid di file itu'
                : '${result.imported} transaksi keimport'
                      '${result.skipped > 0 ? ', ${result.skipped} baris dilewatin' : ''}',
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File-nya ga kebaca — pastiin format .xlsx'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _busy ? null : _import,
      icon: _busy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.file_upload_outlined, size: 18),
      label: Text(_busy ? 'Ngimport...' : 'Import dari Excel (.xlsx)'),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }
}

/// Backup file database + restore dari file backup.
class _BackupRestoreButtons extends StatefulWidget {
  const _BackupRestoreButtons();

  @override
  State<_BackupRestoreButtons> createState() => _BackupRestoreButtonsState();
}

class _BackupRestoreButtonsState extends State<_BackupRestoreButtons> {
  bool _busy = false;

  Future<void> _backup() async {
    setState(() => _busy = true);
    try {
      final dir = await getTemporaryDirectory();
      final now = DateTime.now();
      final name =
          'duit_nia_backup_${now.year}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}.duitges';
      final path = '${dir.path}/$name';
      await DatabaseHelper.instance.backupTo(path);
      await SharePlus.instance.share(
        ShareParams(files: [XFile(path)], text: 'Backup data Duit Ges'),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    final path = (await openFile())?.path;
    if (path == null || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore backup?'),
        content: const Text(
          'SEMUA data sekarang bakal DITIMPA sama isi file backup. '
          'Aksi ini ga bisa dibatalin. Lanjut?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Timpa & Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    final ok = await DatabaseHelper.instance.restoreFrom(path);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('File-nya bukan backup Duit Ges yang valid'),
        ),
      );
      return;
    }
    // Reload semua provider biar UI langsung nampilin data hasil restore
    await context.read<TransactionProvider>().load();
    if (!mounted) return;
    await context.read<BudgetProvider>().load();
    if (!mounted) return;
    await context.read<WalletProvider>().load();
    if (!mounted) return;
    await context.read<GoalProvider>().load();
    if (!mounted) return;
    await context.read<DebtProvider>().load();
    if (!mounted) return;
    await context.read<CategoryProvider>().load();
    if (!mounted) return;
    await context.read<RecurringProvider>().load();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Data berhasil di-restore!')));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Backup nyimpen seluruh data dan foto struk ke satu file .duitges '
          '— simpen di tempat aman.',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: _busy ? null : _backup,
                icon: const Icon(Icons.backup_outlined, size: 18),
                label: const Text('Backup'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _restore,
                icon: const Icon(Icons.restore, size: 18),
                label: const Text('Restore'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Setting kunci PIN: toggle + alur bikin/hapus PIN.
class _PinSetting extends StatelessWidget {
  const _PinSetting();

  Future<void> _enablePin(BuildContext context) async {
    final pin = await _askPin(context, 'Bikin PIN (4 digit)');
    if (pin == null || !context.mounted) return;
    final confirm = await _askPin(context, 'Ulangi PIN-nya');
    if (confirm == null || !context.mounted) return;
    if (pin != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN-nya ga sama, coba lagi ya')),
      );
      return;
    }
    await context.read<SettingsProvider>().setPin(pin);
  }

  Future<void> _disablePin(BuildContext context) async {
    final pin = await _askPin(context, 'Masukin PIN sekarang');
    if (pin == null || !context.mounted) return;
    final ok = await context.read<SettingsProvider>().removePin(pin);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('PIN salah')));
    }
  }

  Future<String?> _askPin(BuildContext context, String title) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(fontSize: 16)),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 4,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, letterSpacing: 16),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onSubmitted: (value) {
            if (value.length == 4) Navigator.pop(context, value);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.length == 4) {
                Navigator.pop(context, controller.text);
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Kunci dengan PIN'),
      subtitle: const Text('App minta PIN 4 digit tiap kali dibuka'),
      value: settings.pinEnabled,
      onChanged: (enable) {
        if (enable) {
          _enablePin(context);
        } else {
          _disablePin(context);
        }
      },
    );
  }
}

class _BackgroundTemplateOption extends StatelessWidget {
  final FrierenRialBackground background;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _BackgroundTemplateOption({
    required this.background,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: Colors.black,
          gradient: background == FrierenRialBackground.defaultBackground
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [accent.withValues(alpha: 0.6), Colors.black],
                )
              : null,
          borderRadius: BorderRadius.circular(12),
          border: selected ? Border.all(color: accent, width: 2) : null,
          image: background.asset == null
              ? null
              : DecorationImage(
                  image: AssetImage(background.asset!),
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      background.cardTone.withValues(alpha: 0.82),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 8,
              right: 8,
              bottom: 7,
              child: Text(
                background.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (selected)
              Positioned(
                top: 6,
                right: 6,
                child: Icon(Icons.check_circle, color: accent, size: 18),
              ),
          ],
        ),
      ),
    );
  }
}

/// Satu pilihan tema penuh: emoji + nama + warna khasnya.
class _ThemeOption extends StatelessWidget {
  final ThemePreset theme;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.theme,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final previewAsset = switch (theme.id) {
      'jjk' => 'assets/theme/jjk/footer_transaksi_jjk.png',
      'jjk2' => 'assets/theme/jjk2/footer_transaksi_static.png',
      'call_duck' => 'assets/theme/call_duck/footer_transaksi_static.png',
      'frieren_rial' => 'assets/theme/frieren_rial/footer_transaksi.png',
      _ => null,
    };
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: theme.defaultAccent.withValues(alpha: selected ? 0.15 : 0.05),
          border: Border.all(
            color: selected ? theme.defaultAccent : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            AnimatedScale(
              scale: selected ? 1.15 : 1.0,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutBack,
              // Tema polos tanpa maskot dipreview pakai bulatan gradient
              // warnanya; tema bergambar pakai artwork-nya.
              child: previewAsset != null
                  ? Image.asset(
                      previewAsset,
                      width: 44,
                      height: 44,
                      fit: BoxFit.contain,
                    )
                  : !theme.showMascotIcon && theme.artwork == null
                  ? Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            theme.defaultAccent,
                            HSLColor.fromColor(
                              theme.defaultAccent,
                            ).withLightness(0.3).toColor(),
                          ],
                        ),
                      ),
                    )
                  : ThemeArtwork(
                      preset: theme,
                      tile: 0,
                      size: 44,
                      fallback: Icon(
                        theme.icon,
                        size: 28,
                        color: theme.defaultAccent,
                      ),
                    ),
            ),
            const SizedBox(height: 6),
            // FittedBox: nama tema panjang (misal SpongeBob) dikecilin
            // otomatis biar muat satu baris, ga kepotong/turun baris.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  theme.name,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                    color: selected ? theme.defaultAccent : null,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kartu pembungkus tiap bagian pengaturan.
class _Section extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _Section({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: cardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _ColorSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutBack,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? color : Colors.transparent,
            width: 2.5,
          ),
        ),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: AnimatedScale(
            scale: selected ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutBack,
            child: const Icon(Icons.check, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}

/// Tombol export semua data ke file Excel lalu buka share sheet.
class _ExportButton extends StatefulWidget {
  const _ExportButton();

  @override
  State<_ExportButton> createState() => _ExportButtonState();
}

class _ExportButtonState extends State<_ExportButton> {
  bool _busy = false;

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final file = await ExcelExporter.export();
      if (!mounted) return;
      if (file == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Belum ada data buat diexport')),
        );
        return;
      }
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], text: 'Export data Duit Ges'),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Isi file: semua transaksi + rekap harian, mingguan, bulanan, dan '
          'tahunan (5 sheet).',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonalIcon(
            onPressed: _busy ? null : _export,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.file_download_outlined, size: 18),
            label: Text(_busy ? 'Nyiapin file...' : 'Export ke Excel (.xlsx)'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }
}

/// Satu pilihan template kartu: preview mini + nama + tanda kepilih.
/// Satu pilihan font: preview "Aa" + contoh nominal dirender pake
/// font itu sendiri, biar user langsung liat bedanya tanpa nebak.
class _FontOption extends StatelessWidget {
  final AppFont font;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  const _FontOption({
    required this.font,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? accent : scheme.onSurface.withValues(alpha: 0.1),
            width: selected ? 2 : 1,
          ),
          color: selected ? accent.withValues(alpha: 0.06) : Colors.transparent,
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Aa',
                style: TextStyle(
                  fontFamily: font.family,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: accent,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    font.label,
                    style: TextStyle(
                      fontFamily: font.family,
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.bold : FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${font.vibe} — Rawr',
                    style: TextStyle(
                      fontFamily: font.family,
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (selected) Icon(Icons.check_circle, color: accent, size: 20),
          ],
        ),
      ),
    );
  }
}

class _CardStyleOption extends StatelessWidget {
  final CardStyle style;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  const _CardStyleOption({
    required this.style,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  BoxDecoration _previewDecoration(BuildContext context) {
    final hsl = HSLColor.fromColor(accent);
    final bright = hsl
        .withLightness((hsl.lightness + 0.12).clamp(0.0, 1.0))
        .toColor();
    final deep = hsl
        .withLightness((hsl.lightness - 0.22).clamp(0.0, 1.0))
        .toColor();
    final radius = BorderRadius.circular(10);
    switch (style) {
      case CardStyle.gradient:
        return BoxDecoration(
          gradient: LinearGradient(colors: [bright, deep]),
          borderRadius: radius,
        );
      case CardStyle.neon:
        return BoxDecoration(
          color: const Color(0xFF0A0F1E),
          borderRadius: radius,
          border: Border.all(color: accent, width: 1.5),
          boxShadow: [
            BoxShadow(color: accent.withValues(alpha: 0.4), blurRadius: 8),
          ],
        );
      case CardStyle.glass:
        return BoxDecoration(
          color: accent.withValues(alpha: 0.1),
          borderRadius: radius,
          border: Border.all(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.2),
          ),
        );
      case CardStyle.minimal:
        return BoxDecoration(
          color: cardColor(context),
          borderRadius: radius,
          border: Border.all(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.1),
          ),
        );
      case CardStyle.jjkVideo1:
      case CardStyle.jjkVideo2:
      case CardStyle.frierenRialVideo135:
      case CardStyle.frierenRialVideo136:
      case CardStyle.frierenRialVideo137:
      case CardStyle.frierenRialVideo138:
        return BoxDecoration(color: Colors.black, borderRadius: radius);
      case CardStyle.callDuck:
        return BoxDecoration(
          image: const DecorationImage(
            image: AssetImage('assets/theme/call_duck/kartu_saldo.png'),
            fit: BoxFit.cover,
          ),
          borderRadius: radius,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? accent : scheme.onSurface.withValues(alpha: 0.1),
            width: selected ? 2 : 1,
          ),
          color: selected ? accent.withValues(alpha: 0.06) : Colors.transparent,
        ),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 40,
              clipBehavior: Clip.antiAlias,
              decoration: _previewDecoration(context),
              child: switch (style) {
                CardStyle.minimal => Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 3,
                    height: 24,
                    margin: const EdgeInsets.only(left: 5),
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                CardStyle.jjkVideo1 => const LoopingAssetVideo(
                  asset: 'assets/theme/jjk2/card_saldo_1.mp4',
                  quarterTurns: 3,
                ),
                CardStyle.jjkVideo2 => const LoopingAssetVideo(
                  asset: 'assets/theme/jjk2/card_saldo_2.mp4',
                  quarterTurns: 3,
                ),
                CardStyle.frierenRialVideo135 => const LoopingAssetVideo(
                  asset: 'assets/theme/frieren_rial/card_saldo_135.mp4',
                ),
                CardStyle.frierenRialVideo136 => const LoopingAssetVideo(
                  asset: 'assets/theme/frieren_rial/card_saldo_136.mp4',
                ),
                CardStyle.frierenRialVideo137 => const LoopingAssetVideo(
                  asset: 'assets/theme/frieren_rial/card_saldo_137.mp4',
                ),
                CardStyle.frierenRialVideo138 => const LoopingAssetVideo(
                  asset: 'assets/theme/frieren_rial/card_saldo_138.mp4',
                ),
                CardStyle.callDuck => const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xCCFFF8EC), Color(0x33FFF8EC)],
                    ),
                  ),
                ),
                _ => null,
              },
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                style.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ),
            AnimatedScale(
              scale: selected ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              child: Icon(Icons.check_circle, color: accent, size: 22),
            ),
          ],
        ),
      ),
    );
  }
}
