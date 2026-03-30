#!/usr/bin/env bash
# pyre installer — one command to set up crash recovery for Claude Code
# Usage: curl -fsSL https://raw.githubusercontent.com/phoenixstrategy/pyre/main/install.sh | bash
set -euo pipefail

INSTALL_DIR="$HOME/.pyre"
REPO="https://github.com/phoenixstrategy/pyre.git"

echo ""
echo "  Installing pyre — crash recovery for Claude Code"
echo "  ================================================="
echo ""

# 1. Clone or update
if [[ -d "$INSTALL_DIR" ]]; then
    echo "  Updating existing install..."
    git -C "$INSTALL_DIR" pull --quiet 2>/dev/null || true
else
    echo "  Downloading pyre..."
    git clone --quiet "$REPO" "$INSTALL_DIR" 2>/dev/null
fi

chmod +x "$INSTALL_DIR/pyre.sh" "$INSTALL_DIR/pyre-backup.sh" "$INSTALL_DIR/pyre-daemon.sh"

# 2. Create a `pyre` command
BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"
ln -sf "$INSTALL_DIR/pyre.sh" "$BIN_DIR/pyre"

# 3. Add to PATH if needed
PATH_LINE='export PATH="$HOME/.local/bin:$PATH"'
SHELL_RC=""
if [[ -f "$HOME/.zshrc" ]]; then
    SHELL_RC="$HOME/.zshrc"
elif [[ -f "$HOME/.bashrc" ]]; then
    SHELL_RC="$HOME/.bashrc"
elif [[ -f "$HOME/.bash_profile" ]]; then
    SHELL_RC="$HOME/.bash_profile"
fi

if [[ -n "$SHELL_RC" ]]; then
    if ! grep -qF '.local/bin' "$SHELL_RC" 2>/dev/null; then
        echo "" >> "$SHELL_RC"
        echo "# pyre — Claude Code crash recovery" >> "$SHELL_RC"
        echo "$PATH_LINE" >> "$SHELL_RC"
        echo "  Added pyre to your PATH in $SHELL_RC"
    fi
    # Add startup check — quietly alerts you if a session crashed
    if ! grep -qF 'pyre check' "$SHELL_RC" 2>/dev/null; then
        echo 'command -v pyre >/dev/null 2>&1 && pyre check' >> "$SHELL_RC"
        echo "  Added startup check to $SHELL_RC"
    fi
fi

# Make it available in current session
export PATH="$BIN_DIR:$PATH"

# 4. Install Claude Code hooks
"$INSTALL_DIR/pyre.sh" install

# 5. Enable background daemon (starts on boot)
echo ""
"$INSTALL_DIR/pyre.sh" enable

echo ""
echo "  Done! pyre is now protecting your Claude Code sessions."
echo ""
echo "  Two layers of protection are active:"
echo "    1. Hooks  — instant backup after every Claude Code action"
echo "    2. Daemon — background watcher, starts automatically on boot"
echo ""
echo "  Try these commands:"
echo "    pyre status       Check if the daemon is running"
echo "    pyre stats        See backup info"
echo "    pyre list         List saved sessions"
echo "    pyre latest       Restore your most recent session"
echo ""
echo "  If 'pyre' isn't found, restart your terminal or run:"
echo "    source ${SHELL_RC:-~/.zshrc}"
echo ""
