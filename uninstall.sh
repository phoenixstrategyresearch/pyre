#!/usr/bin/env bash
# pyre uninstaller — cleanly remove pyre from your system
set -euo pipefail

INSTALL_DIR="$HOME/.pyre"
BIN_LINK="$HOME/.local/bin/pyre"

echo ""
echo "  Uninstalling pyre..."
echo ""

# Stop daemon and remove auto-start
if [[ -f "$INSTALL_DIR/pyre.sh" ]]; then
    "$INSTALL_DIR/pyre.sh" disable 2>/dev/null || true
    "$INSTALL_DIR/pyre.sh" uninstall 2>/dev/null || true
fi

# Clean up PID and log files
rm -f "$HOME/.pyre/pyre-daemon.pid" "$HOME/.pyre/pyre-daemon.log" 2>/dev/null || true

# Remove symlink
if [[ -L "$BIN_LINK" ]]; then
    rm "$BIN_LINK"
    echo "  Removed pyre command"
fi

# Remove startup check from shell rc
for rc in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.bash_profile"; do
    if [[ -f "$rc" ]] && grep -qF 'pyre check' "$rc" 2>/dev/null; then
        sed -i.bak '/pyre check/d' "$rc" && rm -f "${rc}.bak"
        echo "  Removed startup check from $rc"
    fi
done

# Remove install directory
if [[ -d "$INSTALL_DIR" ]]; then
    rm -rf "$INSTALL_DIR"
    echo "  Removed $INSTALL_DIR"
fi

echo ""
echo "  pyre has been uninstalled."
echo ""
echo "  Your backups are still safe at ~/.claude/backups/"
echo "  To delete them too:  rm -rf ~/.claude/backups"
echo ""
