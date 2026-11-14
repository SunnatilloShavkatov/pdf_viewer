import 'dart:io';
import 'dart:typed_data';

import 'package:pdf_viewer/src/native/pdf_native_android.dart';
import 'package:pdf_viewer/src/native/pdf_native_darwin.dart';
import 'package:pdf_viewer/src/pdf_exception.dart';

/// Open result the native side returns for a password-protected file (any negative id is a failure).
const int pdfPasswordRequired = -2;

/// Turns a native open result into a document id, or throws [PdfException] naming [source].
int checkOpened(int id, String source) {
  if (id >= 0) {
    return id;
  }
  if (id == pdfPasswordRequired) {
    throw PdfException('PDF is password protected: $source');
  }
  throw PdfException('Cannot open PDF: $source');
}

/// Native PDF operations. Android goes through JNI, iOS through FFI. Tests replace [instance].
abstract interface class PdfNative {
  static PdfNative? _instance;

  /// The platform implementation, created on first use so tests can replace it before it is touched.
  static PdfNative get instance => _instance ??= _platformNative();

  static set instance(PdfNative value) => _instance = value;

  static PdfNative _platformNative() {
    if (Platform.isAndroid) {
      return AndroidPdfNative();
    }
    if (Platform.isIOS) {
      return DarwinPdfNative();
    }
    throw UnsupportedError('pdf_viewer supports Android and iOS only.');
  }

  /// Returns a document id. Throws `PdfException` when the file cannot be opened.
  Future<int> openFile(String path);

  /// Returns a document id. Throws `PdfException` when the bytes are not a readable PDF.
  Future<int> openBytes(Uint8List bytes);

  int pageCount(int docId);

  /// Page width in PDF points.
  double pageWidth(int docId, int page);

  /// Page height in PDF points.
  double pageHeight(int docId, int page);

  /// JPEG bytes of [page] rendered [width] pixels wide.
  Future<Uint8List> renderPage(int docId, int page, int width);

  /// JSON `[[char, x0, y0, x1, y1], ...]`, normalized 0..1 with a top-left origin.
  Future<String> textLayer(int docId, int page);

  void close(int docId);
}
