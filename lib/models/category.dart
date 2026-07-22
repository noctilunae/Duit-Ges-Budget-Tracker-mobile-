import 'package:flutter/material.dart';

enum TxType { income, expense }

class Category {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final TxType type;

  const Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.type,
  });
}

const List<Category> expenseCategories = [
  Category(
    id: 'makanan',
    name: 'Makanan',
    icon: Icons.restaurant,
    color: Color(0xFFFF7043),
    type: TxType.expense,
  ),
  Category(
    id: 'kopi',
    name: 'Kopi & Jajan',
    icon: Icons.local_cafe,
    color: Color(0xFF8D6E63),
    type: TxType.expense,
  ),
  Category(
    id: 'transportasi',
    name: 'Transportasi',
    icon: Icons.directions_bus,
    color: Color(0xFF42A5F5),
    type: TxType.expense,
  ),
  Category(
    id: 'belanja',
    name: 'Belanja',
    icon: Icons.shopping_bag,
    color: Color(0xFFEC407A),
    type: TxType.expense,
  ),
  Category(
    id: 'hiburan',
    name: 'Hiburan',
    icon: Icons.movie,
    color: Color(0xFFAB47BC),
    type: TxType.expense,
  ),
  Category(
    id: 'game',
    name: 'Game',
    icon: Icons.sports_esports,
    color: Color(0xFF7E57C2),
    type: TxType.expense,
  ),
  Category(
    id: 'tagihan',
    name: 'Tagihan',
    icon: Icons.receipt_long,
    color: Color(0xFFFFA726),
    type: TxType.expense,
  ),
  Category(
    id: 'internet',
    name: 'Internet & Pulsa',
    icon: Icons.wifi,
    color: Color(0xFF26C6DA),
    type: TxType.expense,
  ),
  Category(
    id: 'rumah',
    name: 'Rumah',
    icon: Icons.home,
    color: Color(0xFF66BB6A),
    type: TxType.expense,
  ),
  Category(
    id: 'kesehatan',
    name: 'Kesehatan',
    icon: Icons.local_hospital,
    color: Color(0xFFEF5350),
    type: TxType.expense,
  ),
  Category(
    id: 'olahraga',
    name: 'Olahraga',
    icon: Icons.fitness_center,
    color: Color(0xFF26A69A),
    type: TxType.expense,
  ),
  Category(
    id: 'pendidikan',
    name: 'Pendidikan',
    icon: Icons.school,
    color: Color(0xFF5C6BC0),
    type: TxType.expense,
  ),
  Category(
    id: 'perawatan',
    name: 'Perawatan',
    icon: Icons.spa,
    color: Color(0xFFF06292),
    type: TxType.expense,
  ),
  Category(
    id: 'liburan',
    name: 'Liburan',
    icon: Icons.flight,
    color: Color(0xFF29B6F6),
    type: TxType.expense,
  ),
  Category(
    id: 'donasi',
    name: 'Donasi',
    icon: Icons.volunteer_activism,
    color: Color(0xFFFFB300),
    type: TxType.expense,
  ),
  Category(
    id: 'peliharaan',
    name: 'Peliharaan',
    icon: Icons.pets,
    color: Color(0xFFA1887F),
    type: TxType.expense,
  ),
  Category(
    id: 'sembako',
    name: 'Sembako',
    icon: Icons.local_grocery_store,
    color: Color(0xFF7CB342),
    type: TxType.expense,
  ),
  Category(
    id: 'sewa',
    name: 'Kos & Sewa',
    icon: Icons.apartment,
    color: Color(0xFF8D6E63),
    type: TxType.expense,
  ),
  Category(
    id: 'bensin',
    name: 'Bensin',
    icon: Icons.local_gas_station,
    color: Color(0xFFFF7043),
    type: TxType.expense,
  ),
  Category(
    id: 'parkir',
    name: 'Parkir',
    icon: Icons.local_parking,
    color: Color(0xFF5C6BC0),
    type: TxType.expense,
  ),
  Category(
    id: 'laundry',
    name: 'Laundry',
    icon: Icons.local_laundry_service,
    color: Color(0xFF26C6DA),
    type: TxType.expense,
  ),
  Category(
    id: 'langganan',
    name: 'Langganan',
    icon: Icons.subscriptions,
    color: Color(0xFF7E57C2),
    type: TxType.expense,
  ),
  Category(
    id: 'pajak',
    name: 'Pajak',
    icon: Icons.account_balance,
    color: Color(0xFF546E7A),
    type: TxType.expense,
  ),
  Category(
    id: 'asuransi',
    name: 'Asuransi',
    icon: Icons.verified_user,
    color: Color(0xFF00897B),
    type: TxType.expense,
  ),
  Category(
    id: 'kantor',
    name: 'Keperluan Kerja',
    icon: Icons.business_center,
    color: Color(0xFF6D4C41),
    type: TxType.expense,
  ),
  Category(
    id: 'hobi',
    name: 'Hobi',
    icon: Icons.palette,
    color: Color(0xFFEC407A),
    type: TxType.expense,
  ),
  Category(
    id: 'keluarga',
    name: 'Keluarga',
    icon: Icons.family_restroom,
    color: Color(0xFFFFA726),
    type: TxType.expense,
  ),
  Category(
    id: 'elektronik',
    name: 'Elektronik',
    icon: Icons.devices,
    color: Color(0xFF42A5F5),
    type: TxType.expense,
  ),
  Category(
    id: 'lainnya_keluar',
    name: 'Lainnya',
    icon: Icons.more_horiz,
    color: Color(0xFF78909C),
    type: TxType.expense,
  ),
];

