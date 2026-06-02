/// Flutter Golden Test 全局配置
///
/// 两层对比架构:
/// 1. matchesGoldenFile → 保存代码渲染截图到 actual/ (用于截图采集)
/// 2. CompareEngine → Figma baseline vs actual 多维对比 (真正的还原度判定)
///
/// baselines/ 目录: Figma 导出的设计稿截图 (不可用 --update-goldens 覆盖)
/// actual/ 目录: 代码渲染截图 (每次测试自动更新)
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  goldenFileComparator = ActualSnapshotComparator();
  await testMain();
}

/// Actual Snapshot Comparator
///
/// - 对 actual/ 路径下的 golden: 总是更新截图 (用于后续 CompareEngine 对比)
/// - 对 baselines/ 路径: 禁止覆盖
class ActualSnapshotComparator extends GoldenFileComparator {
  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final goldenFile = _getFile(golden);

    // actual/ 目录的截图: 总是写入最新渲染结果, 然后视为通过
    // (真正的还原度对比在测试代码中由 CompareEngine 执行)
    if (golden.path.contains('actual/')) {
      goldenFile.parent.createSync(recursive: true);
      goldenFile.writeAsBytesSync(imageBytes);
      return true;
    }

    // baselines/ 目录: 严格对比
    if (!goldenFile.existsSync()) {
      throw TestFailure(
        'Golden baseline not found: ${goldenFile.path}\n'
        'Place Figma-exported PNG in test/goldens/baselines/',
      );
    }

    final goldenBytes = goldenFile.readAsBytesSync();
    final ComparisonResult result = await GoldenFileComparator.compareLists(
      imageBytes,
      goldenBytes,
    );

    if (!result.passed) {
      throw TestFailure(
        'Pixel mismatch: ${(result.diffPercent * 100).toStringAsFixed(4)}%\n'
        'Golden: ${goldenFile.path}',
      );
    }
    return true;
  }

  @override
  Future<void> update(Uri golden, Uint8List imageBytes) async {
    final goldenFile = _getFile(golden);

    // 禁止 --update-goldens 覆盖 Figma baselines
    if (golden.path.contains('baselines/')) {
      debugPrint(
        'SKIPPED: Cannot overwrite Figma baseline with --update-goldens.\n'
        '  File: ${goldenFile.path}\n'
        '  Baselines must come from Figma export.',
      );
      return;
    }

    goldenFile.parent.createSync(recursive: true);
    goldenFile.writeAsBytesSync(imageBytes);
    debugPrint('Actual snapshot saved: ${goldenFile.path}');
  }

  @override
  Uri getTestUri(Uri key, int? version) => key;

  File _getFile(Uri golden) {
    return File('${Directory.current.path}/${golden.toFilePath()}');
  }
}
