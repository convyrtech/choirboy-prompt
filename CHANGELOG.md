# Changelog

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
