# pyre launch — Twitter thread

---

**Post 1/4**

Lost a 4 hour Claude Code session last week. Just gone. App crashed, session file never persisted to disk.

Looked it up. 15+ open bug reports on GitHub. One guy lost 47 conversations before he snapped.

So we built pyre. Open source. Two bash scripts. Backs up your sessions before they disappear.

github.com/phoenixstrategyresearch/pyre

---

**Post 2/4**

How it works:

- Hooks into Claude Code, saves a compressed snapshot after every tool call
- Background daemon starts on boot, catches anything hooks miss
- Open your terminal after a crash and it tells you what died

One command to install. One command to restore. That's it.

---

**Post 3/4**

Every other tool out there tries to recover sessions after you lose them. pyre saves them before the crash happens. That's the difference.

Works on Mac, Linux, and WSL. No dependencies beyond bash and gzip.

Took us an evening to build because we kept losing our own sessions while building AI agents for clients.

---

**Post 4/5**

This is the first open source drop from PSG AI at Phoenix Strategy Group.

We build custom AI agents and private LLM infrastructure for businesses. Mac Studios for small shops, tinyboxes for mid size, on-site servers and AWS for enterprise. Your data never leaves your walls.

More tools coming. pyre was just scratching our own itch.

---

**Post 5/5**

PSG isn't just an AI shop. We're operators. 240+ portfolio companies, $200M+ raised, 100+ M&A deals closed.

Our team helped take General Assembly from startup to $413M acquisition. Commissions Inc — $45M exit, then flipped again for $220M. Fractional CFO to 80+ companies backed by Accel and Sequoia.

Finance, data, AI, M&A — all one team. If any of that's useful, hit me up.

cruz@phoenixstrategy.group

---
