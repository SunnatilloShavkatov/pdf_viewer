/// Smallest zoom: the page fits the view width.
const double pdfMinZoom = 1;

/// Largest zoom a pinch can reach.
const double pdfMaxZoom = 4;

/// Zoom after a pinch. Scales [startZoom] by how far the fingers moved apart, rounded to quarter steps
/// (each step re-renders the visible pages, so every pixel would be wasteful) and clamped to the zoom range.
double zoomForPinch({required double startZoom, required double startDistance, required double distance}) {
  if (startDistance <= 0) {
    return startZoom;
  }
  final double raw = startZoom * distance / startDistance;
  final double quantized = (raw * 4).roundToDouble() / 4;
  return quantized.clamp(pdfMinZoom, pdfMaxZoom);
}
