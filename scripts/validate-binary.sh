#!/usr/bin/env bash
set -euo pipefail

#
# EstaCoda binary validation script.
#
# Builds the binary, extracts it, validates the sidecar layout, runs smoke
# tests, and reports pass/fail.  Used for release gating and CI validation.
#
# Usage:
#   bash scripts/validate-binary.sh            # validate host platform
#   bash scripts/validate-binary.sh --all      # validate all 4 targets
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$ROOT_DIR"

PASS=0
FAIL=0
WARN=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }
warn() { echo "  WARN: $1"; WARN=$((WARN + 1)); }

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
BUILD_TARGET=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --all)
      BUILD_TARGET="all"
      shift
      ;;
    *)
      BUILD_TARGET="$1"
      shift
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------
echo "==> Building binary..."
if [ "$BUILD_TARGET" = "all" ]; then
  bash scripts/build-binary.sh --all
else
  bash scripts/build-binary.sh ${BUILD_TARGET:+$BUILD_TARGET}
fi

# ---------------------------------------------------------------------------
# Validate each release directory
# ---------------------------------------------------------------------------
echo ""
echo "==> Validating release packages..."

for release_dir in dist-bin/release/*/; do
  [ -d "$release_dir" ] || continue
  platform=$(basename "$release_dir")
  echo ""
  echo "--- $platform ---"

  # 1. Binary exists and is executable
  if [ -x "$release_dir/estacoda" ]; then
    pass "Binary exists and is executable"
  else
    fail "Binary missing or not executable"
    continue
  fi

  # 2. Binary runs
  if "$release_dir/estacoda" --version >/dev/null 2>&1; then
    version=$("$release_dir/estacoda" --version 2>&1 | head -1)
    pass "Binary runs: $version"
  else
    fail "Binary does not respond to --version"
  fi

  # 3. --help runs
  if "$release_dir/estacoda" --help >/dev/null 2>&1; then
    pass "--help works"
  else
    fail "--help fails"
  fi

  # 4. Sidecar directories exist
  for dir in skills workers assets scripts/whatsapp-bridge acp_registry; do
    if [ -d "$release_dir/$dir" ]; then
      count=$(find "$release_dir/$dir" -type f | wc -l)
      pass "Sidecar directory $dir/ exists ($count files)"
    else
      fail "Sidecar directory $dir/ missing"
    fi
  done

  # 5. package.json present
  if [ -f "$release_dir/package.json" ]; then
    pass "package.json present"
  else
    fail "package.json missing"
  fi

  # 6. Install method stamp
  if [ -f "$release_dir/.install-method.json" ]; then
    method=$(grep -o '"method"[[:space:]]*:[[:space:]]*"[^"]*"' "$release_dir/.install-method.json" | head -1)
    pass "Install method stamp: $method"
  else
    fail "Install method stamp missing"
  fi

  # 7. Tarball exists
  tarball="dist-bin/estacoda-${platform}.tar.gz"
  if [ -f "$tarball" ]; then
    size=$(du -h "$tarball" | cut -f1)
    pass "Tarball exists: $tarball ($size)"
  else
    fail "Tarball missing: $tarball"
  fi

  # 8. LICENSE present
  if [ -f "$release_dir/LICENSE" ]; then
    pass "LICENSE present"
  else
    warn "LICENSE missing"
  fi
done

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "=============================="
echo "  PASS: $PASS"
echo "  FAIL: $FAIL"
echo "  WARN: $WARN"
echo "=============================="

if [ "$FAIL" -gt 0 ]; then
  echo "Validation FAILED."
  exit 1
else
  echo "Validation PASSED."
  exit 0
fi
