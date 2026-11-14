import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_viewer/pdf_viewer.dart';
import 'package:pdf_viewer/src/native/pdf_native.dart';

class _FakeNative implements PdfNative {
  @override
  Future<int> openFile(String path) async => 1;
  @override
  Future<int> openBytes(Uint8List bytes) async => 1;
  @override
  int pageCount(int docId) => 1;
  @override
  double pageWidth(int docId, int page) => 612;
  @override
  double pageHeight(int docId, int page) => 792;
  @override
  Future<Uint8List> renderPage(int docId, int page, int width) async => Uint8List(0);
  @override
  Future<String> textLayer(int docId, int page) async => '[]';
  @override
  void close(int docId) {}
}

void main() {
  const String json = '[["a",0.1,0.1,0.2,0.2],["b",0.2,0.1,0.3,0.2],["c",0.3,0.1,0.4,0.2]]';

  setUp(() => PdfNative.instance = _FakeNative());

  Future<(PdfDocument, PdfViewController)> openWithController() async {
    final PdfDocument doc = await PdfDocument.openBytes(Uint8List(4));
    final PdfViewController controller = PdfViewController()..attach(doc);
    return (doc, controller);
  }

  test('highlightSelection adds one highlight', () async {
    final (PdfDocument doc, PdfViewController controller) = await openWithController();
    controller
      ..startSelection(0, PdfTextLayer.fromJson(json), 0)
      ..extendSelection(2);
    await controller.highlightSelection();
    expect(doc.highlights, hasLength(1));
    expect(doc.highlights.single.text, 'abc');
  });

  test('highlighting the same text again replaces instead of stacking', () async {
    final (PdfDocument doc, PdfViewController controller) = await openWithController();
    final PdfTextLayer layer = PdfTextLayer.fromJson(json);
    controller
      ..startSelection(0, layer, 0)
      ..extendSelection(2);
    await controller.highlightSelection();
    controller
      ..startSelection(0, layer, 1)
      ..extendSelection(2);
    await controller.highlightSelection();
    expect(doc.highlights, hasLength(1));
    expect(doc.highlights.single.text, 'bc');
  });

  test('a picked highlight can be deleted', () async {
    final (PdfDocument doc, PdfViewController controller) = await openWithController();
    controller
      ..startSelection(0, PdfTextLayer.fromJson(json), 0)
      ..extendSelection(2);
    await controller.highlightSelection();
    controller.selectHighlight(doc.highlights.single.id);
    expect(controller.activeHighlightId, isNotNull);
    expect(await controller.deleteActiveHighlight(), isTrue);
    expect(doc.highlights, isEmpty);
    expect(controller.activeHighlightId, isNull);
  });
}
