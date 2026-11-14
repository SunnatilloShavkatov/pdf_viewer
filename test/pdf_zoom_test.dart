import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_viewer/src/widgets/pdf_zoom.dart';

void main() {
  group('zoomForPinch', () {
    test('doubling the finger distance doubles the zoom', () {
      expect(zoomForPinch(startZoom: 1, startDistance: 100, distance: 200), 2);
    });

    test('zoom moves in quarter steps so pages are not re-rendered on every pixel', () {
      expect(zoomForPinch(startZoom: 1, startDistance: 100, distance: 130), 1.25);
      expect(zoomForPinch(startZoom: 1, startDistance: 100, distance: 112), 1.0);
    });

    test('zoom never goes below 1 or above the maximum', () {
      expect(zoomForPinch(startZoom: 1, startDistance: 100, distance: 10), 1);
      expect(zoomForPinch(startZoom: 1, startDistance: 10, distance: 1000), pdfMaxZoom);
    });

    test('a zero start distance keeps the current zoom', () {
      expect(zoomForPinch(startZoom: 2, startDistance: 0, distance: 50), 2);
    });
  });
}
