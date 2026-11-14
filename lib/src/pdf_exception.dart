/// Thrown when a native PDF operation fails (unreadable file, page out of range, encoder error).
class PdfException implements Exception {
  const new(this.message);

  final String message;

  @override
  String toString() => 'PdfException: $message';
}
