import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_viewer/pdf_viewer.dart';

PdfTextLayer _layer(String text) => PdfTextLayer(<PdfChar>[
  for (int i = 0; i < text.length; i++) PdfChar(text[i], Rect.fromLTWH(i * 0.02, 0.1, 0.02, 0.02)),
]);

void main() {
  test('wordBounds selects the whole word around the index', () {
    final PdfTextLayer layer = _layer('hello big world');
    expect(layer.wordBounds(1), (0, 4));
    expect(layer.wordBounds(7), (6, 8));
    expect(layer.wordBounds(12), (10, 14));
  });

  test('wordBounds on whitespace selects only that glyph', () {
    expect(_layer('a b').wordBounds(1), (1, 1));
  });

  test('selectWord selects the word under the index', () {
    final PdfViewController controller = PdfViewController()..selectWord(0, _layer('hello big world'), 7);
    expect(controller.selectedText, 'big');
  });

  test('dragSelectionEdge keeps the fixed end and moves the other', () {
    final PdfViewController controller = PdfViewController()
      ..startSelection(0, _layer('hello big world'), 1)
      ..dragSelectionEdge(4, 10);
    expect(controller.selection!.start, 4);
    expect(controller.selection!.end, 10);
    // Dragging past the fixed end flips the order without losing the fixed point.
    controller.dragSelectionEdge(10, 2);
    expect(controller.selection!.start, 2);
    expect(controller.selection!.end, 10);
  });

  test('selectAll covers the whole page layer', () {
    final PdfViewController controller = PdfViewController()
      ..startSelection(0, _layer('hello big world'), 1)
      ..selectAll();
    expect(controller.selectedText, 'hello big world');
  });

  test('selectHighlight clears the text selection and clearSelection clears both', () {
    final PdfViewController controller = PdfViewController()
      ..startSelection(0, _layer('hello'), 1)
      ..selectHighlight('h1');
    expect(controller.selection, isNull);
    expect(controller.activeHighlightId, 'h1');
    controller.clearSelection();
    expect(controller.activeHighlightId, isNull);
  });
}
