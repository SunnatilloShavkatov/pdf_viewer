import 'dart:async';
import 'dart:typed_data';

import 'package:pdf_viewer/src/native/pdf_native.dart';

/// In-memory [PdfNative] for widget tests. Pages are letter size. Rendering never completes, so widgets
/// stay in their loading state and tests can check layout without decoding images.
class FakePdfNative implements PdfNative {
  const new({this.pages = 2});

  final int pages;

  @override
  Future<int> openFile(String path) async => 1;

  @override
  Future<int> openBytes(Uint8List bytes) async => 1;

  @override
  int pageCount(int docId) => pages;

  @override
  double pageWidth(int docId, int page) => 612;

  @override
  double pageHeight(int docId, int page) => 792;

  @override
  Future<Uint8List> renderPage(int docId, int page, int width) => Completer<Uint8List>().future;

  @override
  Future<String> textLayer(int docId, int page) async => '[]';

  @override
  void close(int docId) {}
}
