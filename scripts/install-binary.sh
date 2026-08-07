#!/usr/bin/env bash
set -euo pipefail

#
# EstaCoda prebuilt binary installer.
#
# Downloads a platform-appropriate tarball from GitHub Releases and extracts
# it to ~/.estacoda/bin/ (or /usr/local/lib/estacoda for FHS).  No Node.js,
# git, or pnpm is required on the target machine — the Node.js runtime is
# embedded in the binary.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/sifr01-labs/EstaCoda/main/scripts/install-binary.sh | bash
#   bash scripts/install-binary.sh [--version <tag>] [--dir <path>] [--fhs]
#

INSTALLER_VERSION="v0.1.0-prerelease"
GITHUB_REPO="sifr01-labs/EstaCoda"
VERSION=""
INSTALL_DIR=""
FORCE_FHS=0

usage() {
  cat <<'USAGE'
EstaCoda prebuilt binary installer

Usage:
  curl -fsSL https://raw.githubusercontent.com/sifr01-labs/EstaCoda/main/scripts/install-binary.sh | bash
  bash scripts/install-binary.sh [--version <tag>] [--dir <path>] [--fhs]

Options:
  --version <tag>  Download a specific release tag (default: latest)
  --dir <path>     Install into a custom directory
  --fhs            Use Linux FHS paths: /usr/local/lib/estacoda and /usr/local/bin
  -h, --help       Show this help without changing files
USAGE
}

die() {
  echo "Error: $*" >&2
  exit 1
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --version)
      [ "$#" -ge 2 ] || die "--version requires a value"
      VERSION="$2"
      shift 2
      ;;
    --dir)
      [ "$#" -ge 2 ] || die "--dir requires a value"
      INSTALL_DIR="$2"
      shift 2
      ;;
    --fhs)
      FORCE_FHS=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "Unknown option: $1"
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Detect platform
# ---------------------------------------------------------------------------
detect_platform() {
  local os arch
  os="$(uname -s)"
  arch="$(uname -m)"

  case "$arch" in
    x86_64|amd64) arch="x64" ;;
    arm64|aarch64) arch="arm64" ;;
    *) die "Unsupported CPU architecture: $arch" ;;
  esac

  case "$os" in
    Darwin) PLATFORM="macos-${arch}" ;;
    Linux)  PLATFORM="linux-${arch}" ;;
    *) die "Unsupported operating system: $os" ;;
  esac

  echo "Platform: $PLATFORM"
}

# ---------------------------------------------------------------------------
# Choose install paths
# ---------------------------------------------------------------------------
is_termux() {
  [ -n "${TERMUX_VERSION:-}" ] || [[ "${PREFIX:-}" == *"/com.termux/"* ]]
}

choose_paths() {
  local os
  os="$(uname -s)"

  if [ -n "$INSTALL_DIR" ]; then
    INSTALL_DIR="$(cd "$(dirname "$INSTALL_DIR")" && pwd)/$(basename "$INSTALL_DIR")"
    mkdir -p "$(dirname "$INSTALL_DIR")"
  elif [ "$FORCE_FHS" -eq 1 ] || { [ "${EUID:-$(id -u)}" -eq 0 ] && [ "$os" = "Linux" ] && ! is_termux; }; then
    INSTALL_DIR="/usr/local/lib/estacoda"
    FORCE_FHS=1
  else
    [ -n "${HOME:-}" ] || die "HOME is not set. Use --dir to choose an install directory."
    INSTALL_DIR="$HOME/.estacoda/bin"
  fi

  if [ "$FORCE_FHS" -eq 1 ]; then
    BIN_DIR="/usr/local/bin"
  elif is_termux; then
    [ -n "${PREFIX:-}" ] || die "PREFIX is required for Termux installs."
    BIN_DIR="$PREFIX/bin"
  else
    [ -n "${HOME:-}" ] || die "HOME is not set."
    BIN_DIR="$HOME/.local/bin"
  fi
}

