import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../db/database_helper.dart';
import '../providers/transaction_provider.dart';
import '../utils/app_style.dart';
import '../utils/formatters.dart';

class _StoredImageInfo {
  final File file;
  final int bytes;
  final DateTime date;
  final bool used;
  final List<String> usages;

  const _StoredImageInfo({
    required this.file,
    required this.bytes,
    required this.date,
    required this.used,
    this.usages = const [],
  });
}

/// Kelola foto struk atau ikon custom tanpa menduplikasi tampilan.
class ReceiptsScreen extends StatefulWidget {
  const ReceiptsScreen({super.key}) : icons = false;
  const ReceiptsScreen.icons({super.key}) : icons = true;

  final bool icons;

  @override
  State<ReceiptsScreen> createState() => _ReceiptsScreenState();
}

class _ReceiptsScreenState extends State<ReceiptsScreen> {
  List<_StoredImageInfo>? _items;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final dir = await getApplicationDocumentsDirectory();
    final imageDir = Directory(
      '${dir.path}/${widget.icons ? 'custom_icons' : 'struk'}',
    );
    if (!await imageDir.exists()) {
      if (mounted) setState(() => _items = []);
      return;
    }
    final iconUsages = widget.icons
        ? await DatabaseHelper.instance.customIconUsages()
        : const <String, List<String>>{};
    final used = widget.icons
        ? iconUsages.keys.toSet()
        : await DatabaseHelper.instance.usedReceiptPaths();
    final infos = <_StoredImageInfo>[];
    await for (final entity in imageDir.list()) {
      if (entity is! File) continue;
      final stat = await entity.stat();
      final name = entity.uri.pathSegments.last
          .split('.')
          .first
          .replaceFirst('icon_', '');
      final ts = int.tryParse(name);
      infos.add(
        _StoredImageInfo(
          file: entity,
          bytes: stat.size,
          date: ts != null
              ? widget.icons
                    ? DateTime.fromMicrosecondsSinceEpoch(ts)
                    : DateTime.fromMillisecondsSinceEpoch(ts)
              : stat.modified,
          used: used.contains(entity.path),
          usages: iconUsages[entity.path] ?? const [],
        ),
      );
    }
    infos.sort((a, b) => b.date.compareTo(a.date));
    if (mounted) setState(() => _items = infos);
  }

  Future<void> _delete(_StoredImageInfo item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus foto ini?'),
        content: Text(
          item.used
              ? 'Foto ini masih nempel di transaksi — transaksinya tetep '
                    'aman, cuma fotonya yang ilang.'
              : 'Foto ini udah ga dipakai transaksi manapun.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await DatabaseHelper.instance.clearReceiptPath(item.file.path);
    if (await item.file.exists()) await item.file.delete();
    if (!mounted) return;
    await context.read<TransactionProvider>().load();
    await _load();
  }

  Future<void> _deleteUnused(List<_StoredImageInfo> items) async {
    final unused = items.where((item) => !item.used).toList();
    if (unused.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bersihkan foto?'),
        content: Text('${unused.length} foto yang ga dipakai akan dihapus.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Bersihkan'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    for (final item in unused) {
      if (await item.file.exists()) await item.file.delete();
    }
    await _load();
  }

  void _preview(_StoredImageInfo item) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: InteractiveViewer(
          child: Image.file(item.file, cacheWidth: 1200),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final totalBytes =
        items?.fold<int>(0, (sum, item) => sum + item.bytes) ?? 0;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final noun = widget.icons ? 'ikon' : 'foto';

    return Scaffold(
      appBar: AppBar(title: Text(widget.icons ? 'Ikon Custom' : 'Foto Struk')),
      body: items == null
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
          ? Center(
              child: Text(
                widget.icons
                    ? 'Belum ada ikon custom tersimpan'
                    : 'Belum ada foto struk tersimpan',
                style: TextStyle(color: muted),
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Row(
                    children: [
                      Icon(
                        widget.icons
                            ? Icons.image_outlined
                            : Icons.sd_storage_outlined,
                        size: 16,
                        color: muted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${items.length} $noun • total '
                        '${formatFileSize(totalBytes)}',
                        style: TextStyle(fontSize: 13, color: muted),
                      ),
                      const Spacer(),
                      if (!widget.icons && items.any((item) => !item.used))
                        TextButton(
                          onPressed: () => _deleteUnused(items),
                          child: const Text('Bersihkan'),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final status = widget.icons
                          ? item.usages.isEmpty
                                ? 'tidak dipakai'
                                : item.usages.join(' • ')
                          : item.used
                          ? 'dipakai transaksi'
                          : 'ga kepakai';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: cardColor(context),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: cardShadow(context),
                        ),
                        child: ListTile(
                          onTap: () => _preview(item),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              item.file,
                              width: 48,
                              height: 48,
                              fit: widget.icons ? BoxFit.contain : BoxFit.cover,
                              // cacheWidth: decode kecil aja buat
                              // thumbnail, ga usah full resolusi
                              cacheWidth: 120,
                            ),
                          ),
                          title: Text(
                            tanggalPendek(item.date),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            '${formatFileSize(item.bytes)} • $status',
                            style: TextStyle(
                              fontSize: 12,
                              color: item.used
                                  ? muted
                                  : const Color(0xFFFFA726),
                            ),
                          ),
                          trailing: widget.icons
                              ? null
                              : IconButton(
                                  tooltip: 'Hapus $noun',
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => _delete(item),
                                ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
