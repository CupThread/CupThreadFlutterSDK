#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCREENSHOTS_DIR="$REPO_ROOT/docs/screenshots"

mkdir -p "$SCREENSHOTS_DIR"

for name in roadmap feature_requests submit_request whats_new changelog_overlay feedback_composer; do
    src_png="$SCREENSHOTS_DIR/$name.png"
    target_jpg="$SCREENSHOTS_DIR/$name.jpg"
    if [ -f "$src_png" ]; then
        echo "Converting $name.png -> $name.jpg..."
        sips -s format jpeg -s formatOptions 75 "$src_png" --out "$target_jpg" >/dev/null 2>&1
        rm -f "$src_png"
    fi
done

rm -f "$SCREENSHOTS_DIR"/*.png
find "$SCREENSHOTS_DIR" -maxdepth 1 -type f -name '*.jpg' -print | sort
