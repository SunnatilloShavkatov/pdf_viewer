# pdf_viewer

A Flutter PDF viewer with native rendering, page text selection, copy, and highlights.

- **Android:** pages rendered with `PdfRenderer`, text extracted with PDFBox (`com.tom-roush:pdfbox-android`), bridged via JNI (`jni`).
- **iOS:** pages rendered and text extracted with PDFKit, bridged via FFI (`objective_c`).
- **Caching:** optional text layer and highlight persistence with `hive_ce`.

## Features

- Open PDFs from a file path, bytes, a Flutter asset, or a URL.
- Long-press text selection with page-level text layers.
- Copy the selected text.
- Create highlights, select them, and delete them.
- Cache extracted text and highlights between app launches (optional).

## Requirements

| Platform | Minimum              |
|----------|----------------------|
| Flutter  | 3.50.0               |
| Dart     | 3.14.0               |
| Android  | API 24 (Android 7.0) |
| iOS      | 15.0                 |

## Installation

```bash
flutter pub add pdf_viewer
```

## Usage

### Show a PDF

```dart
import 'package:flutter/material.dart';
import 'package:pdf_viewer/pdf_viewer.dart';

class ReaderPage extends StatefulWidget {
  const ReaderPage({super.key});

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  final PdfViewController _controller = PdfViewController();
  PdfDocument? _document;

  @override
  void initState() {
    super.initState();
    PdfDocument.openAsset('assets/sample.pdf').then((doc) {
      if (mounted) setState(() => _document = doc);
    });
  }

  @override
  void dispose() {
    _document?.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final document = _document;
    if (document == null) return const Center(child: CircularProgressIndicator());
    return PdfView(document: document, controller: _controller);
  }
}
```

### Open a document

```dart
// From a file on disk
final doc = await PdfDocument.openFile('/path/to/file.pdf');

// From bytes already in memory
final doc = await PdfDocument.openBytes(bytes, cacheKey: 'invoice-42');

// From a bundled asset (declare it under `assets:` in your pubspec)
final doc = await PdfDocument.openAsset('assets/sample.pdf');

// Downloaded over HTTP(S)
final doc = await PdfDocument.openUrl(Uri.parse('https://example.com/a.pdf'));
```

Always call `document.dispose()` when you are done with it.

### Copy and highlight

```dart
final controller = PdfViewController();

// Pass the same controller to PdfView, then act on the selection:
final String? text = controller.selectedText;
await controller.copySelection();
final PdfHighlight? highlight = await controller.highlightSelection(color: 0xFFFFEB3B);
await controller.deleteActiveHighlight();
controller.clearSelection();
```

Highlights are stored on the `PdfDocument`. Read them with `document.highlights` or `document.highlightsForPage(page)`, add with `addHighlight`, and remove with `removeHighlight(id)`. The document notifies its listeners when they change.

### Persist text layers and highlights

```dart
final cache = await HivePdfCache.open(path: appDocsDir.path);
final doc = await PdfDocument.openUrl(url, cache: cache);
```

Without a cache argument the default `NoPdfCache` is used, so nothing is persisted.

To use your own storage, implement `PdfCache`:

```dart
abstract class PdfCache {
  Future<String?> readTextLayer(String documentKey, int page);
  Future<void> writeTextLayer(String documentKey, int page, String json);
  Future<List<PdfHighlight>> readHighlights(String documentKey);
  Future<void> writeHighlights(String documentKey, List<PdfHighlight> highlights);
}
```

The cache key decides when cached data is reused:

- `openFile`: defaults to path + file size + modification time, so an edited file gets a fresh cache.
- `openBytes` / `openAsset` / `openUrl`: default to a content fingerprint, the asset name, or the URL. If the content behind a URL changes, pass a new `cacheKey` to avoid stale highlights.

### Widget options

`PdfView` accepts:

| Parameter          | Default     | Purpose                                              |
|--------------------|-------------|------------------------------------------------------|
| `document`         | required    | The open `PdfDocument`.                              |
| `controller`       | internal    | Pass your own to copy or highlight from outside.     |
| `pageSpacing`      | `12`        | Gap between pages, in logical pixels.                |
| `highlightColor`   | yellow      | Color used by the toolbar's highlight action.        |
| `selectionColor`   | blue        | Color of the selection overlay.                      |
| `backgroundColor`  | light grey  | Background behind the pages.                         |

## Error handling

Failures are thrown as `PdfException`, for example when a URL download returns a non-200 status:

```dart
try {
  final doc = await PdfDocument.openUrl(uri);
} on PdfException catch (e) {
  debugPrint(e.message);
}
```

## Example

The `example/` app opens `assets/sample.pdf` with a Hive-backed cache:

```bash
cd example
flutter run
```

## Development

Native bindings are generated, not hand-written. Regenerate them only when the native API changes:

| Output                                                                                                    | Source                                                 | Command                                                                                                       |
|-----------------------------------------------------------------------------------------------------------|--------------------------------------------------------|---------------------------------------------------------------------------------------------------------------|
| `lib/src/bindings/pdf_viewer_darwin.g.dart` and `ios/pdf_viewer/Sources/pdf_viewer_c/pdf_viewer_darwin.m` | `ios/pdf_viewer/Sources/pdf_viewer_c/pdf_viewer_api.h` | `dart run tool/ffigen.dart`                                                                                   |
| `lib/src/bindings/pdf_viewer_api.g.dart`                                                                  | Compiled Kotlin `PdfViewerApi`                         | `cd example/android && ./gradlew :pdf_viewer:compileDebugKotlin && cd ../..` then `dart run tool/jnigen.dart` |

Run tests and analysis:

```bash
flutter test
dart analyze
```

See [CLAUDE.md](CLAUDE.md) / [AGENTS.md](AGENTS.md) for contributor and AI-agent guidelines.

## Known limitations

- Text selection depends on the PDF containing extractable text; scanned pages without an OCR layer have no selectable text.
- Rendered pages are kept in a small in-memory LRU (12 pages per document).

## License

See [LICENSE](LICENSE).
