import 'package:flutter/material.dart';

class CustomThemeProfile {
  const CustomThemeProfile({
    required this.id,
    required this.name,
    this.iconKey,
    this.previewSeconds = 3,
  });

  final String id;
  final String name;
  final String? iconKey;
  final int previewSeconds;

  CustomThemeProfile copyWith({
    String? name,
    String? iconKey,
    int? previewSeconds,
  }) => CustomThemeProfile(
    id: id,
    name: name ?? this.name,
    iconKey: iconKey ?? this.iconKey,
    previewSeconds: previewSeconds ?? this.previewSeconds,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'iconKey': iconKey,
    'previewSeconds': previewSeconds,
  };

  factory CustomThemeProfile.fromMap(Map<String, Object?> map) {
    final id = map['id'] as String? ?? '';
    final name = (map['name'] as String? ?? 'Custom').trim();
    if (!id.startsWith('custom')) {
      throw const FormatException('ID tema custom tidak valid');
    }
    return CustomThemeProfile(
      id: id,
      name: name.isEmpty ? 'Custom' : name,
      iconKey: map['iconKey'] as String?,
      previewSeconds: (map['previewSeconds'] as int? ?? 3).clamp(1, 5),
    );
  }
}

class ThemeCustomization {
  const ThemeCustomization({
    this.pageColors = const {},
    this.artwork = const {},
    this.footerArtwork = const {},
    this.icons = const {},
    this.plusX = 0,
    this.plusY = 0,
  });

  final Map<int, int> pageColors;
  final Map<int, String> artwork;
  final Map<int, String> footerArtwork;
  final Map<String, String> icons;
  final double plusX;
  final double plusY;

  Color? pageColor(int page) {
    final value = pageColors[page];
    return value == null ? null : Color(value);
  }

  ThemeCustomization copyWith({
    Map<int, int>? pageColors,
    Map<int, String>? artwork,
    Map<int, String>? footerArtwork,
    Map<String, String>? icons,
    double? plusX,
    double? plusY,
  }) => ThemeCustomization(
    pageColors: pageColors ?? this.pageColors,
    artwork: artwork ?? this.artwork,
    footerArtwork: footerArtwork ?? this.footerArtwork,
    icons: icons ?? this.icons,
    plusX: plusX ?? this.plusX,
    plusY: plusY ?? this.plusY,
  );

  Map<String, Object> toMap() => {
    'pageColors': pageColors.map((key, value) => MapEntry('$key', value)),
    'artwork': artwork.map((key, value) => MapEntry('$key', value)),
    'footerArtwork': footerArtwork.map((key, value) => MapEntry('$key', value)),
    'icons': icons,
    'plusX': plusX,
    'plusY': plusY,
  };

  factory ThemeCustomization.fromMap(Map<String, Object?> map) {
    Map<int, T> numbered<T>(Object? value) {
      if (value is! Map) return {};
      return {
        for (final entry in value.entries)
          if (int.tryParse('${entry.key}') case final key?)
            if (entry.value is T) key: entry.value as T,
      };
    }

    return ThemeCustomization(
      pageColors: numbered<int>(map['pageColors']),
      artwork: numbered<String>(map['artwork']),
      footerArtwork: numbered<String>(map['footerArtwork']),
      icons: map['icons'] is Map
          ? Map<String, String>.from(map['icons'] as Map)
          : const {},
      plusX: ((map['plusX'] as num?)?.toDouble() ?? 0).clamp(-18, 18),
      plusY: ((map['plusY'] as num?)?.toDouble() ?? 0).clamp(-18, 18),
    );
  }
}
