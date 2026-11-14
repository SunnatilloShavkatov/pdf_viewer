import 'dart:ui';

/// A user highlight on one page. [rects] are normalized to the page (0..1, top-left origin).
class PdfHighlight {
  const new({required this.id, required this.page, required this.rects, required this.text, this.color = 0xFFFFEB3B});

  factory fromJson(Map<String, Object?> json) {
    final List<dynamic> rects = json['rects']! as List<dynamic>;
    return PdfHighlight(
      id: json['id']! as String,
      page: json['page']! as int,
      text: json['text']! as String,
      color: json['color']! as int,
      rects: <Rect>[
        for (final dynamic r in rects)
          Rect.fromLTRB(
            ((r as List<dynamic>)[0] as num).toDouble(),
            (r[1] as num).toDouble(),
            (r[2] as num).toDouble(),
            (r[3] as num).toDouble(),
          ),
      ],
    );
  }

  final String id;
  final int page;
  final List<Rect> rects;
  final String text;

  /// ARGB color, e.g. `0xFFFFEB3B`.
  final int color;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'page': page,
    'text': text,
    'color': color,
    'rects': <List<double>>[
      for (final Rect r in rects) <double>[r.left, r.top, r.right, r.bottom],
    ],
  };
}
