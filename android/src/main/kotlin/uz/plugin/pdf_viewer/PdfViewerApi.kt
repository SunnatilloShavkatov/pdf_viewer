package uz.plugin.pdf_viewer

/**
 * The only surface Dart sees through JNI. Primitives, String, ByteArray and callback
 * interfaces only, so jnigen can read the compiled class. Regenerate bindings with
 * `dart run tool/jnigen.dart` after changing this file.
 */
object PdfViewerApi {
    /** Returns a document id, or -1 when the file cannot be opened. */
    @JvmStatic
    fun openFile(path: String): Int = PdfDocumentHost.openFile(path)

    /** Returns a document id, or -1 when the bytes are not a readable PDF. */
    @JvmStatic
    fun openBytes(data: ByteArray): Int = PdfDocumentHost.openBytes(data)

    @JvmStatic
    fun pageCount(docId: Int): Int = PdfDocumentHost.pageCount(docId)

    /** Page width in PDF points (crop box). */
    @JvmStatic
    fun pageWidth(docId: Int, page: Int): Double = PdfDocumentHost.pageWidth(docId, page)

    /** Page height in PDF points (crop box). */
    @JvmStatic
    fun pageHeight(docId: Int, page: Int): Double = PdfDocumentHost.pageHeight(docId, page)

    /** Renders [page] at [width] pixels wide (height follows the aspect ratio) as JPEG, asynchronously. */
    @JvmStatic
    fun renderPage(docId: Int, page: Int, width: Int, callback: PdfRenderCallback) {
        PdfDocumentHost.render(docId, page, width, callback)
    }

    /** Extracts per-character boxes for [page], asynchronously. */
    @JvmStatic
    fun textLayer(docId: Int, page: Int, callback: PdfTextCallback) {
        PdfDocumentHost.textLayer(docId, page, callback)
    }

    @JvmStatic
    fun close(docId: Int) = PdfDocumentHost.close(docId)
}
