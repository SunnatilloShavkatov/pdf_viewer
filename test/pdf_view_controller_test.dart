import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_viewer/pdf_viewer.dart';

void main() {
  const String json = '[["a",0.1,0.1,0.2,0.2],["b",0.2,0.1,0.3,0.2],["c",0.3,0.1,0.4,0.2]]';

  test('selection covers anchor and focus in order', () {
    final PdfViewController controller = PdfViewController()
      ..startSelection(0, PdfTextLayer.fromJson(json), 2)
      ..extendSelection(0);
    expect(controller.selection!.start, 0);
    expect(controller.selection!.end, 2);
    expect(controller.selectedText, 'abc');
  });

  test('clearSelection removes the selection and its text', () {
    final PdfViewController controller = PdfViewController()
      ..startSelection(0, PdfTextLayer.fromJson(json), 1)
      ..clearSelection();
    expect(controller.selection, isNull);
    expect(controller.selectedText, isNull);
  });

  test('extending without a selection is a no-op', () {
    final PdfViewController controller = PdfViewController()..extendSelection(3);
    expect(controller.selection, isNull);
  });
}
