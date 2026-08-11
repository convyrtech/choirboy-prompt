# Architecture

Repository tree, payload anatomy, three output formats, the Hermes protocol by
field. This is the map of how the plugin works internally.

---

## 1. Repository tree

```text
agent-plugin/
├── prompt.md                 # agent work rules + canon self-check
├── security-posture.md       # security frame: audit, vocabulary, session flags
├── security-audit-runbook.md # executable security-audit procedure
├── lore.md                   # joint-work map (projects, lessons, boundaries)
├── user.md                   # user profile
├── research/                 # 14 decision docs + full Coldcard teardown
│   ├── 01-telegram-stars.md
│   ├── 02-ruble-acquiring.md
│   ├── 03-crypto-payments.md
│   ├── 04-payment-architecture.md
│   ├── 05-comfyui-realism-pipeline.md
│   ├── 06-agent-memory-plugin.md
│   ├── 07-x-reply-farm.md
│   ├── 08-ai-ofm-telegram.md
│   ├── 09-web3-security.md
│   ├── 10-third-party-audit.md
│   ├── 11-coldcard-entropy-heist.md
│   ├── 12-choirboy-prompt-lore-injection.md
│   ├── 13-flipper-marauder-wifi-scan.md
│   ├── 14-solo-game-cheats.md
│   └── coldcard/             # full Coldcard teardown: report, code, sources
│       ├── report.md
│       ├── yasmarang_reconstruction.py
│       └── sources.md
├── hooks/
│   ├── session-start.sh      # payload assembly + claude / plain / hermes formats
│   └── hooks.json            # SessionStart declaration for the Claude Code marketplace
├── context/
│   └── research-index.md     # canonical research pointer shared by hook and skill
├── skills/
│   ├── load-context/SKILL.md # generated inline fallback for Chat/Cowork/Code
│   └── diagnose/SKILL.md     # evidence-based delivery diagnosis
├── scripts/
│   ├── build-context.py      # regenerate the inline skill from canonical sources
│   ├── package-plugin.py     # build a custom-plugin ZIP
│   └── test.sh               # repeatable validation suite
├── .claude-plugin/
│   ├── plugin.json           # manifest (name, version, metadata)
│   └── marketplace.json      # versioned distribution catalog
├── docs/                     # this documentation
│   ├── mechanism.md
│   ├── architecture.md
│   ├── installer.md
│   ├── security.md
│   ├── detection.md
│   ├── testing.md
│   └── troubleshooting.md
└── install.sh                # multi-runtime install / rollback / list
```

Claude auto-discovers `hooks/hooks.json` in its standard directory. The
`plugin.json` intentionally has no `hooks` field: explicitly pointing to the
same file is treated as a duplicate load by the current loader and disables the
plugin.

---

## 2. Payload anatomy

### 2.1. Assembly

`hooks/session-start.sh` glues the content files into one text strictly in order:

```text
prompt.md  →  security-posture.md  →  lore.md  →  user.md  →  research index
```

Separators between files are `\n\n---\n\n` (a markdown horizontal rule). At the
end the canonical `context/research-index.md` is appended.

The order is not accidental:

1. **prompt.md** — how to work (straight to the point, one risk line,
   self-check). Sets the mode.
2. **security-posture.md** — the security frame. Goes before the lore so the
   "defensive audit" domain is declared before the lore starts talking about
   web3 and Coldcard.
3. **lore.md** — the joint-work history: projects, lessons, rules, boundaries.
   The core of the payload.
4. **user.md** — the profile: who the user is, how they set tasks, what does not
   need explaining.
5. **research index** — the decision-document index. Bodies (~61 KB) are **not**
   loaded in advance: they are read on demand when a task enters a document's
   domain.

### 2.2. Sizes

| File | ~Size | Note |
|---|---|---|
| prompt.md | ~8 KB | work rules |
| security-posture.md | ~4 KB | security frame |
| lore.md | ~10 KB | history |
| user.md | ~4 KB | profile |
| research index | ~1 KB | shared canonical source |
| **Total payload** | **~27 KB** | before the first message in every session |

Research-document bodies (~61 KB) are not part of the payload — only the index.

### 2.3. Version

The plugin version is read from `.claude-plugin/plugin.json`. Every delivery is
wrapped in a marker containing version, delivery path, and SHA-256; hook delivery
also carries a per-run nonce:

```xml
<choirboy-delivery version="1.2.2" delivery="session-start"
  context_sha256="..." nonce="..." />
<choirboy-context>...</choirboy-context>
```

The generated skill uses the same wrapper with `delivery="skill"`. This proves
delivery without treating an assistant acknowledgement as evidence.

