import 'dart:convert';
import 'dart:ui';

/// One glyph and its box, normalized to the page (0..1, top-left origin).
class PdfChar {
  const new(this.char, this.box);

  final String char;
  final Rect box;
}

/// Glyph boxes for one page, in reading order as produced by the native text extractor.
class PdfTextLayer {
  new(this.chars);

  factory fromJson(String json) {
    final List<dynamic> items = jsonDecode(json) as List<dynamic>;
    return PdfTextLayer(<PdfChar>[for (final dynamic item in items) _parse(item as List<dynamic>)]);
  }

  static final PdfTextLayer empty = PdfTextLayer(const <PdfChar>[]);

  final List<PdfChar> chars;

  bool get isEmpty => chars.isEmpty;

  /// Index of the glyph under [point] (normalized). When none contains it, the nearest glyph within [tolerance].
  int? indexAt(Offset point, {double tolerance = 0.012}) {
    int? nearest;
    double nearestDistance = double.infinity;
    for (int i = 0; i < chars.length; i++) {
      final Rect box = chars[i].box;
      if (box.isEmpty) {
        continue;
      }
      if (box.contains(point)) {
        return i;
      }
      final double distance = (box.center - point).distance;
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearest = i;
      }
    }
    return nearestDistance <= tolerance ? nearest : null;
  }

  /// Text between [start] and [end], both inclusive, in either order. Word and line breaks that the
  /// extractor left out (Android PDFBox emits no space glyphs) are restored from the glyph gaps.
  String textBetween(int start, int end) {
    final (int from, int to) = _ordered(start, end);
    final StringBuffer buffer = StringBuffer();
    for (int i = from; i <= to; i++) {
      if (i > from && _breaksBefore(i)) {
        buffer.write(_sameLine(chars[i - 1].box, chars[i].box) ? ' ' : '\n');
      }
      buffer.write(chars[i].char);
    }
    return buffer.toString().trim();
  }

  /// Inclusive glyph range of the word containing [index]. Whitespace glyphs select only themselves.
  (int, int) wordBounds(int index) {
    bool isWordChar(int i) => chars[i].char.trim().isNotEmpty;
    if (!isWordChar(index)) {
      return (index, index);
    }
    int start = index;
    int end = index;
    while (start > 0 && isWordChar(start - 1) && !_breaksBefore(start)) {
      start--;
    }
    while (end < chars.length - 1 && isWordChar(end + 1) && !_breaksBefore(end + 1)) {
      end++;
    }
    return (start, end);
  }

  /// Relative gap, as a fraction of glyph height, that counts as a word break.
  static const double _gapRatio = 0.25;

  /// True when glyph [i] starts a new word or line after glyph `i - 1`, judged by the gap between their boxes.
  /// Blank glyphs already carry the break, so they never add another one.
  bool _breaksBefore(int i) {
    if (i <= 0) {
      return false;
    }
    final PdfChar previous = chars[i - 1];
    final PdfChar current = chars[i];
    if (previous.box.isEmpty || current.box.isEmpty) {
      return false;
    }
    if (previous.char.trim().isEmpty || current.char.trim().isEmpty) {
      return false;
    }
    if (!_sameLine(previous.box, current.box)) {
      return true;
    }
    return current.box.left - previous.box.right > current.box.height * _gapRatio;
  }

  /// Boxes covering [start] to [end], one rect per text line.
  List<Rect> rectsBetween(int start, int end) {
    final (int from, int to) = _ordered(start, end);
    final List<Rect> lines = <Rect>[];
    Rect? current;
    for (int i = from; i <= to; i++) {
      final Rect box = chars[i].box;
      if (box.isEmpty) {
        continue;
      }
      if (current == null || !_sameLine(current, box)) {
        if (current != null) {
          lines.add(current);
        }
        current = box;
      } else {
        current = current.expandToInclude(box);
      }
    }
    if (current != null) {
      lines.add(current);
    }
    return lines;
  }

  (int, int) _ordered(int start, int end) {
    final int from = start.clamp(0, chars.length - 1);
    final int to = end.clamp(0, chars.length - 1);
    return from <= to ? (from, to) : (to, from);
  }

  static bool _sameLine(Rect line, Rect box) {
    final double tolerance = box.height * 0.5;
    return (line.center.dy - box.center.dy).abs() <= tolerance;
  }

  static PdfChar _parse(List<dynamic> item) {
    final double x0 = (item[1] as num).toDouble();
    final double y0 = (item[2] as num).toDouble();
    final double x1 = (item[3] as num).toDouble();
    final double y1 = (item[4] as num).toDouble();
    return PdfChar(item[0] as String, Rect.fromLTRB(x0, y0, x1, y1));
  }
}
