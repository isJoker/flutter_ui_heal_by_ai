/// AI 调用连通性测试
///
/// 测试目的: 验证 heal_engine 中 AI 调用的编码修复是否生效
/// 运行: dart run scripts/test_ai_connectivity.dart
library;

import 'dart:convert';
import 'dart:io';
import 'package:flutter_demo/ui_heal/env_config.dart';

void main() async {
  print('=== AI Connectivity Test ===\n');

  // 1. 测试 .env 读取
  print('1. Loading .env config...');
  EnvConfig.reset();
  final env = EnvConfig.load();
  final endpoint = env['UI_HEAL_API_ENDPOINT'] ?? '';
  final apiKey = env['UI_HEAL_API_KEY'] ?? '';
  final model = env['UI_HEAL_MODEL'] ?? 'gpt-4o';

  if (endpoint.isEmpty || apiKey.isEmpty) {
    print('   ERROR: UI_HEAL_API_ENDPOINT or UI_HEAL_API_KEY not set in .env');
    exit(1);
  }
  print('   Endpoint: $endpoint');
  print('   Model: $model');
  print('   API Key: ${apiKey.substring(0, 8)}...');
  print('   OK\n');

  // 2. 测试简单文本请求 (验证编码修复)
  print('2. Testing simple API call (text only)...');
  final simpleResult = await _testApiCall(
    endpoint: endpoint,
    apiKey: apiKey,
    model: model,
    content: 'Reply with exactly: {"status": "ok"}',
  );
  if (simpleResult != null) {
    print('   Response: $simpleResult');
    print('   OK\n');
  } else {
    print('   FAILED\n');
  }

  // 3. 测试含 base64 图片的请求 (验证 "Invalid characters" 修复)
  print('3. Testing multimodal API call (with base64 image)...');

  // 生成一个小的测试 PNG (1x1 像素红色)
  final testPngBase64 = _createMinimalPng();
  print('   Test PNG base64 length: ${testPngBase64.length} chars');

  final multimodalResult = await _testApiCall(
    endpoint: endpoint,
    apiKey: apiKey,
    model: model,
    content: null,
    multimodalContent: [
      {'type': 'text', 'text': 'What color is this 1x1 pixel image? Reply with: {"color": "red"}'},
      {
        'type': 'image_url',
        'image_url': {
          'url': 'data:image/png;base64,$testPngBase64',
          'detail': 'low',
        },
      },
    ],
  );
  if (multimodalResult != null) {
    print('   Response: $multimodalResult');
    print('   OK\n');
  } else {
    print('   FAILED\n');
  }

  // 4. 测试大 base64 payload (模拟真实场景)
  print('4. Testing large base64 payload (simulating real golden images)...');

  // 读取一个真实的 baseline 或 actual 图片
  final testImagePaths = [
    'test/goldens/baselines/app_button_primary_default.png',
    'test/goldens/actual/app_button_primary.png',
  ];

  String? realBase64;
  for (final path in testImagePaths) {
    final file = File(path);
    if (file.existsSync()) {
      realBase64 = base64Encode(file.readAsBytesSync());
      print('   Using real image: $path (${realBase64.length} chars base64)');
      break;
    }
  }

  if (realBase64 != null) {
    // 只验证编码不报错, 不需要完整 VLM 响应
    final largePayloadResult = await _testApiCall(
      endpoint: endpoint,
      apiKey: apiKey,
      model: model,
      content: null,
      multimodalContent: [
        {'type': 'text', 'text': 'Describe this UI component briefly. Reply JSON: {"description": "..."}'},
        {
          'type': 'image_url',
          'image_url': {
            'url': 'data:image/png;base64,$realBase64',
            'detail': 'low',
          },
        },
      ],
    );
    if (largePayloadResult != null) {
      print('   Response: ${largePayloadResult.substring(0, largePayloadResult.length.clamp(0, 200))}');
      print('   OK\n');
    } else {
      print('   FAILED (but encoding issue is fixed if no "Invalid characters" error)\n');
    }
  } else {
    print('   SKIPPED: No real images found\n');
  }

  print('=== Test Complete ===');
}

/// 发送 API 请求 (使用修复后的 utf8.encode 方式)
Future<String?> _testApiCall({
  required String endpoint,
  required String apiKey,
  required String model,
  String? content,
  List<Map<String, dynamic>>? multimodalContent,
}) async {
  final messages = <Map<String, dynamic>>[
    {
      'role': 'user',
      'content': multimodalContent ?? content,
    },
  ];

  final requestBody = jsonEncode({
    'model': model,
    'messages': messages,
    'temperature': 0.1,
    'max_tokens': 100,
  });

  print('   Request body size: ${requestBody.length} bytes');

  final client = HttpClient();
    client.badCertificateCallback = (cert, host, port) => true;
  client.connectionTimeout = const Duration(seconds: 30);

  try {
    final uri = Uri.parse('$endpoint/chat/completions');
    final request = await client.postUrl(uri);
    request.headers.set('Content-Type', 'application/json');
    request.headers.set('Authorization', 'Bearer $apiKey');

    // 关键修复: 使用 utf8.encode 而不是 write()
    request.add(utf8.encode(requestBody));

    final response = await request.close().timeout(
      const Duration(seconds: 30),
    );
    final responseBody = await response.transform(utf8.decoder).join();

    if (response.statusCode == 200) {
      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      final choices = json['choices'] as List?;
      if (choices != null && choices.isNotEmpty) {
        return choices[0]['message']['content'] as String?;
      }
    } else {
      print('   HTTP ${response.statusCode}: ${responseBody.substring(0, responseBody.length.clamp(0, 200))}');
    }
    return null;
  } catch (e) {
    print('   Error: $e');
    return null;
  } finally {
    client.close();
  }
}

/// 创建最小 PNG (1x1 红色像素)
String _createMinimalPng() {
  // Minimal valid 1x1 red pixel PNG
  final bytes = <int>[
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
    0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR chunk
    0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, // 1x1
    0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53, // 8-bit RGB
    0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41, // IDAT chunk
    0x54, 0x08, 0xD7, 0x63, 0xF8, 0xCF, 0xC0, 0x00, // compressed red pixel
    0x00, 0x00, 0x04, 0x00, 0x01, 0x02, 0x8A, 0x05, //
    0x93, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, // IEND chunk
    0x44, 0xAE, 0x42, 0x60, 0x82,
  ];
  return base64Encode(bytes);
}