const List<Category> incomeCategories = [
  Category(
    id: 'gaji',
    name: 'Gaji',
    icon: Icons.payments,
    color: Color(0xFF26A69A),
    type: TxType.income,
  ),
  Category(
    id: 'freelance',
    name: 'Freelance',
    icon: Icons.laptop_mac,
    color: Color(0xFF5C6BC0),
    type: TxType.income,
  ),
  Category(
    id: 'bonus',
    name: 'Bonus',
    icon: Icons.card_giftcard,
    color: Color(0xFF66BB6A),
    type: TxType.income,
  ),
  Category(
    id: 'investasi',
    name: 'Investasi',
    icon: Icons.trending_up,
    color: Color(0xFF00ACC1),
    type: TxType.income,
  ),
  Category(
    id: 'jualan',
    name: 'Jualan',
    icon: Icons.storefront,
    color: Color(0xFF29B6F6),
    type: TxType.income,
  ),
  Category(
    id: 'cashback',
    name: 'Cashback',
    icon: Icons.redeem,
    color: Color(0xFFFF7043),
    type: TxType.income,
  ),
  Category(
    id: 'thr',
    name: 'THR',
    icon: Icons.celebration,
    color: Color(0xFFAB47BC),
    type: TxType.income,
  ),
  Category(
    id: 'usaha',
    name: 'Usaha',
    icon: Icons.business_center,
    color: Color(0xFF00897B),
    type: TxType.income,
  ),
  Category(
    id: 'komisi',
    name: 'Komisi',
    icon: Icons.handshake,
    color: Color(0xFF7CB342),
    type: TxType.income,
  ),
  Category(
    id: 'dividen',
    name: 'Dividen',
    icon: Icons.savings,
    color: Color(0xFF43A047),
    type: TxType.income,
  ),
  Category(
    id: 'bunga',
    name: 'Bunga',
    icon: Icons.account_balance,
    color: Color(0xFF5C6BC0),
    type: TxType.income,
  ),
  Category(
    id: 'sewa_masuk',
    name: 'Hasil Sewa',
    icon: Icons.home_work,
    color: Color(0xFF26A69A),
    type: TxType.income,
  ),
  Category(
    id: 'refund',
    name: 'Refund',
    icon: Icons.currency_exchange,
    color: Color(0xFFFF7043),
    type: TxType.income,
  ),
  Category(
    id: 'jual_aset',
    name: 'Jual Aset',
    icon: Icons.sell,
    color: Color(0xFF29B6F6),
    type: TxType.income,
  ),
  // 'Lainnya' pemasukan mesti paling akhir: categoryById fallback ke sini.
  Category(
    id: 'lainnya_masuk',
    name: 'Lainnya',
    icon: Icons.more_horiz,
    color: Color(0xFF78909C),
    type: TxType.income,
  ),
];

/// Kategori khusus transfer antar dompet — sengaja DI LUAR list
/// expense/income biar ga muncul di picker, budget, dan statistik.
const transferOut = Category(
  id: 'transfer_keluar',
  name: 'Transfer Keluar',
  icon: Icons.swap_horiz,
  color: Color(0xFF607D8B),
  type: TxType.expense,
);

const transferIn = Category(
  id: 'transfer_masuk',
  name: 'Transfer Masuk',
  icon: Icons.swap_horiz,
  color: Color(0xFF607D8B),
  type: TxType.income,
);

/// Kategori sistem untuk uang yang dipindahkan dari dompet ke target.
/// Di luar picker biasa, tetapi tetap tampil jelas di riwayat transaksi.
const goalSaving = Category(
  id: 'tabungan_target',
  name: 'Tabungan Target',
  icon: Icons.savings,
  color: Color(0xFF26A69A),
  type: TxType.expense,
);

const debtPaymentOut = Category(
  id: 'bayar_utang',
  name: 'Bayar Utang',
  icon: Icons.handshake,
  color: Color(0xFFEF5350),
  type: TxType.expense,
);

const debtPaymentIn = Category(
  id: 'bayar_piutang',
  name: 'Pembayaran Piutang',
  icon: Icons.handshake,
  color: Color(0xFF26A69A),
  type: TxType.income,
);

const _fallback = Category(
  id: 'lainnya_masuk',
  name: 'Lainnya',
  icon: Icons.more_horiz,
  color: Color(0xFF78909C),
  type: TxType.income,
);

const List<Category> allCategories = [
  ...expenseCategories,
  ...incomeCategories,
  transferOut,
  transferIn,
  goalSaving,
  debtPaymentOut,
  debtPaymentIn,
];

