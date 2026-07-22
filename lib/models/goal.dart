import 'package:flutter/material.dart';

import 'category.dart';

/// Target nabung (savings goal): "Beli laptop Rp 15jt", dst.
class Goal {
  final int? id;
  final String name;
  final double target;
  final double saved;
  final Color color;
  final String iconKey;

  const Goal({
    this.id,
    required this.name,
    required this.target,
    this.saved = 0,
    this.color = const Color(0xFF2E5BFF),
    this.iconKey = 'savings',
  });

  String? get emoji =>
      iconKey.startsWith('emoji:') ? iconKey.substring(6) : null;
  IconData get icon => categoryIconChoices[iconKey] ?? Icons.savings;
  Widget iconWidget({Color? color, double? size}) => emoji == null
      ? Icon(icon, color: color, size: size)
      : Text(emoji!, style: TextStyle(fontSize: size));

  bool get achieved => saved >= target;
  double get fraction => target == 0 ? 0 : (saved / target).clamp(0.0, 1.0);

  Goal copyWith({
    String? name,
    double? target,
    double? saved,
    Color? color,
    String? iconKey,
  }) {
    return Goal(
      id: id,
      name: name ?? this.name,
      target: target ?? this.target,
      saved: saved ?? this.saved,
      color: color ?? this.color,
      iconKey: iconKey ?? this.iconKey,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'target': target.round(),
    'saved': saved.round(),
    'color': color.toARGB32(),
    'icon': iconKey,
  };

  factory Goal.fromMap(Map<String, dynamic> map) => Goal(
    id: map['id'] as int?,
    name: map['name'] as String,
    target: (map['target'] as num).toDouble(),
    saved: (map['saved'] as num?)?.toDouble() ?? 0,
    color: Color(map['color'] as int? ?? 0xFF2E5BFF),
    iconKey: map['icon'] as String? ?? 'savings',
  );
}
