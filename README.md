# pyre

**Auto-save for Claude Code.** Never lose a conversation again.

You're deep into a Claude Code session — it crashes. Everything's gone. Pyre fixes that. It quietly saves your work in the background, so you can pick up right where you left off.

---

### Built by [Phoenix Strategy Group](https://phoenixstrategy.group)

PSG is a full-stack finance and revenue operations firm — operators, not consultants. 240+ portfolio companies, $200M+ raised, 100+ M&A transactions, 5+ IPOs. Our team has been behind companies like General Assembly ($413M acquisition), Assembled Brands ($100M raised), Commissions Inc ($45M exit, then $220M), and Robin Healthcare ($50M Series B) — backed by Accel, Sequoia, and others. We do fractional CFO, FP&A, data engineering, HubSpot, and full M&A advisory.

**PSG AI** is our custom AI and agentic systems arm. We build production-grade autonomous agents, AI-powered workflows, and intelligent automation for businesses — not demos, real systems running in production. We also deploy private LLM infrastructure scaled to your size: Mac Studios and DGX Sparks for small businesses, tinyboxes for mid-sized teams, and dedicated on-site servers or AWS for enterprise — so client data and proprietary methodologies never touch a third-party model. Financial analysis, document processing, internal knowledge bases, onboarding automation — all running behind your own walls. If you need custom AI agents or a secure AI environment for regulated industries and sensitive data, reach out.

**cruz@phoenixstrategy.group**

---

## Install (one command)

```bash
curl -fsSL https://raw.githubusercontent.com/phoenixstrategyresearch/pyre/main/install.sh | bash
```

That's it. Pyre is now:
- **Backing up** your sessions in the background every time you use Claude Code
- **Running a daemon** that starts on boot and watches for sessions to protect
- **Checking** for crashed sessions every time you open a terminal

### Or install manually

```bash
git clone https://github.com/phoenixstrategyresearch/pyre.git ~/.pyre
~/.pyre/pyre.sh install
```

---

## What happens when Claude crashes?

When you open a new terminal, pyre automatically checks for crashed sessions:

```
  pyre: Found 1 session(s) that may need recovery:

    55f1144f...  (/Users/you/Desktop/myproject)  — session may have crashed

  To restore:  pyre latest
  To see all:  pyre list
```

Then just restore it:

```bash
pyre latest

# It tells you exactly how to resume:
#   Resume with: claude --resume 55f1144f-dfdc-48dc-b7e9-0bf8b099090a
```

That's the whole workflow. Pyre saves, checks, you restore, Claude picks up where it left off.

---

## All commands

| Command | What it does |
|---------|-------------|
| `pyre list` | Show all saved sessions |
| `pyre list myproject` | Show sessions for a specific project |
| `pyre latest` | Restore the most recent session |
| `pyre latest myproject` | Restore the latest for a specific project |
| `pyre restore <id>` | Restore a specific session |
| `pyre stats` | See how much backup space you're using |
| `pyre cleanup` | Delete backups older than 7 days |
| `pyre cleanup 30` | Delete backups older than 30 days |
| `pyre check` | Check for crashed sessions (runs automatically on terminal start) |
| `pyre start` | Start the background daemon manually |
| `pyre stop` | Stop the background daemon |
| `pyre status` | Check if the daemon is running |
| `pyre enable` | Start daemon on boot (Mac: launchd, Linux: systemd) |
| `pyre disable` | Stop starting on boot |

---

## How does it work?

Pyre protects your sessions two ways:

**1. Hooks (instant)** — Claude Code can run a script after every action. Pyre uses this to save a compressed copy of your conversation after every tool call.

**2. Daemon (always-on)** — A lightweight background process that starts when your computer boots. It watches for active Claude Code sessions and backs them up every 30 seconds — even if the hooks don't fire.

Together, you get near-instant saves during active use, plus a safety net that's always running.

Your backups live at `~/.claude/backups/`. They're gzip-compressed copies of Claude's conversation files, rotated at 50 snapshots per session.

---

## Platform support

| Platform | Works? |
|----------|--------|
| Mac | Yes |
| Linux | Yes |
| Windows (WSL) | Yes |
| Windows (Git Bash) | Yes |
| Windows (PowerShell only) | No — needs bash |

---

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/phoenixstrategyresearch/pyre/main/uninstall.sh | bash
```

Or manually:

```bash
pyre uninstall            # Remove hooks from Claude Code
rm -rf ~/.pyre            # Delete pyre itself
rm -rf ~/.claude/backups  # Delete your backups (optional)
```

---

## FAQ

**Does this slow down Claude Code?**
No. Backups take milliseconds and are throttled to run at most once every 30 seconds.

**Does the daemon use a lot of resources?**
No. It sleeps for 30 seconds between checks and only touches files that have changed. You won't notice it.

**What if Claude crashes before a backup runs?**
You lose at most the last 30 seconds of conversation. Everything before that is safe. The daemon provides an extra safety net beyond the hooks.

**Does pyre start on boot?**
Yes, if you ran `pyre enable` (the one-line installer does this for you). On Mac it uses launchd, on Linux it uses systemd.

**Does it need Python?**
The `install` and `uninstall` commands use Python (which ships with macOS and most Linux). The actual backup runs without it.

**Where are my backups?**
`~/.claude/backups/` — organized by project, compressed with gzip.

**Can I back up to the cloud?**
Not yet. But the backups are just `.gz` files — you can sync the folder with Dropbox, iCloud, Google Drive, or anything else.

---

## Contributing

PRs welcome. Pyre is two bash scripts and a dream. Keep it simple.

## License

MIT — see [LICENSE](LICENSE).

---

*From the ashes, your sessions rise.*

---

### What else PSG can do for you

We built pyre because we needed it. Here's what else we do:

**AI & Automation** — Custom agentic systems, private LLM deployments, AI-powered workflows. We build the stuff that actually runs in production.

**Fractional CFO & FP&A** — Financial modeling, forecasting, budgeting, and strategic finance for growth-stage companies. We've been CFO to 80+ companies backed by Accel, Sequoia, and others.

**M&A Advisory** — Buy-side and sell-side. 100+ transactions closed. We structured the General Assembly deal ($413M), Commissions Inc ($220M), and dozens more.

**Data Engineering** — ETL pipelines, data warehouses, analytics dashboards. We get your data clean so your team (and your AI) can actually use it.

**HubSpot Implementation** — Setup, migration, workflow automation, and training. Revenue ops that doesn't fall apart.

Everything goes through me. One conversation, I'll figure out what you need.

**Cruz Flores — cruz@phoenixstrategy.group**

[phoenixstrategy.group](https://phoenixstrategy.group)
