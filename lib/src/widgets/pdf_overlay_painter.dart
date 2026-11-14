import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pdf_viewer/src/highlight/pdf_highlight.dart';

/// Paints saved highlights and the live selection over a page. Rects are normalized (0..1).
class PdfOverlayPainter extends CustomPainter {
  const new({required this.highlights, required this.selection, required this.selectionColor});

  final List<PdfHighlight> highlights;
  final List<Rect> selection;
  final Color selectionColor;

  @override
  void paint(Canvas canvas, Size size) {
    for (final PdfHighlight highlight in highlights) {
      final Paint paint = Paint()..color = Color(highlight.color).withValues(alpha: 0.4);
      for (final Rect rect in highlight.rects) {
        canvas.drawRect(_scale(rect, size), paint);
      }
    }
    final Paint selectionPaint = Paint()..color = selectionColor.withValues(alpha: 0.35);
    for (final Rect rect in selection) {
      canvas.drawRect(_scale(rect, size), selectionPaint);
    }
  }

  static Rect _scale(Rect rect, Size size) =>
      Rect.fromLTRB(rect.left * size.width, rect.top * size.height, rect.right * size.width, rect.bottom * size.height);

  /// Compares contents: the page rebuilds these lists on every frame, so identity would repaint needlessly.
  @override
  bool shouldRepaint(PdfOverlayPainter oldDelegate) =>
      !listEquals(oldDelegate.highlights, highlights) ||
      !listEquals(oldDelegate.selection, selection) ||
      oldDelegate.selectionColor != selectionColor;
}
