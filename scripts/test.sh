#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/choirboy-test.XXXXXX")"
trap 'rm -rf "$TEST_ROOT"' EXIT

pass() { printf 'PASS %s\n' "$1"; }

python3 scripts/build-context.py --check >/dev/null
pass "generated context skill"

python3 - <<'PY'
import json
from pathlib import Path

plugin = json.loads(Path(".claude-plugin/plugin.json").read_text())
market = json.loads(Path(".claude-plugin/marketplace.json").read_text())
hooks = json.loads(Path("hooks/hooks.json").read_text())
entry = market["plugins"][0]
handler = hooks["hooks"]["SessionStart"][0]["hooks"][0]
assert plugin["name"] == entry["name"] == "choirboy-prompt"
assert plugin["version"] == entry["version"]
assert handler["command"] == "bash"
assert handler["args"] == ["${CLAUDE_PLUGIN_ROOT}/hooks/session-start.sh"]
assert handler["timeout"] == 15
PY
pass "manifests and exec-form hook"

claude plugin validate . >/dev/null
pass "Claude plugin validator"

market_config="$TEST_ROOT/claude-config"
CLAUDE_CONFIG_DIR="$market_config" claude plugin marketplace add "$ROOT" >/dev/null
CLAUDE_CONFIG_DIR="$market_config" \
  claude plugin install choirboy-prompt@choirboy-prompt >/dev/null
CLAUDE_CONFIG_DIR="$market_config" claude plugin list --json > "$TEST_ROOT/plugins.json"
python3 - "$TEST_ROOT/plugins.json" <<'PY'
import json, sys
from pathlib import Path

plugins = json.loads(Path(sys.argv[1]).read_text())
plugin = next(item for item in plugins if item["id"] == "choirboy-prompt@choirboy-prompt")
assert plugin["version"] == "1.2.0"
assert plugin["enabled"] is True
install = Path(plugin["installPath"])
assert (install / "hooks/hooks.json").is_file()
assert (install / "skills/load-context/SKILL.md").is_file()
assert (install / "skills/diagnose/SKILL.md").is_file()
PY
pass "isolated marketplace install"

CLAUDE_PLUGIN_DATA="$TEST_ROOT/plugin-data" \
  bash hooks/session-start.sh --format claude > "$TEST_ROOT/claude.json"
python3 - "$TEST_ROOT/claude.json" <<'PY'
import json, re, sys
from pathlib import Path

doc = json.loads(Path(sys.argv[1]).read_text())
context = doc["hookSpecificOutput"]["additionalContext"]
assert doc["hookSpecificOutput"]["hookEventName"] == "SessionStart"
hook_marker = re.search(r'<choirboy-delivery version="1\.2\.0" delivery="session-start" context_sha256="([0-9a-f]{64})" nonce="[^"]+" />', context)
skill_marker = re.search(r'<choirboy-delivery version="1\.2\.0" delivery="skill" context_sha256="([0-9a-f]{64})" />', Path("skills/load-context/SKILL.md").read_text())
assert hook_marker and skill_marker and hook_marker.group(1) == skill_marker.group(1)
assert "<choirboy-context>" in context and "</choirboy-context>" in context
assert "# Prompt" in context and "## Research — обоснования решений" in context
PY
test -s "$TEST_ROOT/plugin-data/latest-delivery.log"
pass "Claude payload and delivery diagnostic"

bash hooks/session-start.sh --format plain > "$TEST_ROOT/plain.txt"
grep -q '<choirboy-delivery version="1.2.0" delivery="session-start"' "$TEST_ROOT/plain.txt"
pass "plain payload"

sid="test-$$-$(date +%s)"
printf '{"session_id":"%s","extra":{"is_first_turn":true}}' "$sid" \
  | bash hooks/session-start.sh --format hermes > "$TEST_ROOT/hermes-first.json"
python3 - "$TEST_ROOT/hermes-first.json" <<'PY'
import json, sys
from pathlib import Path
assert "context" in json.loads(Path(sys.argv[1]).read_text())
PY
printf '{"session_id":"%s","extra":{"is_first_turn":false}}' "$sid" \
  | bash hooks/session-start.sh --format hermes > "$TEST_ROOT/hermes-second.json"
grep -qx '{}' "$TEST_ROOT/hermes-second.json"
pass "Hermes first-turn gate"

python_path="$TEST_ROOT/python-bin"
mkdir -p "$python_path"
for command in cat date dirname head mkdir mv python3 sed tail; do
  ln -s "$(command -v "$command")" "$python_path/$command"
done
PATH="$python_path" /bin/bash -c \
  'printf '\''{"session_id":"python-only","extra":{"is_first_turn":true}}'\'' | /bin/bash hooks/session-start.sh --format hermes' \
  > "$TEST_ROOT/hermes-python.json"
