import Foundation
import PDFKit
import UIKit

/// Surface Dart sees through the Objective-C runtime. Every signature must match
/// `pdf_viewer/Sources/pdf_viewer_c/pdf_viewer_api.h` exactly (selectors and block types).
@objc(PdfViewerApi)
public final class PdfViewerApi: NSObject {
  private static let worker = DispatchQueue(label: "uz.plugin.pdf_viewer.worker")
  private static var documents: [Int32: PDFDocument] = [:]
  private static var nextId: Int32 = 1
  private static let lock = NSLock()

  /// Returns a document id, -1 when the file cannot be opened, or -2 when it is password protected.
  @objc(openFile:)
  public static func openFile(_ path: String) -> Int32 {
    guard let document = PDFDocument(url: URL(fileURLWithPath: path)) else { return -1 }
    return document.isLocked ? -2 : register(document)
  }

  /// Returns a document id, -1 when the bytes are not a readable PDF, or -2 when it is password protected.
  @objc(openBytes:)
  public static func openBytes(_ data: Data) -> Int32 {
    guard let document = PDFDocument(data: data) else { return -1 }
    return document.isLocked ? -2 : register(document)
  }

  @objc(pageCount:)
  public static func pageCount(_ docId: Int32) -> Int32 {
    Int32(document(docId)?.pageCount ?? 0)
  }

  /// Page width in PDF points as displayed (crop box, swapped when the page is rotated 90 or 270 degrees).
  @objc(pageWidth:page:)
  public static func pageWidth(_ docId: Int32, _ page: Int32) -> Double {
    guard let pdfPage = pdfPage(docId, page) else { return 0 }
    return Double(displayedSize(pdfPage).width)
  }

  /// Page height in PDF points as displayed.
  @objc(pageHeight:page:)
  public static func pageHeight(_ docId: Int32, _ page: Int32) -> Double {
    guard let pdfPage = pdfPage(docId, page) else { return 0 }
    return Double(displayedSize(pdfPage).height)
  }

  /// Renders [page] at [width] pixels wide as JPEG, asynchronously. `error` is set when `data` is nil.
  @objc(renderPage:page:width:completion:)
  public static func renderPage(
    _ docId: Int32, _ page: Int32, _ width: Int32,
    completion: @escaping (Data?, String?) -> Void
  ) {
    worker.async {
      guard let pdfPage = pdfPage(docId, page) else {
        completion(nil, "page \(page) of document \(docId) is unavailable")
        return
      }
      let shown = displayedSize(pdfPage)
      let scale = CGFloat(width) / shown.width
      let size = CGSize(width: CGFloat(width), height: (shown.height * scale).rounded())
      let image = pdfPage.thumbnail(of: size, for: .cropBox)
      guard let jpeg = image.jpegData(compressionQuality: 0.85) else {
        completion(nil, "JPEG encoding failed")
        return
      }
      completion(jpeg, nil)
    }
  }

  /// Extracts per-character boxes for [page], asynchronously. `json` is `[[char,x0,y0,x1,y1], ...]`,
  /// normalized 0..1 with a top-left origin.
  @objc(textLayer:page:completion:)
  public static func textLayer(
    _ docId: Int32, _ page: Int32,
    completion: @escaping (String?, String?) -> Void
  ) {
    worker.async {
      guard let pdfPage = pdfPage(docId, page) else {
        completion(nil, "page \(page) of document \(docId) is unavailable")
        return
      }
      let crop = pdfPage.bounds(for: .cropBox)
      let rotation = normalizedRotation(pdfPage)
      let text = (pdfPage.string ?? "") as NSString
      var glyphs: [[Any]] = []
      glyphs.reserveCapacity(text.length)
      var index = 0
      while index < text.length {
        // A surrogate pair (emoji, rare CJK) is one character: keep it whole and leave an empty glyph for its trail.
        let isPair = index + 1 < text.length && isSurrogatePair(text, at: index)
        let length = isPair ? 2 : 1
        let char = text.substring(with: NSRange(location: index, length: length))
        glyphs.append(glyph(char, box: pdfPage.characterBounds(at: index), crop: crop, rotation: rotation))
        if isPair {
          glyphs.append(["", 0, 0, 0, 0])
        }
        index += length
      }
      guard let data = try? JSONSerialization.data(withJSONObject: glyphs),
        let json = String(data: data, encoding: .utf8)
      else {
        completion(nil, "JSON encoding failed")
        return
      }
      completion(json, nil)
    }
  }

  @objc(close:)
  public static func close(_ docId: Int32) {
    lock.lock()
    documents.removeValue(forKey: docId)
    lock.unlock()
  }

  private static func register(_ document: PDFDocument) -> Int32 {
    lock.lock()
    defer { lock.unlock() }
    let id = nextId
    nextId += 1
    documents[id] = document
    return id
  }

  private static func document(_ docId: Int32) -> PDFDocument? {
    lock.lock()
    defer { lock.unlock() }
    return documents[docId]
  }

  private static func pdfPage(_ docId: Int32, _ page: Int32) -> PDFPage? {
    guard let document = document(docId), page >= 0, Int(page) < document.pageCount else { return nil }
    return document.page(at: Int(page))
  }

  private static func clamp(_ value: CGFloat) -> Double {
    Double(min(max(value, 0), 1))
  }

  /// Page size as the user sees it. PDF /Rotate turns the page clockwise, so 90 and 270 swap the sides.
  private static func displayedSize(_ pdfPage: PDFPage) -> CGSize {
    let crop = pdfPage.bounds(for: .cropBox)
    return normalizedRotation(pdfPage) % 180 == 0 ? crop.size : CGSize(width: crop.height, height: crop.width)
  }

  private static func normalizedRotation(_ pdfPage: PDFPage) -> Int {
    ((pdfPage.rotation % 360) + 360) % 360
  }

  private static func isSurrogatePair(_ text: NSString, at index: Int) -> Bool {
    UTF16.isLeadSurrogate(text.character(at: index)) && UTF16.isTrailSurrogate(text.character(at: index + 1))
  }

  /// One glyph entry `[char, x0, y0, x1, y1]`. The box is normalized to the displayed page, top-left origin.
  private static func glyph(_ char: String, box: CGRect, crop: CGRect, rotation: Int) -> [Any] {
    guard !box.isNull, box.width > 0 || box.height > 0 else {
      return [char, 0, 0, 0, 0]
    }
    let left = Double(clamp((box.minX - crop.minX) / crop.width))
    let right = Double(clamp((box.maxX - crop.minX) / crop.width))
    let top = Double(clamp((crop.maxY - box.maxY) / crop.height))
    let bottom = Double(clamp((crop.maxY - box.minY) / crop.height))
    let a = rotated(left, top, rotation: rotation)
    let b = rotated(right, bottom, rotation: rotation)
    return [char, min(a.x, b.x), min(a.y, b.y), max(a.x, b.x), max(a.y, b.y)]
  }

  /// Maps a normalized point of the unrotated page into the displayed page (PDF /Rotate is clockwise).
  private static func rotated(_ x: Double, _ y: Double, rotation: Int) -> (x: Double, y: Double) {
    switch rotation {
    case 90: return (1 - y, x)
    case 180: return (1 - x, 1 - y)
    case 270: return (y, 1 - x)
    default: return (x, y)
    }
  }
}
