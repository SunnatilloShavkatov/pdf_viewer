import 'package:material_ui/material_ui.dart';
import 'package:pdf_viewer/src/pdf_document.dart';
import 'package:pdf_viewer/src/pdf_view_controller.dart';
import 'package:pdf_viewer/src/widgets/pdf_page_view.dart';
import 'package:pdf_viewer/src/widgets/pdf_zoom.dart';

/// Scrollable list of PDF pages. Text behaves like SelectableText: double tap or long press selects a word,
/// drag the handles to adjust, and use the toolbar to copy, highlight, select all, or clear.
/// Tap a saved highlight to delete it.
///
/// ```dart
/// PdfView(document: document, controller: controller)
/// ```
class PdfView extends StatefulWidget {
  const new({
    super.key,
    required this.document,
    this.controller,
    this.pageSpacing = 12,
    this.highlightColor = const Color(0xFFFFEB3B),
    this.selectionColor = const Color(0xFF2196F3),
    this.backgroundColor = const Color(0xFFE0E0E0),
  });

  final PdfDocument document;

  /// Optional. Pass one to copy or highlight the selection from outside the widget.
  final PdfViewController? controller;
  final double pageSpacing;

  /// Color used by the toolbar's highlight action.
  final Color highlightColor;
  final Color selectionColor;
  final Color backgroundColor;

  @override
  State<PdfView> createState() => _PdfViewState();
}

class _PdfViewState extends State<PdfView> {
  PdfViewController? _ownController;

  double _zoom = pdfMinZoom;
  final Map<int, Offset> _pointers = <int, Offset>{};
  double? _pinchStartDistance;
  double _pinchStartZoom = pdfMinZoom;

  PdfViewController get _controller => widget.controller ?? (_ownController ??= PdfViewController());

  @override
  void initState() {
    super.initState();
    _controller.attach(widget.document);
  }

  @override
  void didUpdateWidget(PdfView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.document != widget.document) {
      _controller.attach(widget.document);
    }
  }

  @override
  void dispose() {
    _ownController?.dispose();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent event) {
    _pointers[event.pointer] = event.position;
    if (_pointers.length == 2) {
      _pinchStartDistance = _spread();
      _pinchStartZoom = _zoom;
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_pointers.containsKey(event.pointer)) {
      return;
    }
    _pointers[event.pointer] = event.position;
    final double? startDistance = _pinchStartDistance;
    if (_pointers.length != 2 || startDistance == null) {
      return;
    }
    final double zoom = zoomForPinch(startZoom: _pinchStartZoom, startDistance: startDistance, distance: _spread());
    if (zoom != _zoom) {
      setState(() => _zoom = zoom);
    }
  }

  void _onPointerEnd(PointerEvent event) {
    _pointers.remove(event.pointer);
    if (_pointers.length < 2) {
      _pinchStartDistance = null;
    }
  }

  /// Distance between the two tracked pointers. Only valid while exactly two are down.
  double _spread() {
    final List<Offset> points = _pointers.values.toList();
    return (points[0] - points[1]).distance;
  }

  /// Page list at the current zoom. Zoomed pages wider than the view scroll horizontally.
  Widget _pages(BuildContext context, BoxConstraints constraints, PdfViewController controller) {
    final double dpr = MediaQuery.devicePixelRatioOf(context);
    final double pageWidth = constraints.maxWidth * _zoom;
    final Widget list = SizedBox(
      width: pageWidth,
      height: constraints.maxHeight,
      child: ListView.builder(
        padding: EdgeInsets.symmetric(vertical: widget.pageSpacing),
        itemCount: widget.document.pageCount,
        itemBuilder: (BuildContext context, int page) => Padding(
          padding: EdgeInsets.only(bottom: widget.pageSpacing),
          child: Center(
            child: PdfPageView(
              key: ValueKey<int>(page),
              document: widget.document,
              controller: controller,
              page: page,
              width: pageWidth,
              devicePixelRatio: dpr,
              selectionColor: widget.selectionColor,
            ),
          ),
        ),
      ),
    );
    return SingleChildScrollView(scrollDirection: Axis.horizontal, child: list);
  }

  @override
  Widget build(BuildContext context) {
    final PdfViewController controller = _controller;
    return ColoredBox(
      color: widget.backgroundColor,
      child: Stack(
        children: <Widget>[
          Listener(
            // Observes pointers without entering the gesture arena, so page gestures keep working.
            onPointerDown: _onPointerDown,
            onPointerMove: _onPointerMove,
            onPointerUp: _onPointerEnd,
            onPointerCancel: _onPointerEnd,
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) => _pages(context, constraints, controller),
            ),
          ),
          ListenableBuilder(
            listenable: controller,
            builder: (BuildContext context, Widget? child) {
              final String? highlightId = controller.activeHighlightId;
              if (controller.selection == null && highlightId == null) {
                return const SizedBox.shrink();
              }
              return Positioned(
                left: 0,
                right: 0,
                bottom: 16,
                child: Center(
                  child: highlightId != null
                      ? _HighlightToolbar(
                          onDelete: () async {
                            await controller.deleteActiveHighlight();
                          },
                          onClose: controller.clearSelection,
                        )
                      : _SelectionToolbar(
                          onCopy: controller.copySelection,
                          onHighlight: () async {
                            await controller.highlightSelection(color: widget.highlightColor.toARGB32());
                          },
                          onSelectAll: controller.selectAll,
                          onClear: controller.clearSelection,
                        ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SelectionToolbar extends StatelessWidget {
  const new({required this.onCopy, required this.onHighlight, required this.onSelectAll, required this.onClear});

  final VoidCallback onCopy;
  final VoidCallback onHighlight;
  final VoidCallback onSelectAll;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => _ToolbarShell(
    children: <Widget>[
      IconButton(tooltip: 'Copy', icon: const Icon(Icons.copy), onPressed: onCopy),
      IconButton(tooltip: 'Highlight', icon: const Icon(Icons.highlight), onPressed: onHighlight),
      IconButton(tooltip: 'Select all', icon: const Icon(Icons.select_all), onPressed: onSelectAll),
      IconButton(tooltip: 'Clear', icon: const Icon(Icons.close), onPressed: onClear),
    ],
  );
}

class _HighlightToolbar extends StatelessWidget {
  const new({required this.onDelete, required this.onClose});

  final VoidCallback onDelete;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => _ToolbarShell(
    children: <Widget>[
      IconButton(tooltip: 'Delete highlight', icon: const Icon(Icons.delete_outline), onPressed: onDelete),
      IconButton(tooltip: 'Close', icon: const Icon(Icons.close), onPressed: onClose),
    ],
  );
}

class _ToolbarShell extends StatelessWidget {
  const new({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Material(
    elevation: 4,
    borderRadius: BorderRadius.circular(24),
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: Row(mainAxisSize: MainAxisSize.min, children: children),
  );
}
