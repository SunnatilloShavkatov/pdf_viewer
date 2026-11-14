package uz.plugin.pdf_viewer

/** Called on a native worker thread. [jpeg] is null when [error] is set. */
interface PdfRenderCallback {
    fun onResult(jpeg: ByteArray?, error: String?)
}
