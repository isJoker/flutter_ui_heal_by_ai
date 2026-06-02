import 'dart:io';

/// .env 文件解析器
///
/// 从项目根目录的 .env 文件读取配置，支持:
/// - KEY=VALUE
/// - KEY="VALUE" (带引号)
/// - KEY='VALUE' (带单引号)
/// - # 注释行
/// - 空行忽略
class EnvConfig {
  static Map<String, String>? _cache;

  /// 加载 .env 文件并缓存
  static Map<String, String> load({String? path}) {
    if (_cache != null) return _cache!;

    final envPath = path ?? _findEnvFile();
    if (envPath == null) {
      _cache = {};
      return _cache!;
    }

    final file = File(envPath);
    if (!file.existsSync()) {
      _cache = {};
      return _cache!;
    }

    final entries = <String, String>{};
    final lines = file.readAsLinesSync();

    for (final line in lines) {
      final trimmed = line.trim();

      // 跳过空行和注释
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

      final eqIndex = trimmed.indexOf('=');
      if (eqIndex <= 0) continue;

      final key = trimmed.substring(0, eqIndex).trim();
      var value = trimmed.substring(eqIndex + 1).trim();

      // 去掉引号
      if ((value.startsWith('"') && value.endsWith('"')) ||
          (value.startsWith("'") && value.endsWith("'"))) {
        value = value.substring(1, value.length - 1);
      }

      // 去掉行尾注释 (仅无引号的情况)
      if (!trimmed.substring(eqIndex + 1).trim().startsWith('"') &&
          !trimmed.substring(eqIndex + 1).trim().startsWith("'")) {
        final commentIndex = value.indexOf(' #');
        if (commentIndex > 0) {
          value = value.substring(0, commentIndex).trim();
        }
      }

      entries[key] = value;
    }

    _cache = entries;
    return _cache!;
  }

  /// 获取配置值
  static String get(String key, {String defaultValue = ''}) {
    final env = load();
    return env[key] ?? defaultValue;
  }

  /// 清除缓存 (测试用)
  static void reset() => _cache = null;

  /// 向上查找 .env 文件
  static String? _findEnvFile() {
    var dir = Directory.current;

    // 最多向上查找 5 层
    for (var i = 0; i < 5; i++) {
      final envFile = File('${dir.path}/.env');
      if (envFile.existsSync()) return envFile.path;

      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }

    return null;
  }
}
