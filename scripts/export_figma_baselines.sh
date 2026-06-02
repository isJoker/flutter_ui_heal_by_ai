#!/bin/bash
# ============================================================
# Figma Baseline 导出耚本 (占位版)
# ============================================================
#
# 生产环境用法:
#   ./scripts/export_figma_baselines.sh
#
# 此脚本在生产环境如中会:
# 1. 调用 Figma REST API 获取又组件列表
# 2. 导出 2x PNG 基准图
# 3. 导出 layout.json (约束信息)
#
# 当前 demo 版本: 生成占位图片供测试
# ============================================================

set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BASELINES_DIR="$PROJECT_DIR/test/goldens/baselines"

mkdir -p "$BASELINES_DIR"

echo "=== Figma Baseline Export ==="
echo "Output: $BASELINES_DIR"
echo ""

# ---- 占位图片生成 ----
# 使用 Flutter 自身截图作为 baseline (首次运行 --update-goldens)
# 后续更换为 Figma 导出的真实设计稿截图

echo "Generating placeholder baselines..."
echo "(Replace these with actual Figma exports later)"

# 使用 flutter test 生成 golden 文件作为初始 baseline
cd "$PROJECT_DIR"
flutter test --update-goldens test/goldens/ 2>&1

# 复制生成的 golden 文件到 baselines 目录
if [ -d "test/goldens/goldens" ]; then
  cp test/goldens/goldens/*.png "$BASELINES_DIR/" 2>/dev/null || true
fi

echo ""
echo "Baselines exported:"
ls -la "$BASELINES_DIR/"*.png 2>/dev/null || echo "  (no PNG files yet - run flutter test --update-goldens first)"
echo ""
echo "=== Done ==="
echo ""
echo "Next steps:"
echo "  1. Replace baselines with actual Figma exported PNGs"
echo "  2. Run: ./scripts/run_golden_heal.sh"
