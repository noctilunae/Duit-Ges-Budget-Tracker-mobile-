import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../models/category.dart';
import '../models/transaction.dart';
import '../models/wallet.dart';
import '../providers/category_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/wallet_provider.dart';
import '../utils/formatters.dart';
import '../utils/stored_icon.dart';
import '../widgets/custom_image_icon_picker.dart';

class AddTransactionScreen extends StatefulWidget {
  /// Kalau diisi, layar ini jadi mode edit (prefill + update, bukan insert).
  final TransactionModel? existing;

  /// Prefill transaksi baru, misalnya dari catatan utang/piutang.
  final TransactionModel? draft;
  final String? budgetId;
  final TxType? transactionType;
  final String? categoryId;

  const AddTransactionScreen({
    super.key,
    this.existing,
    this.draft,
    this.budgetId,
    this.transactionType,
    this.categoryId,
  }) : assert(existing == null || draft == null);

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  TxType _type = TxType.expense;
  String? _categoryId;
  int? _walletId;
  String? _receiptPath;
  DateTime _date = DateTime.now();
  bool _showAllCategories = false;
  int _walletPage = 0;
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _amountFocus = FocusNode();
  final _unsavedReceiptPaths = <String>{};
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final seed = widget.existing ?? widget.draft;
    if (seed != null) {
      _type = widget.transactionType ?? seed.type;
      _categoryId =
          widget.transactionType != null && widget.transactionType != seed.type
          ? null
          : seed.categoryId;
      _walletId = seed.walletId;
      _receiptPath = seed.receiptPath;
      _date = seed.date;
      _amountController.text = groupRibuan(seed.amount.toInt().toString());
      _noteController.text = seed.note;
    } else {
      _type = widget.transactionType ?? TxType.expense;
      _categoryId = widget.categoryId;
    }
    final wallets = context.read<WalletProvider>();
    _walletId ??= wallets.defaultWalletId;
    final index = wallets.wallets.indexWhere(
      (wallet) => wallet.id == _walletId,
    );
    if (index >= 0) _walletPage = index ~/ 2;
  }

  @override
  void dispose() {
    for (final path in _unsavedReceiptPaths) {
      File(path).delete().ignore();
    }
    _amountController.dispose();
    _noteController.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  /// [addAgain] true = simpan lalu form direset buat input berikutnya
  /// (batch input banyak transaksi sekaligus tanpa keluar-masuk layar).
  Future<void> _save({bool addAgain = false}) async {
    if (_saving) return;
    // Buang titik ribuan dulu ("1.250.000" → "1250000") baru diparse.
    final amount =
        double.tryParse(_amountController.text.replaceAll('.', '')) ?? 0;
    if (amount <= 0) {
      _showError('Isi jumlahnya dulu ya');
      return;
    }
    if (_categoryId == null) {
      _showError('Pilih kategorinya dulu');
      return;
    }
    // Pas edit, jam aslinya dipertahankan; transaksi baru pakai jam sekarang.
    final time = widget.existing?.date ?? DateTime.now();
    final wallets = context.read<WalletProvider>().wallets;
    final tx = TransactionModel(
      id: widget.existing?.id,
      amount: amount,
      categoryId: _categoryId!,
      note: _noteController.text.trim(),
      date: DateTime(
        _date.year,
        _date.month,
        _date.day,
        time.hour,
        time.minute,
      ),
      type: _type,
      walletId:
          _walletId ??
          context.read<WalletProvider>().defaultWalletId ??
          wallets.first.id ??
          1,
      receiptPath: _receiptPath,
      sourceType: widget.existing?.sourceType,
      sourceId: widget.existing?.sourceId,
      budgetId: widget.existing?.budgetId ?? widget.budgetId,
    );
    final provider = context.read<TransactionProvider>();
    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await provider.updateTransaction(tx);
      } else {
        await provider.addTransaction(tx);
      }
      if (_receiptPath != null) _unsavedReceiptPaths.remove(_receiptPath);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        _showError('Transaksi gagal disimpan, coba lagi ya');
      }
      return;
    }
    if (!mounted) return;
    setState(() => _saving = false);
    if (addAgain) {
      // Reset nominal/catatan/struk doang — tipe, kategori, dompet, dan
      // tanggal dipertahankan biar input beruntun makin cepet.
      setState(() {
        _amountController.clear();
        _noteController.clear();
        _receiptPath = null;
      });
      _amountFocus.requestFocus();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${categoryById(tx.categoryId).name} '
            '${rupiah(tx.amount)} tersimpan — gas lanjut!',
          ),
          duration: const Duration(seconds: 1),
        ),
      );
      return;
    }
    Navigator.pop(context);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Ambil foto struk dari kamera/galeri, copy ke storage app
  /// (file asli galeri bisa dihapus user, makanya di-copy).
  Future<void> _pickReceipt(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 80,
    );
    if (picked == null) return;
    final dir = await getApplicationDocumentsDirectory();
    final strukDir = Directory('${dir.path}/struk');
    await strukDir.create(recursive: true);
    final path =
        '${strukDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(picked.path).copy(path);
    if (!mounted) {
      File(path).delete().ignore();
      return;
    }
    final previous = _receiptPath;
    _unsavedReceiptPaths.add(path);
    setState(() => _receiptPath = path);
    _discardUnsavedReceipt(previous);
  }

  void _discardUnsavedReceipt(String? path) {
    if (path == null || !_unsavedReceiptPaths.remove(path)) return;
    File(path).delete().ignore();
  }

  void _showReceiptPicker() {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Foto pake kamera'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickReceipt(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pilih dari galeri'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickReceipt(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCategoryManager() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _CategoryManagerSheet(initialType: _type),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<CategoryProvider>();
    final allCategoriesForType = _type == TxType.expense
        ? categories.expenseAll
        : categories.incomeAll;
    // Default cuma nampilin kategori favorit (berbintang); sisanya nongol
    // setelah tombol dropdown dipencet. Kategori yang lagi kepilih selalu
    // ikut tampil biar ga "ilang" pas mode edit. Tombol dropdown-nya
    // nempel tepat setelah favorit (bukan paling bawah) biar posisinya
    // tetep — nutup lagi ga perlu scroll nyari tombolnya.
    final favorites = [
      ...allCategoriesForType.where((c) => categories.isHighlighted(c.id)),
      if (_categoryId != null &&
          !allCategoriesForType.any(
            (c) => categories.isHighlighted(c.id) && c.id == _categoryId,
          ))
        ...allCategoriesForType.where((c) => c.id == _categoryId),
    ];
    final rest = allCategoriesForType
        .where((c) => !favorites.contains(c))
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Transaksi' : 'Tambah Transaksi'),
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<TxType>(
            segments: const [
              ButtonSegment(
                value: TxType.expense,
                label: Text('Pengeluaran'),
                icon: Icon(Icons.arrow_upward, size: 16),
              ),
              ButtonSegment(
                value: TxType.income,
                label: Text('Pemasukan'),
                icon: Icon(Icons.arrow_downward, size: 16),
              ),
            ],
            selected: {_type},
            onSelectionChanged: widget.transactionType != null
                ? null
                : (selection) {
                    setState(() {
                      _type = selection.first;
                      _categoryId = null;
                    });
                  },
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _amountController,
            focusNode: _amountFocus,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              RibuanInputFormatter(),
            ],
            autofocus: true,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
            decoration: const InputDecoration(
              prefixText: 'Rp ',
              hintText: '0',
              border: UnderlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          _ReceiptTile(
            hasReceipt: _receiptPath != null,
            onTap: _showReceiptPicker,
            onRemove: () {
              _discardUnsavedReceipt(_receiptPath);
              setState(() {
                _receiptPath = null;
              });
            },
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Kategori',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
              TextButton.icon(
                onPressed: _showCategoryManager,
                icon: const Icon(Icons.tune, size: 17),
                label: const Text('Kelola'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 8,
            childAspectRatio: 0.9,
            children: [
              for (final category in favorites)
                _CategoryItem(
                  category: category,
                  selected: category.id == _categoryId,
                  highlighted: categories.isHighlighted(category.id),
                  onTap: () => setState(() => _categoryId = category.id),
                ),
              // Tombol dropdown buat munculin/nyembunyiin sisa kategori
              if (favorites.isNotEmpty)
                _ExpandCategoriesTile(
                  expanded: _showAllCategories,
                  onTap: () =>
                      setState(() => _showAllCategories = !_showAllCategories),
                ),
              if (favorites.isEmpty || _showAllCategories)
                for (final category in rest)
                  _CategoryItem(
                    category: category,
                    selected: category.id == _categoryId,
                    highlighted: categories.isHighlighted(category.id),
                    onTap: () => setState(() => _categoryId = category.id),
                  ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Dompet',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Builder(
            builder: (context) {
              final wallets = context.watch<WalletProvider>().wallets;
              final selectedId =
                  _walletId ?? context.watch<WalletProvider>().defaultWalletId;
              // Cuma 2 dompet per halaman; panah kanan muter ke
              // halaman berikutnya (wrap-around).
              const perPage = 2;
              final pages = (wallets.length / perPage).ceil();
              final page = pages == 0 ? 0 : _walletPage % pages;
              final visible = wallets
                  .skip(page * perPage)
                  .take(perPage)
                  .toList();
              return Row(
                children: [
                  for (final wallet in visible)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _WalletChip(
                          wallet: wallet,
                          selected: wallet.id == selectedId,
                          onTap: () => setState(() => _walletId = wallet.id),
                        ),
                      ),
                    ),
                  // Kalau halaman terakhir isinya cuma 1, tambahin slot
                  // kosong biar lebarnya konsisten.
                  if (visible.length < perPage)
                    const Expanded(child: SizedBox()),
                  if (wallets.length > perPage)
                    IconButton(
                      tooltip: 'Dompet berikutnya',
                      onPressed: () => setState(() => _walletPage = page + 1),
                      icon: const Icon(Icons.chevron_right),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today, size: 20),
            title: Text(tanggalPendek(_date)),
            trailing: const Icon(Icons.chevron_right),
            onTap: _pickDate,
          ),
          TextField(
            controller: _noteController,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Catatan (opsional)',
              prefixIcon: Icon(Icons.notes, size: 20),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          if (_isEdit)
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                'Simpan Perubahan',
                style: TextStyle(fontSize: 16),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => _save(addAgain: true),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'Simpan & Lagi',
                      style: TextStyle(fontSize: 15),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Simpan', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ReceiptTile extends StatelessWidget {
  final bool hasReceipt;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _ReceiptTile({
    required this.hasReceipt,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      leading: const Icon(Icons.receipt_long, size: 20),
      title: Text(hasReceipt ? 'Foto struk terpasang' : 'Tambah foto struk'),
      subtitle: const Text('Opsional, simpan foto struk'),
      trailing: hasReceipt
          ? IconButton(
              tooltip: 'Hapus foto struk',
              onPressed: onRemove,
              icon: Icon(Icons.close, color: muted),
            )
          : const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _CategoryItem extends StatelessWidget {
  final Category category;
  final bool selected;
  final bool highlighted;
  final VoidCallback onTap;

  const _CategoryItem({
    required this.category,
    required this.selected,
    required this.highlighted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedScale(
            scale: selected ? 1.12 : 1.0,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutBack,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected
                        ? category.color
                        : category.color.withValues(alpha: 0.15),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: category.color.withValues(alpha: 0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: category.iconWidget(
                      color: selected ? Colors.white : category.color,
                      size: 24,
                    ),
                  ),
                ),
                if (highlighted)
                  Positioned(
                    right: -2,
                    top: -3,
                    child: Icon(
                      Icons.star_rounded,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontSize: 11,
              color: selected
                  ? category.color
                  : Theme.of(context).colorScheme.onSurface,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
            child: Text(
              category.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tile terakhir di grid kategori: dropdown buat buka/tutup sisa kategori.
class _ExpandCategoriesTile extends StatelessWidget {
  final bool expanded;
  final VoidCallback onTap;

  const _ExpandCategoriesTile({required this.expanded, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.primary.withValues(alpha: 0.1),
              border: Border.all(color: scheme.primary.withValues(alpha: 0.35)),
            ),
            child: AnimatedRotation(
              turns: expanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              child: Icon(Icons.expand_more, color: scheme.primary),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            expanded ? 'Tutup' : 'Lainnya',
            maxLines: 1,
            style: TextStyle(fontSize: 11, color: scheme.primary),
          ),
        ],
      ),
    );
  }
}

/// Chip dompet lebar penuh (2 per baris) buat picker di form transaksi.
class _WalletChip extends StatelessWidget {
  final Wallet wallet;
  final bool selected;
  final VoidCallback onTap;

  const _WalletChip({
    required this.wallet,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? wallet.color : wallet.color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? wallet.color : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            wallet.iconWidget(
              size: 16,
              color: selected ? Colors.white : wallet.color,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                wallet.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                  color: selected
                      ? Colors.white
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryManagerSheet extends StatefulWidget {
  final TxType initialType;

  const _CategoryManagerSheet({required this.initialType});

  @override
  State<_CategoryManagerSheet> createState() => _CategoryManagerSheetState();
}

class _CategoryManagerSheetState extends State<_CategoryManagerSheet> {
  late TxType _type = widget.initialType;

  void _addCategories() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _AddCategoriesSheet(initialType: _type),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CategoryProvider>();
    final categories = _type == TxType.expense
        ? provider.expenseAll
        : provider.incomeAll;
    final customIds = provider.custom
        .where((category) => category.type == _type)
        .map((category) => category.id)
        .toSet();
    return FractionallySizedBox(
      heightFactor: 0.92,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 12),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Kelola Kategori',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<TxType>(
              segments: const [
                ButtonSegment(
                  value: TxType.expense,
                  label: Text('Pengeluaran'),
                ),
                ButtonSegment(value: TxType.income, label: Text('Pemasukan')),
              ],
              selected: {_type},
              onSelectionChanged: (value) =>
                  setState(() => _type = value.first),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Sorot di form transaksi',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'Kategori berbintang tampil paling atas.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final category in categories)
                      FilterChip(
                        selected: provider.isHighlighted(category.id),
                        showCheckmark: false,
                        avatar: category.iconWidget(
                          size: 16,
                          color: category.color,
                        ),
                        label: Text(category.name),
                        onSelected: (_) =>
                            provider.toggleHighlight(category.id),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  'Daftar kategori',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                for (final category in categories)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    onTap: customIds.contains(category.id)
                        ? () {
                            final custom = provider.custom.firstWhere(
                              (item) => item.id == category.id,
                            );
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              useSafeArea: true,
                              builder: (_) => _AddCategoriesSheet(
                                initialType: custom.type,
                                existing: custom,
                              ),
                            );
                          }
                        : null,
                    leading: CircleAvatar(
                      backgroundColor: category.color.withValues(alpha: 0.15),
                      child: category.iconWidget(
                        color: category.color,
                        size: 24,
                      ),
                    ),
                    title: Text(category.name),
                    subtitle: Text(
                      customIds.contains(category.id)
                          ? 'Tap buat edit'
                          : 'Kategori bawaan',
                      style: TextStyle(fontSize: 11),
                    ),
                    trailing: IconButton(
                      tooltip: 'Hapus kategori',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        final ok = await provider.deleteCategory(category.id);
                        if (!context.mounted || ok) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Kategori masih dipakai atau merupakan kategori terakhir',
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _addCategories,
                icon: const Icon(Icons.add),
                label: const Text('Tambah Satu atau Banyak'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddCategoriesSheet extends StatefulWidget {
  final TxType initialType;

  /// Kalau diisi, sheet ini jadi mode edit satu kategori (prefill + update).
  final CustomCategory? existing;

  const _AddCategoriesSheet({required this.initialType, this.existing});

  @override
  State<_AddCategoriesSheet> createState() => _AddCategoriesSheetState();
}

class _AddCategoriesSheetState extends State<_AddCategoriesSheet> {
  late final _namesController = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late final _emojiController = TextEditingController(
    text: widget.existing?.iconKey.startsWith('emoji:') == true
        ? widget.existing!.iconKey.substring(6)
        : '',
  );
  late TxType _type = widget.initialType;
  late String _iconKey = widget.existing?.iconKey ?? 'star';
  late Color _color = widget.existing?.color ?? categoryColorChoices.first;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _namesController.dispose();
    _emojiController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final names = parseCategoryNames(_namesController.text);
    if (names.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Isi minimal satu nama kategori')),
      );
      return;
    }
    final emoji = _emojiController.text.trim();
    if (_iconKey.startsWith('emoji:') && emoji.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Masukkan satu emoji')));
      return;
    }
    if (_iconKey.startsWith('image:') && !isValidStoredImageIcon(_iconKey)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih gambar ikon terlebih dahulu')),
      );
      return;
    }
    final savedIcon = _iconKey.startsWith('emoji:') ? 'emoji:$emoji' : _iconKey;
    setState(() => _saving = true);
    if (_isEdit) {
      // Id & tipe dipertahankan biar transaksi lama tetep nyambung.
      await context.read<CategoryProvider>().saveCategory(
        CustomCategory(
          id: widget.existing!.id,
          name: names.first,
          iconKey: savedIcon,
          color: _color,
          type: widget.existing!.type,
        ),
      );
    } else {
      final stamp = DateTime.now().microsecondsSinceEpoch;
      await context.read<CategoryProvider>().saveCategories([
        for (var i = 0; i < names.length; i++)
          CustomCategory(
            id: 'custom_${_type.name}_${stamp}_$i',
            name: names[i],
            iconKey: savedIcon,
            color: _color,
            type: _type,
          ),
      ]);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEdit ? 'Edit Kategori' : 'Tambah Kategori',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            // Tipe ga bisa diganti pas edit — transaksi lama udah kadung
            // kecatat sebagai pengeluaran/pemasukan.
            if (!_isEdit) ...[
              SegmentedButton<TxType>(
                segments: const [
                  ButtonSegment(
                    value: TxType.expense,
                    label: Text('Pengeluaran'),
                  ),
                  ButtonSegment(value: TxType.income, label: Text('Pemasukan')),
                ],
                selected: {_type},
                onSelectionChanged: (value) =>
                    setState(() => _type = value.first),
              ),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: _namesController,
              autofocus: true,
              minLines: _isEdit ? 1 : 3,
              maxLines: _isEdit ? 1 : 5,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Nama kategori',
                hintText: _isEdit ? null : 'Laundry\nKos\nLangganan',
                helperText: _isEdit
                    ? null
                    : 'Satu per baris atau pisahkan dengan koma (maks. 20)',
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Pilih ikon',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'icon', label: Text('Ikon')),
                ButtonSegment(value: 'emoji', label: Text('Emoji')),
                ButtonSegment(value: 'image', label: Text('PNG/JPG')),
              ],
              selected: {
                _iconKey.startsWith('emoji:')
                    ? 'emoji'
                    : _iconKey.startsWith('image:')
                    ? 'image'
                    : 'icon',
              },
              onSelectionChanged: (value) => setState(() {
                _iconKey = switch (value.first) {
                  'emoji' => 'emoji:',
                  'image' =>
                    _iconKey.startsWith('image:') ? _iconKey : 'image:',
                  _ => 'star',
                };
              }),
            ),
            const SizedBox(height: 8),
            if (_iconKey.startsWith('emoji:'))
              Column(
                children: [
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _emojiController,
                    builder: (_, value, _) => CircleAvatar(
                      radius: 36,
                      backgroundColor: _color.withValues(alpha: 0.15),
                      child: value.text.trim().isEmpty
                          ? Icon(
                              Icons.emoji_emotions_outlined,
                              color: _color,
                              size: 32,
                            )
                          : Padding(
                              padding: const EdgeInsets.all(8),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  value.text.trim(),
                                  style: const TextStyle(fontSize: 32),
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Preview di lingkaran',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _emojiController,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 32),
                    decoration: const InputDecoration(
                      labelText: 'Emoji kategori',
                      hintText: '🦆',
                      helperText: 'Masukkan satu emoji dari keyboard HP',
                    ),
                  ),
                ],
              )
            else if (_iconKey.startsWith('image:'))
              CustomImageIconPicker(
                iconKey: _iconKey,
                fallbackKey: 'star',
                previewColor: _color,
                onChanged: (value) => setState(() => _iconKey = value),
              )
            else
              GridView.count(
                crossAxisCount: 7,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                children: [
                  for (final entry in categoryIconChoices.entries)
                    InkWell(
                      onTap: () => setState(() => _iconKey = entry.key),
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        decoration: BoxDecoration(
                          color: _iconKey == entry.key
                              ? _color.withValues(alpha: 0.2)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _iconKey == entry.key
                                ? _color
                                : Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        child: Icon(entry.value, color: _color),
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 20),
            const Text('Warna', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: [
                for (final color in categoryColorChoices)
                  InkWell(
                    onTap: () => setState(() => _color = color),
                    customBorder: const CircleBorder(),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: color,
                      child: _color == color
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 18,
                            )
                          : null,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(
                  _saving
                      ? 'Menyimpan...'
                      : _isEdit
                      ? 'Simpan'
                      : 'Tambahkan',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
