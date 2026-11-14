package uz.plugin.pdf_viewer

/** Called on a native worker thread. [json] is a JSON array of `[char, x0, y0, x1, y1]`, normalized 0..1, top-left origin. */
interface PdfTextCallback {
    fun onResult(json: String?, error: String?)
}
