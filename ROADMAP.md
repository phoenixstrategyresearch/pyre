# pyre — Roadmap

## v1.0 — Launch (Current)

What we're shipping now. The foundation.

- [x] Auto-backup via Claude Code hooks (PostToolUse, Stop)
- [x] Background daemon that starts on boot (launchd/systemd)
- [x] CLI: list, restore, latest, stats, cleanup
- [x] One-command installer (`curl | bash`)
- [x] Cross-platform (macOS, Linux, WSL, Git Bash)
- [x] Terminal startup crash detection (`pyre check`)
- [x] Compressed + rotated snapshots (gzip, 50 max per session)
- [x] Subagent file backup
- [x] Clean uninstaller

---

## v1.1 — Polish

Make it bulletproof for non-technical users.

- [ ] `pyre doctor` — diagnostics command
  - Check if hooks are installed in settings.json
  - Check if daemon is running
  - Check if backup directory exists and is writable
  - Check if pyre-backup.sh is executable
  - Check disk space
  - Verify Python is available
  - Print a clear pass/fail report with fix suggestions

- [ ] `pyre --version` — version flag across all scripts

- [ ] `pyre log` — shortcut to tail the daemon log
  - `pyre log` — last 20 lines
  - `pyre log -f` — follow (live tail)

- [ ] macOS/Linux notifications on crash detection
  - macOS: `osascript` notification when `pyre check` finds crashed sessions
  - Linux: `notify-send` if available
  - Fallback to terminal output if neither works

- [ ] CONTRIBUTING.md
  - How to run/test locally
  - PR guidelines (keep it simple, bash only)
  - Issue templates

---

## v1.2 — Distribution

Make it easy to install everywhere.

- [ ] Homebrew tap — `brew install phoenixstrategy/tap/pyre`
- [ ] npm wrapper — `npx pyre-cli install`
- [ ] AUR package for Arch Linux
- [ ] GitHub Releases with tagged versions
- [ ] GitHub Actions CI — shellcheck linting on PRs

---

## v1.3 — Power Features

For developers who want more.

- [ ] `pyre export <session>` — export backup to readable markdown
  - Parse JSONL, extract user messages + assistant responses
  - Clean formatting for sharing or archiving
  - Optional: export to HTML

- [ ] Pre-compaction hook — back up right before Claude's context compaction
  - Hook into PreCompact event
  - Save full context before the lossy summarization happens
  - This is the #1 silent data loss vector people don't know about

- [ ] `pyre diff <session> [snapshot1] [snapshot2]` — compare two snapshots
  - See what was added between backups
  - Useful for understanding what was lost in a crash

- [ ] `pyre search <query>` — search across all backed-up sessions
  - grep through decompressed JSONL
  - Find that conversation where you solved a specific bug

---

## v1.4 — Cloud & Sync

Optional remote backup for teams and paranoid individuals.

- [ ] `pyre sync` — push backups to remote storage
  - S3 / R2 / GCS support
  - Git repo sync (private repo as backup target)
  - iCloud Drive / Dropbox folder sync (just set backup dir)
- [ ] `pyre sync pull` — restore from remote on a new machine
- [ ] Encryption at rest — AES-256 before upload
- [ ] Team dashboard — shared backup visibility (stretch)

---

## v2.0 — Intelligent Recovery

Where PSG AI meets pyre.

- [ ] Smart restore — AI-powered session summarization on restore
  - When restoring a long session, generate a concise summary of where you were
  - Inject as context so Claude picks up faster

- [ ] Session health monitoring — detect corruption before it's too late
  - Watch for truncated JSONL, zero-byte files, index mismatches
  - Alert before you lose anything

- [ ] Cross-device session handoff
  - Start on your desktop, pick up on your laptop
  - Cloud sync + smart context injection

- [ ] VS Code extension
  - Integrate pyre directly into the editor
  - Visual timeline of session snapshots
  - One-click restore

---

## PSG Plug — Enhancements

Things to add to the README/marketing as we ship features.

### v1.1 launch
- Add a "Why we built this" section
  - PSG AI engineers hit this problem daily building agentic systems for clients
  - We lost sessions, built the fix, open-sourced it
  - Mention the 15+ GitHub issues, the dev who lost 47 conversations
  - Position PSG AI as practitioners, not just consultants

### v1.2 launch
- Add install count badge (GitHub releases downloads)
- Add "Used by X engineers" once we have traction
- Add testimonials/quotes from early adopters

### v1.3 launch
- Blog post: "How We Built pyre — Crash Recovery for Claude Code"
  - Technical deep dive on hooks, daemon architecture, cross-platform challenges
  - Publish on phoenixstrategy.group/blog
  - Cross-post to DEV Community, Hacker News, Reddit r/ClaudeCode

### v1.4 launch
- Case study: "PSG AI's Private Infrastructure Stack"
  - Mac Studios / DGX Sparks / tinyboxes / on-site servers / AWS
  - How pyre fits into the broader PSG AI toolchain
  - Lead gen for enterprise AI consulting

### v2.0 launch
- Position PSG AI as the company that builds AI tools for AI engineers
- "We don't just implement AI for clients — we build the tools the community needs"
- Open source as a growth channel for PSG AI consulting

---

## Standing Principles

- pyre stays simple — bash scripts, no compiled dependencies
- Every feature must work offline
- Cloud features are always optional, never required
- Non-technical users should never need to read code to use it
- PSG plug should feel natural, not forced — earn attention by shipping great tools
