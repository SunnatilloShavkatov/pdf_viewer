import 'dart:async';
import 'dart:typed_data';

import 'package:jni/jni.dart';
import 'package:pdf_viewer/src/bindings/pdf_viewer_api.g.dart';
import 'package:pdf_viewer/src/native/pdf_native.dart';
import 'package:pdf_viewer/src/pdf_exception.dart';

/// [PdfNative] over JNI: Dart calls `PdfViewerApi` directly, with no method channel.
class AndroidPdfNative implements PdfNative {
  @override
  Future<int> openFile(String path) async {
    final int id = using((Arena arena) => PdfViewerApi.openFile(path.toJString()..releasedBy(arena)));
    return checkOpened(id, path);
  }

  @override
  Future<int> openBytes(Uint8List bytes) async {
    final int id = using((Arena arena) {
      final JByteArray array = JByteArray(bytes.length)
        ..releasedBy(arena)
        ..setRange(0, bytes.length, bytes.buffer.asInt8List(bytes.offsetInBytes, bytes.length));
      return PdfViewerApi.openBytes(array);
    });
    return checkOpened(id, 'bytes');
  }

  @override
  int pageCount(int docId) => PdfViewerApi.pageCount(docId);

  @override
  double pageWidth(int docId, int page) => PdfViewerApi.pageWidth(docId, page);

  @override
  double pageHeight(int docId, int page) => PdfViewerApi.pageHeight(docId, page);

  @override
  Future<Uint8List> renderPage(int docId, int page, int width) {
    final Completer<Uint8List> completer = Completer<Uint8List>();
    final PdfRenderCallback callback = PdfRenderCallback.implement(
      $PdfRenderCallback(
        onResult: (JByteArray? jpeg, JString? error) {
          try {
            if (jpeg != null) {
              completer.complete(Uint8List.fromList(jpeg.asDart()));
            } else {
              completer.completeError(PdfException(error?.toDartString() ?? 'Render failed'));
            }
          } finally {
            jpeg?.release();
            error?.release();
          }
        },
      ),
    );
    _handOver(callback, (PdfRenderCallback proxy) => PdfViewerApi.renderPage(docId, page, width, proxy));
    return completer.future;
  }

  @override
  Future<String> textLayer(int docId, int page) {
    final Completer<String> completer = Completer<String>();
    final PdfTextCallback callback = PdfTextCallback.implement(
      $PdfTextCallback(
        onResult: (JString? json, JString? error) {
          try {
            if (json != null) {
              completer.complete(json.toDartString());
            } else {
              completer.completeError(PdfException(error?.toDartString() ?? 'Text extraction failed'));
            }
          } finally {
            json?.release();
            error?.release();
          }
        },
      ),
    );
    _handOver(callback, (PdfTextCallback proxy) => PdfViewerApi.textLayer(docId, page, proxy));
    return completer.future;
  }

  @override
  void close(int docId) => PdfViewerApi.close(docId);
}

/// Passes a Dart-implemented [proxy] to native code and drops Dart's own reference. Kotlin keeps the proxy alive
/// for as long as it needs it; without the release every call would pin a JNI global reference.
void _handOver<T extends JObject>(T proxy, void Function(T proxy) pass) {
  try {
    pass(proxy);
  } finally {
    proxy.release();
  }
}
