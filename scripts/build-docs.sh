#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${1:-"${ROOT_DIR}/docs-site"}"

echo "==> Generating CupThread Flutter SDK API documentation with dart doc..."
cd "${ROOT_DIR}"

dart doc --output "${OUTPUT_DIR}"

SCREENSHOTS_DIR="${ROOT_DIR}/docs/screenshots"
if [ -d "${SCREENSHOTS_DIR}" ]; then
  mkdir -p "${OUTPUT_DIR}/docs/screenshots"
  cp -R "${SCREENSHOTS_DIR}/." "${OUTPUT_DIR}/docs/screenshots/"
  echo "==> Copied visual showcase screenshots to ${OUTPUT_DIR}/docs/screenshots"
fi

echo "==> Documentation generated successfully at: ${OUTPUT_DIR}"
