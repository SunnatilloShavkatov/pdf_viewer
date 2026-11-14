# AGENTS.md

Guidance for AI coding agents working in this repository. `CLAUDE.md` imports this file.

## Project

`pdf_viewer` is a Flutter **plugin** (v0.1.0) that renders PDFs natively and adds text selection, copy, highlights, and optional caching.

- Android: `PdfRenderer` for pages, PDFBox (`com.tom-roush:pdfbox-android`) for text, bridged with **JNI** (`package:jni`). Package `uz.plugin.pdf_viewer`, minSdk 24.
- iOS: PDFKit, bridged with **FFI** (`package:objective_c`). Min iOS 15.0.
- Cache: `hive_ce` via `HivePdfCache`; `NoPdfCache` is the default.

Public API is exported from `lib/pdf_viewer.dart`. Everything under `lib/src/` is internal.

## Layout

| Path                                                   | Contents                                                                              |
|--------------------------------------------------------|---------------------------------------------------------------------------------------|
| `lib/pdf_viewer.dart`                                  | Public exports only. Add new public types here.                                       |
| `lib/src/pdf_document.dart`                            | `PdfDocument`: open (file/bytes/asset/URL), render, text layers, highlights.          |
| `lib/src/pdf_view_controller.dart`                     | `PdfViewController` and `PdfSelection`: selection, copy, highlight.                   |
| `lib/src/widgets/`                                     | `PdfView` (toolbar, selection), `PdfPageView` (single page), overlay painter.         |
| `lib/src/native/`                                      | `PdfNative` interface and `AndroidPdfNative` / `DarwinPdfNative` implementations.     |
| `lib/src/bindings/`                                    | **Generated** JNI and FFI bindings. Do not hand-edit.                                 |
| `lib/src/cache/`                                       | `PdfCache` interface, `NoPdfCache`, `HivePdfCache`.                                   |
| `lib/src/text/`, `lib/src/highlight/`, `lib/src/util/` | Text layer model, highlight model, LRU cache.                                         |
| `android/src/main/kotlin/uz/plugin/pdf_viewer/`        | Kotlin side: `PdfViewerApi` facade, plugin, document host, text extractor, callbacks. |
| `ios/pdf_viewer/Sources/`                              | Swift plugin and API; `pdf_viewer_c/` holds the C header and Objective-C wrapper.     |
| `tool/`                                                | Binding generators: `ffigen.dart` (iOS), `jnigen.dart` (Android).                     |
| `example/`                                             | Demo app; `example/assets/sample.pdf`.                                                |
| `test/`                                                | Unit tests for the text layer and selection controller.                               |

## Commands

```bash
flutter pub get
flutter test
dart analyze
dart format --line-length 120 lib test   # analysis_options sets page_width 120
cd example && flutter run                # manual check on a device or simulator
```

Binding regeneration (only when the native API changes):

```bash
dart run tool/ffigen.dart                # iOS: from pdf_viewer_api.h
cd example/android && ./gradlew :pdf_viewer:compileDebugKotlin && cd ../..
dart run tool/jnigen.dart                # Android: from compiled Kotlin
```

## Rules for changes

1. **Native API first.** If a feature needs new native behavior, change the Kotlin and Swift/ObjC sources, regenerate bindings, then update `PdfNative` and both implementations together. Never let the Android and iOS implementations drift apart in behavior.
2. **Generated files.** Never edit `*.g.dart` or the generated `pdf_viewer_darwin.m`. Change the source header or the generator and regenerate.
3. **Keep the public surface small.** Anything not exported from `lib/pdf_viewer.dart` is private. Do not export `src/` internals without a reason.
4. **Keep the cache contract.** `PdfCache` implementations must work with `NoPdfCache` semantics: a cache miss returns `null` or an empty list, and a write never throws into the viewer. Cache keys must change when the document content changes.
5. **Dispose resources.** `PdfDocument` must be disposed by its owner; the native document is closed in `dispose()`. Do not add paths that leak native handles.
6. **Errors.** Throw `PdfException` for user-facing failures. Do not swallow native errors silently.
7. **Dart style.** Null safety, explicit types on public APIs, `final` by default, and the lints from `analysis_lints`. Follow the existing style: primary-constructor-like declarations are used in several files; match the file you are editing.
8. **Tests.** Add or update tests in `test/` for any change to selection, text layers, highlights, or the cache. Pure Dart logic should be testable without a device.
9. **Don't bump versions or the changelog** unless the task is a release. `CHANGELOG.md` currently has a placeholder entry; if you add a real entry, keep it short.
10. **Do not publish `CLAUDE.md`/`AGENTS.md`.** They are listed in `.pubignore`; keep it that way.

## Before you finish

- `flutter test` and `dart analyze` pass.
- Changes touching native code: state which platform you could **not** build or run (for example, iOS on a Linux host), so the user can verify it.
- If bindings were regenerated, say so and list the files changed.
