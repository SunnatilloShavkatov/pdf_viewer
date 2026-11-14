// Regenerates lib/src/bindings/pdf_viewer_darwin.g.dart and the Objective-C block wrapper
// ios/pdf_viewer/Sources/pdf_viewer_c/pdf_viewer_darwin.m from pdf_viewer_api.h.
// Run from the package root: `dart run tool/ffigen.dart`.
import 'dart:io';

import 'package:ffigen/ffigen.dart';

Future<void> main() async {
  final Uri packageRoot = Platform.script.resolve('../');
  final Uri cSources = packageRoot.resolve('ios/pdf_viewer/Sources/pdf_viewer_c/');
  await FfiGenerator(
    output: Output(
      dart: DartOutput(path: packageRoot.resolve('lib/src/bindings/pdf_viewer_darwin.g.dart')),
      objectiveCFile: cSources.resolve('pdf_viewer_darwin.m'),
    ),
    objectiveC: const ObjectiveC(),
    input: Input(entryPoints: <Uri>[cSources.resolve('pdf_viewer_api.h')]),
    visitors: <Visitor>[
      Visitor(
        objCInterface: (node) {
          if (node.originalName == 'PdfViewerApi') {
            node.isIncluded = true;
          }
        },
      ),
    ],
  ).generate();
}
