import Flutter

/// Lifecycle only. Dart talks to `PdfViewerApi` through the Objective-C runtime (ffigen + objective_c).
public class PdfViewerPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {}
}
