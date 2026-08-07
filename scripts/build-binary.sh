#!/usr/bin/env bash
set -euo pipefail

#
# EstaCoda prebuilt binary build script.
#
# Uses @yao-pkg/pkg Enhanced SEA mode to compile the Node.js project into a
# standalone executable with the Node.js runtime embedded.  Non-JS assets
# (skills, workers, model catalog, WhatsApp bridge, ACP registry) are placed
# alongside the binary as sidecar directories.
#
# pkg's VFS cannot resolve modules through pnpm's .pnpm symlink structure, so
# this script installs a temporary hoisted node_modules (flat, like npm) before
# running pkg, then restores the original pnpm node_modules.
#
# Usage:
#   bash scripts/build-binary.sh                 # build for host platform
#   bash scripts/build-binary.sh node22-linux-x64
#   bash scripts/build-binary.sh --all          # build all 4 targets
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

ALL_TARGETS=(
  "node22-linux-x64"
  "node22-linux-arm64"
  "node22-macos-x64"
  "node22-macos-arm64"
)

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
TARGET_ARG=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --all)
      TARGET_ARG="all"
      shift
      ;;
    -h|--help)
      cat <<'USAGE'
EstaCoda prebuilt binary build script

Usage:
  bash scripts/build-binary.sh                     Build for host platform
  bash scripts/build-binary.sh node22-linux-x64     Build for one target
  bash scripts/build-binary.sh --all               Build all 4 targets

Targets:
  node22-linux-x64      Linux x86_64
  node22-linux-arm64    Linux aarch64
  node22-macos-x64      macOS x86_64 (Intel)
  node22-macos-arm64    macOS aarch64 (Apple Silicon)
USAGE
      exit 0
      ;;
    *)
      TARGET_ARG="$1"
      shift
      ;;
  esac
done

if [ "$TARGET_ARG" = "all" ]; then
  TARGETS=("${ALL_TARGETS[@]}")
elif [ -n "$TARGET_ARG" ]; then
  TARGETS=("$TARGET_ARG")
else
  TARGETS=("host")
fi

# ---------------------------------------------------------------------------
# Build TypeScript
# ---------------------------------------------------------------------------
echo "==> Building TypeScript..."
cd "$ROOT_DIR"
pnpm run build

# ---------------------------------------------------------------------------
# Ensure pkg is available
# ---------------------------------------------------------------------------
if ! command -v pnpm exec pkg >/dev/null 2>&1; then
  echo "==> Installing dependencies..."
  pnpm install
fi

# ---------------------------------------------------------------------------
# Switch to hoisted node_modules for pkg compatibility
#
# pkg's Enhanced SEA VFS cannot resolve bare specifiers through pnpm's .pnpm
# symlink structure.  A hoisted (npm-style flat) node_modules is needed so that
# node_modules/better-sqlite3/ is a real directory, not a symlink.
# ---------------------------------------------------------------------------
PKG_BIN_DIR="$ROOT_DIR/.node-modules-backup"

if [ -d "$ROOT_DIR/node_modules" ] && [ ! -d "$PKG_BIN_DIR" ]; then
  echo "==> Switching to hoisted node_modules for pkg compatibility..."
  mv "$ROOT_DIR/node_modules" "$PKG_BIN_DIR"
  npm_config_node_linker=hoisted pnpm install --frozen-lockfile 2>/dev/null || {
    echo "==> Hoisted install failed, trying without frozen lockfile..."
    npm_config_node_linker=hoisted pnpm install
  }
fi

cleanup() {
  if [ -d "$PKG_BIN_DIR" ]; then
    echo "==> Restoring pnpm node_modules..."
    rm -rf "$ROOT_DIR/node_modules"
    mv "$PKG_BIN_DIR" "$ROOT_DIR/node_modules"
  fi
}
trap cleanup EXIT

