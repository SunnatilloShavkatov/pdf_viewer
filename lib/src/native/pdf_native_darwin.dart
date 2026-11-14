import 'dart:async';
import 'dart:typed_data';

import 'package:objective_c/objective_c.dart';
import 'package:pdf_viewer/src/bindings/pdf_viewer_darwin.g.dart';
import 'package:pdf_viewer/src/native/pdf_native.dart';
import 'package:pdf_viewer/src/pdf_exception.dart';

/// [PdfNative] over FFI: Dart calls the Swift `PdfViewerApi` through the Objective-C runtime.
class DarwinPdfNative implements PdfNative {
  @override
  Future<int> openFile(String path) async {
    final int id = PdfViewerApi.openFile(path.toNSString());
    return checkOpened(id, path);
  }

  @override
  Future<int> openBytes(Uint8List bytes) async {
    final int id = PdfViewerApi.openBytes(bytes.toNSData());
    return checkOpened(id, 'bytes');
  }

  @override
  int pageCount(int docId) => PdfViewerApi.pageCount(docId);

  @override
  double pageWidth(int docId, int page) => PdfViewerApi.pageWidth(docId, page: page);

  @override
  double pageHeight(int docId, int page) => PdfViewerApi.pageHeight(docId, page: page);

  @override
  Future<Uint8List> renderPage(int docId, int page, int width) {
    final Completer<Uint8List> completer = Completer<Uint8List>();
    PdfViewerApi.renderPage(
      docId,
      page: page,
      width: width,
      completion: ObjCBlock_ffiVoid_NSData_NSString.listener((NSData? data, NSString? error) {
        if (data != null) {
          completer.complete(data.toList());
        } else {
          completer.completeError(PdfException(error?.toDartString() ?? 'Render failed'));
        }
      }),
    );
    return completer.future;
  }

  @override
  Future<String> textLayer(int docId, int page) {
    final Completer<String> completer = Completer<String>();
    PdfViewerApi.textLayer(
      docId,
      page: page,
      completion: ObjCBlock_ffiVoid_NSString_NSString.listener((NSString? json, NSString? error) {
        if (json != null) {
          completer.complete(json.toDartString());
        } else {
          completer.completeError(PdfException(error?.toDartString() ?? 'Text extraction failed'));
        }
      }),
    );
    return completer.future;
  }

  @override
  void close(int docId) => PdfViewerApi.close(docId);
}
