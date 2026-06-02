import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_demo/components/app_button.dart';
import 'package:flutter_demo/ui_heal/compare_engine.dart';
import 'package:flutter_test/flutter_test.dart';

/// AppButton Golden Test — Figma 还原度验证
///
/// 基准图来自 Figma 导出 (test/goldens/baselines/*.png)
/// 测试流程:
///   1. Flutter 渲染组件并截图保存到 actual/
///   2. 用 CompareEngine 对比 Figma 基准 vs 渲染截图
///   3. SSIM >= 阈值 且 像素差异 < 阈值 → PASS
///   4. 否则 → FAIL (触发自愈)
///
/// 基准图更新: 从 Figma 重新导出 PNG 替换 baselines/*.png
/// 不要用 --update-goldens 更新基准!
void main() {
  final engine = CompareEngine(
    ssimThreshold: 0.95,
    pixelDiffThreshold: 0.002,
    colorTolerance: 10,
  );

  final projectRoot = Directory.current.path;
  final baselinesDir = '$projectRoot/test/goldens/baselines';
  final actualDir = '$projectRoot/test/goldens/actual';
  final diffDir = '$projectRoot/test/goldens/diff';

  setUpAll(() {
    Directory(actualDir).createSync(recursive: true);
    Directory(diffDir).createSync(recursive: true);
  });

  group('AppButton Figma Fidelity Tests', () {
    testWidgets('Primary button matches Figma design', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AppButton(text: 'Primary Action', onPressed: () {}),
            ),
          ),
        ),
      );

      // 截图保存到 actual 目录
      await expectLater(
        find.byType(AppButton),
        matchesGoldenFile('test/goldens/actual/app_button_primary.png'),
      );

      // 用 CompareEngine 对比 Figma 基准
      final baseline = '$baselinesDir/app_button_primary_default.png';
      final actual = '$actualDir/app_button_primary.png';

      if (!File(baseline).existsSync()) {
        fail(
          'Figma baseline not found: $baseline\n'
          'Please export from Figma and place in test/goldens/baselines/',
        );
      }

      final result = engine.compare(
        baseline,
        actual,
        diffOutputPath: '$diffDir/app_button_primary_diff.png',
      );

      expect(result.pass, isTrue,
          reason: 'Figma fidelity check failed: ${result.details}');
    });

    testWidgets('Primary button disabled matches Figma design', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: AppButton(text: 'Disabled', onPressed: null),
            ),
          ),
        ),
      );

      await expectLater(
        find.byType(AppButton),
        matchesGoldenFile('test/goldens/actual/app_button_disabled.png'),
      );

      final baseline = '$baselinesDir/app_button_primary_disabled.png';
      final actual = '$actualDir/app_button_disabled.png';

      if (!File(baseline).existsSync()) {
        fail(
          'Figma baseline not found: $baseline\n'
          'Please export from Figma and place in test/goldens/baselines/',
        );
      }

      final result = engine.compare(
        baseline,
        actual,
        diffOutputPath: '$diffDir/app_button_disabled_diff.png',
      );

      expect(result.pass, isTrue,
          reason: 'Figma fidelity check failed: ${result.details}');
    });

    testWidgets('Secondary button matches Figma design', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AppButton(
                text: 'Secondary',
                variant: ButtonVariant.secondary,
                onPressed: () {},
              ),
            ),
          ),
        ),
      );

      await expectLater(
        find.byType(AppButton),
        matchesGoldenFile('test/goldens/actual/app_button_secondary.png'),
      );

      final baseline = '$baselinesDir/app_button_secondary_default.png';
      final actual = '$actualDir/app_button_secondary.png';

      if (!File(baseline).existsSync()) {
        fail(
          'Figma baseline not found: $baseline\n'
          'Please export from Figma and place in test/goldens/baselines/',
        );
      }

      final result = engine.compare(
        baseline,
        actual,
        diffOutputPath: '$diffDir/app_button_secondary_diff.png',
      );

      expect(result.pass, isTrue,
          reason: 'Figma fidelity check failed: ${result.details}');
    });
  });
}