# ---------------------------------------------------------------------------
# Build each target
# ---------------------------------------------------------------------------
for target in "${TARGETS[@]}"; do
  echo ""
  echo "==> Building binary for target: $target"

  # Clean dist-bin for this target
  rm -f "$ROOT_DIR/dist-bin/estacoda" "$ROOT_DIR"/dist-bin/estacoda-*

  pnpm exec pkg . --sea --compress GZip \
    ${target:+-t "$target"} \
    --out-path "$ROOT_DIR/dist-bin"

  # pkg outputs a single binary named "estacoda" (for host) or
  # "estacoda-<platform>" (for explicit targets).
  # Find all produced binaries and create sidecar release directories.
  found_binary=""
  for binary in "$ROOT_DIR"/dist-bin/estacoda "$ROOT_DIR"/dist-bin/estacoda-*; do
    [ -f "$binary" ] || continue
    found_binary="$binary"
    break
  done

  if [ -z "$found_binary" ]; then
    echo "Error: No binary was produced by pkg" >&2
    exit 1
  fi

  # Determine platform name for the release directory
  base=$(basename "$found_binary")
  if [ "$base" = "estacoda" ]; then
    # Host build — detect platform
    os=$(uname -s | tr '[:upper:]' '[:lower:]')
    arch=$(uname -m)
    case "$arch" in
      x86_64|amd64) arch="x64" ;;
      arm64|aarch64) arch="arm64" ;;
    esac
    case "$os" in
      darwin) platform="macos-${arch}" ;;
      linux)  platform="linux-${arch}" ;;
      *)      platform="unknown" ;;
    esac
  else
    # Explicit target — extract from filename
    platform="${base#estacoda-}"
    platform="${platform%.exe}"
    platform="${platform%.app}"
    # Convert pkg target name (node22-linux-x64) to platform (linux-x64)
    platform="${platform#node*-}"
  fi

  releaseDir="$ROOT_DIR/dist-bin/release/${platform}"
  echo "==> Creating release directory: $releaseDir"

  rm -rf "$releaseDir"
  mkdir -p "$releaseDir"

  # Move binary
  mv "$found_binary" "$releaseDir/estacoda"
  chmod +x "$releaseDir/estacoda"

  # Copy sidecar assets
  cp -r "$ROOT_DIR/skills/" "$releaseDir/skills/"
  cp -r "$ROOT_DIR/workers/" "$releaseDir/workers/"
  cp -r "$ROOT_DIR/assets/" "$releaseDir/assets/"
  mkdir -p "$releaseDir/scripts/"
  cp -r "$ROOT_DIR/scripts/whatsapp-bridge/" "$releaseDir/scripts/whatsapp-bridge/"
  cp -r "$ROOT_DIR/acp_registry/" "$releaseDir/acp_registry/"
  cp "$ROOT_DIR/package.json" "$releaseDir/package.json"
  cp "$ROOT_DIR/LICENSE" "$releaseDir/LICENSE" 2>/dev/null || true
  cp "$ROOT_DIR/NOTICE" "$releaseDir/NOTICE" 2>/dev/null || true

  # Write install-method stamp
  cat > "$releaseDir/.install-method.json" <<STAMP
{
  "method": "binary",
  "installDir": ""
}
STAMP

  # Create tarball
  tarball="$ROOT_DIR/dist-bin/estacoda-${platform}.tar.gz"
  echo "==> Creating tarball: $tarball"
  rm -f "$tarball"
  tar -czf "$tarball" -C "$releaseDir" .

  echo "==> Done: $tarball"

  # Quick smoke test
  echo "==> Smoke testing binary..."
  if "$releaseDir/estacoda" --version 2>&1; then
    echo "==> Binary smoke test passed."
  else
    echo "Warning: Binary smoke test failed." >&2
  fi
done

echo ""
echo "==> All builds complete."
echo "    Release tarballs: dist-bin/estacoda-*.tar.gz"
echo "    Release dirs:     dist-bin/release/"