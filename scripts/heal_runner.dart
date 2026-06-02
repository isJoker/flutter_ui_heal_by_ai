/// Flutter Golden Test UI 自愈运行器
///
/// 此脚本由 CI 调用, 分析 golden test 失败的 diff
/// 并尝试自动修复源代码。
///
/// 运行: dart run scripts/heal_runner.dart --round 1
library;

import 'dart:io';

import 'package:flutter_demo/ui_heal/compare_engine.dart';
import 'package:flutter_demo/ui_heal/heal_engine.dart';

void main(List<String> args) async {
  final round = _parseRound(args);
  print('=== Heal Runner (round $round) ===');

  final projectDir = Directory.current.path;
  final baselinesDir = '$projectDir/test/goldens/baselines';
  final actualDir = '$projectDir/test/goldens/actual';
  final diffDir = '$projectDir/test/goldens/diff';

  // 查找所有 baseline 文件
  final baselineDir = Directory(baselinesDir);
  if (!baselineDir.existsSync()) {
    print('No baselines directory found.');
    exit(1);
  }

  final baselines = baselineDir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.png'))
      .toList();

  if (baselines.isEmpty) {
    print('No baseline PNG files found.');
    exit(1);
  }

  print('Found ${baselines.length} baselines to check.');

  final engine = HealEngine(
    compareEngine: CompareEngine(
      ssimThreshold: 0.95,
      pixelDiffThreshold: 0.002,
      colorTolerance: 10,
    ),
    maxRounds: 1, // 每次调用只执行 1 轮 (外部循环控制总轮数)
  );

  // baseline 文件名 -> actual 文件名 & 源文件映射
  final mappings = {
    'app_button_primary_default': {
      'actual': 'app_button_primary',
      'source': '$projectDir/lib/components/app_button.dart',
    },
    'app_button_primary_disabled': {
      'actual': 'app_button_disabled',
      'source': '$projectDir/lib/components/app_button.dart',
    },
    'app_button_secondary_default': {
      'actual': 'app_button_secondary',
      'source': '$projectDir/lib/components/app_button.dart',
    },
    'user_card_standard': {
      'actual': 'user_card_standard',
      'source': '$projectDir/lib/components/user_card.dart',
    },
    'user_card_long_email': {
      'actual': 'user_card_long_email',
      'source': '$projectDir/lib/components/user_card.dart',
    },
    'metric_badge_pass': {
      'actual': 'metric_badge_pass',
      'source': '$projectDir/lib/components/metric_badge.dart',
    },
    'metric_badge_fail': {
      'actual': 'metric_badge_fail',
      'source': '$projectDir/lib/components/metric_badge.dart',
    },
    'metric_badge_warning': {
      'actual': 'metric_badge_warning',
      'source': '$projectDir/lib/components/metric_badge.dart',
    },
  };

  int healed = 0;
  int failed = 0;
  int skipped = 0;

  for (final baseline in baselines) {
    final baselineName =
        baseline.uri.pathSegments.last.replaceAll('.png', '');
    final mapping = mappings[baselineName];

    if (mapping == null) {
      print('  No mapping for: $baselineName, skipping.');
      skipped++;
      continue;
    }

    final actualPath = '$actualDir/${mapping["actual"]}.png';
    final sourcePath = mapping['source']!;

    // 检查是否有 actual 截图
    if (!File(actualPath).existsSync()) {
      skipped++;
      continue;
    }

    // 先检查是否真的有问题
    final checkEngine = CompareEngine(
      ssimThreshold: 0.95,
      pixelDiffThreshold: 0.002,
      colorTolerance: 10,
    );
    final checkResult = checkEngine.compare(baseline.path, actualPath);
    if (checkResult.pass) {
      // 这个组件没问题，跳过
      continue;
    }

    print('  Healing: $baselineName (${checkResult.details})');

    final result = await engine.heal(
      componentName: baselineName,
      baselinePath: baseline.path,
      actualPath: actualPath,
      diffDir: diffDir,
      sourceFilePath: sourcePath,
    );

    if (result.success) {
      healed++;
    } else {
      failed++;
    }
  }

  print('');
  print('=== Round $round Summary ===');
  print('  Healed: $healed');
  print('  Failed: $failed');
  print('  Skipped: $skipped');

  exit(failed > 0 ? 1 : 0);
}

int _parseRound(List<String> args) {
  for (int i = 0; i < args.length - 1; i++) {
    if (args[i] == '--round') {
      return int.tryParse(args[i + 1]) ?? 1;
    }
  }
  return 1;
}
