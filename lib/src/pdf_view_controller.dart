import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pdf_viewer/src/highlight/pdf_highlight.dart';
import 'package:pdf_viewer/src/pdf_document.dart';
import 'package:pdf_viewer/src/text/pdf_text_layer.dart';

/// A text selection on one page. [anchor] is the fixed end, [focus] follows the finger.
@immutable
class PdfSelection {
  const new({required this.page, required this.anchor, required this.focus});

  final int page;
  final int anchor;
  final int focus;

  int get start => anchor < focus ? anchor : focus;

  int get end => anchor < focus ? focus : anchor;
}

/// Owns the current selection (or the tapped highlight) and turns it into copied text, saved
/// highlights, or deletions. Selections stay on one page: starting one on another page replaces the old one.
class PdfViewController extends ChangeNotifier {
  PdfDocument? _document;
  PdfSelection? _selection;
  PdfTextLayer? _layer;
  String? _activeHighlightId;

  PdfSelection? get selection => _selection;

  /// Id of the saved highlight the user tapped, or null.
  String? get activeHighlightId => _activeHighlightId;

  /// Text of the current selection, or null when nothing is selected.
  String? get selectedText {
    final PdfSelection? s = _selection;
    final PdfTextLayer? layer = _layer;
    if (s == null || layer == null) {
      return null;
    }
    final String text = layer.textBetween(s.start, s.end);
    return text.isEmpty ? null : text;
  }

  /// Attaches to a document. Called by `PdfView`; a controller can be reused across documents.
  void attach(PdfDocument document) {
    if (identical(_document, document)) {
      return;
    }
    _document = document;
    clearSelection();
  }

  /// Starts a selection at glyph [index] of [page]. [layer] must be the page's text layer.
  void startSelection(int page, PdfTextLayer layer, int index) {
    _layer = layer;
    _activeHighlightId = null;
    _selection = PdfSelection(page: page, anchor: index, focus: index);
    notifyListeners();
  }

  /// Selects the whole word at glyph [index] of [page], like a double tap or long press in a SelectableText.
  /// [layer] must be the page's text layer.
  void selectWord(int page, PdfTextLayer layer, int index) {
    final (int start, int end) = layer.wordBounds(index);
    _layer = layer;
    _activeHighlightId = null;
    _selection = PdfSelection(page: page, anchor: start, focus: end);
    notifyListeners();
  }

  /// Moves the selection's focus to glyph [index]. Ignored when nothing is selected.
  void extendSelection(int index) {
    final PdfSelection? s = _selection;
    if (s == null || s.focus == index) {
      return;
    }
    _selection = PdfSelection(page: s.page, anchor: s.anchor, focus: index);
    notifyListeners();
  }

  /// Moves one edge while a selection handle is dragged: [fixed] stays, [moving] follows the finger.
  void dragSelectionEdge(int fixed, int moving) {
    final PdfSelection? s = _selection;
    if (s == null || (s.anchor == fixed && s.focus == moving)) {
      return;
    }
    _selection = PdfSelection(page: s.page, anchor: fixed, focus: moving);
    notifyListeners();
  }

  /// Selects all text of the selected page. Ignored when nothing is selected.
  void selectAll() {
    final PdfSelection? s = _selection;
    final PdfTextLayer? layer = _layer;
    if (s == null || layer == null || layer.isEmpty) {
      return;
    }
    _selection = PdfSelection(page: s.page, anchor: 0, focus: layer.chars.length - 1);
    notifyListeners();
  }

  /// Picks a saved highlight so it can be deleted. Clears any text selection.
  void selectHighlight(String id) {
    _selection = null;
    _layer = null;
    _activeHighlightId = id;
    notifyListeners();
  }

  /// Clears the text selection and the picked highlight.
  void clearSelection() {
    if (_selection == null && _activeHighlightId == null) {
      return;
    }
    _selection = null;
    _layer = null;
    _activeHighlightId = null;
    notifyListeners();
  }

  /// Copies the selected text to the system clipboard. Returns false when nothing is selected.
  Future<bool> copySelection() async {
    final String? text = selectedText;
    if (text == null) {
      return false;
    }
    await Clipboard.setData(ClipboardData(text: text));
    return true;
  }

  /// Saves the selection as a highlight and clears the selection. Returns null when nothing is selected.
  Future<PdfHighlight?> highlightSelection({int color = 0xFFFFEB3B}) async {
    final PdfSelection? s = _selection;
    final PdfTextLayer? layer = _layer;
    final PdfDocument? document = _document;
    if (s == null || layer == null || document == null) {
      return null;
    }
    final List<Rect> rects = layer.rectsBetween(s.start, s.end);
    final PdfHighlight highlight = PdfHighlight(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      page: s.page,
      rects: rects,
      text: layer.textBetween(s.start, s.end),
      color: color,
    );
    clearSelection();
    // Highlighting over text that is already highlighted replaces the old highlight instead of stacking a copy.
    for (final PdfHighlight existing in document.highlightsForPage(s.page)) {
      if (existing.rects.any((Rect r) => rects.any(r.overlaps))) {
        await document.removeHighlight(existing.id);
      }
    }
    await document.addHighlight(highlight);
    return highlight;
  }

  /// Deletes the highlight picked with [selectHighlight]. Returns false when none is picked.
  Future<bool> deleteActiveHighlight() async {
    final String? id = _activeHighlightId;
    final PdfDocument? document = _document;
    if (id == null || document == null) {
      return false;
    }
    clearSelection();
    await document.removeHighlight(id);
    return true;
  }
}
