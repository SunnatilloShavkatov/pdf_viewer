import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pdf_viewer/src/cache/pdf_cache.dart';
import 'package:pdf_viewer/src/highlight/pdf_highlight.dart';
import 'package:pdf_viewer/src/native/pdf_native.dart';
import 'package:pdf_viewer/src/pdf_exception.dart';
import 'package:pdf_viewer/src/text/pdf_text_layer.dart';
import 'package:pdf_viewer/src/util/lru_cache.dart';

/// An open PDF. Rendered pages are kept in a small in-memory LRU; text layers and highlights go through [PdfCache].
/// Notifies listeners when highlights change.
class PdfDocument extends ChangeNotifier {
  new _(this._native, this._id, this.cacheKey, this._cache, this._highlights);

  /// Opens a file. [cacheKey] defaults to path, size and modification time, so a changed file gets a fresh cache.
  static Future<PdfDocument> openFile(String path, {PdfCache cache = const NoPdfCache(), String? cacheKey}) async {
    final PdfNative native = PdfNative.instance;
    final int id = await native.openFile(path);
    final File file = File(path);
    final String key = cacheKey ?? '$path:${file.lengthSync()}:${file.lastModifiedSync().millisecondsSinceEpoch}';
    return _create(native, id, key, cache);
  }

  /// Opens PDF bytes. Pass a stable [cacheKey] (for example a URL or content hash) to reuse cached text and highlights.
  static Future<PdfDocument> openBytes(Uint8List bytes, {PdfCache cache = const NoPdfCache(), String? cacheKey}) async {
    final PdfNative native = PdfNative.instance;
    final int id = await native.openBytes(bytes);
    return _create(native, id, cacheKey ?? _fingerprint(bytes), cache);
  }

  /// Opens a PDF bundled as a Flutter asset, for example `assets/sample.pdf`. [cacheKey] defaults to the asset name.
  static Future<PdfDocument> openAsset(
    String assetName, {
    AssetBundle? bundle,
    PdfCache cache = const NoPdfCache(),
    String? cacheKey,
  }) async {
    final ByteData data = await (bundle ?? rootBundle).load(assetName);
    final Uint8List bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    return openBytes(bytes, cache: cache, cacheKey: cacheKey ?? 'asset:$assetName');
  }

