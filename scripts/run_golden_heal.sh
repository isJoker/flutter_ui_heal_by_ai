#!/bin/bash
# ============================================================
# Flutter Golden Test UI Self-Healing CI Script
# ============================================================
#
# Usage:
#   ./scripts/run_golden_heal.sh [--update] [--component COMP]
#
# Args:
#   --update        Update golden baselines
#   --component     Test specific component only
#   --max-rounds    Max heal rounds (default 3)
# ============================================================

set -e
export PATH="/Users/bytedance/Flutter/flutter_3_44/bin:$PATH"

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

# Use the dart from Flutter SDK (matches flutter test runtime)
DART_BIN="/Users/bytedance/Flutter/flutter_3_44/bin/cache/dart-sdk/bin/dart"
UPDATE_GOLDENS=false
MAX_ROUNDS=3
COMPONENT=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --update)
      UPDATE_GOLDENS=true
      shift
      ;;
    --component)
      COMPONENT="$2"
      shift 2
      ;;
    --max-rounds)
      MAX_ROUNDS="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

echo "========================================"
echo "  Flutter Golden Test UI Self-Healing"
echo "========================================"
echo "Project: $PROJECT_DIR"
echo "Update goldens: $UPDATE_GOLDENS"
echo "Max heal rounds: $MAX_ROUNDS"
echo ""

# Step 1: Dependencies
echo "[Step 1] Checking dependencies..."
flutter pub get 2>/dev/null || echo "pub get skipped (deps already resolved)"

# Step 2: Update mode
if [ "$UPDATE_GOLDENS" = true ]; then
  echo "[Step 2] Updating golden files..."
  flutter test --update-goldens test/goldens/
  echo "Golden files updated successfully!"
  echo ""
  echo "[Step 3] Generating report..."
  $DART_BIN run scripts/generate_report.dart 2>&1 || true
  exit 0
fi

# Step 3: Run golden tests
echo "[Step 3] Running golden tests..."
TEST_RESULT=0
if [ -n "$COMPONENT" ]; then
  flutter test test/goldens/${COMPONENT}_golden_test.dart 2>&1 || TEST_RESULT=$?
else
  flutter test test/goldens/ 2>&1 || TEST_RESULT=$?
fi

# Step 4: All pass -> generate report and exit
if [ $TEST_RESULT -eq 0 ]; then
  echo ""
  echo "========================================"
  echo "  ALL GOLDEN TESTS PASSED"
  echo "========================================"
  echo ""
  echo "[Step 5] Generating report..."
  $DART_BIN run scripts/generate_report.dart 2>&1 || true
  exit 0
fi

# Step 5: Failed -> enter heal loop
echo ""
echo "========================================"
echo "  Golden test failed, starting self-heal..."
echo "========================================"

HEAL_ROUND=0
HEAL_SUCCESS=false

while [ $HEAL_ROUND -lt $MAX_ROUNDS ]; do
  HEAL_ROUND=$((HEAL_ROUND + 1))
  echo ""
  echo "[Heal Round $HEAL_ROUND/$MAX_ROUNDS]"

  echo "  Analyzing diffs and generating patches..."
  $DART_BIN run scripts/heal_runner.dart --round $HEAL_ROUND 2>&1 || true

  echo "  Re-running golden tests..."
  TEST_RESULT=0
  if [ -n "$COMPONENT" ]; then
    flutter test test/goldens/${COMPONENT}_golden_test.dart 2>&1 || TEST_RESULT=$?
  else
    flutter test test/goldens/ 2>&1 || TEST_RESULT=$?
  fi

  if [ $TEST_RESULT -eq 0 ]; then
    HEAL_SUCCESS=true
    break
  fi
done

# Step 6: Result
echo ""
echo "========================================"
if [ "$HEAL_SUCCESS" = true ]; then
  echo "  HEALED in round $HEAL_ROUND"
  echo "========================================"

  if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    echo "  Not a git repo, skipping commit."
  elif git diff --quiet; then
    echo "  No changes to commit."
  else
    echo "  Auto-committing heal patches..."
    git add -A
    git commit -m "fix(ui): auto-heal golden test failures (round $HEAL_ROUND)"
    echo "  Committed."
  fi
else
  echo "  FAILED after $MAX_ROUNDS rounds"
  echo "  Manual intervention required."
  echo "========================================"
  echo ""
  echo "Diff images:"
  find test/goldens/failures -name "*.png" 2>/dev/null | while read f; do
    echo "  $f"
  done
fi

# Step 7: Always generate report
echo ""
echo "[Step 7] Generating report..."
$DART_BIN run scripts/generate_report.dart 2>&1 || true
echo "Done."

if [ "$HEAL_SUCCESS" = false ] && [ $TEST_RESULT -ne 0 ]; then
  exit 1
fi