# ---------------------------------------------------------------------------
# Determine download URL
# ---------------------------------------------------------------------------
resolve_url() {
  if [ -n "$VERSION" ]; then
    TARBALL_URL="https://github.com/${GITHUB_REPO}/releases/download/${VERSION}/estacoda-${PLATFORM}.tar.gz"
  else
    # Use GitHub API to find latest release tag
    local api_url="https://api.github.com/repos/${GITHUB_REPO}/releases/latest"
    if command_exists curl; then
      VERSION="$(curl -fsSL -H "User-Agent: estacoda-installer" "$api_url" | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)"
    elif command_exists wget; then
      VERSION="$(wget -qO- --header="User-Agent: estacoda-installer" "$api_url" | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)"
    else
      die "Neither curl nor wget was found. Install one to download EstaCoda."
    fi

    if [ -z "$VERSION" ]; then
      die "Could not determine the latest release tag from GitHub."
    fi

    TARBALL_URL="https://github.com/${GITHUB_REPO}/releases/download/${VERSION}/estacoda-${PLATFORM}.tar.gz"
  fi

  echo "Version: $VERSION"
  echo "Download: $TARBALL_URL"
}

# ---------------------------------------------------------------------------
# Download and extract
# ---------------------------------------------------------------------------
download_and_extract() {
  local tmpdir
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' EXIT

  local tarball="$tmpdir/estacoda.tar.gz"

  echo "Downloading..."
  if command_exists curl; then
    curl -fsSL -o "$tarball" "$TARBALL_URL" || die "Download failed: $TARBALL_URL"
  elif command_exists wget; then
    wget -qO "$tarball" "$TARBALL_URL" || die "Download failed: $TARBALL_URL"
  else
    die "Neither curl nor wget was found."
  fi

  echo "Extracting to $INSTALL_DIR..."
  mkdir -p "$INSTALL_DIR"
  tar -xzf "$tarball" -C "$INSTALL_DIR"
  chmod +x "$INSTALL_DIR/estacoda"

  # Verify the binary runs
  if [ -x "$INSTALL_DIR/estacoda" ]; then
    "$INSTALL_DIR/estacoda" --version >/dev/null 2>&1 || echo "Warning: binary did not respond to --version. It may need additional dependencies."
  fi
}

# ---------------------------------------------------------------------------
# Write install-method stamp
# ---------------------------------------------------------------------------
write_stamp() {
  local stamp_path="$INSTALL_DIR/.install-method.json"
  cat > "$stamp_path" <<STAMP
{
  "method": "binary",
  "installDir": "$INSTALL_DIR",
  "installedAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "installerVersion": "$INSTALLER_VERSION"
}
STAMP
}

# ---------------------------------------------------------------------------
# Create wrapper symlink
# ---------------------------------------------------------------------------
write_wrapper() {
  local wrapper="$BIN_DIR/estacoda"
  mkdir -p "$BIN_DIR"

  # Remove existing wrapper if it's ours or a symlink
  if [ -L "$wrapper" ] || [ -e "$wrapper" ]; then
    if [ -L "$wrapper" ]; then
      rm -f "$wrapper"
    elif grep -Eq "Generated by scripts/(install|setup-estacoda|install-binary)\\.sh|EstaCoda" "$wrapper" 2>/dev/null; then
      rm -f "$wrapper"
    else
      echo "Warning: refusing to overwrite existing non-EstaCoda command: $wrapper" >&2
      echo "Binary installed at: $INSTALL_DIR/estacoda" >&2
      return 0
    fi
  fi

  ln -s "$INSTALL_DIR/estacoda" "$wrapper"
  echo "Wrapper: $wrapper -> $INSTALL_DIR/estacoda"
}

# ---------------------------------------------------------------------------
# Add to PATH if needed
# ---------------------------------------------------------------------------
ensure_path() {
  if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    local rc_file
    for rc_file in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile" "$HOME/.bash_profile"; do
      [ -f "$rc_file" ] || continue
      if ! grep -qF "$BIN_DIR" "$rc_file" 2>/dev/null; then
        echo "" >> "$rc_file"
        echo "# Added by EstaCoda installer" >> "$rc_file"
        echo "export PATH=\"$BIN_DIR:\$PATH\"" >> "$rc_file"
        echo "Added PATH entry to $rc_file"
      fi
    done

    echo ""
    echo "Add to PATH for this session: export PATH=\"$BIN_DIR:\$PATH\""
  fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
echo "EstaCoda prebuilt binary installer"
detect_platform
choose_paths
resolve_url
download_and_extract
write_stamp
write_wrapper
ensure_path

echo ""
echo "EstaCoda $VERSION installed."
echo "Command: $BIN_DIR/estacoda"
echo ""
echo "Next steps:"
if [[ ":$PATH:" == *":$BIN_DIR:"* ]]; then
  echo "  1. Run: estacoda"
else
  echo "  1. Add to PATH: export PATH=\"$BIN_DIR:\$PATH\""
  echo "  2. Run: estacoda"
fi