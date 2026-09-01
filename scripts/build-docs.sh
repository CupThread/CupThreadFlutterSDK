#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${1:-"${ROOT_DIR}/docs-site"}"

echo "==> Generating CupThread Flutter SDK API documentation with dart doc..."
cd "${ROOT_DIR}"

dart doc --output "${OUTPUT_DIR}"

echo "==> Documentation generated successfully at: ${OUTPUT_DIR}"
