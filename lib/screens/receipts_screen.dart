import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../db/database_helper.dart';
import '../providers/transaction_provider.dart';
import '../utils/app_style.dart';
import '../utils/formatters.dart';

class _ReceiptInfo {
  final File file;
  final int bytes;
  final DateTime date;
  final bool used;

  const _ReceiptInfo({
    required this.file,
    required this.bytes,
    required this.date,
    required this.used,
  });
}

String _formatBytes(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
  return '${(bytes / 1024).round()} KB';
}

/// Kelola semua foto struk: liat, cek ukuran, hapus biar ga numpuk.
class ReceiptsScreen extends StatefulWidget {
  const ReceiptsScreen({super.key});

  @override
  State<ReceiptsScreen> createState() => _ReceiptsScreenState();
}

class _ReceiptsScreenState extends State<ReceiptsScreen> {
  List<_ReceiptInfo>? _receipts;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final dir = await getApplicationDocumentsDirectory();
    final strukDir = Directory('${dir.path}/struk');
    if (!await strukDir.exists()) {
      if (mounted) setState(() => _receipts = []);
      return;
    }
    final used = await DatabaseHelper.instance.usedReceiptPaths();
    final infos = <_ReceiptInfo>[];
    await for (final entity in strukDir.list()) {
      if (entity is! File) continue;
      final stat = await entity.stat();
      // Nama file = timestamp pas foto diambil
      final name = entity.uri.pathSegments.last.split('.').first;
      final ts = int.tryParse(name);
      infos.add(
        _ReceiptInfo(
          file: entity,
          bytes: stat.size,
          date: ts != null
              ? DateTime.fromMillisecondsSinceEpoch(ts)
              : stat.modified,
          used: used.contains(entity.path),
        ),
      );
    }
    infos.sort((a, b) => b.date.compareTo(a.date));
    if (mounted) setState(() => _receipts = infos);
  }

  Future<void> _delete(_ReceiptInfo receipt) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus foto ini?'),
        content: Text(
          receipt.used
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
    await DatabaseHelper.instance.clearReceiptPath(receipt.file.path);
    if (await receipt.file.exists()) await receipt.file.delete();
    if (!mounted) return;
    // Refresh list transaksi biar foto yang ilang ga direferensiin lagi
    await context.read<TransactionProvider>().load();
    await _load();
  }

  Future<void> _deleteUnused(List<_ReceiptInfo> receipts) async {
    final unused = receipts.where((receipt) => !receipt.used).toList();
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
    for (final receipt in unused) {
      if (await receipt.file.exists()) await receipt.file.delete();
    }
    await _load();
  }

  void _preview(_ReceiptInfo receipt) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: InteractiveViewer(
          child: Image.file(receipt.file, cacheWidth: 1200),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final receipts = _receipts;
    final totalBytes = receipts?.fold<int>(0, (sum, r) => sum + r.bytes) ?? 0;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(title: const Text('Foto Struk')),
      body: receipts == null
          ? const Center(child: CircularProgressIndicator())
          : receipts.isEmpty
          ? Center(
              child: Text(
                'Belum ada foto struk tersimpan',
                style: TextStyle(color: muted),
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Row(
                    children: [
                      Icon(Icons.sd_storage_outlined, size: 16, color: muted),
                      const SizedBox(width: 6),
                      Text(
                        '${receipts.length} foto • total '
                        '${_formatBytes(totalBytes)}',
                        style: TextStyle(fontSize: 13, color: muted),
                      ),
                      const Spacer(),
                      if (receipts.any((receipt) => !receipt.used))
                        TextButton(
                          onPressed: () => _deleteUnused(receipts),
                          child: const Text('Bersihkan'),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: receipts.length,
                    itemBuilder: (context, index) {
                      final receipt = receipts[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: cardColor(context),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: cardShadow(context),
                        ),
                        child: ListTile(
                          onTap: () => _preview(receipt),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              receipt.file,
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                              // cacheWidth: decode kecil aja buat
                              // thumbnail, ga usah full resolusi
                              cacheWidth: 120,
                            ),
                          ),
                          title: Text(
                            tanggalPendek(receipt.date),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            '${_formatBytes(receipt.bytes)} • '
                            '${receipt.used ? 'dipakai transaksi' : 'ga kepakai'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: receipt.used
                                  ? muted
                                  : const Color(0xFFFFA726),
                            ),
                          ),
                          trailing: IconButton(
                            tooltip: 'Hapus foto',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _delete(receipt),
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
