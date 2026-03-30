#!/usr/bin/env bash
# pyre-daemon.sh — background watcher that backs up Claude Code sessions
# Runs on boot via launchd (macOS) or systemd (Linux)
# Watches ~/.claude/projects/ for active sessions and backs them up every 30s
set -euo pipefail

BACKUP_DIR="$HOME/.claude/backups"
PROJECTS_DIR="$HOME/.claude/projects"
MAX_BACKUPS=50
INTERVAL=30

mkdir -p "$BACKUP_DIR"

# Cross-platform stat
if stat -f %m / >/dev/null 2>&1; then
    file_mtime() { stat -f %m "$1"; }
else
    file_mtime() { stat -c %Y "$1"; }
fi

log() {
    echo "[pyre $(date '+%H:%M:%S')] $*"
}

backup_session() {
    local session_file="$1"
    local rel_path="${session_file#$PROJECTS_DIR/}"
    local project=$(dirname -- "$rel_path")
    local filename=$(basename -- "$rel_path" .jsonl)

    # Skip subagent files
    [[ "$rel_path" == *"/subagents/"* ]] && return 0

    local session_backup_dir="$BACKUP_DIR/$project"
    mkdir -p "$session_backup_dir"

    local latest="$session_backup_dir/${filename}_latest.jsonl.gz"

    # Throttle: skip if backup is already up to date
    if [[ -f "$latest" ]]; then
        local backup_mtime=$(file_mtime "$latest" 2>/dev/null || echo 0)
        local session_mtime=$(file_mtime "$session_file" 2>/dev/null || echo 0)
        if [[ "$backup_mtime" -ge "$session_mtime" ]]; then
            return 0
        fi
    fi

    # Backup
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local dest="$session_backup_dir/${filename}_${timestamp}.jsonl.gz"
    gzip -c "$session_file" > "$dest"
    cp "$dest" "$latest"

    # Backup subagents if they exist
    local subagent_dir="$PROJECTS_DIR/$project/$filename/subagents"
    if [[ -d "$subagent_dir" ]]; then
        tar -czf "$session_backup_dir/${filename}_subagents_${timestamp}.tar.gz" -C "$subagent_dir" . 2>/dev/null || true
    fi

    # Rotate old backups
    local count=$(ls -1 "$session_backup_dir/${filename}_2"*.jsonl.gz 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$count" -gt "$MAX_BACKUPS" ]]; then
        ls -1t "$session_backup_dir/${filename}_2"*.jsonl.gz | tail -n +$((MAX_BACKUPS + 1)) | xargs rm -f
        ls -1t "$session_backup_dir/${filename}_subagents_"*.tar.gz 2>/dev/null | tail -n +$((MAX_BACKUPS + 1)) | xargs rm -f 2>/dev/null || true
    fi

    log "backed up $filename"
}

log "daemon started — watching $PROJECTS_DIR"

while true; do
    # Find session files modified in the last 2 hours
    if [[ -d "$PROJECTS_DIR" ]]; then
        find "$PROJECTS_DIR" -name "*.jsonl" -mmin -120 -type f 2>/dev/null | while read -r session_file; do
            backup_session "$session_file"
        done
    fi
    sleep "$INTERVAL"
done
