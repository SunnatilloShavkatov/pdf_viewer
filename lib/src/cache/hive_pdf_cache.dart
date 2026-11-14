import 'dart:convert';

import 'package:hive_ce/hive.dart';
import 'package:pdf_viewer/src/cache/pdf_cache.dart';
import 'package:pdf_viewer/src/highlight/pdf_highlight.dart';

/// [PdfCache] backed by hive_ce. Text layers and highlights are stored as JSON strings, so no
/// TypeAdapters or code generation are needed.
///
/// Open once at startup and pass it to `PdfDocument.openFile` / `openBytes`. `path` is a
/// writable directory for the cache files (e.g. the app documents directory):
/// ```dart
/// final cache = await HivePdfCache.open(path: appDocsDir.path);
/// ```
class HivePdfCache implements PdfCache {
  new _(this._textLayers, this._highlights);

  static const String _textLayerBox = 'pdf_viewer_text_layers';
  static const String _highlightBox = 'pdf_viewer_highlights';

  static Future<HivePdfCache>? _opening;

  /// Initializes Hive at [path] and opens the boxes. Safe to call repeatedly; the boxes open once,
  /// so later calls return the first instance regardless of [path].
  static Future<HivePdfCache> open({required String path}) => _opening ??= _open(path).onError(_forgetFailedOpen);

  /// A failed open must not stay cached: the next call retries.
  static Future<HivePdfCache> _forgetFailedOpen(Object error, StackTrace stack) {
    _opening = null;
    return Future<HivePdfCache>.error(error, stack);
  }

  static Future<HivePdfCache> _open(String path) async {
    Hive.init(path);
    final Box<String> textLayers = await Hive.openBox<String>(_textLayerBox);
    final Box<String> highlights = await Hive.openBox<String>(_highlightBox);
    return HivePdfCache._(textLayers, highlights);
  }

  final Box<String> _textLayers;
  final Box<String> _highlights;

  @override
  Future<String?> readTextLayer(String documentKey, int page) async => _textLayers.get(_pageKey(documentKey, page));

  @override
  Future<void> writeTextLayer(String documentKey, int page, String json) =>
      _textLayers.put(_pageKey(documentKey, page), json);

  @override
  Future<List<PdfHighlight>> readHighlights(String documentKey) async {
    final String? raw = _highlights.get(documentKey);
    if (raw == null) {
      return const <PdfHighlight>[];
    }
    final List<dynamic> items = jsonDecode(raw) as List<dynamic>;
    return <PdfHighlight>[
      for (final dynamic item in items) PdfHighlight.fromJson(Map<String, Object?>.from(item as Map<dynamic, dynamic>)),
    ];
  }

  @override
  Future<void> writeHighlights(String documentKey, List<PdfHighlight> highlights) {
    if (highlights.isEmpty) {
      return _highlights.delete(documentKey);
    }
    return _highlights.put(documentKey, jsonEncode(<Map<String, Object?>>[for (final h in highlights) h.toJson()]));
  }

  /// Removes all cached text layers and highlights.
  Future<void> clear() async {
    await _textLayers.clear();
    await _highlights.clear();
  }

  static String _pageKey(String documentKey, int page) => '$documentKey#$page';
}
