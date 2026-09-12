#!/bin/sh
# Installs the `termul` publisher script: curl -fsSL <raw-url>/agent/install.sh | sh
set -e

REPO_RAW="https://raw.githubusercontent.com/febrianrz/Termul/main/agent/termul.sh"

if [ -w /usr/local/bin ] 2>/dev/null; then
  INSTALL_DIR="/usr/local/bin"
else
  INSTALL_DIR="$HOME/.local/bin"
  mkdir -p "$INSTALL_DIR"
fi

TARGET="$INSTALL_DIR/termul"

echo "Downloading termul to $TARGET ..."
curl -fsSL "$REPO_RAW" -o "$TARGET"
chmod +x "$TARGET"
echo "Installed: $TARGET"

case ":$PATH:" in
  *":$INSTALL_DIR:"*) : ;;
  *)
    echo
    echo "$INSTALL_DIR is not on your PATH yet. Add this to your shell profile"
    echo "(~/.zshrc or ~/.bashrc) and open a new terminal:"
    echo "  export PATH=\"$INSTALL_DIR:\$PATH\""
    ;;
esac

if ! command -v qrencode >/dev/null 2>&1; then
  echo
  echo "termul also needs 'qrencode' to draw QR codes in the terminal."

  SUDO=""
  if [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
  fi

  if command -v brew >/dev/null 2>&1; then
    echo "Installing it via Homebrew..."
    brew install qrencode || echo "Automatic install failed - install it manually: brew install qrencode"
  elif command -v apt-get >/dev/null 2>&1; then
    echo "Installing it via apt..."
    $SUDO apt-get update -qq && $SUDO apt-get install -y qrencode ||
      echo "Automatic install failed - install it manually: sudo apt install qrencode"
  elif command -v dnf >/dev/null 2>&1; then
    echo "Installing it via dnf..."
    $SUDO dnf install -y qrencode || echo "Automatic install failed - install it manually: sudo dnf install qrencode"
  elif command -v pacman >/dev/null 2>&1; then
    echo "Installing it via pacman..."
    $SUDO pacman -Sy --noconfirm qrencode || echo "Automatic install failed - install it manually: sudo pacman -S qrencode"
  elif command -v zypper >/dev/null 2>&1; then
    echo "Installing it via zypper..."
    $SUDO zypper install -y qrencode || echo "Automatic install failed - install it manually: sudo zypper install qrencode"
  else
    echo "Install it manually, e.g.:"
    echo "  macOS:         brew install qrencode"
    echo "  Debian/Ubuntu: sudo apt install qrencode"
    echo "  Fedora/RHEL:   sudo dnf install qrencode"
    echo "  Arch:          sudo pacman -S qrencode"
  fi
fi

echo
echo "Done. Run: termul"
