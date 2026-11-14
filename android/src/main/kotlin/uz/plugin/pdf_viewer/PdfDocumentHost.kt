package uz.plugin.pdf_viewer

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.os.ParcelFileDescriptor
import com.tom_roush.pdfbox.pdmodel.PDDocument
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicInteger
import kotlin.math.roundToInt

/**
 * Owns open documents. Every page operation runs on [worker], because [PdfRenderer] allows only
 * one open page at a time and PDFBox is not thread safe.
 */
internal object PdfDocumentHost {
    /** Returned by the open calls for a password-protected file. Dart maps it to a PdfException. */
    const val PASSWORD_REQUIRED = -2

    private class Doc(
        val file: File,
        val ownsFile: Boolean,
        val renderer: PdfRenderer,
        val descriptor: ParcelFileDescriptor,
        val widths: DoubleArray,
        val heights: DoubleArray,
    ) {
        var pdfBox: PDDocument? = null
    }

    private val documents = ConcurrentHashMap<Int, Doc>()
    private val nextId = AtomicInteger(1)
    private var appContext: Context? = null
    private var worker: ExecutorService = Executors.newSingleThreadExecutor()

    fun attach(context: Context) {
        appContext = context.applicationContext
        if (worker.isShutdown) worker = Executors.newSingleThreadExecutor()
    }

    fun detach() {
        documents.keys.toList().forEach { close(it) }
        worker.shutdown()
        appContext = null
    }

    fun openFile(path: String): Int = open(File(path), ownsFile = false)

    fun openBytes(data: ByteArray): Int {
        val context = appContext ?: return -1
        val temp = File.createTempFile("pdf_viewer_", ".pdf", context.cacheDir)
        temp.writeBytes(data)
        val id = open(temp, ownsFile = true)
        if (id < 0) temp.delete()
        return id
    }

    /** Returns the document id, [PASSWORD_REQUIRED] for an encrypted file, or -1 for anything else unreadable. */
    private fun open(file: File, ownsFile: Boolean): Int {
        var descriptor: ParcelFileDescriptor? = null
        var renderer: PdfRenderer? = null
        val failure: Int = try {
            val fd = ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY).also { descriptor = it }
            val pdfRenderer = PdfRenderer(fd).also { renderer = it }
            val id = nextId.getAndIncrement()
            // Page sizes are read lazily; only the count is needed up front.
            val count = pdfRenderer.pageCount
            documents[id] = Doc(file, ownsFile, pdfRenderer, fd, DoubleArray(count) { Double.NaN }, DoubleArray(count) { Double.NaN })
            return id
        } catch (e: SecurityException) {
            PASSWORD_REQUIRED
        } catch (e: Exception) {
            -1
        }
        // Release whatever was opened before the failure, so a bad file leaks no descriptor.
        renderer?.close()
        descriptor?.close()
        if (ownsFile) file.delete()
        return failure
    }

    fun pageCount(docId: Int): Int = documents[docId]?.widths?.size ?: 0

    fun pageWidth(docId: Int, page: Int): Double = pageSize(docId, page)?.first ?: 0.0

    fun pageHeight(docId: Int, page: Int): Double = pageSize(docId, page)?.second ?: 0.0

    /** Reads the size of [page] from the document on first use. Shares [renderer] with rendering, so it locks the same way. */
    private fun pageSize(docId: Int, page: Int): Pair<Double, Double>? {
        val doc = documents[docId] ?: return null
        if (page !in doc.widths.indices) return null
        if (doc.widths[page].isNaN()) {
            synchronized(doc) {
                if (doc.widths[page].isNaN()) {
                    doc.renderer.openPage(page).use { pdfPage ->
                        doc.widths[page] = pdfPage.width.toDouble()
                        doc.heights[page] = pdfPage.height.toDouble()
                    }
                }
            }
        }
        return doc.widths[page] to doc.heights[page]
    }

    fun render(docId: Int, page: Int, width: Int, callback: PdfRenderCallback) {
        worker.execute {
            try {
                val doc = documents[docId] ?: throw IllegalStateException("document $docId is closed")
                callback.onResult(renderJpeg(doc, page, width), null)
            } catch (e: Exception) {
                callback.onResult(null, e.message ?: e.javaClass.simpleName)
            }
        }
    }

    private fun renderJpeg(doc: Doc, page: Int, width: Int): ByteArray {
        synchronized(doc) {
            doc.renderer.openPage(page).use { pdfPage ->
                val height = (width * pdfPage.height / pdfPage.width.toDouble()).roundToInt().coerceAtLeast(1)
                val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                try {
                    bitmap.eraseColor(Color.WHITE)
                    pdfPage.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                    val out = ByteArrayOutputStream()
                    bitmap.compress(Bitmap.CompressFormat.JPEG, 85, out)
                    return out.toByteArray()
                } finally {
                    bitmap.recycle()
                }
            }
        }
    }

    fun textLayer(docId: Int, page: Int, callback: PdfTextCallback) {
        worker.execute {
            try {
                val doc = documents[docId] ?: throw IllegalStateException("document $docId is closed")
                val pdfBox = doc.pdfBox ?: PDDocument.load(doc.file).also { doc.pdfBox = it }
                callback.onResult(PdfTextExtractor.extract(pdfBox, page), null)
            } catch (e: Exception) {
                callback.onResult(null, e.message ?: e.javaClass.simpleName)
            }
        }
    }

    fun close(docId: Int) {
        val doc = documents.remove(docId) ?: return
        worker.execute {
            synchronized(doc) {
                doc.pdfBox?.close()
                doc.renderer.close()
                doc.descriptor.close()
                if (doc.ownsFile) doc.file.delete()
            }
        }
    }
}
