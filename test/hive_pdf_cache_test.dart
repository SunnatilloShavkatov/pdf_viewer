import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_viewer/pdf_viewer.dart';

void main() {
  test('a failed open is not cached, so the next open can succeed', () async {
    final Directory dir = await Directory.systemTemp.createTemp('hive_pdf_cache_test');
    addTearDown(() => dir.delete(recursive: true));

    // A path under a regular file cannot hold Hive boxes, so this open fails.
    final File blocker = File('${dir.path}/not_a_directory')..writeAsStringSync('x');
    await expectLater(HivePdfCache.open(path: '${blocker.path}/cache'), throwsA(isA<Object>()));

    final HivePdfCache cache = await HivePdfCache.open(path: '${dir.path}/cache');
    await cache.writeTextLayer('doc', 0, '[]');
    expect(await cache.readTextLayer('doc', 0), '[]');
  });
}
