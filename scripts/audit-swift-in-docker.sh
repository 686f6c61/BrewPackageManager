#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="${ROOT_DIR}/.audit-docker"
mkdir -p "${OUT_DIR}"

run_and_log() {
  local name="$1"
  shift

  echo "==> ${name}"
  if "$@" >"${OUT_DIR}/${name}.log" 2>&1; then
    echo "PASS  ${name}"
  else
    local code=$?
    echo "FAIL  ${name} (exit ${code})"
  fi
  tail -n 40 "${OUT_DIR}/${name}.log" || true
  echo
}

run_and_log swiftlint \
  docker run --rm -v "${ROOT_DIR}:/work" -w /work ghcr.io/realm/swiftlint:latest \
  lint --strict BrewPackageManager/BrewPackageManager

run_and_log swiftformat \
  docker run --rm -v "${ROOT_DIR}:/work" -w /work ghcr.io/nicklockwood/swiftformat:latest \
  --lint BrewPackageManager/BrewPackageManager

run_and_log semgrep \
  docker run --rm -v "${ROOT_DIR}:/src" -w /src semgrep/semgrep \
  semgrep scan --config auto \
  --exclude '.derived-*' \
  --exclude '.derived' \
  --exclude '.preview' \
  --exclude '.qa-screens' \
  --exclude 'dmg' \
  --exclude 'assets' \
  BrewPackageManager/BrewPackageManager

echo "Logs written to ${OUT_DIR}"
