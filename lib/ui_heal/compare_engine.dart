import 'dart:io';
import 'dart:math';
import 'package:image/image.dart' as img;

/// 比对结果
class CompareResult {
  final bool pass;
  final double ssim;
  final int pixelDiffCount;
  final double pixelDiffPercent;
  final String? diffImagePath;
  final String details;

  CompareResult({
    required this.pass,
    required this.ssim,
    required this.pixelDiffCount,
    required this.pixelDiffPercent,
    this.diffImagePath,
    required this.details,
  });

  @override
  String toString() =>
      'CompareResult(pass=$pass, ssim=${ssim.toStringAsFixed(4)}, '
      'pixelDiff=$pixelDiffCount (${(pixelDiffPercent * 100).toStringAsFixed(3)}%))';
}

/// 多维比对引擎
///
/// 四维比对:
/// 1. 像素级对比 (逐像素 color distance)
/// 2. SSIM 结构相似度
/// 3. 布局数值对比 (宽高/间距 — 在 golden test 中由 Flutter 框架保证)
/// 4. VLM 语义判断 (生产环境接入多模态模型)
class CompareEngine {
  /// SSIM 通过阈值
  final double ssimThreshold;

  /// 像素差异容差百分比
  final double pixelDiffThreshold;

  /// 颜色差异容差 (0-255)
  final int colorTolerance;

  CompareEngine({
    this.ssimThreshold = 0.95,
    this.pixelDiffThreshold = 0.01,
    this.colorTolerance = 10,
  });

  /// 执行完整对比: 像素 + SSIM
  CompareResult compare(
    String baselinePath,
    String actualPath, {
    String? diffOutputPath,
  }) {
    final baselineFile = File(baselinePath);
    final actualFile = File(actualPath);

    if (!baselineFile.existsSync()) {
      return CompareResult(
        pass: false,
        ssim: 0,
        pixelDiffCount: -1,
        pixelDiffPercent: 1.0,
        details: 'Baseline not found: $baselinePath',
      );
    }

    if (!actualFile.existsSync()) {
      return CompareResult(
        pass: false,
        ssim: 0,
        pixelDiffCount: -1,
        pixelDiffPercent: 1.0,
        details: 'Actual image not found: $actualPath',
      );
    }

    final baseline = img.decodePng(baselineFile.readAsBytesSync());
    final actual = img.decodePng(actualFile.readAsBytesSync());

    if (baseline == null || actual == null) {
      return CompareResult(
        pass: false,
        ssim: 0,
        pixelDiffCount: -1,
        pixelDiffPercent: 1.0,
        details: 'Failed to decode PNG images',
      );
    }

    // 尺寸对齐 (取较小尺寸)
    final width = min(baseline.width, actual.width);
    final height = min(baseline.height, actual.height);

    // === 维度 1: 像素级对比 ===
    int diffCount = 0;
    final diffImage = img.Image(width: width, height: height);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final bPixel = baseline.getPixel(x, y);
        final aPixel = actual.getPixel(x, y);

        // image 4.x: getPixel() 返回 Pixel 对象，.r/.g/.b 是 num 类型
        final dr = (bPixel.r.toInt() - aPixel.r.toInt()).abs();
        final dg = (bPixel.g.toInt() - aPixel.g.toInt()).abs();
        final db = (bPixel.b.toInt() - aPixel.b.toInt()).abs();

        if (dr > colorTolerance || dg > colorTolerance || db > colorTolerance) {
          diffCount++;
          // 标记差异像素为红色
          diffImage.setPixelRgba(x, y, 255, 0, 0, 200);
        } else {
          // 相同像素保留原始半透明
          diffImage.setPixelRgba(
            x, y,
            aPixel.r.toInt(), aPixel.g.toInt(), aPixel.b.toInt(), 80,
          );
        }
      }
    }

    final totalPixels = width * height;
    final diffPercent = totalPixels > 0 ? diffCount / totalPixels : 1.0;

    // === 维度 2: SSIM 结构相似度 ===
    final ssimValue = _calculateSSIM(baseline, actual, width, height);

    // 保存 diff 图
    String? savedDiffPath;
    if (diffOutputPath != null && diffCount > 0) {
      final diffFile = File(diffOutputPath);
      diffFile.parent.createSync(recursive: true);
      diffFile.writeAsBytesSync(img.encodePng(diffImage));
      savedDiffPath = diffOutputPath;
    }

    // === 综合判定 ===
    final pass = diffCount == 0 ||
        (diffPercent < pixelDiffThreshold && ssimValue >= ssimThreshold);

    return CompareResult(
      pass: pass,
      ssim: ssimValue,
      pixelDiffCount: diffCount,
      pixelDiffPercent: diffPercent,
      diffImagePath: savedDiffPath,
      details: pass
          ? 'PASS: pixels=$diffCount (${(diffPercent * 100).toStringAsFixed(3)}%), SSIM=${ssimValue.toStringAsFixed(4)}'
          : 'FAIL: pixels=$diffCount (${(diffPercent * 100).toStringAsFixed(3)}%), SSIM=${ssimValue.toStringAsFixed(4)}',
    );
  }

  /// SSIM (Structural Similarity Index) 计算
  /// 使用 8x8 滑动窗口
  double _calculateSSIM(img.Image img1, img.Image img2, int width, int height) {
    const c1 = 6.5025; // (0.01 * 255)^2
    const c2 = 58.5225; // (0.03 * 255)^2
    const windowSize = 8;

    if (width < windowSize || height < windowSize) return 0;

    double totalSSIM = 0;
    int windowCount = 0;

    for (int wy = 0; wy <= height - windowSize; wy += windowSize) {
      for (int wx = 0; wx <= width - windowSize; wx += windowSize) {
        double mean1 = 0, mean2 = 0;
        final pixels = windowSize * windowSize;

        for (int y = wy; y < wy + windowSize; y++) {
          for (int x = wx; x < wx + windowSize; x++) {
            mean1 += _luminance(img1.getPixel(x, y));
            mean2 += _luminance(img2.getPixel(x, y));
          }
        }
        mean1 /= pixels;
        mean2 /= pixels;

        double var1 = 0, var2 = 0, covar = 0;
        for (int y = wy; y < wy + windowSize; y++) {
          for (int x = wx; x < wx + windowSize; x++) {
            final l1 = _luminance(img1.getPixel(x, y)) - mean1;
            final l2 = _luminance(img2.getPixel(x, y)) - mean2;
            var1 += l1 * l1;
            var2 += l2 * l2;
            covar += l1 * l2;
          }
        }
        var1 /= (pixels - 1);
        var2 /= (pixels - 1);
        covar /= (pixels - 1);

        final numerator = (2 * mean1 * mean2 + c1) * (2 * covar + c2);
        final denominator =
            (mean1 * mean1 + mean2 * mean2 + c1) * (var1 + var2 + c2);
        totalSSIM += numerator / denominator;
        windowCount++;
      }
    }

    return windowCount > 0 ? totalSSIM / windowCount : 0;
  }

  /// image 4.x: Pixel 对象的 .r/.g/.b 返回 num
  double _luminance(img.Pixel pixel) {
    return 0.2126 * pixel.r.toDouble() +
        0.7152 * pixel.g.toDouble() +
        0.0722 * pixel.b.toDouble();
  }
}