/// Kategori bikinan user — diisi CategoryProvider pas app nyala.
/// Global biar [categoryById] tetep bisa sinkron dipanggil dari mana aja.
final Map<String, Category> customCategoryRegistry = {};

Category categoryById(String id) {
  final custom = customCategoryRegistry[id];
  if (custom != null) return custom;
  return allCategories.firstWhere((c) => c.id == id, orElse: () => _fallback);
}

/// Pilihan icon buat kategori custom (key disimpen di database).
const categoryIconChoices = <String, IconData>{
  'restaurant': Icons.restaurant,
  'cafe': Icons.local_cafe,
  'coffee': Icons.coffee,
  'bus': Icons.directions_bus,
  'car': Icons.directions_car,
  'bag': Icons.shopping_bag,
  'movie': Icons.movie,
  'game': Icons.sports_esports,
  'music': Icons.music_note,
  'receipt': Icons.receipt_long,
  'wifi': Icons.wifi,
  'home': Icons.home,
  'health': Icons.local_hospital,
  'gym': Icons.fitness_center,
  'school': Icons.school,
  'book': Icons.menu_book,
  'spa': Icons.spa,
  'flight': Icons.flight,
  'donate': Icons.volunteer_activism,
  'pet': Icons.pets,
  'baby': Icons.child_friendly,
  'groceries': Icons.local_grocery_store,
  'fastfood': Icons.fastfood,
  'train': Icons.train,
  'taxi': Icons.local_taxi,
  'bike': Icons.directions_bike,
  'fuel': Icons.local_gas_station,
  'parking': Icons.local_parking,
  'laundry': Icons.local_laundry_service,
  'apartment': Icons.apartment,
  'work': Icons.business_center,
  'tools': Icons.build,
  'electric': Icons.electrical_services,
  'subscription': Icons.subscriptions,
  'bank': Icons.account_balance,
  'insurance': Icons.verified_user,
  'family': Icons.family_restroom,
  'devices': Icons.devices,
  'phone': Icons.smartphone,
  'medicine': Icons.medication,
  'beauty': Icons.face_retouching_natural,
  'palette': Icons.palette,
  'camera': Icons.photo_camera,
  'garden': Icons.yard,
  'money': Icons.payments,
  'laptop': Icons.laptop_mac,
  'gift': Icons.card_giftcard,
  'chart': Icons.trending_up,
  'store': Icons.storefront,
  'star': Icons.star,
  'savings': Icons.savings,
  'handshake': Icons.handshake,
  'refund': Icons.currency_exchange,
  'sell': Icons.sell,
  'rent': Icons.home_work,
  'food_bank': Icons.food_bank,
  'cake': Icons.cake,
  'event': Icons.event,
  'ticket': Icons.confirmation_number,
  'other': Icons.category,
};

const categoryColorChoices = [
  Color(0xFFD32F2F),
  Color(0xFFEF5350),
  Color(0xFFFF7043),
  Color(0xFFFFA726),
  Color(0xFFFDD835),
  Color(0xFFFFCA28),
  Color(0xFFFFEE58),
  Color(0xFFFFF59D),
  Color(0xFF2E7D32),
  Color(0xFF7CB342),
  Color(0xFF66BB6A),
  Color(0xFF26A69A),
  Color(0xFF26C6DA),
  Color(0xFF1565C0),
  Color(0xFF42A5F5),
  Color(0xFF5C6BC0),
  Color(0xFF7E57C2),
  Color(0xFF6A1B9A),
  Color(0xFFAB47BC),
  Color(0xFFEC407A),
  Color(0xFF8D6E63),
];

/// Satu nama per baris atau dipisah koma; maksimal 20 kategori sekali simpan.
List<String> parseCategoryNames(String input) {
  final names = <String>{};
  for (final raw in input.split(RegExp(r'[\n,]'))) {
    final name = raw.trim();
    if (name.isNotEmpty) {
      names.add(name.length > 30 ? name.substring(0, 30) : name);
    }
  }
  return names.take(20).toList();
}

/// Data mentah kategori custom (nyimpen iconKey biar bisa diedit).
class CustomCategory {
  final String id;
  final String name;
  final String iconKey;
  final Color color;
  final TxType type;

  const CustomCategory({
    required this.id,
    required this.name,
    required this.iconKey,
    required this.color,
    required this.type,
  });

  Category toCategory() => Category(
    id: id,
    name: name,
    icon: categoryIconChoices[iconKey] ?? Icons.category,
    color: color,
    type: type,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'icon': iconKey,
    'color': color.toARGB32(),
    'type': type.name,
  };

  factory CustomCategory.fromMap(Map<String, dynamic> map) => CustomCategory(
    id: map['id'] as String,
    name: map['name'] as String,
    iconKey: map['icon'] as String,
    color: Color(map['color'] as int),
    type: TxType.values.byName(map['type'] as String),
  );
}

bool isTransferCategory(String categoryId) =>
    categoryId == transferOut.id || categoryId == transferIn.id;
