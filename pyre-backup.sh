#!/usr/bin/env bash
# pyre-backup.sh — lightweight session crash recovery for Claude Code
# https://github.com/phoenixstrategy/pyre
#
# Triggered by Claude Code hooks: PostToolUse, Stop
# Backs up active session .jsonl files to ~/.claude/backups/

set -euo pipefail

BACKUP_DIR="$HOME/.claude/backups"
PROJECTS_DIR="$HOME/.claude/projects"
MAX_BACKUPS=50          # per session — rotate old snapshots
THROTTLE_SECONDS=30     # skip if last backup was < 30s ago

mkdir -p "$BACKUP_DIR"

# Find python
PYTHON=""
for p in python3 python; do
    command -v "$p" >/dev/null 2>&1 && PYTHON="$p" && break
done

# Cross-platform stat for file mtime (epoch seconds)
if stat -f %m / >/dev/null 2>&1; then
    file_mtime() { stat -f %m "$1"; }
else
    file_mtime() { stat -c %Y "$1"; }
fi

# Parse hook input from stdin (JSON with session_id, cwd, etc.)
INPUT=$(cat)
if [[ -n "$PYTHON" ]]; then
    SESSION_ID=$(echo "$INPUT" | "$PYTHON" -c "import sys,json; d=json.load(sys.stdin); print(d.get('session_id',''))" 2>/dev/null || true)
    CWD=$(echo "$INPUT" | "$PYTHON" -c "import sys,json; d=json.load(sys.stdin); print(d.get('cwd',''))" 2>/dev/null || true)
else
    # Fallback: parse JSON without python (basic grep)
    SESSION_ID=$(echo "$INPUT" | grep -o '"session_id"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"session_id"[[:space:]]*:[[:space:]]*"//;s/"$//' || true)
    CWD=$(echo "$INPUT" | grep -o '"cwd"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"cwd"[[:space:]]*:[[:space:]]*"//;s/"$//' || true)
fi

# If we got a session_id and cwd, target that specific session
if [[ -n "$SESSION_ID" && -n "$CWD" ]]; then
    # Derive project dir from cwd (same encoding Claude Code uses)
    # Normalize Windows paths: C:\foo\bar -> /C/foo/bar, then encode
    NORMALIZED_CWD=$(echo "$CWD" | sed 's|\\|/|g; s|^\([A-Za-z]\):|/\1|')
    PROJECT_HASH=$(echo "$NORMALIZED_CWD" | sed 's|/|-|g')
    SESSION_FILE="$PROJECTS_DIR/$PROJECT_HASH/$SESSION_ID.jsonl"

    if [[ ! -f "$SESSION_FILE" ]]; then
        exit 0
    fi

    SESSION_BACKUP_DIR="$BACKUP_DIR/$PROJECT_HASH"
    mkdir -p "$SESSION_BACKUP_DIR"

    # Throttle: skip if last backup is recent
    LATEST="$SESSION_BACKUP_DIR/${SESSION_ID}_latest.jsonl.gz"
    if [[ -f "$LATEST" ]]; then
        LAST_MOD=$(file_mtime "$LATEST" 2>/dev/null || echo 0)
        NOW=$(date +%s)
        DIFF=$((NOW - LAST_MOD))
        if [[ $DIFF -lt $THROTTLE_SECONDS ]]; then
            exit 0
        fi
    fi

    # Backup with timestamp
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    DEST="$SESSION_BACKUP_DIR/${SESSION_ID}_${TIMESTAMP}.jsonl.gz"
    gzip -c "$SESSION_FILE" > "$DEST"

    # Also keep a "latest" copy for quick restore
    cp "$DEST" "$LATEST"

    # Also backup subagent files if they exist
    SUBAGENT_DIR="$PROJECTS_DIR/$PROJECT_HASH/$SESSION_ID/subagents"
    if [[ -d "$SUBAGENT_DIR" ]]; then
        SUBAGENT_BACKUP="$SESSION_BACKUP_DIR/${SESSION_ID}_subagents_${TIMESTAMP}.tar.gz"
        tar -czf "$SUBAGENT_BACKUP" -C "$SUBAGENT_DIR" . 2>/dev/null || true
    fi

    # Rotate: keep only MAX_BACKUPS per session
    BACKUP_COUNT=$(ls -1 "$SESSION_BACKUP_DIR/${SESSION_ID}_2"*.jsonl.gz 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$BACKUP_COUNT" -gt "$MAX_BACKUPS" ]]; then
        ls -1t "$SESSION_BACKUP_DIR/${SESSION_ID}_2"*.jsonl.gz | tail -n +$((MAX_BACKUPS + 1)) | xargs rm -f
        ls -1t "$SESSION_BACKUP_DIR/${SESSION_ID}_subagents_"*.tar.gz 2>/dev/null | tail -n +$((MAX_BACKUPS + 1)) | xargs rm -f 2>/dev/null || true
    fi

    exit 0
fi

# Fallback: if no session_id in input, backup ALL recent sessions (modified in last hour)
find "$PROJECTS_DIR" -name "*.jsonl" -mmin -60 -type f 2>/dev/null | while read -r SESSION_FILE; do
    REL_PATH="${SESSION_FILE#$PROJECTS_DIR/}"
    PROJECT=$(dirname -- "$REL_PATH")
    FILENAME=$(basename -- "$REL_PATH" .jsonl)

    # Skip subagent files in fallback
    if [[ "$REL_PATH" == *"/subagents/"* ]]; then
        continue
    fi

    SESSION_BACKUP_DIR="$BACKUP_DIR/$PROJECT"
    mkdir -p "$SESSION_BACKUP_DIR"

    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    gzip -c "$SESSION_FILE" > "$SESSION_BACKUP_DIR/${FILENAME}_${TIMESTAMP}.jsonl.gz"
done
