import 'package:flutter/material.dart';

/// Pilihan icon dompet (disimpen sebagai key string di DB).
const walletIcons = <String, IconData>{
  'cash': Icons.payments,
  'bank': Icons.account_balance,
  'ewallet': Icons.smartphone,
  'card': Icons.credit_card,
  'savings': Icons.savings,
  'invest': Icons.trending_up,
};

const walletColors = [
  Color(0xFF26A69A),
  Color(0xFF2E5BFF),
  Color(0xFFFF7043),
  Color(0xFFAB47BC),
  Color(0xFF66BB6A),
  Color(0xFFFFA726),
  Color(0xFFEC407A),
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
