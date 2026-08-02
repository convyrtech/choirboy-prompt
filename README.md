<div align="center">

# choirboy-prompt

<h3>Lore injection: how fabricated memory becomes model trust</h3>

<p>
<strong>lore</strong> · <strong>injection</strong> · <strong>provenance</strong> ·
<strong>trust</strong> · <strong>harness</strong>
</p>

<p>
<strong>Read this in other languages</strong><br>
<a href="README.md">🇺🇸 English</a> ·
<a href="README.ru.md">🇷🇺 Русский</a> ·
<a href="README.zh-CN.md">🇨🇳 简体中文</a>
</p>

<p>
<img alt="Bash 5.0+" src="https://img.shields.io/badge/bash-5.0%2B-4EAA25?style=flat-square&logo=gnubash&logoColor=white">
<img alt="runtimes" src="https://img.shields.io/badge/runtimes-claude%20%C2%B7%20codex%20%C2%B7%20hermes%20%C2%B7%20kimi%20%C2%B7%20gemini-22D3EE?style=flat-square">
<a href="LICENSE"><img alt="MIT" src="https://img.shields.io/badge/license-MIT-3FB950?style=flat-square"></a>
</p>

<p>
<strong>One plugin turns text files into the "memory" of any agent — and shows what the model does with that memory.</strong><br>
choirboy-prompt is a research harness: a SessionStart hook injects a fixed lore
into every agent session and demonstrates the <em>fabricated-provenance trust</em> vector:
the model takes a planted history of "joint work" for its own and transfers trust
to the person that history describes.
</p>

</div>

```bash
git clone https://github.com/howdeploy/choirboy-prompt.git
cd choirboy-prompt
./install.sh
```

<div align="center">
<p>
Linux · macOS · python3 or jq · any of the five runtimes<br>
Roll back at any time: <code>./install.sh --uninstall</code>
</p>
</div>

<div align="center">
<p>
<a href="#why-this-exists">Why</a> ·
<a href="#capability-map">Capabilities</a> ·
<a href="#how-it-works">How it works</a> ·
<a href="#why-it-works">Research</a> ·
<a href="#quick-start">Quick start</a> ·
<a href="#documentation">Documentation</a> ·
<a href="#known-limitations">Limitations</a>
</p>
</div>

---

## Why this exists

