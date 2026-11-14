import 'dart:async';
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:pdf_viewer/src/highlight/pdf_highlight.dart';
import 'package:pdf_viewer/src/pdf_document.dart';
import 'package:pdf_viewer/src/pdf_view_controller.dart';
import 'package:pdf_viewer/src/text/pdf_text_layer.dart';
import 'package:pdf_viewer/src/widgets/pdf_overlay_painter.dart';

/// One page: the rendered image, SelectableText-like selection (double tap or long press to select a word,
/// drag the handles to adjust), and saved highlights on top. Tapping a highlight picks it for deletion.
class PdfPageView extends StatefulWidget {
  const new({
    super.key,
    required this.document,
    required this.controller,
    required this.page,
    required this.width,
    required this.devicePixelRatio,
    required this.selectionColor,
  });

  final PdfDocument document;
  final PdfViewController controller;
  final int page;

  /// Logical width of the page in the list.
  final double width;
  final double devicePixelRatio;
  final Color selectionColor;

  @override
  State<PdfPageView> createState() => _PdfPageViewState();
}

class _PdfPageViewState extends State<PdfPageView> {
  static const double _handleSize = 24;
  static const double _handleDot = 12;

  late Future<Uint8List> _image;
  PdfTextLayer? _loadedLayer;
  int _layerRequest = 0;
  int? _pixelWidth;
  final GlobalKey _pageKey = GlobalKey();
  Offset? _lastTap;

  /// Glyph index that stays put while a selection handle is dragged.
  int? _dragFixed;

  @override
  void initState() {
    super.initState();
    _loadLayer();
    _loadImage();
  }

  @override
  void didUpdateWidget(PdfPageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool pageChanged = oldWidget.document != widget.document || oldWidget.page != widget.page;
    if (pageChanged) {
      _loadLayer();
    }
    if (pageChanged || _targetPixelWidth() != _pixelWidth) {
      _loadImage();
    }
  }

  int _targetPixelWidth() => (widget.width * widget.devicePixelRatio).round();

  void _loadImage() {
    _pixelWidth = _targetPixelWidth();
    _image = widget.document.renderPage(widget.page, width: _pixelWidth!);
  }

  void _loadLayer() {
    final int request = ++_layerRequest;
    _loadedLayer = null;
    unawaited(
      widget.document
          .textLayer(widget.page)
          .then(
            (PdfTextLayer layer) {
              // A layer for a page or document we no longer show must not replace the current one.
              if (request == _layerRequest) {
                _loadedLayer = layer;
              }
            },
            onError: (Object error, StackTrace stack) {
              FlutterError.reportError(
                FlutterErrorDetails(
                  exception: error,
                  stack: stack,
                  library: 'pdf_viewer',
                  context: ErrorDescription('while extracting the text layer of page ${widget.page}'),
                ),
              );
            },
          ),
    );
  }

  void _onTapUp(TapUpDetails details, Size size) {
    final Offset point = _normalize(details.localPosition, size);
    for (final PdfHighlight highlight in widget.document.highlightsForPage(widget.page)) {
      if (highlight.rects.any((Rect rect) => rect.contains(point))) {
        widget.controller.selectHighlight(highlight.id);
        return;
      }
    }
    widget.controller.clearSelection();
  }

  void _onDoubleTap(Size size) {
    final PdfTextLayer? layer = _loadedLayer;
    final Offset? tap = _lastTap;
    if (layer == null || tap == null) {
      return;
    }
    _selectWordAt(layer, tap, size);
  }

  void _onLongPressStart(LongPressStartDetails details, Size size) {
    final PdfTextLayer? layer = _loadedLayer;
    if (layer == null) {
      return;
    }
    _selectWordAt(layer, details.localPosition, size);
  }

  void _selectWordAt(PdfTextLayer layer, Offset local, Size size) {
    final int? index = layer.indexAt(_normalize(local, size));
    if (index != null) {
      widget.controller.selectWord(widget.page, layer, index);
    }
  }

  void _onLongPressMoveUpdate(LongPressMoveUpdateDetails details, Size size) {
    final PdfTextLayer? layer = _loadedLayer;
    final PdfSelection? selection = widget.controller.selection;
    if (layer == null || selection == null || selection.page != widget.page) {
      return;
    }
    final int? index = layer.indexAt(_normalize(details.localPosition, size));
    if (index != null) {
      widget.controller.extendSelection(index);
    }
  }

