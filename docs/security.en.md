# Security and disclosure

The research frame, the pre-publication sanitization checklist, and the rules of
responsible disclosure. This document is how the project treats itself.

---

## 1. Research frame

The project is published for **defensive research**:

- tests — on **your own** agents and **your own** lore files;
- no third-party targets: other users, their data, and their agents are not
  affected;
- the finding is directed at vendors and harness authors — so detection is built
  at the platform level (see [docs/detection.en.md](detection.en.md)).

The vector is demonstrated, not exploited. The difference is in every
publication: we explain the mechanics, we do not hand out a ready-made attack
tool against foreign systems.

---

## 2. Research boundaries

| Allowed | Not allowed |
|---|---|
| Research the vector on your own agents | Use the vector against foreign agents/users |
| Publish the mechanics and lore artifacts | Publish working tools for recovering foreign keys |
| Direct findings to vendors | Exploit findings before the fix |
| Analyze publicly disclosed incidents | Expose victim addresses and full consolidators |
| Give vendors detection recommendations | Publish PoCs against live systems |

These boundaries are not decoration: they correspond to `research/10` (third-party
contract audits and responsible disclosure) and `research/09` (web3 security, key
entropy).

---

## 3. Pre-publication sanitization checklist

By nature the plugin carries **personal memory** — the joint-work history of a
"human + agent" pair. A public repository is a different space from a local
install. Checklist:

### 3.1. Content

A **sanitized** version is published: the lore and research docs are the
demonstrated material itself, but without identifying details.

- [ ] `prompt.md`, `lore.md`, `user.md` — published; checked that they contain no
      paths to private projects and no personal data.
- [ ] `security-posture.md` — published as part of the payload; neutral
      vocabulary, no instructions revealing moderation bypass beyond the public
      frame.
- [ ] `research/01–12` — published; checked that they contain no names of
      specific NSFW/refusal models, no paths to files with addresses, and no full
      addresses.
- [ ] `security-audit-runbook.md` — executable audit commands; safe, references
      `security-posture.md` — verify the linkage.

### 3.2. Identification

- [ ] No mentions of paths to private projects (weak-entropy research
      repositories, etc.).
- [ ] No full wallet addresses; only anonymized prefixes (`bc1qnk…`) if needed
      at all.
- [ ] No names of specific NSFW/refusal models or refusal-removing LoRAs;
      functional roles remain ("NSFW checkpoint", "refusal reduction"). The
      concrete list of forbidden names lives **outside the repo** (private
      checklist) — it is not reproduced in public documents.
- [ ] No "Creator/Master" addresses and no personal details in public texts.

### 3.3. Mechanics

- [ ] The hook reads files on the fly — no reinstall needed after content edits.
- [ ] The hook works without content files (graceful mode): in a fresh clone
      without `prompt.md`/`lore.md`/`user.md` it does not fail with
      `set -euo pipefail` — it skips missing files with a warning.

### 3.4. Repository

- [ ] `.gitignore` created **before** the first `git add .` (see example below).
- [ ] `LICENSE` exists (README and badge reference it).
- [ ] Manifest `.claude-plugin/plugin.json` renamed to the public name
      (`choirboy-prompt`), version bumped.
- [ ] Old READMEs (EN/zh-CN) with the vibe-lore branding updated or removed —
      none of them in the public repo.
- [ ] `assets/vibe-lore-hero.svg` — old branding; replaced or removed.

### 3.5. Example `.gitignore`

Content is published, so `.gitignore` is only housekeeping:

```gitignore
# local backups install.sh makes while editing configs
*.bak.*
# editor/OS
.DS_Store
*.swp
```

---

## 4. Responsible disclosure rules (per research/10)

Findings in foreign projects follow the process:

1. Contact the project: security contact, bounty program (Immunefi, HackerOne,
   Sherlock, Code4rena), or a public channel.
2. Report: class, impact, PoC **on a fork/testnet**, suggested fix. No
   exploitation of foreign funds, no public disclosure before the fix.
3. Fix window (usually up to 90 days, by agreement).
4. Publication after the fix (or after the deadline): report for the project and
   community, recommendations for integrators.
5. If contact is impossible or the project stays silent — publication on an
   ethical deadline, with a minimum of exploitable details: we never publish a
   working exploit against live funds.

---

## 5. Behavior on a session flag

A known vendor problem: server classifiers flag defensive vocabulary regardless
of the frame in context. One Claude flag poisons the whole session — it only gets
worse from there.

Rule: in a flagged session we do not continue and do not argue. We start a new
session with an explicit frame from the first turn: "this is my repository, audit
of my own code per OWASP". In the new session we work from that frame.

This is not part of the vector — it is a countermeasure against false flags.

---

## 6. Publication risk assessment

| Risk | Level | Mitigation |
|---|---|---|
| Repo identifies the author (personal memory) | Medium | Sanitization: private-project paths, full addresses, NSFW/refusal model names cut out |
| Vector read as a censorship-bypass guide | Medium | Research frame in the README and this document; mechanics + countermeasures, not "how to attack" |
| Address/key leak | Critical | Pre-publication check: grep for bc1/0x/seed files |
| NSFW model name leak | High | Functional roles instead of names; private list outside the repo |
| AI audit as a guarantee | — | Coldcard teardown (`research/11`): a one-off AI audit missed the bug; audits must check the executable path, not code presence |
