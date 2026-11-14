import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf_viewer/pdf_viewer.dart';

void main() => runApp(const PdfViewerExampleApp());

class PdfViewerExampleApp extends StatelessWidget {
  const PdfViewerExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pdf Viewer',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const PdfDemoPage(),
    );
  }
}

class PdfDemoPage extends StatefulWidget {
  const PdfDemoPage({super.key});

  @override
  State<PdfDemoPage> createState() => _PdfDemoPageState();
}

class _PdfDemoPageState extends State<PdfDemoPage> {
  PdfDocument? _document;
  final PdfViewController _controller = PdfViewController();
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_open());
  }

  Future<void> _open() async {
    try {
      final Directory dir = await getApplicationDocumentsDirectory();
      final HivePdfCache cache = await HivePdfCache.open(path: dir.path);
      final PdfDocument document = await PdfDocument.openAsset('assets/sample.pdf', cache: cache);
      if (!mounted) {
        document.dispose();
        return;
      }
      setState(() => _document = document);
    } on Object catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  void dispose() {
    _document?.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final PdfDocument? document = _document;
    return Scaffold(
      appBar: AppBar(title: const Text('Pdf Viewer')),
      body: switch ((document, _error)) {
        (_, final String error) => Center(child: Text(error)),
        (final PdfDocument doc, _) => PdfView(document: doc, controller: _controller),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}
