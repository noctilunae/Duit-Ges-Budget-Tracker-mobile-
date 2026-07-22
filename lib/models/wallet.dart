import 'package:flutter/material.dart';

/// Pilihan icon dompet (disimpen sebagai key string di DB).
const walletIcons = <String, IconData>{
  'cash': Icons.payments,
  'bank': Icons.account_balance,
  'ewallet': Icons.smartphone,
  'card': Icons.credit_card,
  'savings': Icons.savings,
  'invest': Icons.trending_up,
  'wallet': Icons.wallet,
  'balance': Icons.account_balance_wallet,
  'exchange': Icons.currency_exchange,
  'store': Icons.storefront,
  'gift': Icons.card_giftcard,
  'property': Icons.home_work,
  'work': Icons.business_center,
  'handshake': Icons.handshake,
  'egg': Icons.egg_outlined,
  'pet': Icons.pets,
  'animal': Icons.cruelty_free,
  'other': Icons.category,
};

const walletColors = [
  Color(0xFFEF5350),
  Color(0xFFFF7043),
  Color(0xFFFFA726),
  Color(0xFFFFCA28),
  Color(0xFFFFF176),
  Color(0xFF66BB6A),
  Color(0xFF26A69A),
  Color(0xFF26C6DA),
  Color(0xFF2E5BFF),
  Color(0xFF5C6BC0),
  Color(0xFFAB47BC),
  Color(0xFFEC407A),
  Color(0xFF8D6E63),
  Color(0xFF78909C),
];

class Wallet {
  final int? id;
  final String name;
  final String iconKey;
  final Color color;
  final double initialBalance;

  const Wallet({
    this.id,
    required this.name,
    this.iconKey = 'cash',
    this.color = const Color(0xFF26A69A),
    this.initialBalance = 0,
  });

  IconData get icon => walletIcons[iconKey] ?? Icons.wallet;
  String? get emoji =>
      iconKey.startsWith('emoji:') ? iconKey.substring(6) : null;

  Widget iconWidget({Color? color, double? size}) => emoji == null
      ? Icon(icon, color: color, size: size)
      : Text(emoji!, style: TextStyle(fontSize: size));

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'icon': iconKey,
      'color': color.toARGB32(),
      'initial_balance': initialBalance.round(),
    };
  }

  factory Wallet.fromMap(Map<String, dynamic> map) {
    return Wallet(
      id: map['id'] as int?,
      name: map['name'] as String,
      iconKey: map['icon'] as String? ?? 'cash',
      color: Color(map['color'] as int),
      initialBalance: (map['initial_balance'] as num?)?.toDouble() ?? 0,
    );
  }
}
