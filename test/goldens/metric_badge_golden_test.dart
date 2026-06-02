import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_demo/components/metric_badge.dart';
import 'package:flutter_demo/ui_heal/compare_engine.dart';
import 'package:flutter_test/flutter_test.dart';

/// MetricBadge Golden Test — Figma 还原度验证
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

  group('MetricBadge Figma Fidelity Tests', () {
    testWidgets('Pass badge matches Figma', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: MetricBadge(
                label: 'SSIM',
                value: '0.98',
                status: MetricStatus.pass,
              ),
            ),
          ),
        ),
      );

      await expectLater(
        find.byType(MetricBadge),
        matchesGoldenFile('test/goldens/actual/metric_badge_pass.png'),
      );

      final baseline = '$baselinesDir/metric_badge_pass.png';
      final actual = '$actualDir/metric_badge_pass.png';

      if (!File(baseline).existsSync()) {
        fail(
          'Figma baseline not found: $baseline\n'
          'Please export from Figma and place in test/goldens/baselines/',
        );
      }

      final result = engine.compare(
        baseline,
        actual,
        diffOutputPath: '$diffDir/metric_badge_pass_diff.png',
      );

      expect(result.pass, isTrue,
          reason: 'Figma fidelity check failed: ${result.details}');
    });

    testWidgets('Fail badge matches Figma', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: MetricBadge(
                label: 'Pixel Diff',
                value: '12.5%',
                status: MetricStatus.fail,
              ),
            ),
          ),
        ),
      );

      await expectLater(
        find.byType(MetricBadge),
        matchesGoldenFile('test/goldens/actual/metric_badge_fail.png'),
      );

      final baseline = '$baselinesDir/metric_badge_fail.png';
      final actual = '$actualDir/metric_badge_fail.png';

      if (!File(baseline).existsSync()) {
        fail(
          'Figma baseline not found: $baseline\n'
          'Please export from Figma and place in test/goldens/baselines/',
        );
      }

      final result = engine.compare(
        baseline,
        actual,
        diffOutputPath: '$diffDir/metric_badge_fail_diff.png',
      );

      expect(result.pass, isTrue,
          reason: 'Figma fidelity check failed: ${result.details}');
    });

    testWidgets('Warning badge matches Figma', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: MetricBadge(
                label: 'Layout',
                value: '0.91',
                status: MetricStatus.warning,
              ),
            ),
          ),
        ),
      );

      await expectLater(
        find.byType(MetricBadge),
        matchesGoldenFile('test/goldens/actual/metric_badge_warning.png'),
      );

      final baseline = '$baselinesDir/metric_badge_warning.png';
      final actual = '$actualDir/metric_badge_warning.png';

      if (!File(baseline).existsSync()) {
        fail(
          'Figma baseline not found: $baseline\n'
          'Please export from Figma and place in test/goldens/baselines/',
        );
      }

      final result = engine.compare(
        baseline,
        actual,
        diffOutputPath: '$diffDir/metric_badge_warning_diff.png',
      );

      expect(result.pass, isTrue,
          reason: 'Figma fidelity check failed: ${result.details}');
    });
  });
}
