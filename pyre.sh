#!/usr/bin/env bash
# pyre — session crash recovery CLI for Claude Code
# https://github.com/phoenixstrategy/pyre
#
# Usage:
#   pyre list                    — list all backed-up sessions
#   pyre list <project>          — list sessions matching a project name
#   pyre restore <session-id>    — restore a specific backup
#   pyre restore <file>          — restore from a backup file path
#   pyre latest                  — restore the most recent backup
#   pyre latest <project>        — restore the most recent backup for a project
#   pyre cleanup [days]          — remove backups older than N days (default: 7)
#   pyre stats                   — show backup storage usage
#   pyre install                 — install hooks into Claude Code settings
#   pyre uninstall               — remove hooks from Claude Code settings

set -euo pipefail

BACKUP_DIR="$HOME/.claude/backups"
PROJECTS_DIR="$HOME/.claude/projects"
SETTINGS_FILE="$HOME/.claude/settings.json"
SCRIPT_DIR="$(cd "$(dirname -- "$0")" && pwd)"
BACKUP_SCRIPT="$SCRIPT_DIR/pyre-backup.sh"

# Cross-platform helpers (macOS vs Linux stat)
if stat -f %m / >/dev/null 2>&1; then
    # macOS
    file_mtime()    { stat -f %m "$1"; }
    file_date()     { stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$1"; }
    file_date_short() { stat -f "%Sm" -t "%Y-%m-%d" "$1"; }
    file_mtime_name() { stat -f "%m %N" "$1"; }
else
    # Linux / WSL
    file_mtime()    { stat -c %Y "$1"; }
    file_date()     { stat -c "%y" "$1" | cut -d. -f1 | cut -c1-16; }
    file_date_short() { stat -c "%y" "$1" | cut -d' ' -f1; }
    file_mtime_name() { echo "$(stat -c %Y "$1") $1"; }
fi

# Find python
PYTHON=""
for p in python3 python; do
    if command -v "$p" >/dev/null 2>&1; then
        PYTHON="$p"
        break
    fi
done

DAEMON_SCRIPT="$SCRIPT_DIR/pyre-daemon.sh"
LAUNCHD_PLIST="$HOME/Library/LaunchAgents/group.phoenixstrategy.pyre.plist"
SYSTEMD_UNIT="$HOME/.config/systemd/user/pyre.service"
PID_FILE="$HOME/.pyre/pyre-daemon.pid"
LOG_FILE="$HOME/.pyre/pyre-daemon.log"

cmd="${1:-help}"

case "$cmd" in
    start)
        mkdir -p "$(dirname "$PID_FILE")"

        # Check if already running
        if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
            echo "pyre daemon is already running (PID $(cat "$PID_FILE"))"
            exit 0
        fi

        nohup bash "$DAEMON_SCRIPT" >> "$LOG_FILE" 2>&1 &
        echo "$!" > "$PID_FILE"
        echo "pyre daemon started (PID $!)"
        echo "Logs: $LOG_FILE"
        ;;

    stop)
        if [[ -f "$PID_FILE" ]]; then
            PID=$(cat "$PID_FILE")
            if kill -0 "$PID" 2>/dev/null; then
                kill "$PID"
                echo "pyre daemon stopped (PID $PID)"
            else
                echo "pyre daemon was not running"
            fi
            rm -f "$PID_FILE"
        else
            echo "pyre daemon is not running"
        fi
        ;;

    status)
        if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
            echo "pyre daemon is running (PID $(cat "$PID_FILE"))"
            echo "Logs: $LOG_FILE"
            if [[ -f "$LOG_FILE" ]]; then
                echo ""
                echo "Last 5 log entries:"
                tail -5 "$LOG_FILE"
            fi
        else
            echo "pyre daemon is not running"
            echo ""
            echo "Start it with:  pyre start"
            echo "Auto-start with:  pyre enable"
        fi
        ;;

    enable)
        # Set up auto-start on boot
        if [[ "$(uname)" == "Darwin" ]]; then
            # macOS — launchd
            mkdir -p "$(dirname "$LAUNCHD_PLIST")"
            cat > "$LAUNCHD_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>group.phoenixstrategy.pyre</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$DAEMON_SCRIPT</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$LOG_FILE</string>
    <key>StandardErrorPath</key>
    <string>$LOG_FILE</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>HOME</key>
        <string>$HOME</string>
    </dict>
</dict>
</plist>
PLIST
            launchctl load "$LAUNCHD_PLIST" 2>/dev/null || true
            echo "pyre will now start automatically on boot (macOS launchd)"
            echo "It's also running right now."

        elif command -v systemctl >/dev/null 2>&1; then
            # Linux — systemd user unit
            mkdir -p "$(dirname "$SYSTEMD_UNIT")"
            cat > "$SYSTEMD_UNIT" <<UNIT
