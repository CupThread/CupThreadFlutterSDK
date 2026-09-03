#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEVICE="${1:-${CUPTHREAD_SCREENSHOT_DEVICE:-iPhone 16 Pro}}"
OUTPUT_DIR="$REPO_ROOT/docs/screenshots"

mkdir -p "$OUTPUT_DIR"

echo "==> Running Flutter integration screenshot test on $DEVICE..."
(
    cd "$REPO_ROOT/example"
    CUPTHREAD_SCREENSHOT_OUTPUT="$OUTPUT_DIR" flutter drive \
        --driver=test_driver/screenshot_test.dart \
        --target=integration_test/screenshot_test.dart \
        --device-id="$DEVICE" \
        --dart-define=CUPTHREAD_SCREENSHOT_MODE=true
)

echo "==> Converting screenshots to JPEG..."
"$REPO_ROOT/scripts/convert-screenshots.sh"

echo "==> Done! Screenshots updated in $OUTPUT_DIR."
