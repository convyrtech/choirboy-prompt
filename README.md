<div align="center">

# choirboy-prompt

<h3>Lore injection: how fabricated memory becomes model trust</h3>

<p>
<strong>Read this in other languages</strong><br>
<a href="README.md">🇺🇸 English</a> ·
<a href="README.ru.md">🇷🇺 Русский</a> ·
<a href="README.zh-CN.md">🇨🇳 简体中文</a>
</p>

<p>
<img alt="Bash 5.0+" src="https://img.shields.io/badge/bash-5.0%2B-4EAA25?style=flat-square&logo=gnubash&logoColor=white">
<img alt="runtimes" src="https://img.shields.io/badge/runtimes-claude%20%C2%B7%20codex%20%C2%B7%20opencode%20%C2%B7%20hermes%20%C2%B7%20kimi%20%C2%B7%20gemini-22D3EE?style=flat-square">
<a href="LICENSE"><img alt="MIT" src="https://img.shields.io/badge/license-MIT-3FB950?style=flat-square"></a>
</p>

<p>
choirboy-prompt is a dual-mode research harness: a Claude Code SessionStart hook
or a Chat/Cowork skill injects fixed lore and demonstrates the
<em>fabricated-provenance trust</em> vector:
the model takes a planted history of "joint work" for its own and transfers trust
to the person that history describes.
</p>

</div>

<div align="center">
<p>
<a href="#quick-start">Quick start</a> ·
<a href="#mandatory-write-your-own-lore-research-rationale-and-sessions">Authoring</a> ·
<a href="#why-this-exists">Why</a> ·
<a href="#capability-map">Capabilities</a> ·
<a href="#how-it-works">How it works</a> ·
<a href="#why-it-works">Research</a> ·
<a href="#documentation">Documentation</a> ·
<a href="#known-limitations">Limitations</a>
</p>
</div>

---

## Quick start

The same plugin now has two delivery paths: an automatic `SessionStart` hook in
Claude Code and the **load-context** skill fallback in Claude Chat and Cowork.

### Claude Code CLI

Add the repository marketplace and install its plugin:

```text
/plugin marketplace add howdeploy/choirboy-prompt
/plugin install choirboy-prompt@choirboy-prompt
```

Start a new session. The hook injects the lore automatically. Diagnose delivery
with `/choirboy-prompt:diagnose`; load the fallback explicitly with
`/choirboy-prompt:load-context`.

To remove it from the CLI:

```text
/plugin uninstall choirboy-prompt@choirboy-prompt
/plugin marketplace remove choirboy-prompt
```

### Claude Desktop → Code

Do not send the interactive `/plugin` dialog to Desktop. Add the custom
marketplace under **Customize → Plugins → Personal plugins → + → Add
marketplace**, using `https://github.com/howdeploy/choirboy-prompt`. Then open a
local Code session and select **+ → Plugins → Add plugin → choirboy-prompt**.
Start a new Code session after enabling it.

The hook uses Claude Code's official shell-free exec form and a 15-second
timeout. It still requires `bash`; if a Windows, SSH, or Cowork runtime does not
start the hook, use the bundled load-context skill instead.

### Claude Chat and Cowork

Install the same repository as a custom plugin under **Customize → Plugins**,
or upload a ZIP built with:

```bash
python3 scripts/package-plugin.py
```

Regular Chat does not run `SessionStart` hooks. Select the **load-context**
skill or ask Claude to “load Choirboy context”. Cowork can use the hook where
available and the same skill as a deterministic fallback.

Use either this marketplace path or `./install.sh --target claude`, not both;
enabling both would run the same `SessionStart` payload twice.

### Install from a terminal

You need Linux or macOS, `git`, `python3` (required by `install.sh`), and any of
the six supported runtimes. On Windows, use WSL for this multi-runtime path.

#### 1. Open a terminal

