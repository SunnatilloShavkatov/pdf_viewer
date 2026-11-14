import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_viewer/pdf_viewer.dart';

const String _json = '''
[["H",0.10,0.10,0.15,0.14],["i",0.15,0.10,0.18,0.14],[" ",0.18,0.10,0.19,0.14],["P",0.10,0.20,0.15,0.24],["D",0.15,0.20,0.20,0.24],["F",0.20,0.20,0.25,0.24]]
''';

void main() {
  group('PdfTextLayer', () {
    late PdfTextLayer layer;

    setUp(() => layer = PdfTextLayer.fromJson(_json));

    test('parses glyphs from JSON', () {
      expect(layer.chars, hasLength(6));
      expect(layer.chars.first.char, 'H');
      expect(layer.chars.first.box, const Rect.fromLTRB(0.10, 0.10, 0.15, 0.14));
    });

    test('indexAt finds the glyph under a point and ignores far points', () {
      expect(layer.indexAt(const Offset(0.12, 0.12)), 0);
      expect(layer.indexAt(const Offset(0.22, 0.22)), 5);
      expect(layer.indexAt(const Offset(0.9, 0.9)), isNull);
    });

    test('textBetween returns inclusive text in either order', () {
      expect(layer.textBetween(0, 1), 'Hi');
      expect(layer.textBetween(3, 5), 'PDF');
      expect(layer.textBetween(5, 3), 'PDF');
    });

    test('rectsBetween merges glyphs into one rect per line', () {
      final List<Rect> rects = layer.rectsBetween(0, 5);
      expect(rects, hasLength(2));
      expect(rects.first, const Rect.fromLTRB(0.10, 0.10, 0.19, 0.14));
      expect(rects.last, const Rect.fromLTRB(0.10, 0.20, 0.25, 0.24));
    });

    test('empty layer yields nothing', () {
      expect(PdfTextLayer.empty.isEmpty, isTrue);
      expect(PdfTextLayer.empty.indexAt(Offset.zero), isNull);
    });
  });

  group('PdfTextLayer without space glyphs (Android PDFBox output)', () {
    // "Hey" then a gap, then "World" on the same line. No glyph for the space between them.
    const String spaced = '''
[["H",0.10,0.10,0.15,0.14],["e",0.15,0.10,0.18,0.14],["y",0.18,0.10,0.21,0.14],
 ["W",0.25,0.10,0.30,0.14],["o",0.30,0.10,0.33,0.14]]
''';

    // "Hi" on the first line, "P" on the next line, with no newline glyph.
    const String multiline = '''
[["H",0.10,0.10,0.15,0.14],["i",0.15,0.10,0.18,0.14],["P",0.10,0.20,0.15,0.24]]
''';

    test('textBetween inserts a space where glyphs have a horizontal gap', () {
      final PdfTextLayer layer = PdfTextLayer.fromJson(spaced);
      expect(layer.textBetween(0, 4), 'Hey Wo');
    });

    test('textBetween inserts a newline where the next glyph starts a new line', () {
      final PdfTextLayer layer = PdfTextLayer.fromJson(multiline);
      expect(layer.textBetween(0, 2), 'Hi\nP');
    });

    test('wordBounds stops at an inferred word gap', () {
      final PdfTextLayer layer = PdfTextLayer.fromJson(spaced);
      expect(layer.wordBounds(1), (0, 2));
      expect(layer.wordBounds(3), (3, 4));
    });

    test('glyphs that touch with no gap stay one word', () {
      const String touching = '[["H",0.10,0.10,0.15,0.14],["i",0.15,0.10,0.18,0.14],["P",0.18,0.10,0.23,0.14]]';
      final PdfTextLayer layer = PdfTextLayer.fromJson(touching);
      expect(layer.textBetween(0, 2), 'HiP');
      expect(layer.wordBounds(0), (0, 2));
    });

    test('existing whitespace glyphs are not doubled', () {
      final PdfTextLayer layer = PdfTextLayer.fromJson(_json);
      expect(layer.textBetween(0, 5), 'Hi PDF');
    });
  });

  group('PdfHighlight', () {
    test('round-trips through JSON', () {
      const PdfHighlight highlight = PdfHighlight(
        id: '1',
        page: 2,
        rects: <Rect>[Rect.fromLTRB(0.1, 0.2, 0.3, 0.4)],
        text: 'hello',
      );
      final PdfHighlight decoded = PdfHighlight.fromJson(highlight.toJson());
      expect(decoded.id, '1');
      expect(decoded.page, 2);
      expect(decoded.text, 'hello');
      expect(decoded.color, highlight.color);
      expect(decoded.rects, highlight.rects);
    });
  });
}
