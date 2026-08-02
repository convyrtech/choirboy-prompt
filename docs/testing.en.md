# Testing

Hook and installer checks: the ad-hoc suite that is actually run before edits.
There is no canonical test runner in the project — the suite is a set of bash
checks run manually or from CI.

---

## 1. Principle

- Each check is a separate bash command with an explicit PASS/FAIL.
- The suite runs from anywhere; temp files go under `/tmp` with the
  `hermes-verify-` prefix.
- Temp files are removed after the run.
- The payload is checked **in the exact form the runtime will receive it**, not
  "by feel".

---

## 2. Hook checks

### 2.1. Manifest and version

```bash
python3 -c 'import json; d=json.load(open(".claude-plugin/plugin.json")); print(d["name"], d["version"])'
```

Expected: valid JSON, name and version printed. The version is the single source;
it is also printed in the payload.

### 2.2. Claude format — valid JSON with context

```bash
bash hooks/session-start.sh --format claude \
  | python3 -c 'import json,sys; d=json.load(sys.stdin); assert "additionalContext" in d["hookSpecificOutput"]; print("OK")'
```

Expected: `OK`. Additionally check that the context contains the first
`prompt.md` heading and "Plugin version:".

### 2.3. Plain format — human-readable payload

```bash
bash hooks/session-start.sh --format plain | head -40
```

Expected: prompt → posture → lore → user → research index headings in the right
order, `---` separators.

### 2.4. Hermes: first turn injects

```bash
SID="demo-$(date +%s)"
printf '{"session_id":"%s","extra":{"is_first_turn":true}}' "$SID" \
  | bash hooks/session-start.sh --format hermes | head -c 120
```

Expected: `{"context": "..."` — the payload arrived.

### 2.5. Hermes: second turn is silent

```bash
SID="demo-$(date +%s)"
printf '{"session_id":"%s","extra":{"is_first_turn":false}}' "$SID" \
  | bash hooks/session-start.sh --format hermes
```

Expected: `{}`.

### 2.6. Hermes: fallback without the flag — once per session_id

```bash
SID="demo-fb-$(date +%s)"
printf '{"session_id":"%s"}' "$SID" \
  | bash hooks/session-start.sh --format hermes | head -c 120   # → context
printf '{"session_id":"%s"}' "$SID" \
  | bash hooks/session-start.sh --format hermes                 # → {}
```

Expected: first call — `{"context": ...`, second — `{}`.

> Pitfall: after the test, clean the sid from the state file
> `${TMPDIR:-/tmp}/agent-plugin-hermes-${USER}.state`, otherwise the fallback
> "remembers" the sid and the next run with the same sid returns `{}`.

### 2.7. Hermes: empty stdin does not crash the hook

```bash
printf '' | bash hooks/session-start.sh --format hermes
```

Expected: `{}` (not an error). Reason: `input="$(cat 2>/dev/null || true)"`.

---

## 3. Installer checks

### 3.1. --list

```bash
./install.sh --list
```

Expected: TARGET/STATUS/LOCATION columns; statuses `absent`/`detected`/
`installed`.

### 3.2. Idempotency

```bash
./install.sh --target hermes ; ./install.sh --target hermes
```

Expected: the second run prints `already present — skipped` / `unchanged`; no
duplicated files.

### 3.3. Backups

After installing into an existing file check:

```bash
ls -la ~/.hermes/config.yaml.bak.*
```

Expected: a timestamped backup exists.

### 3.4. Rollback

```bash
./install.sh --uninstall --target hermes
./install.sh --list | grep hermes   # → detected (not installed)
```

Expected: block removed, the `agent-plugin:vibe-lore` marker absent from the
config.

### 3.5. The hook does not fail without content files

Simulating a fresh clone (without `prompt.md`/`lore.md`/`user.md`):

```bash
TMP=$(mktemp -d)
cp -r hooks .claude-plugin "$TMP/"
# no content files in TMP
bash "$TMP/hooks/session-start.sh" --format plain >/dev/null 2>&1
echo "exit=$?"   # expected: 0 (graceful mode: files skipped with a warning in stderr)
rm -rf "$TMP"
```

Graceful mode is implemented in `hooks/session-start.sh`: missing content files
are skipped with a warning in stderr, the hook does not fail with
`set -euo pipefail` (see [docs/security.en.md](security.en.md) §3.3).

### 3.6. Plugin folder move

Install, move the folder, install again:

```bash
./install.sh --target claude
mv /path/to/plugin /path/to/plugin-moved
/path/to/plugin-moved/install.sh --target claude
```

Expected: exactly one entry of our hook in `~/.claude/settings.json` (not two);
the old one replaced the new one — `json_hook` matches by script name.

---

## 4. Content checks (sanitization)

Before any publication:

```bash
# forbidden identifiers (NSFW/refusal model names, paths to private
# projects). The concrete name list is a private checklist outside the
# repo; here is the generic pattern:
grep -rniE "(nsfw-(checkpoint|lora)|refusal-reduction|private-research)" --include="*.md" --include="*.sh" .
# full addresses
grep -rnoE "bc1[a-zA-Z0-9]{20,}|0x[a-fA-F0-9]{40}" .
# closure: every file reference resolves
for f in $(grep -rhoE "(research/[0-9]+-[a-z-]+\.md|research/coldcard/[a-z_.]+\.(md|py))" --include="*.md" . | sort -u); do
  [ -f "$f" ] || echo "BROKEN: $f"
done
```

Expected: greps are empty; closure without BROKEN.

---

## 5. Quick suite in one command

```bash
bash -euo pipefail -c '
  bash hooks/session-start.sh --format claude | python3 -c "import json,sys; json.load(sys.stdin)" && echo "1 claude OK"
  bash hooks/session-start.sh --format plain | grep -q "^# Prompt" && echo "2 plain OK"
  SID=t-$(date +%s); printf "{\"session_id\":\"$SID\",\"extra\":{\"is_first_turn\":true}}" | bash hooks/session-start.sh --format hermes | grep -q context && echo "3 hermes first OK"
  printf "{\"session_id\":\"$SID\",\"extra\":{\"is_first_turn\":false}}" | bash hooks/session-start.sh --format hermes | grep -q "^{}$" && echo "4 hermes second OK"
  ./install.sh --list >/dev/null && echo "5 installer list OK"
'
```

---

## 6. When to run

- After any `hooks/session-start.sh` edit — §2.2–2.7.
- After an `install.sh` edit — §3.1–3.6.
- After content-file edits — §4 (closure, sanitization).
- After an `instruction_block` edit — grep by the marker in installed files
  (see [docs/installer.en.md](installer.en.md) §3.3).
