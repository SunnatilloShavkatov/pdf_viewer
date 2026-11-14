import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_viewer/pdf_viewer.dart';
import 'package:pdf_viewer/src/native/pdf_native.dart';
import 'package:pdf_viewer/src/widgets/pdf_page_view.dart';

import 'support/fake_pdf_native.dart';

/// Two fingers that start [from] pixels apart and end [to] pixels apart, centred on the page.
Future<void> _pinch(WidgetTester tester, {required double from, required double to}) async {
  const Offset centre = Offset(200, 400);
  final TestGesture a = await tester.startGesture(centre + Offset(-from / 2, 0), pointer: 1);
  final TestGesture b = await tester.startGesture(centre + Offset(from / 2, 0), pointer: 2);
  await a.moveTo(centre + Offset(-to / 2, 0));
  await b.moveTo(centre + Offset(to / 2, 0));
  await a.up();
  await b.up();
  await tester.pump();
}

double _pageWidth(WidgetTester tester) => tester.getSize(find.byType(PdfPageView).first).width;

void main() {
  setUp(() => PdfNative.instance = const FakePdfNative());

  testWidgets('pinch out enlarges the pages and pinch in returns to fit width', (WidgetTester tester) async {
    final PdfDocument document = await PdfDocument.openBytes(Uint8List(1));
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(400, 800)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: 400, height: 800, child: PdfView(document: document)),
          ),
        ),
      ),
    );
    expect(_pageWidth(tester), 400);

    await _pinch(tester, from: 100, to: 200);
    expect(_pageWidth(tester), 800);

    await _pinch(tester, from: 200, to: 50);
    expect(_pageWidth(tester), 400, reason: 'zoom never drops below fit width');
  });
}
