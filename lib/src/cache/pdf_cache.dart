import 'package:pdf_viewer/src/highlight/pdf_highlight.dart';

/// Persistent cache for text layers and highlights, keyed by a document key.
/// Rendered page images are never stored here; they are cheap to render and large to keep.
abstract interface class PdfCache {
  Future<String?> readTextLayer(String documentKey, int page);

  Future<void> writeTextLayer(String documentKey, int page, String json);

  Future<List<PdfHighlight>> readHighlights(String documentKey);

  Future<void> writeHighlights(String documentKey, List<PdfHighlight> highlights);
}

/// Cache that stores nothing. The default when the app does not configure one.
class NoPdfCache implements PdfCache {
  const new();

  @override
  Future<String?> readTextLayer(String documentKey, int page) async => null;

  @override
  Future<void> writeTextLayer(String documentKey, int page, String json) async {}

  @override
  Future<List<PdfHighlight>> readHighlights(String documentKey) async => const <PdfHighlight>[];

  @override
  Future<void> writeHighlights(String documentKey, List<PdfHighlight> highlights) async {}
}
