import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_viewer/src/widgets/pdf_overlay_painter.dart';

PdfOverlayPainter _painter(Rect selected) =>
    PdfOverlayPainter(highlights: const [], selection: <Rect>[selected], selectionColor: const Color(0xFF2196F3));

void main() {
  test('does not repaint when the same selection is rebuilt as a new list', () {
    const Rect selected = Rect.fromLTRB(0, 0, 0.5, 0.5);
    expect(_painter(selected).shouldRepaint(_painter(selected)), isFalse);
  });

  test('repaints when the selection changes', () {
    expect(
      _painter(const Rect.fromLTRB(0, 0, 0.9, 0.5)).shouldRepaint(_painter(const Rect.fromLTRB(0, 0, 0.5, 0.5))),
      isTrue,
    );
  });
}