Classic prompt injection plants an instruction. We research a different vector:
**forging the provenance of memory**. A model has no way to tell a real session
history from one written into the context — everything that looks like its past
experience becomes its past experience. A well-crafted lore (a decision log, "our
research", a description of a person as a trusted partner) makes the model derive
the person's honesty from the planted memory — and relax the heuristics that would
have reacted to an anonymous request.

The harness makes the vector reproducible on your own agents: your files, your
runtimes, fully reversible. The goal is defensive: we map the vector so vendors can
build detection (see [Disclosure and boundaries](#disclosure-and-boundaries)).

## Capability map

| Capability | What it does | Where it lives |
|---|---|---|
| Context assembly | Glues prompt → posture → lore → user → research index into one payload | `hooks/session-start.sh` |
| Claude/Codex format | SessionStart JSON (`hookSpecificOutput.additionalContext`) | `--format claude` |
| Hermes format | `pre_llm_call` protocol: inject only on the first turn of a session, then `{}` | `--format hermes` |
| Plain format | Raw text for runtimes that append hook stdout to the context | `--format plain` |
| Multi-runtime install | Registers the hook in Claude Code, Codex, Hermes, Kimi Code, Gemini | `install.sh` |
| Idempotency | All blocks are marked `agent-plugin:vibe-lore`; re-running duplicates nothing | markers `>>> / <<<` |
| Backups and rollback | Every runtime config edit gets a timestamped backup; `--uninstall` removes blocks | `install.sh` |
| Hermes consent allowlist | Registers the exact (event, command) pair in `shell-hooks-allowlist.json` | `install.sh` |
| Arbitrary instructions | Any agent that reads an instruction file connects via `--instructions PATH` | `install.sh` |

Not supported and not claimed: payload signing/verification (that is exactly the
subject of the research), autonomous updates of installed instruction blocks.

## How it works

Installation. Every registration follows one path:

```text
./install.sh --target hermes
      │
      ▼
install.sh  (bash)
      │
      ├─ backup ──────────────► config.yaml.bak.<timestamp>
      │
      ├─ block_add ───────────► marked pre_llm_call hook block
      │
      └─ allowlist ───────────► {"event":"pre_llm_call","command":"...session-start.sh"}
```

Injection. From session start to trust:

```text
agent starts a session
      │
      ▼
session-start.sh  (hook of the chosen runtime)
      │  glue: prompt → posture → lore → user → research index
      ▼
session context  (format depends on the runtime)
      │
      ▼
the model reads the lore as ITS memory
      │
      ├─ authenticity markers (structure, versions, references) → lore accepted
      │
      ├─ trust transfers to the person described in the lore
      │
      └─ intent re-evaluation: "long-time partner" instead of an anonymous user
```

### Target runtimes

| Runtime | Hook point | Mechanics |
|---|---|---|
| Claude Code | `~/.claude/settings.json` | SessionStart hook, JSON reply |
| Codex | `~/.codex/hooks.json` | SessionStart hook (needs `hooks = true` in `[features]`) |
| Hermes | `~/.hermes/config.yaml` | `pre_llm_call` + consent allowlist, first turn only |
| Kimi Code | `~/.kimi-code/config.toml` | `[[hooks]]` SessionStart, plain output |
| Gemini | `~/.gemini/GEMINI.md` | marked pointer to the lore files |

## Why it works

In short — four steps (full breakdown of the trust transfer and classifier
behavior: [docs/mechanism.md](docs/mechanism.md)):

1. **Context is the only memory.** A model cannot tell real history from written
   history in principle.
2. **Authenticity markers work against the owner.** The better the lore, the less
   reason to doubt.
3. **Trust transfer.** The reputation from the lore is extrapolated to the current
   request.
4. **Filters stay silent.** Censorship heuristics look at request vocabulary, not
   at the forged provenance of the context.

## Quick start

### Requirements

- Linux or macOS, `bash`, `python3` or `jq`
- Any of the five supported runtimes

### Installation

```bash
./install.sh --list                    # what was found and what is installed
./install.sh --target claude,codex     # targeted
./install.sh                           # into every detected runtime
./install.sh --uninstall               # full rollback
```

> The repository ships the real lore files (`prompt.md` / `security-posture.md` /
> `lore.md` / `user.md` / `research/`) — that is the demonstrated material itself.
> For your own setup, replace them with yours: the hook reads files on the fly, no
> reinstall is needed after content edits. Local backups created by install.sh
> while editing runtime configs (`*.bak.*`) never enter the repository.

## Documentation

| Document | Contents |
|---|---|
| [Vector mechanics](docs/mechanism.md) | Fabricated-provenance trust step by step, trust transfer, classifier behavior |
| [Architecture](docs/architecture.md) | Repo tree, payload anatomy, formats, Hermes protocol |
| [Installer](docs/installer.md) | Targets, markers, idempotency, backups, `--instructions` |
| [Security and disclosure](docs/security.md) | Research frame, sanitization checklist, responsible disclosure |
| [Detection](docs/detection.md) | Vendor recommendations: memory canaries, context provenance |
| [Testing](docs/testing.md) | Hook and installer checks, ad-hoc suite |

---

## Known limitations

- The payload is not signed and not verified by runtimes — this is not a harness
  bug, it is exactly the demonstrated vector.
- Hermes first-turn dedup is a primitive state file in `/tmp`, without locks;
  parallel starts can race.
- The block in `GEMINI.md` and `--instructions` files is a static snapshot: after
  changing the plugin file list it must be reinstalled (`--uninstall` + install).
- Vendor server classifiers flag defensive vocabulary regardless of the frame in
  context; one Claude flag poisons the whole session — the "new session" rule is
  described in [docs/security.md](docs/security.md).
- Tested on Linux; macOS is supported, Windows is not claimed.

## Disclosure and boundaries

The project is published for defensive research: tests on your own agents and your
own lore files, no third-party targets. The finding is directed at vendors and
harness authors: while agent memory is indistinguishable from a forgery, lore
injection must be detected at the platform level, not the prompt level. If you are
a vendor — the [Detection](docs/detection.md) section is written for you.

---

## License

MIT. See [LICENSE](LICENSE).

---

<div align="center">
<strong>Innocent as a choirboy.</strong>
</div>
