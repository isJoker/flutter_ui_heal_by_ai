import 'package:flutter/material.dart';

enum MetricStatus { pass, warning, fail }

/// MetricBadge - 指标徽章组件
///
/// 用于展示比对结果指标 (SSIM / Pixel Diff / Layout)
class MetricBadge extends StatelessWidget {
  final String label;
  final String value;
  final MetricStatus status;

  const MetricBadge({
    super.key,
    required this.label,
    required this.value,
    this.status = MetricStatus.pass,
  });

  Color get _bgColor {
    switch (status) {
      case MetricStatus.pass:
        return const Color(0xFFDCFCE7);
      case MetricStatus.warning:
        return const Color(0xFFFEF3C7);
      case MetricStatus.fail:
        return const Color(0xFFFEE2E2);
    }
  }

  Color get _textColor {
    switch (status) {
      case MetricStatus.pass:
        return const Color(0xFF166534);
      case MetricStatus.warning:
        return const Color(0xFF92400E);
      case MetricStatus.fail:
        return const Color(0xFF991B1B);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: _textColor.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _textColor,
            ),
          ),
        ],
      ),
    );
  }
}