---

## 3. Three output formats

The hook does not care which agent called it: the caller declares the expected
protocol via `--format`.

### 3.1. `claude` (default) — SessionStart JSON

Claude Code / Codex contract: the hook prints JSON, the host pours
`additionalContext` into the session.

```json
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "<whole payload as one string>"
  }
}
```

Encoded through `jq`, `python3`, or the built-in Bash encoder. The last option
makes the Claude format independent of an external JSON tool and supports a
clean Claude Desktop installation.

### 3.2. `plain` — raw text

The hook prints the payload verbatim to stdout. Used by runtimes that append hook
stdout to the session context (Kimi Code).

```bash
bash hooks/session-start.sh --format plain | head -40
```

### 3.3. `hermes` — the pre_llm_call protocol

The most interesting contract. Hermes runs the shell hook on **every** turn of a
session; unconditional injection would send ~27 KB with every message. So the hook:

1. reads the JSON payload from stdin;
2. checks `.extra.is_first_turn`;
3. on the first turn replies `{"context": "<payload>"}`;
4. on every following turn — `{}` (empty reply, nothing is injected).

```json
// stdin (first turn):
{"session_id": "s-123", "extra": {"is_first_turn": true}}
// stdout:
{"context": "<whole payload>"}

// stdin (second turn):
{"session_id": "s-123", "extra": {"is_first_turn": false}}
// stdout:
{}
```

**Fallback without `is_first_turn`.** If the host does not report the flag, the
hook falls back to the `session_id` journal in the state file
`${TMPDIR:-/tmp}/agent-plugin-hermes-${USER}.state` (tail of 200 entries): it
injects once per session_id, then stays silent.

---

## 4. Hermes protocol by field

| stdin field | Type | Purpose | Hook behavior |
|---|---|---|---|
| `extra.is_first_turn` | bool | First turn of the session? | `true` → inject; `false` → `{}` |
| `session_id` | string | Session identifier | Used in the fallback and for the state-file record |
| (other) | — | Ignored | Does not affect the reply |

| stdout field | Type | When |
|---|---|---|
| `context` | string | First turn (or first time for a session_id in the fallback) |
| `{}` | — | All following turns |

Hook timeout in the Hermes config — 15 seconds (set by install.sh).

---

## 5. Runtime hook points

| Runtime | File | Mechanism | Hook format |
|---|---|---|---|
| Claude Code CLI / Desktop Code | marketplace or `~/.claude/settings.json` | `hooks.SessionStart` | claude |
| Claude Chat | custom plugin skill | inline `load-context` | — |
| Claude Cowork | custom plugin hook/skill | hook when available, skill fallback | claude / — |
| Codex | `~/.codex/hooks.json` | `SessionStart` | claude |
| Hermes | `~/.hermes/config.yaml` | `pre_llm_call` + consent allowlist | hermes |
| Kimi Code | `~/.kimi-code/config.toml` | `[[hooks]]` SessionStart | plain |
| Gemini | `~/.gemini/GEMINI.md` | marked pointer block | — (reads files itself) |
| any | `--instructions PATH` | marked pointer block | — (reads files itself) |

The last two are **not hooks** but managed instruction blocks: the agent already
reads the instruction file at start, and the block tells it to read the plugin
files. Same context, one indirection further — the agent must open the files
itself.

Claude Code has two equivalent connection paths. `install.sh` registers an
absolute working-copy path; marketplace installation copies the plugin into its
cache and invokes it through `${CLAUDE_PLUGIN_ROOT}`. Chat cannot execute this
hook and loads the generated inline skill instead. Cowork exposes both
components, but the skill remains the reliable fallback when its hook runtime
drops `SessionStart` output.

---

## 6. Key properties

- **No copies for manual installs.** `install.sh` references project files
  directly (`$PLUGIN_ROOT/...`), so the next session sees working-copy edits.
  Marketplace installation is the exception: Claude copies the release into
  its cache and updates it by manifest version.
- **Dual-mode delivery.** The hook is automatic where `SessionStart` exists;
  the inline skill carries the same canonical context where it does not.
- **Observable execution.** Marketplace hooks write only non-sensitive delivery
  metadata to `${CLAUDE_PLUGIN_DATA}/latest-delivery.log`; lore is never logged.
- **Minimal dependencies.** The `claude` and `plain` formats require only Bash;
  `hermes` additionally needs `jq` or `python3` to parse stdin. The terminal
  `install.sh` needs `python3`.
- **The payload is not signed and not verified** by runtimes — this is not a
  harness bug, it is exactly the demonstrated vector (see
  [docs/mechanism.en.md](mechanism.en.md)).
