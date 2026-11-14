import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_viewer/pdf_viewer.dart';
import 'package:pdf_viewer/src/native/pdf_native.dart';

void main() {
  group('checkOpened', () {
    test('returns a usable document id unchanged', () {
      expect(checkOpened(7, 'sample.pdf'), 7);
    });

    test('reports a password-protected file as such', () {
      expect(
        () => checkOpened(pdfPasswordRequired, 'secret.pdf'),
        throwsA(isA<PdfException>().having((PdfException e) => e.message, 'message', contains('password protected'))),
      );
    });

    test('reports any other failure as a generic open error', () {
      expect(
        () => checkOpened(-1, 'broken.pdf'),
        throwsA(isA<PdfException>().having((PdfException e) => e.message, 'message', contains('Cannot open'))),
      );
    });
  });
}
