import 'package:flutter/material.dart';

enum ButtonVariant { primary, secondary }

/// AppButton - 主按钮组件
///
/// Figma 设计规范:
/// - Primary: 蓝底白字, 圆角 8px, 高度 48px, padding 水平 24px
/// - Secondary: 白底蓝字蓝边框, 同尺寸
class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final ButtonVariant variant;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.variant = ButtonVariant.primary,
  });

  @override
  Widget build(BuildContext context) {
    final isPrimary = variant == ButtonVariant.primary;

    return SizedBox(
      height: 48,
      width: 200,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary ? const Color(0xFF2196F3) : Colors.white,
          foregroundColor: isPrimary ? Colors.white : const Color(0xFF2196F3),
          elevation: isPrimary ? 2 : 0,
          side: isPrimary
              ? null
              : const BorderSide(color: Color(0xFF2196F3), width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
