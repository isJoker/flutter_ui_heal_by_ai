import 'dart:convert';
import 'dart:io';
import 'compare_engine.dart';
import 'env_config.dart';

/// AI 修复补丁
class HealPatch {
  final String filePath;
  final String original;
  final String modified;
  final String reason;

  HealPatch({
    required this.filePath,
    required this.original,
    required this.modified,
    required this.reason,
  });

  @override
  String toString() => 'HealPatch(reason=$reason, file=$filePath)';
}

/// 自愈结果
class HealResult {
  final bool success;
  final int roundsUsed;
  final CompareResult finalCompare;
  final List<HealPatch> appliedPatches;
  final String summary;

  HealResult({
    required this.success,
    required this.roundsUsed,
    required this.finalCompare,
    required this.appliedPatches,
    required this.summary,
  });
}

/// AI Provider 配置
class AIConfig {
  /// OpenAI 兼容 API 端点
  /// - OpenAI: https://api.openai.com/v1/chat/completions
  /// - 字节内部: 按实际部署地址填写
  /// - Claude: https://api.anthropic.com/v1/messages (需适配)
  final String apiEndpoint;

  /// API Key (从 .env 文件读取)
  final String apiKey;

  /// 模型名称
  /// - gpt-4o (推荐，多模态能力强)
  /// - gpt-4o-mini (更快，成本低)
  /// - claude-3.5-sonnet (需适配请求格式)
  final String model;

  /// 请求超时 (秒)
  final int timeoutSeconds;

  AIConfig({
    required this.apiEndpoint,
    required this.apiKey,
    required this.model,
    this.timeoutSeconds = 60,
  });

  /// 从项目根目录 .env 文件读取配置
  ///
  /// .env 文件格式:
  /// ```
  /// UI_HEAL_API_ENDPOINT=https://api.openai.com/v1/chat/completions
  /// UI_HEAL_API_KEY=sk-xxxxx
  /// UI_HEAL_MODEL=gpt-4o
  /// UI_HEAL_TIMEOUT=60
  /// ```
  factory AIConfig.fromEnvFile() {
    final env = EnvConfig.load();
    return AIConfig(
      apiEndpoint: env['UI_HEAL_API_ENDPOINT'] ?? '',
      apiKey: env['UI_HEAL_API_KEY'] ?? '',
      model: env['UI_HEAL_MODEL'] ?? 'gpt-4o',
      timeoutSeconds: int.tryParse(env['UI_HEAL_TIMEOUT'] ?? '60') ?? 60,
    );
  }

  bool get isConfigured => apiEndpoint.isNotEmpty && apiKey.isNotEmpty;
}

/// UI 自愈引擎
///
/// 核心流程:
/// 1. Golden Test 截图 vs Figma baseline 多维对比
/// 2. 若不通过, 将 baseline + actual + diff + 源代码 发送给 VLM
/// 3. VLM 返回修复建议 (JSON 格式的 patches)
/// 4. 应用 patch -> 重新 golden test -> 再对比
/// 5. 最多 maxRounds 轮 (默认 3)
class HealEngine {
  final CompareEngine compareEngine;
  final int maxRounds;
  final AIConfig _aiConfig;

  HealEngine({
    CompareEngine? compareEngine,
    this.maxRounds = 3,
    AIConfig? aiConfig,
  })  : compareEngine = compareEngine ?? CompareEngine(),
        _aiConfig = aiConfig ?? AIConfig.fromEnvFile();

