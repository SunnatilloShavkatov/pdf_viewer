import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_viewer/pdf_viewer.dart';
import 'package:pdf_viewer/src/native/pdf_native.dart';

import 'support/fake_pdf_native.dart';

/// A cache whose every call fails, to check that failures never reach the viewer.
class _BrokenCache implements PdfCache {
  @override
  Future<String?> readTextLayer(String documentKey, int page) => Future<String?>.error(StateError('read'));

  @override
  Future<void> writeTextLayer(String documentKey, int page, String json) => Future<void>.error(StateError('write'));

  @override
  Future<List<PdfHighlight>> readHighlights(String documentKey) => Future<List<PdfHighlight>>.error(StateError('read'));

  @override
  Future<void> writeHighlights(String documentKey, List<PdfHighlight> highlights) =>
      Future<void>.error(StateError('write'));
}

PdfHighlight _highlight(String id) =>
    PdfHighlight(id: id, page: 0, rects: const <Rect>[Rect.fromLTRB(0, 0, 1, 1)], text: 'x');

void main() {
  late List<FlutterErrorDetails> reported;
  final FlutterExceptionHandler? previous = FlutterError.onError;

  setUp(() {
    PdfNative.instance = const FakePdfNative();
    reported = <FlutterErrorDetails>[];
    FlutterError.onError = reported.add;
  });

  tearDown(() => FlutterError.onError = previous);

  test('a failing cache write does not stop a highlight from being added', () async {
    final PdfDocument document = await PdfDocument.openBytes(Uint8List.fromList(<int>[1]), cache: _BrokenCache());

    await document.addHighlight(_highlight('a'));

    expect(document.highlights.map((PdfHighlight h) => h.id), <String>['a']);
    expect(reported, isNotEmpty, reason: 'the failure is reported, not swallowed');
  });

  test('a failing cache read is treated as a miss and the layer comes from the native side', () async {
    final PdfDocument document = await PdfDocument.openBytes(Uint8List.fromList(<int>[1]), cache: _BrokenCache());

    final PdfTextLayer layer = await document.textLayer(0);

    expect(layer.isEmpty, isTrue);
    expect(reported, isNotEmpty);
  });
}