[Unit]
Description=pyre — Claude Code session backup daemon
After=default.target

[Service]
Type=simple
ExecStart=/bin/bash $DAEMON_SCRIPT
Restart=on-failure
RestartSec=10
Environment=HOME=$HOME

[Install]
WantedBy=default.target
UNIT
            systemctl --user daemon-reload
            systemctl --user enable pyre.service
            systemctl --user start pyre.service
            echo "pyre will now start automatically on boot (systemd)"
            echo "It's also running right now."

        else
            # Fallback — just start the daemon and add to shell rc
            bash "$0" start
            echo ""
            echo "No launchd or systemd found. pyre daemon started manually."
            echo "Add 'pyre start' to your shell startup file to auto-start."
        fi
        ;;

    disable)
        if [[ "$(uname)" == "Darwin" ]]; then
            if [[ -f "$LAUNCHD_PLIST" ]]; then
                launchctl unload "$LAUNCHD_PLIST" 2>/dev/null || true
                rm -f "$LAUNCHD_PLIST"
                echo "pyre auto-start disabled (launchd agent removed)"
            else
                echo "pyre auto-start is not enabled"
            fi
        elif command -v systemctl >/dev/null 2>&1; then
            systemctl --user stop pyre.service 2>/dev/null || true
            systemctl --user disable pyre.service 2>/dev/null || true
            rm -f "$SYSTEMD_UNIT"
            systemctl --user daemon-reload 2>/dev/null || true
            echo "pyre auto-start disabled (systemd unit removed)"
        fi
        # Also stop the daemon
        bash "$0" stop 2>/dev/null || true
        ;;

    list)
        PROJECT_FILTER="${2:-}"
        echo "=== pyre — session backups ==="
        echo ""

        found=0
        for project_dir in "$BACKUP_DIR"/*/; do
            [[ -d "$project_dir" ]] || continue
            project=$(basename -- "$project_dir")

            if [[ -n "$PROJECT_FILTER" && "$project" != *"$PROJECT_FILTER"* ]]; then
                continue
            fi

            # Convert project hash back to readable path
            readable=$(echo "$project" | sed 's|^-|/|; s|-|/|g')
            echo "Project: $readable"

            for latest in "$project_dir"/*_latest.jsonl.gz; do
                [[ -f "$latest" ]] || continue
                found=1
                session_id=$(basename -- "$latest" | sed 's/_latest\.jsonl\.gz//')
                size=$(du -sh "$latest" | cut -f1)
                mod=$(file_date "$latest")
                count=$(ls -1 "$project_dir/${session_id}_2"*.jsonl.gz 2>/dev/null | wc -l | tr -d ' ')
                echo "  ${session_id:0:8}...  |  $count snapshots  |  $size  |  $mod"
            done
            echo ""
        done

        if [[ $found -eq 0 ]]; then
            echo "  No backups yet. Start a Claude Code session — pyre hooks will handle the rest."
        fi
        ;;

    restore)
        if [[ -z "${2:-}" ]]; then
            echo "Usage: pyre restore <backup-file|session-id>"
            echo ""
            echo "Run 'pyre list' to see available backups."
            exit 1
        fi

        TARGET="$2"

        # If it's a full path to a .gz file
        if [[ -f "$TARGET" ]]; then
            BACKUP_FILE="$TARGET"
        else
            # Search by session ID prefix
            BACKUP_FILE=$(find "$BACKUP_DIR" -name "${TARGET}*_latest.jsonl.gz" -type f 2>/dev/null | head -1)
            if [[ -z "$BACKUP_FILE" ]]; then
                echo "No backup found matching: $TARGET"
                exit 1
            fi
        fi

        REL=$(echo "$BACKUP_FILE" | sed "s|$BACKUP_DIR/||")
        PROJECT_HASH=$(dirname -- "$REL")
        FILENAME=$(basename -- "$BACKUP_FILE")
        SESSION_ID=$(echo "$FILENAME" | sed 's/_latest\.jsonl\.gz//; s/_[0-9]\{8\}_[0-9]\{6\}\.jsonl\.gz//')

        DEST="$PROJECTS_DIR/$PROJECT_HASH/$SESSION_ID.jsonl"
        DEST_DIR=$(dirname -- "$DEST")
        mkdir -p "$DEST_DIR"

        if [[ -f "$DEST" ]]; then
            EXISTING_SIZE=$(wc -c < "$DEST")
            if [[ "$EXISTING_SIZE" -gt 100 ]]; then
                echo "Session file exists ($EXISTING_SIZE bytes): $DEST"
                read -p "Overwrite? [y/N] " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    echo "Aborted."
                    exit 0
                fi
                cp "$DEST" "${DEST}.pre-restore.bak"
                echo "Existing file saved to ${DEST}.pre-restore.bak"
            fi
        fi

        gunzip -c "$BACKUP_FILE" > "$DEST"
        RESTORED_SIZE=$(wc -c < "$DEST")
        echo "Restored: $SESSION_ID ($RESTORED_SIZE bytes)"
        echo ""
        echo "Resume with:  claude --resume $SESSION_ID"
        ;;

    latest)
        PROJECT_FILTER="${2:-}"

        if [[ -n "$PROJECT_FILTER" ]]; then
            SEARCH_DIR=$(find "$BACKUP_DIR" -maxdepth 1 -name "*${PROJECT_FILTER}*" -type d | head -1)
            [[ -n "$SEARCH_DIR" ]] || { echo "No project matching: $PROJECT_FILTER"; exit 1; }
        else
            SEARCH_DIR="$BACKUP_DIR"
        fi

        LATEST_FILE=""
        LATEST_MTIME=0
        while IFS= read -r f; do
            mt=$(file_mtime "$f")
            if [[ "$mt" -gt "$LATEST_MTIME" ]]; then
                LATEST_MTIME="$mt"
                LATEST_FILE="$f"
            fi
        done < <(find "$SEARCH_DIR" -name "*_latest.jsonl.gz" -type f 2>/dev/null)

        if [[ -z "${LATEST_FILE:-}" ]]; then
            echo "No backups found."
            exit 1
        fi

        echo "Most recent backup: $LATEST_FILE"
        echo ""
        bash "$0" restore "$LATEST_FILE"
        ;;

    cleanup)
        DAYS="${2:-7}"
        echo "Removing backups older than $DAYS days..."
        COUNT=$(find "$BACKUP_DIR" -name "*.gz" -mtime +"$DAYS" -type f 2>/dev/null | wc -l | tr -d ' ')
        find "$BACKUP_DIR" -name "*.gz" -mtime +"$DAYS" -type f -delete 2>/dev/null
        find "$BACKUP_DIR" -type d -empty -delete 2>/dev/null || true
        echo "Removed $COUNT old backup files."
        ;;

    stats)
        echo "=== pyre — backup stats ==="
        if [[ ! -d "$BACKUP_DIR" ]]; then
            echo "  No backups yet."
            exit 0
        fi
        TOTAL=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1)
        FILE_COUNT=$(find "$BACKUP_DIR" -name "*.gz" -type f 2>/dev/null | wc -l | tr -d ' ')
        PROJECT_COUNT=$(find "$BACKUP_DIR" -maxdepth 1 -type d 2>/dev/null | tail -n +2 | wc -l | tr -d ' ')
        OLDEST="n/a"; NEWEST="n/a"
        while IFS= read -r f; do
            d=$(file_date_short "$f")
            if [[ "$OLDEST" == "n/a" || "$d" < "$OLDEST" ]]; then OLDEST="$d"; fi
            if [[ "$NEWEST" == "n/a" || "$d" > "$NEWEST" ]]; then NEWEST="$d"; fi
        done < <(find "$BACKUP_DIR" -name "*.gz" -type f 2>/dev/null)

        echo "  Total size:  $TOTAL"
        echo "  Files:       $FILE_COUNT"
        echo "  Projects:    $PROJECT_COUNT"
        echo "  Oldest:      ${OLDEST:-n/a}"
        echo "  Newest:      ${NEWEST:-n/a}"
        ;;

    install)
        echo "Installing pyre hooks into Claude Code..."

        if [[ ! -f "$SETTINGS_FILE" ]]; then
            echo '{}' > "$SETTINGS_FILE"
        fi

        # Use python3 to merge hooks into settings.json
        if [[ -z "$PYTHON" ]]; then
            echo "Error: python3 or python not found. Install Python to use pyre install/uninstall."
            exit 1
        fi
        "$PYTHON" -c "
import json, sys

with open('$SETTINGS_FILE') as f:
    settings = json.load(f)

hook_entry = [{
    'matcher': '',
    'hooks': [{'type': 'command', 'command': '$BACKUP_SCRIPT'}]
}]

if 'hooks' not in settings:
    settings['hooks'] = {}

settings['hooks']['PostToolUse'] = hook_entry
settings['hooks']['Stop'] = hook_entry

with open('$SETTINGS_FILE', 'w') as f:
    json.dump(settings, f, indent=2)
    f.write('\n')
"
        echo "Done. Hooks added to $SETTINGS_FILE"
        echo ""
        echo "pyre will now auto-backup sessions on every tool use and when Claude stops."
        ;;

    uninstall)
        echo "Removing pyre hooks from Claude Code..."

        if [[ ! -f "$SETTINGS_FILE" ]]; then
            echo "No settings file found. Nothing to remove."
            exit 0
        fi

        if [[ -z "$PYTHON" ]]; then
            echo "Error: python3 or python not found. Install Python to use pyre install/uninstall."
            exit 1
        fi
        "$PYTHON" -c "
import json

with open('$SETTINGS_FILE') as f:
    settings = json.load(f)

hooks = settings.get('hooks', {})
for event in ['PostToolUse', 'Stop']:
    if event in hooks:
        hooks[event] = [h for h in hooks[event]
                        if not any(hk.get('command','').endswith('pyre-backup.sh')
                                   for hk in h.get('hooks', []))]
        if not hooks[event]:
            del hooks[event]

if not hooks:
    del settings['hooks']

with open('$SETTINGS_FILE', 'w') as f:
    json.dump(settings, f, indent=2)
    f.write('\n')
"
        echo "Done. Pyre hooks removed."
        ;;

    check)
        # Silently check for crashed sessions on terminal startup
        # A "crashed" session = backup is newer than the session file, or session file is gone
        [[ -d "$BACKUP_DIR" ]] || exit 0

        CRASHED=()
        while IFS= read -r latest; do
            [[ -f "$latest" ]] || continue

            rel=$(echo "$latest" | sed "s|$BACKUP_DIR/||")
            project_hash=$(dirname -- "$rel")
            filename=$(basename -- "$latest")
            session_id=$(echo "$filename" | sed 's/_latest\.jsonl\.gz//')
            session_file="$PROJECTS_DIR/$project_hash/$session_id.jsonl"

            if [[ ! -f "$session_file" ]]; then
                # Session file is gone — definitely crashed
                CRASHED+=("$session_id|$project_hash|missing")
            else
                # Session file exists — check if backup is significantly newer
                backup_mtime=$(file_mtime "$latest" 2>/dev/null || echo 0)
                session_mtime=$(file_mtime "$session_file" 2>/dev/null || echo 0)
                diff=$((backup_mtime - session_mtime))
                # If backup is 60+ seconds newer, the session likely crashed after the backup
                if [[ "$diff" -gt 60 ]]; then
                    CRASHED+=("$session_id|$project_hash|stale")
                fi
            fi
        done < <(find "$BACKUP_DIR" -name "*_latest.jsonl.gz" -type f -mtime -3 2>/dev/null)

        if [[ ${#CRASHED[@]} -eq 0 ]]; then
            exit 0
        fi

        echo ""
        echo "  pyre: Found ${#CRASHED[@]} session(s) that may need recovery:"
        echo ""
        for entry in "${CRASHED[@]}"; do
            sid=$(echo "$entry" | cut -d'|' -f1)
            phash=$(echo "$entry" | cut -d'|' -f2)
            reason=$(echo "$entry" | cut -d'|' -f3)
            readable=$(echo "$phash" | sed 's|^-|/|; s|-|/|g')
            short_id="${sid:0:8}"
            if [[ "$reason" == "missing" ]]; then
                echo "    $short_id...  ($readable)  — session file missing"
            else
                echo "    $short_id...  ($readable)  — session may have crashed"
            fi
        done
        echo ""
        echo "  To restore:  pyre latest"
        echo "  To see all:  pyre list"
        echo ""
        ;;

    help|--help|-h|*)
        cat <<'HELP'
pyre — session crash recovery for Claude Code
https://github.com/phoenixstrategy/pyre

Usage:
  pyre install              Install backup hooks into Claude Code
  pyre uninstall            Remove hooks from Claude Code
  pyre enable               Start on boot (launchd on Mac, systemd on Linux)
  pyre disable              Stop starting on boot
  pyre start                Start the background daemon manually
  pyre stop                 Stop the background daemon
  pyre status               Check if the daemon is running
  pyre list [project]       List backed-up sessions
  pyre stats                Show backup storage usage
  pyre restore <id|file>    Restore a session from backup
  pyre latest [project]     Restore the most recent backup
  pyre cleanup [days]       Remove backups older than N days (default: 7)
  pyre check                Check for crashed sessions (runs on terminal start)

How it works:
  pyre backs up your Claude Code sessions two ways:

  1. Hooks — after every tool call, pyre saves your session instantly
  2. Daemon — a background watcher that catches anything hooks miss

  Backups are throttled (30s), rotated (50 max per session), and
  include subagent files when present.

Quick start:
  pyre install              # set up hooks (instant backups)
  pyre enable               # start on boot (background protection)
  pyre list                 # see what's backed up
  pyre latest myproject     # restore after a crash
HELP
        ;;
esac
