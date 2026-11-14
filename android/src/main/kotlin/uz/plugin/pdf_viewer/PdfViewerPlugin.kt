package uz.plugin.pdf_viewer

import android.content.Context
import com.tom_roush.pdfbox.android.PDFBoxResourceLoader
import io.flutter.embedding.engine.plugins.FlutterPlugin

/**
 * Lifecycle only. Dart talks to [PdfViewerApi] through JNI (jnigen); there is no method channel.
 */
class PdfViewerPlugin : FlutterPlugin {
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        PdfDocumentHost.attach(binding.applicationContext)
        PDFBoxResourceLoader.init(binding.applicationContext)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        PdfDocumentHost.detach()
    }
}
