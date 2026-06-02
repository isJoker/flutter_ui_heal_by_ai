/// Figma Baseline 导出工具 (Dart 版)
///
/// 使用 Figma REST API 导出组件的 2x PNG 基准图和布局 JSON。
///
/// 配置:
///   环境变量 FIGMA_TOKEN, FIGMA_FILE_KEY
///
/// 运行:
///   dart run scripts/export_figma_baselines_dart.dart
///
/// 生产环境实现 (需要 http package):
/// ```dart
/// final response = await http.get(
///   Uri.parse('https://api.figma.com/v1/files/$fileKey'),
///   headers: { 'X-Figma-Token': token},
/// );
/// ```
library;

import 'dart:io';
import 'dart:convert';

void main() async {
  final token = Platform.environment['FIGMA_TOKEN'];
  final fileKey = Platform.environment['FIGMA_FILE_KEY'];

  if (token == null || fileKey == null) {
    print('=== Figma Baseline Export ===');
    print('');
    print('ERROR: Missing environment variables.');
    print('  Set FIGMA_TOKEN and FIGMA_FILE_KEY');
    print('');
    print('Example:');
    print('  export FIGMA_TOKEN="figd_xxx"');
    print('  export FIGMA_FILE_KEY="abc123"');
    print('  dart run scripts/export_figma_baselines_dart.dart');
    print('');
    print('--- Generating placeholder baselines instead ---');
    _generatePlaceholders();
    return;
  }

  print('=== Figma Baseline Export ===');
  print('File key: $fileKey');
  print('');

  // TODO: 接入 Figma REST API
  // 1. GET /v1/files/{fileKey} → 获取又组件列表
  // 2. GET /v1/images/{fileKey}?ids=...&scale=2&format=png → 导出 PNG
  // 3. GET /v1/files/{fileKey}/nodes?ids=... → 获取布局约束

  print('Figma API integration not yet implemented.');
  print('Using placeholder baselines for demo.');
  _generatePlaceholders();
}

/// 生成占位 baseline 配置文件
void _generatePlaceholders() {
  final projectDir = Directory.current.path;
  final baselinesDir = '$projectDir/test/goldens/baselines';
  final layoutDir = '$projectDir/test/goldens/figma_layout';

  Directory(baselinesDir).createSync(recursive: true);
  Directory(layoutDir).createSync(recursive: true);

  // 生成 layout.json 示例 (模拟 Figma 导出的约束信息)
  final layouts = {
    'app_button_primary': {
      'name': 'Button/Primary',
      'width': 200,
      'height': 48,
      'borderRadius': 8,
      'padding': {'horizontal': 24, 'vertical': 12},
      'backgroundColor': '#2196F3',
      'textColor': '#FFFFFF',
      'fontSize': 16,
      'fontWeight': 600,
    },
    'user_card': {
      'name': 'Card/UserCard',
      'width': 320,
      'height': null, // auto height
      'borderRadius': 12,
      'padding': {'ell': 16},
      'backgroundColor': '#FFFFFF',
      'shadow': {'blur': 8, 'offsetY': 2, 'opacity': 0.05},
      'avatar': {'size': 48, 'shape': 'circle'},
      'gap': 12,
    },
    'metric_badge': {
      'name': 'Badge/Metric',
      'borderRadius': 8,
      'padding': {'horizontal': 12, 'vertical': 8},
      'variants': {
        'pass': {'backgroundColor': '#DCFCE7', 'textColor': '#166534'},
        'warning': {'backgroundColor': '#FEF3C7', 'textColor': '#92400E'},
        'fail': {'backgroundColor': '#FEE2E2', 'textColor': '#991B1B'},
      },
    },
  };

  for (final entry in layouts.entries) {
    final layoutFile = File('$layoutDir/${entry.key}.json');
    layoutFile.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(entry.value),
    );
    print('  Created: ${entry.key}.json');
  }

  print('');
  print('Layout files generated in: $layoutDir');
  print('');
  print('Next steps:');
  print('  1. Run: flutter test --update-goldens');
  print('  2. Copy golden outputs to baselines/');
  print('  3. Later: replace with actual Figma 2x PNG exports');
}
