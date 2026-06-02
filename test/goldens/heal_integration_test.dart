import 'dart:io';
import 'package:flutter_demo/ui_heal/compare_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// UI 自愈集成测试
///
/// 此测试验证 CompareEngine 的多维比对逻辑:
/// 1. 完全一致的图片 -> pass
/// 2. 有微小差异但在容差内 -> pass
/// 3. 超出容差 -> fail (触发自愈)
///
/// 运行: flutter test test/goldens/heal_integration_test.dart
void main() {
  late CompareEngine engine;
  late String testDir;

  setUp(() {
    engine = CompareEngine(
      ssimThreshold: 0.95,
      pixelDiffThreshold: 0.001,
      colorTolerance: 10,
    );
    testDir = Directory.systemTemp.createTempSync('heal_test_').path;
  });

  tearDown(() {
    final dir = Directory(testDir);
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  });

  group('CompareEngine', () {
    test('identical images should pass', () {
      final imgPath = _createTestPng(testDir, 'identical', 100, 100, 0x2196F3);
      final result = engine.compare(imgPath, imgPath);

      expect(result.pass, isTrue);
      expect(result.pixelDiffCount, equals(0));
      expect(result.ssim, greaterThan(0.99));
      print('Test 1 - Identical: ${result.details}');
    });

    test('slightly different images within tolerance should pass', () {
      final baseline = _createTestPng(testDir, 'base', 100, 100, 0x2196F3);
      final actual = _createTestPng(testDir, 'actual', 100, 100, 0x2196F8);

      final result = engine.compare(baseline, actual);

      expect(result.pass, isTrue);
      print('Test 2 - Within tolerance: ${result.details}');
    });

    test('significantly different images should fail', () {
      final baseline = _createTestPng(testDir, 'base2', 100, 100, 0x2196F3);
      final actual = _createTestPng(testDir, 'actual2', 100, 100, 0xFF0000);

      final result = engine.compare(
        baseline,
        actual,
        diffOutputPath: '$testDir/diff.png',
      );

      expect(result.pass, isFalse);
      expect(result.pixelDiffCount, greaterThan(0));
      expect(result.ssim, lessThan(0.95));
      print('Test 3 - Different: ${result.details}');

      if (result.diffImagePath != null) {
        expect(File(result.diffImagePath!).existsSync(), isTrue);
        print('  Diff image saved: ${result.diffImagePath}');
      }
    });

    test('missing baseline should fail gracefully', () {
      final result = engine.compare(
        '$testDir/nonexistent.png',
        '$testDir/also_nonexistent.png',
      );

      expect(result.pass, isFalse);
      expect(result.details, contains('not found'));
      print('Test 4 - Missing file: ${result.details}');
    });
  });
}

/// 使用 image 4.x API 生成纯色 PNG 测试图片
String _createTestPng(String dir, String name, int w, int h, int color) {
  final path = '$dir/$name.png';
  final r = (color >> 16) & 0xFF;
  final g = (color >> 8) & 0xFF;
  final b = color & 0xFF;

  // image 4.x: Image(width:, height:) 命名参数
  final image = img.Image(width: w, height: h);
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      image.setPixelRgba(x, y, r, g, b, 255);
    }
  }

  File(path).writeAsBytesSync(img.encodePng(image));
  return path;
}