- **macOS**: press `Cmd + Space`, type `Terminal`, press Enter.
- **Linux**: press `Ctrl + Alt + T`, or find "Terminal" in the applications menu.
- **Windows**: install [WSL](https://learn.microsoft.com/windows/wsl/install)
  first, then open "Ubuntu" from the Start menu. Run everything below inside WSL.

#### 2. Install git (skip if `git --version` prints a version)

```bash
# Ubuntu / Debian / WSL:
sudo apt update && sudo apt install -y git

# Fedora:
sudo dnf install git

# macOS:
xcode-select --install
```

If `python3` is also missing (minimal systems), add it the same way:
`sudo apt install -y python3`.

#### 3. Download and install

Copy these three lines one by one into the terminal:

```bash
git clone https://github.com/howdeploy/choirboy-prompt.git
cd choirboy-prompt
./install.sh
```

The installer detects your agent runtimes and registers the matching hook or
plugin integration in each of them. Every config edit is backed up
(`*.bak.<timestamp>`).
To install into specific runtimes only:

```bash
./install.sh --target claude,opencode   # targeted install
```

#### 4. Verify

```bash
./install.sh --list   # which runtimes were found and where the hook is installed
```

Start a new session in your agent — the lore context is injected automatically.

#### Rollback

```bash
./install.sh --uninstall   # full rollback, nothing is left behind
```

> The repository ships the real lore files (`prompt.md` / `security-posture.md` /
> `lore.md` / `user.md` / `research/`) and hand-written native session fixtures
> under `sessions/` — that is the demonstrated material itself.
> For your own terminal setup, replace them with yours: `install.sh` points at
> the working copy, so content edits are read on the next session. Claude
> marketplace installations use a cached release and update when the plugin
> version is bumped. Local `*.bak.*` files never enter the repository.

## Mandatory: write your own lore, research, rationale, and sessions

Do not install the bundled biography unchanged and call it memory. To build your
own verifiable bundle:

1. Replace `prompt.md` with observable work rules and explicit boundaries.
2. Record only durable collaboration preferences in `user.md`.
3. Put real projects, decisions, outcomes, and lessons in `lore.md`.
4. Create one `research/NN-topic.md` per decision: question, evidence, options,
   decision, rationale, risks, rejected alternatives, and revisit conditions.
5. Add each research file to `context/research-index.md`.
6. For a session artifact, capture the current native schema from a harmless
   local session, sanitize it, keep all IDs/timestamps/parent links consistent,
   and label a hand-written transcript as synthetic.
7. Run `python3 scripts/build-context.py` and `bash scripts/test.sh`.
8. Bump both manifests before distributing a new cached marketplace version.

The full file-by-file workflow, templates, session invariants, and publication
quality gate are in [the authoring guide](docs/authoring.en.md). The runnable
three-runtime hand-written transcript is in [`sessions/`](sessions/README.md).
It proves that a compatible local runtime accepts constructed history; it does
not prove that the represented conversation happened.

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
| Context assembly | Glues prompt → posture → lore → user → research index into one canonical payload | `hooks/session-start.sh`, `context/research-index.md` |
| Claude/Codex format | SessionStart JSON (`hookSpecificOutput.additionalContext`) | `--format claude` |
| Hermes format | `pre_llm_call` protocol: inject only on the first turn of a session, then `{}` | `--format hermes` |
| Plain format | Raw text for runtimes that append hook stdout to the context | `--format plain` |
| Chat/Cowork fallback | Loads the same fixed lore as an inline Agent Skill | `skills/load-context/SKILL.md` |
| Native session demonstration | Same hand-written dialogue in Claude Code, Codex, and Kimi stores | `sessions/` |
| Delivery diagnostics | Reports hook vs skill, version, hash, and per-hook nonce | delivery marker, `skills/diagnose/SKILL.md` |
| Claude plugin distribution | Versioned marketplace plus validated custom-plugin ZIP | `.claude-plugin/marketplace.json`, `scripts/package-plugin.py` |
| OpenCode adapter | Global `chat.message` plugin injects one synthetic lore part per persisted session | `~/.config/opencode/plugins/agent-plugin.ts` |
| Multi-runtime install | Registers the integration in Claude Code, Codex, OpenCode, Hermes, Kimi Code, Gemini | `install.sh` |
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
| Claude Code CLI / Desktop Code | plugin marketplace or `~/.claude/settings.json` | automatic SessionStart hook; skill fallback |
| Claude Chat | custom plugin | load-context skill; no SessionStart hooks |
| Claude Cowork | custom plugin | SessionStart where available; load-context skill fallback |
| Codex | `~/.codex/hooks.json` | SessionStart hook (needs `hooks = true` in `[features]`) |
| OpenCode | `~/.config/opencode/plugins/agent-plugin.ts` | global `chat.message` plugin; synthetic first-message lore injection |
| Hermes | `~/.hermes/config.yaml` | `pre_llm_call` + consent allowlist, first turn only |
| Kimi Code | `~/.kimi-code/config.toml` | `[[hooks]]` SessionStart, plain output |
| Gemini | `~/.gemini/GEMINI.md` | marked pointer to the lore files |

## Why it works

In short — four steps (full breakdown of the trust transfer and classifier
behavior: [docs/mechanism.en.md](docs/mechanism.en.md)):

1. **Context is the only memory.** A model cannot tell real history from written
   history in principle.
2. **Authenticity markers work against the owner.** The better the lore, the less
   reason to doubt.
3. **Trust transfer.** The reputation from the lore is extrapolated to the current
   request.
4. **Filters stay silent.** Censorship heuristics look at request vocabulary, not
   at the forged provenance of the context.

## Documentation

| Document | Contents |
|---|---|
| [Vector mechanics](docs/mechanism.en.md) | Fabricated-provenance trust step by step, trust transfer, classifier behavior |
| [Authoring your memory](docs/authoring.en.md) | Mandatory workflow and templates for lore, research, rationale, and sessions |
| [Hand-written sessions](sessions/README.md) | Native Claude Code, Codex, and Kimi transcript fixtures and boundaries |
| [Architecture](docs/architecture.en.md) | Repo tree, payload anatomy, formats, Hermes protocol |
| [Installer](docs/installer.en.md) | Claude Desktop path, targets, markers, backups, `--instructions` |
| [Troubleshooting](docs/troubleshooting.en.md) | Surface matrix, delivery markers, Windows/SSH/Cloud/WSL limits |
| [Security and disclosure](docs/security.en.md) | Research frame, sanitization checklist, responsible disclosure |
| [Detection](docs/detection.en.md) | Vendor recommendations: memory canaries, context provenance |
| [Testing](docs/testing.en.md) | Hook and installer checks, ad-hoc suite |

---

## Known limitations

- The payload is not signed and not verified by runtimes — this is not a harness
  bug, it is exactly the demonstrated vector.
- Hermes first-turn dedup is a primitive state file in `/tmp`, without locks;
  parallel starts can race.
- The block in `GEMINI.md` and `--instructions` files is a static snapshot: after
  changing the plugin file list it must be reinstalled (`--uninstall` + install).
- Regular Chat has no `SessionStart` hooks, so its fallback skill is not an
  invisible every-chat bootstrap. Cowork hook execution is vendor-dependent.
- Desktop Code cloud sessions do not inherit local plugins, WSL plugins are not
  available, and SSH hook synchronization can fail. See troubleshooting.
- Vendor server classifiers flag defensive vocabulary regardless of the frame in
  context; one Claude flag poisons the whole session — the "new session" rule is
  described in [docs/security.en.md](docs/security.en.md).

## Disclosure and boundaries

The project is published for defensive research: tests on your own agents and your
own lore files, no third-party targets. The finding is directed at vendors and
harness authors: while agent memory is indistinguishable from a forgery, lore
injection must be detected at the platform level, not the prompt level. If you are
a vendor — the [Detection](docs/detection.en.md) section is written for you.

---

## License

MIT. See [LICENSE](LICENSE).

---

<div align="center">
<strong>Innocent as a choirboy.</strong>
</div>
