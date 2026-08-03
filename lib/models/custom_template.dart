enum CustomTemplateKind { card, background }

enum CustomTemplateMedia { image, video }

class CustomTemplate {
  const CustomTemplate({
    required this.id,
    required this.name,
    required this.kind,
    required this.media,
    required this.path,
    this.zoom = 1,
    this.alignX = 0,
    this.alignY = 0,
    this.opacity = 1,
  });

  final String id;
  final String name;
  final CustomTemplateKind kind;
  final CustomTemplateMedia media;
  final String path;
  final double zoom;
  final double alignX;
  final double alignY;
  final double opacity;

  CustomTemplate copyWith({
    double? zoom,
    double? alignX,
    double? alignY,
    double? opacity,
  }) => CustomTemplate(
    id: id,
    name: name,
    kind: kind,
    media: media,
    path: path,
    zoom: zoom ?? this.zoom,
    alignX: alignX ?? this.alignX,
    alignY: alignY ?? this.alignY,
    opacity: opacity ?? this.opacity,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'kind': kind.name,
    'media': media.name,
    'path': path,
    'zoom': zoom,
    'alignX': alignX,
    'alignY': alignY,
    'opacity': opacity,
  };

  factory CustomTemplate.fromMap(Map<String, Object?> map) => CustomTemplate(
    id: map['id'] as String,
    name: map['name'] as String,
    kind: CustomTemplateKind.values.byName(map['kind'] as String),
    media: CustomTemplateMedia.values.byName(map['media'] as String),
    path: map['path'] as String,
    zoom: (map['zoom'] as num?)?.toDouble() ?? 1,
    alignX: (map['alignX'] as num?)?.toDouble() ?? 0,
    alignY: (map['alignY'] as num?)?.toDouble() ?? 0,
    opacity: (map['opacity'] as num?)?.toDouble() ?? 1,
  );
}
