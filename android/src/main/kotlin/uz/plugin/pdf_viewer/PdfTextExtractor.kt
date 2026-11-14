package uz.plugin.pdf_viewer

import com.tom_roush.pdfbox.pdmodel.PDDocument
import com.tom_roush.pdfbox.text.PDFTextStripper
import com.tom_roush.pdfbox.text.TextPosition
import org.json.JSONArray
import org.json.JSONObject

/**
 * Per-glyph boxes via PDFBox-Android. Coordinates are normalized to the page crop box with a
 * top-left origin, so Dart can map them onto the rendered JPEG directly.
 */
internal object PdfTextExtractor {
    fun extract(document: PDDocument, pageIndex: Int): String {
        val page = document.getPage(pageIndex)
        val media = page.mediaBox
        val crop = page.cropBox
        val cropLeft = crop.lowerLeftX - media.lowerLeftX
        val cropTop = media.upperRightY - crop.upperRightY
        val cropWidth = crop.width.toDouble()
        val cropHeight = crop.height.toDouble()

        val glyphs = JSONArray()
        val stripper = object : PDFTextStripper() {
            override fun writeString(text: String?, textPositions: MutableList<TextPosition>?) {
                textPositions?.forEach { tp ->
                    val x0 = (tp.xDirAdj - cropLeft) / cropWidth
                    val y0 = (tp.yDirAdj - cropTop) / cropHeight
                    val x1 = x0 + tp.widthDirAdj / cropWidth
                    val y1 = y0 + tp.heightDir / cropHeight
                    glyphs.put(
                        JSONArray()
                            .put(tp.unicode)
                            .put(x0.coerceIn(0.0, 1.0))
                            .put(y0.coerceIn(0.0, 1.0))
                            .put(x1.coerceIn(0.0, 1.0))
                            .put(y1.coerceIn(0.0, 1.0)),
                    )
                }
            }
        }
        stripper.startPage = pageIndex + 1
        stripper.endPage = pageIndex + 1
        stripper.getText(document)
        return glyphs.toString()
    }
}