  /// 执行自愈流程
  Future<HealResult> heal({
    required String componentName,
    required String baselinePath,
    required String actualPath,
    required String diffDir,
    required String sourceFilePath,
  }) async {
    final appliedPatches = <HealPatch>[];

    // 初始对比
    CompareResult result = compareEngine.compare(
      baselinePath,
      actualPath,
      diffOutputPath: '$diffDir/${componentName}_diff_r0.png',
    );

    if (result.pass) {
      return HealResult(
        success: true,
        roundsUsed: 0,
        finalCompare: result,
        appliedPatches: [],
        summary:
            'PASS $componentName: No healing needed (SSIM=${result.ssim.toStringAsFixed(4)})',
      );
    }

    // === 自愈循环 ===
    for (int round = 1; round <= maxRounds; round++) {
      print('  [$componentName] Heal round $round/$maxRounds');
      print('    Current: ${result.details}');

      // 1. 分析差异, 生成修复 patch
      final patch = await _analyzeAndGeneratePatch(
        componentName: componentName,
        sourceFilePath: sourceFilePath,
        baselinePath: baselinePath,
        actualPath: actualPath,
        diffPath: '$diffDir/${componentName}_diff_r${round - 1}.png',
        result: result,
        round: round,
        previousPatches: appliedPatches,
      );

      if (patch == null) {
        print('    No patch generated, stopping.');
        break;
      }

      // 2. 应用 patch
      final applied = _applyPatch(patch);
      if (!applied) {
        print('    Patch application failed, stopping.');
        break;
      }
      appliedPatches.add(patch);
      print('    Applied: ${patch.reason}');

      // 3. 重新对比
      result = compareEngine.compare(
        baselinePath,
        actualPath,
        diffOutputPath: '$diffDir/${componentName}_diff_r$round.png',
      );

      if (result.pass) {
        final summary =
            'HEALED $componentName in round $round (SSIM=${result.ssim.toStringAsFixed(4)})';
        print('    $summary');
        return HealResult(
          success: true,
          roundsUsed: round,
          finalCompare: result,
          appliedPatches: appliedPatches,
          summary: summary,
        );
      }
    }

    final summary =
        'FAILED $componentName after $maxRounds rounds (SSIM=${result.ssim.toStringAsFixed(4)})';
    print('    $summary');
    return HealResult(
      success: false,
      roundsUsed: maxRounds,
      finalCompare: result,
      appliedPatches: appliedPatches,
      summary: summary,
    );
  }

  /// 分析 diff 并生成修复 patch
  ///
  /// 策略: AI 优先，降级到规则引擎
  /// - 配置了 AI API → 多模态 VLM 分析
  /// - 未配置 / AI 调用失败
  Future<HealPatch?> _analyzeAndGeneratePatch({
    required String componentName,
    required String sourceFilePath,
    required String baselinePath,
    required String actualPath,
    required String diffPath,
    required CompareResult result,
    required int round,
    required List<HealPatch> previousPatches,
  }) async {
    final file = File(sourceFilePath);
    if (!file.existsSync()) return null;

    final source = file.readAsStringSync();

    // === AI 路径 ===
    if (_aiConfig.isConfigured) {
      try {
        final aiPatch = await _callVLM(
          componentName: componentName,
          source: source,
          sourceFilePath: sourceFilePath,
          baselinePath: baselinePath,
          actualPath: actualPath,
          diffPath: diffPath,
          result: result,
          round: round,
          previousPatches: previousPatches,
        );
        if (aiPatch != null) return aiPatch;
        print('    AI returned no patch, falling back to rules.');
      } catch (e) {
        print('    AI call failed: $e');
        print('    Falling back to rule engine.');
      }
    } else {
      if (round == 1) {
        print('    AI not configured (set UI_HEAL_API_ENDPOINT & UI_HEAL_API_KEY)');
        print('    Using rule engine fallback.');
      }
    }

    return null;
  }

