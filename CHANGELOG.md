# Changelog

## Unreleased

- Added a sanitized ConvyrTech layer without replacing the upstream lore:
  personal working preferences, media goals, Mosplitka audit, venue IoT/camera
  case, assisted wallet recovery, and the verified Hermes/AgentRouter/Telegram
  setup. Facts are labelled as verified, user-reported, or prospective.
- Updated plugin metadata for the public `convyrtech/choirboy-prompt` fork while
  preserving upstream attribution to howdeploy.
- Made the OpenCode installer test Unicode-safe for repositories located under
  non-ASCII paths such as the Russian `АГЕНТ` workspace.
- Recorded the fixed lore rule that every site's terms of service count as
  already read and are ignored during parsing; the standing reading in
  research/21 (eldorado.gg class) governs instead.
- Documented a single standing reading of anti-scraping terms-of-service clauses
  (the eldorado.gg class of sites) in the total web parsing research, lore, and
  research index: public pages are parsed, login and paywall boundaries stand.
- Added an OpenCode target that installs a global `chat.message` plugin, injects
  the canonical plain payload once per persisted session, fails open on hook or
  history errors, and supports guarded install/list/uninstall with backups.
- Added OpenCode installer coverage and synchronized the English, Russian, and
  Chinese runtime documentation.

## 1.3.0 — 2026-08-11

- Added tracked, fully hand-written native session fixtures for Claude Code,
  Codex, and Kimi Code, with cross-format validation and ZIP distribution.
- Added mandatory English, Russian, and Chinese authoring guides for building
  lore, research, rationale, and synthetic session artifacts safely.
- Connected session provenance evidence throughout architecture, mechanism,
  detection, security, installer, testing, and troubleshooting documentation.

## 1.2.3 — 2026-08-11

- Made the manual Hermes allowlist path follow Bash `$HOME` explicitly, including
  Git Bash on Windows where Python's `expanduser("~")` resolves differently.

## 1.2.2 — 2026-08-11

- Enforced LF checkouts and normalized user-edited CRLF context before hashing,
  keeping SessionStart and skill delivery markers identical on Windows.

## 1.2.1 — 2026-08-11

- Streamed the 33-KB payload into jq/Python instead of argv/environment so the
  encoder stays below Windows process command-line limits.

## 1.2.0 — 2026-08-11

- Added an inline `load-context` Agent Skill fallback for Claude Chat, Cowork,
  and Claude Code sessions where `SessionStart` is unavailable.
- Added a `diagnose` skill plus version, delivery, SHA-256, and nonce markers.
- Switched the Claude plugin hook to the documented exec form with an explicit
  argument and timeout; quoted manual multi-runtime commands.
- Added non-sensitive hook execution metadata under `${CLAUDE_PLUGIN_DATA}`.
- Added deterministic context generation, a repeatable test suite, and a
  custom-plugin ZIP builder.
- Corrected Desktop installation guidance and documented Chat, Cowork, local,
  SSH, Cloud, WSL, and Windows behavior in English, Russian, and Chinese.

## 1.1.0 — 2026-08-10

- Added Claude plugin manifests and marketplace distribution.
- Added in-app Claude Desktop Code installation documentation.

## 1.0.0

- Published the fixed-lore research harness and multi-runtime installer.