  /// Downloads a PDF over HTTP(S) and opens it. [cacheKey] defaults to the URL, so a URL whose content changes
  /// keeps its old cached text and highlights until [cacheKey] is changed.
  static Future<PdfDocument> openUrl(
    Uri url, {
    Map<String, String> headers = const <String, String>{},
    PdfCache cache = const NoPdfCache(),
    String? cacheKey,
  }) async {
    final HttpClient client = HttpClient();
    try {
      final HttpClientRequest request = await client.getUrl(url);
      headers.forEach(request.headers.set);
      final HttpClientResponse response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        throw PdfException('Cannot download PDF from $url (HTTP ${response.statusCode})');
      }
      final BytesBuilder builder = BytesBuilder(copy: false);
      await response.forEach(builder.add);
      return await openBytes(builder.takeBytes(), cache: cache, cacheKey: cacheKey ?? url.toString());
    } finally {
      client.close();
    }
  }

  static Future<PdfDocument> _create(PdfNative native, int id, String key, PdfCache cache) async {
    final List<PdfHighlight> highlights = await _readHighlights(cache, key);
    return PdfDocument._(native, id, key, cache, highlights);
  }

  /// A failing read starts the document with no saved highlights instead of failing to open.
  static Future<List<PdfHighlight>> _readHighlights(PdfCache cache, String key) async {
    try {
      return await cache.readHighlights(key);
    } on Object catch (error, stack) {
      _reportCacheFailure(error, stack, 'while reading saved highlights');
      return const <PdfHighlight>[];
    }
  }

  final PdfNative _native;
  final int _id;
  final PdfCache _cache;

  /// Key under which text layers and highlights are cached.
  final String cacheKey;

  final LruCache<String, Uint8List> _pages = LruCache<String, Uint8List>(12);
  final Map<int, PdfTextLayer> _layers = <int, PdfTextLayer>{};
  final Map<int, Future<PdfTextLayer>> _pendingLayers = <int, Future<PdfTextLayer>>{};
  List<PdfHighlight> _highlights;
  bool _closed = false;

  int get pageCount => _native.pageCount(_id);

  /// Page size in PDF points.
  Size pageSize(int page) => Size(_native.pageWidth(_id, page), _native.pageHeight(_id, page));

  /// JPEG bytes of [page] at [width] pixels. Results are memoized per (page, width).
  Future<Uint8List> renderPage(int page, {required int width}) async {
    _ensureOpen();
    final String key = '$page@$width';
    final Uint8List? cached = _pages[key];
    if (cached != null) {
      return cached;
    }
    final Uint8List bytes = await _native.renderPage(_id, page, width);
    if (!_closed) {
      _pages[key] = bytes;
    }
    return bytes;
  }

  /// Glyph boxes for [page]. Reads memory, then the cache, then native; concurrent callers share one extraction.
  Future<PdfTextLayer> textLayer(int page) {
    _ensureOpen();
    final PdfTextLayer? loaded = _layers[page];
    if (loaded != null) {
      return SynchronousFuture<PdfTextLayer>(loaded);
    }
    return _pendingLayers[page] ??= _loadLayer(page);
  }

  Future<PdfTextLayer> _loadLayer(int page) async {
    try {
      final String? cached = await _readCachedLayer(page);
      final String json = cached ?? await _native.textLayer(_id, page);
      final PdfTextLayer layer = PdfTextLayer.fromJson(json);
      if (!_closed) {
        _layers[page] = layer;
      }
      if (cached == null) {
        unawaited(_writeCachedLayer(page, json));
      }
      return layer;
    } finally {
      _pendingLayers.removeWhere((int key, Future<PdfTextLayer> _) => key == page);
    }
  }

  /// A failing cache read is a miss: the layer is extracted again and the viewer keeps working.
  Future<String?> _readCachedLayer(int page) async {
    try {
      return await _cache.readTextLayer(cacheKey, page);
    } on Object catch (error, stack) {
      _reportCacheFailure(error, stack, 'while reading the cached text layer of page $page');
      return null;
    }
  }

  Future<void> _writeCachedLayer(int page, String json) async {
    try {
      await _cache.writeTextLayer(cacheKey, page, json);
    } on Object catch (error, stack) {
      _reportCacheFailure(error, stack, 'while caching the text layer of page $page');
    }
  }

  /// Highlights stay usable in memory when the cache write fails; the failure is reported, not thrown.
  Future<void> _persistHighlights() async {
    try {
      await _cache.writeHighlights(cacheKey, _highlights);
    } on Object catch (error, stack) {
      _reportCacheFailure(error, stack, 'while saving highlights');
    }
  }

  static void _reportCacheFailure(Object error, StackTrace stack, String context) {
    FlutterError.reportError(
      FlutterErrorDetails(exception: error, stack: stack, library: 'pdf_viewer', context: ErrorDescription(context)),
    );
  }

  /// All highlights of this document, in the order they were added.
  List<PdfHighlight> get highlights => List<PdfHighlight>.unmodifiable(_highlights);

  List<PdfHighlight> highlightsForPage(int page) => <PdfHighlight>[
    for (final PdfHighlight h in _highlights)
      if (h.page == page) h,
  ];

  Future<void> addHighlight(PdfHighlight highlight) async {
    _ensureOpen();
    _highlights = <PdfHighlight>[..._highlights, highlight];
    notifyListeners();
    await _persistHighlights();
  }

  Future<void> removeHighlight(String id) async {
    _ensureOpen();
    _highlights = <PdfHighlight>[
      for (final PdfHighlight h in _highlights)
        if (h.id != id) h,
    ];
    notifyListeners();
    await _persistHighlights();
  }

  void _ensureOpen() {
    if (_closed) {
      throw StateError('PdfDocument is closed.');
    }
  }

  @override
  void dispose() {
    if (!_closed) {
      _closed = true;
      _pages.clear();
      _layers.clear();
      _native.close(_id);
    }
    super.dispose();
  }

  /// FNV-1a (32-bit) over up to 128 KB sampled from both ends: enough to tell documents apart
  /// without hashing a whole file on the UI isolate.
  static String _fingerprint(Uint8List bytes) {
    const int window = 64 * 1024;
    int hash = 0x811c9dc5;
    void mix(int byte) {
      hash = ((hash ^ byte) * 0x01000193) & 0xffffffff;
    }

    for (int i = 0; i < bytes.length && i < window; i++) {
      mix(bytes[i]);
    }
    for (int i = bytes.length > window ? bytes.length - window : window; i < bytes.length; i++) {
      mix(bytes[i]);
    }
    return 'bytes-${bytes.length}-${hash.toRadixString(16)}';
  }
}