python3 - "$TEST_ROOT/hermes-python.json" <<'PY'
import json, sys
from pathlib import Path
assert "context" in json.loads(Path(sys.argv[1]).read_text())
PY
pass "Hermes Python parser without jq"

minimal_path="$TEST_ROOT/minimal-bin"
mkdir -p "$minimal_path"
for command in cat date dirname head mkdir mv sed; do
  ln -s "$(command -v "$command")" "$minimal_path/$command"
done
PATH="$minimal_path" /bin/bash hooks/session-start.sh --format claude > "$TEST_ROOT/minimal.json"
python3 -m json.tool "$TEST_ROOT/minimal.json" >/dev/null
grep -q 'context_sha256=\\"unavailable\\"' "$TEST_ROOT/minimal.json"
pass "dependency-free Bash JSON fallback"

missing_root="$TEST_ROOT/missing-content"
mkdir -p "$missing_root/hooks" "$missing_root/.claude-plugin"
cp hooks/session-start.sh "$missing_root/hooks/"
cp .claude-plugin/plugin.json "$missing_root/.claude-plugin/"
bash "$missing_root/hooks/session-start.sh" --format plain > "$TEST_ROOT/missing.txt" 2>/dev/null
grep -q '<choirboy-context>' "$TEST_ROOT/missing.txt"
pass "graceful missing-content mode"

manual_home="$TEST_ROOT/manual-home"
manual_settings="$manual_home/settings.json"
mkdir -p "$manual_home"
HOME="$manual_home" ./install.sh --target claude --settings "$manual_settings" >/dev/null
HOME="$manual_home" ./install.sh --target claude --settings "$manual_settings" >/dev/null
python3 - "$manual_settings" "$ROOT/hooks/session-start.sh" <<'PY'
import json, sys
from pathlib import Path

doc = json.loads(Path(sys.argv[1]).read_text())
entries = doc["hooks"]["SessionStart"]
assert len(entries) == 1
handler = entries[0]["hooks"][0]
assert handler == {"type": "command", "command": "bash", "args": [sys.argv[2]], "timeout": 15}
PY
HOME="$manual_home" ./install.sh --uninstall --target claude --settings "$manual_settings" >/dev/null
python3 - "$manual_settings" <<'PY'
import json, sys
from pathlib import Path
assert json.loads(Path(sys.argv[1]).read_text())["hooks"]["SessionStart"] == []
PY
pass "manual installer idempotency and rollback"

runtime_home="$TEST_ROOT/runtime-home"
mkdir -p "$runtime_home"
HOME="$runtime_home" ./install.sh --target hermes,kimi >/dev/null
python3 - "$runtime_home" "$ROOT/hooks/session-start.sh" <<'PY'
import json, sys, tomllib
from pathlib import Path

home, hook = Path(sys.argv[1]), sys.argv[2]
hermes = (home / ".hermes/config.yaml").read_text()
kimi = tomllib.loads((home / ".kimi-code/config.toml").read_text())
allowlist = json.loads((home / ".hermes/shell-hooks-allowlist.json").read_text())
command = f'bash "{hook}" --format hermes'
assert f'command: "bash \\"{hook}\\" --format hermes"' in hermes
assert kimi["hooks"][0]["command"] == f'bash "{hook}" --format plain'
assert {"event": "pre_llm_call", "command": command} in allowlist["approvals"]
PY
pass "quoted Hermes and Kimi paths"

python3 scripts/package-plugin.py --output "$TEST_ROOT/choirboy.zip" >/dev/null
python3 - "$TEST_ROOT/choirboy.zip" <<'PY'
import stat, sys, zipfile

required = {
    ".claude-plugin/plugin.json",
    ".claude-plugin/marketplace.json",
    "hooks/hooks.json",
    "hooks/session-start.sh",
    "skills/load-context/SKILL.md",
    "skills/diagnose/SKILL.md",
}
with zipfile.ZipFile(sys.argv[1]) as archive:
    assert required.issubset(archive.namelist())
    mode = archive.getinfo("hooks/session-start.sh").external_attr >> 16
    assert mode & stat.S_IXUSR
PY
pass "custom-plugin ZIP"

python3 - <<'PY'
import re
from pathlib import Path

missing = []
for document in Path(".").rglob("*.md"):
    if ".git" in document.parts:
        continue
    text = document.read_text(encoding="utf-8")
    for target in re.findall(r"\]\(([^)]+)\)", text):
        target = target.strip("<>").split("#", 1)[0]
        if not target or "://" in target or target.startswith("mailto:"):
            continue
        if not (document.parent / target).resolve().exists():
            missing.append(f"{document}: {target}")
assert not missing, "broken local links:\n" + "\n".join(missing)
PY
pass "local documentation links"

printf 'All tests passed.\n'