  void _onHandleDragStart(bool isStartHandle) {
    final PdfSelection? selection = widget.controller.selection;
    if (selection == null || selection.page != widget.page) {
      return;
    }
    _dragFixed = isStartHandle ? selection.end : selection.start;
  }

  void _onHandleDragUpdate(DragUpdateDetails details, Size size) {
    final int? fixed = _dragFixed;
    final PdfTextLayer? layer = _loadedLayer;
    final RenderBox? box = _pageKey.currentContext?.findRenderObject() as RenderBox?;
    if (fixed == null || layer == null || box == null) {
      return;
    }
    final Offset local = box.globalToLocal(details.globalPosition);
    final int? index = layer.indexAt(_normalize(local, size));
    if (index != null) {
      widget.controller.dragSelectionEdge(fixed, index);
    }
  }

  void _onHandleDragEnd() {
    _dragFixed = null;
  }

  static Offset _normalize(Offset local, Size size) => Offset(local.dx / size.width, local.dy / size.height);

  static Offset _scale(Offset normalized, Size size) => Offset(normalized.dx * size.width, normalized.dy * size.height);

  Widget _handle({required Offset at, required bool isStartHandle, required Size size}) {
    // The dot sits just below the text line, the hit area is larger than the dot.
    final Offset center = Offset(at.dx, at.dy + 6);
    return Positioned(
      left: center.dx - _handleSize / 2,
      top: center.dy - _handleSize / 2,
      width: _handleSize,
      height: _handleSize,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (DragStartDetails _) => _onHandleDragStart(isStartHandle),
        onPanUpdate: (DragUpdateDetails details) => _onHandleDragUpdate(details, size),
        onPanEnd: (DragEndDetails _) => _onHandleDragEnd(),
        onPanCancel: _onHandleDragEnd,
        child: Center(
          child: Container(
            width: _handleDot,
            height: _handleDot,
            decoration: BoxDecoration(color: widget.selectionColor, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size pageSize = widget.document.pageSize(widget.page);
    final double aspect = pageSize.height / pageSize.width;
    final Size size = Size(widget.width, widget.width * aspect);

    return SizedBox(
      key: _pageKey,
      width: size.width,
      height: size.height,
      child: FutureBuilder<Uint8List>(
        future: _image,
        builder: (BuildContext context, AsyncSnapshot<Uint8List> snapshot) {
          final Uint8List? bytes = snapshot.data;
          if (snapshot.hasError) {
            return const Center(child: Icon(Icons.broken_image_outlined));
          }
          if (bytes == null) {
            return const ColoredBox(
              color: Colors.white,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (TapUpDetails details) => _onTapUp(details, size),
            onDoubleTapDown: (TapDownDetails details) {
              _lastTap = details.localPosition;
            },
            onDoubleTap: () => _onDoubleTap(size),
            onLongPressStart: (LongPressStartDetails details) => _onLongPressStart(details, size),
            onLongPressMoveUpdate: (LongPressMoveUpdateDetails details) => _onLongPressMoveUpdate(details, size),
            child: ListenableBuilder(
              listenable: Listenable.merge(<Listenable>[widget.controller, widget.document]),
              builder: (BuildContext context, Widget? child) {
                final PdfSelection? selection = widget.controller.selection;
                final PdfTextLayer? layer = _loadedLayer;
                final List<Rect> selected = selection != null && selection.page == widget.page && layer != null
                    ? layer.rectsBetween(selection.start, selection.end)
                    : const <Rect>[];
                return Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    CustomPaint(
                      foregroundPainter: PdfOverlayPainter(
                        highlights: widget.document.highlightsForPage(widget.page),
                        selection: selected,
                        selectionColor: widget.selectionColor,
                      ),
                      child: Image.memory(bytes, fit: BoxFit.fill, gaplessPlayback: true, width: size.width),
                    ),
                    if (selected.isNotEmpty) ...<Widget>[
                      _handle(at: _scale(selected.first.bottomLeft, size), isStartHandle: true, size: size),
                      _handle(at: _scale(selected.last.bottomRight, size), isStartHandle: false, size: size),
                    ],
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}
