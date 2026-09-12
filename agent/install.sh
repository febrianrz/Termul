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
  if command -v brew >/dev/null 2>&1; then
    echo "Installing it via Homebrew..."
    brew install qrencode
  else
    echo "Install it manually, e.g.:"
    echo "  macOS:         brew install qrencode"
    echo "  Debian/Ubuntu: sudo apt install qrencode"
  fi
fi

echo
echo "Done. Run: termul"
