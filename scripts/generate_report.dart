/// 生成 HTML 还原度报告
///
/// 运行: dart run scripts/generate_report.dart
library;

import 'dart:io';
import 'package:flutter_demo/ui_heal/compare_engine.dart';
import 'package:flutter_demo/ui_heal/report_generator.dart';

void main() {
  final projectDir = Directory.current.path;
  final baselinesDir = '$projectDir/test/goldens/baselines';
  final actualDir = '$projectDir/test/goldens/actual';
  final diffDir = '$projectDir/test/goldens/diff';
  final reportPath = '$projectDir/test/goldens/report.html';

  final baselineDir = Directory(baselinesDir);
  if (!baselineDir.existsSync()) {
    print('No baselines directory found.');
    exit(1);
  }

  final baselines = baselineDir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.png'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  final engine = CompareEngine(
    ssimThreshold: 0.95,
    pixelDiffThreshold: 0.002,
    colorTolerance: 10,
  );
  final reports = <ComponentReport>[];

  // Mapping: baseline filename -> actual filename
  final baselinesActualMap = <String, String>{
    'app_button_primary_default': 'app_button_primary',
    'app_button_primary_disabled': 'app_button_disabled',
    'app_button_secondary_default': 'app_button_secondary',
    'user_card_standard': 'user_card_standard',
    'user_card_long_email': 'user_card_long_email',
    'metric_badge_pass': 'metric_badge_pass',
    'metric_badge_fail': 'metric_badge_fail',
    'metric_badge_warning': 'metric_badge_warning',
  };

  for (final baseline in baselines) {
    final baselineName = baseline.uri.pathSegments.last.replaceAll('.png', '');
    final actualName = baselinesActualMap[baselineName] ?? baselineName;
    final actualPath = '$actualDir/$actualName.png';

    if (!File(actualPath).existsSync()) {
      reports.add(ComponentReport(
        componentName: baselineName,
        status: 'pending',
        ssim: 0.0,
        pixelDiff: 0,
        pixelDiffPercent: 0.0,
      ));
      continue;
    }

    final result = engine.compare(
      baseline.path,
      actualPath,
      diffOutputPath: '$diffDir/${baselineName}_diff.png',
    );

    reports.add(ComponentReport(
      componentName: baselineName,
      status: result.pass ? 'pass' : 'failed',
      ssim: result.ssim,
      pixelDiff: result.pixelDiffCount,
      pixelDiffPercent: result.pixelDiffPercent,
    ));
  }

  ReportGenerator.generate(results: reports, outputPath: reportPath);
  print('Report generated: $reportPath');
  print('');
  print('Summary:');
  final passCount = reports.where((r) => r.status == 'pass').length;
  final failCount = reports.where((r) => r.status == 'failed').length;
  final pendingCount = reports.where((r) => r.status == 'pending').length;
  print('  Pass: $passCount / ${reports.length}');
  if (failCount > 0) print('  Failed: $failCount');
  if (pendingCount > 0) print('  Pending (no actual): $pendingCount');
}
