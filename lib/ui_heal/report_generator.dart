import 'dart:io';

/// 单组件测试报告
class ComponentReport {
  final String componentName;
  final String status; // pass | healed | failed | pending
  final double ssim;
  final int pixelDiff;
  final double pixelDiffPercent;
  final int? healRounds;

  ComponentReport({
    required this.componentName,
    required this.status,
    required this.ssim,
    required this.pixelDiff,
    this.pixelDiffPercent = 0.0,
    this.healRounds,
  });
}

/// HTML 还原度报告生成器
class ReportGenerator {
  static void generate({
    required List<ComponentReport> results,
    required String outputPath,
  }) {
    final passCount = results.where((r) => r.status == 'pass').length;
    final healedCount = results.where((r) => r.status == 'healed').length;
    final failedCount = results.where((r) => r.status == 'failed').length;
    final total = results.length;
    final score = total > 0 ? ((passCount + healedCount) / total * 100) : 0.0;

    final scoreColor =
        score >= 95 ? '#16a34a' : (score >= 80 ? '#d97706' : '#dc2626');

    final rows = StringBuffer();
    for (final r in results) {
      final diffDisplay = '${r.pixelDiff} (${(r.pixelDiffPercent * 100).toStringAsFixed(3)}%)';
      rows.writeln('      <tr>');
      rows.writeln('        <td>${r.componentName}</td>');
      rows.writeln(
          '        <td><span class="badge ${r.status}">${r.status.toUpperCase()}</span></td>');
      rows.writeln('        <td>${r.ssim.toStringAsFixed(4)}</td>');
      rows.writeln('        <td>$diffDisplay</td>');
      rows.writeln('        <td>${r.healRounds ?? "-"}</td>');
      rows.writeln('      </tr>');
    }

    final now = DateTime.now().toIso8601String();

    final html = '''<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>UI Golden Test Report</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { font-family: -apple-system, BlinkMacSystemFont, sans-serif;
           max-width: 960px; margin: 0 auto; padding: 32px; background: #f8f9fa; }
    h1 { font-size: 28px; color: #1f2329; margin-bottom: 8px; }
    .score { font-size: 56px; font-weight: 800; color: $scoreColor; }
    .summary { display: flex; gap: 16px; margin: 16px 0 32px; }
    .badge { padding: 4px 12px; border-radius: 12px; font-size: 13px; font-weight: 600; }
    .pass { background: #dcfce7; color: #166534; }
    .healed { background: #fef3c7; color: #92400e; }
    .failed { background: #fee2e2; color: #991b1b; }
    .pending { background: #e0e7ff; color: #3730a3; }
    table { width: 100%; border-collapse: collapse; background: white;
            border-radius: 12px; overflow: hidden; box-shadow: 0 1px 3px rgba(0,0,0,0.1); }
    th { background: #1f2329; color: white; padding: 14px 16px; text-align: left; }
    td { padding: 12px 16px; border-bottom: 1px solid #e5e7eb; }
    .timestamp { color: #646a73; font-size: 13px; margin-top: 24px; }
  </style>
</head>
<body>
  <h1>UI Golden Test Report</h1>
  <div class="score">${score.toStringAsFixed(1)}%</div>
  <p style="color:#646a73">UI Fidelity Score</p>
  <div class="summary">
    <span class="badge pass">Pass: $passCount</span>
    <span class="badge healed">Healed: $healedCount</span>
    <span class="badge failed">Failed: $failedCount</span>
  </div>
  <table>
    <thead>
      <tr><th>Component</th><th>Status</th><th>SSIM</th><th>Pixel Diff</th><th>Heal Rounds</th></tr>
    </thead>
    <tbody>
$rows    </tbody>
  </table>
  <p class="timestamp">Generated: $now</p>
</body>
</html>''';

    final file = File(outputPath);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(html);
    print('Report generated: \$outputPath');
  }
}