  /// 调用 VLM (Vision Language Model) 进行多模态分析
  ///
  /// 输入:
  /// - baseline 图片 (Figma 设计稿)
  /// - actual 图片 (代码渲染结果)
  /// - diff 图片 (差异可视化, 红色标记)
  /// - 源代码 (当前 Widget 代码)
  /// - 对比指标 (SSIM, pixelDiff)
  ///
  /// 输出:
  /// - JSON 格式的 HealPatch (original + modified + reason)
  Future<HealPatch?> _callVLM({
    required String componentName,
    required String source,
    required String sourceFilePath,
    required String baselinePath,
    required String actualPath,
    required String diffPath,
    required CompareResult result,
    required int round,
    required List<HealPatch> previousPatches,
  }) async {
    // 编码图片为 base64
    final baselineBase64 = _encodeImageBase64(baselinePath);
    final actualBase64 = _encodeImageBase64(actualPath);
    final diffBase64 = _encodeImageBase64(diffPath);

    if (baselineBase64 == null || actualBase64 == null) {
      return null;
    }

    // 构建 prompt
    final prompt = _buildPrompt(
      componentName: componentName,
      source: source,
      result: result,
      round: round,
      previousPatches: previousPatches,
    );

    // 构建多模态消息
    final content = <Map<String, dynamic>>[
      {'type': 'text', 'text': prompt},
      {
        'type': 'image_url',
        'image_url': {
          'url': 'data:image/png;base64,$baselineBase64',
          'detail': 'high',
        },
      },
      {
        'type': 'image_url',
        'image_url': {
          'url': 'data:image/png;base64,$actualBase64',
          'detail': 'high',
        },
      },
    ];

    // diff 图可能不存在（首轮）
    if (diffBase64 != null) {
      content.add({
        'type': 'image_url',
        'image_url': {
          'url': 'data:image/png;base64,$diffBase64',
          'detail': 'low',
        },
      });
    }

    final requestBody = jsonEncode({
      'model': _aiConfig.model,
      'messages': [
        {
          'role': 'system',
          'content': _systemPrompt,
        },
        {
          'role': 'user',
          'content': content,
        },
      ],
      'temperature': 0.1,
      'max_tokens': 2048,
      'response_format': {'type': 'json_object'},
    });

    // 发送请求
    final client = HttpClient();
    client.connectionTimeout = Duration(seconds: _aiConfig.timeoutSeconds);
    // 允许自签名证书 (企业网络代理环境)
    client.badCertificateCallback = (cert, host, port) => true;

    try {
      // 自动补全 /chat/completions 路径
      var apiUrl = _aiConfig.apiEndpoint;
      if (!apiUrl.endsWith('/chat/completions')) {
        apiUrl = apiUrl.endsWith('/') ? '${apiUrl}chat/completions' : '$apiUrl/chat/completions';
      }
      final uri = Uri.parse(apiUrl);
      final request = await client.postUrl(uri);
      request.headers.set('Content-Type', 'application/json');
      request.headers.set('Authorization', 'Bearer ${_aiConfig.apiKey}');
      request.add(utf8.encode(requestBody));

      final response = await request.close().timeout(
            Duration(seconds: _aiConfig.timeoutSeconds),
          );
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        print('    AI API error (${response.statusCode}): $responseBody');
        return null;
      }

      return _parseAIResponse(responseBody, sourceFilePath);
    } finally {
      client.close();
    }
  }

  /// 系统 prompt —— 指导 VLM 输出结构化修复建议
  static const _systemPrompt = '''You are a Flutter UI self-healing agent. Your job is to analyze visual differences between a Figma design (baseline) and Flutter code render (actual), then produce a precise code patch to fix the discrepancy.

## Input
You receive:
1. **Baseline image** — The Figma design export (ground truth)
2. **Actual image** — Current Flutter code render
3. **Diff image** (optional) — Red-marked difference pixels
4. **Source code** — The Flutter Widget source file
5. **Metrics** — SSIM score and pixel diff percentage

## Output
Return a JSON object with exactly these fields:
```json
{
  "original": "<exact string to find in source code>",
  "modified": "<replacement string>",
  "reason": "<brief explanation of what visual difference this fixes>"
}
```

## Rules
1. `original` MUST be an exact substring of the source code (case-sensitive, whitespace-sensitive)
2. `modified` MUST be valid Dart/Flutter code
3. Only fix ONE property per patch (the most impactful visual difference)
4. Focus on: colors, border-radius, padding, margin, font-size, font-weight, width, height, elevation, opacity
5. Do NOT add new imports, new widgets, or restructure the widget tree
6. Do NOT change logic, callbacks, or non-visual properties
7. If you cannot determine a fix with confidence, return: {"original": "", "modified": "", "reason": "Unable to determine fix"}
8. Prefer design token values (e.g., Color(0xFF...) over Colors.xxx)
''';

  /// 构建 user prompt
  String _buildPrompt({
    required String componentName,
    required String source,
    required CompareResult result,
    required int round,
    required List<HealPatch> previousPatches,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('## Task');
    buffer.writeln(
        'Fix the UI rendering of `$componentName` to match the Figma baseline.');
    buffer.writeln('');
    buffer.writeln('## Metrics');
    buffer.writeln('- SSIM: ${result.ssim.toStringAsFixed(4)}');
    buffer.writeln(
        '- Pixel Diff: ${result.pixelDiffCount} (${(result.pixelDiffPercent * 100).toStringAsFixed(3)}%)');
    buffer.writeln('- Round: $round');
    buffer.writeln('');
    buffer.writeln('## Images (in order)');
    buffer.writeln('1. Baseline (Figma design — this is the TARGET)');
    buffer.writeln('2. Actual (Flutter render — this needs to match baseline)');
    if (round > 1) {
      buffer.writeln('3. Diff (red pixels = differences)');
    }
    buffer.writeln('');

    if (previousPatches.isNotEmpty) {
      buffer.writeln('## Previous patches applied (do NOT repeat these):');
      for (final p in previousPatches) {
        buffer.writeln('- "${p.original}" → "${p.modified}" (${p.reason})');
      }
      buffer.writeln('');
    }

    buffer.writeln('## Source Code');
    buffer.writeln('```dart');
    buffer.writeln(source);
    buffer.writeln('```');
    buffer.writeln('');
    buffer.writeln(
        'Analyze the visual difference and return a JSON patch to fix it.');

    return buffer.toString();
  }

  /// 解析 AI 响应
  HealPatch? _parseAIResponse(String responseBody, String sourceFilePath) {
    try {
      final json = jsonDecode(responseBody) as Map<String, dynamic>;

      // OpenAI 格式
      final choices = json['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) return null;

      final message = choices[0]['message'] as Map<String, dynamic>;
      final content = message['content'] as String;

      final patchJson = jsonDecode(content) as Map<String, dynamic>;
      final original = patchJson['original'] as String? ?? '';
      final modified = patchJson['modified'] as String? ?? '';
      final reason = patchJson['reason'] as String? ?? 'AI suggested fix';

      if (original.isEmpty || modified.isEmpty || original == modified) {
        return null;
      }

      return HealPatch(
        filePath: sourceFilePath,
        original: original,
        modified: modified,
        reason: '[AI] $reason',
      );
    } catch (e) {
      print('    Failed to parse AI response: $e');
      return null;
    }
  }

  /// 图片转 base64
  String? _encodeImageBase64(String path) {
    final file = File(path);
    if (!file.existsSync()) return null;
    return base64Encode(file.readAsBytesSync());
  }

  /// 应用代码修复
  bool _applyPatch(HealPatch patch) {
    try {
      final file = File(patch.filePath);
      if (!file.existsSync()) return false;

      var content = file.readAsStringSync();
      if (!content.contains(patch.original)) {
        print('    Pattern not found: "${patch.original}"');
        return false;
      }

      content = content.replaceFirst(patch.original, patch.modified);
      file.writeAsStringSync(content);
      return true;
    } catch (e) {
      print('    Patch error: $e');
      return false;
    }
  }
}
