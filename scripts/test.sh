#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
VERSION="$(python3 -c 'import json; print(json.load(open(".claude-plugin/plugin.json", encoding="utf-8"))["version"])')"

TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/choirboy-test.XXXXXX")"
trap 'rm -rf "$TEST_ROOT"' EXIT

pass() { printf 'PASS %s\n' "$1"; }

# Git Bash on hosted Windows runners may emulate `ln -s` with plain files when
# symlink creation is unavailable. Small wrappers keep the dependency-isolation
# tests portable without copying executables away from their runtime libraries.
install_test_command() {
  local destination="$1" command="$2" source
  source="$(command -v "$command")"
  printf '#!/bin/bash\nexec "%s" "$@"\n' "$source" > "$destination/$command"
  chmod +x "$destination/$command"
}

python3 scripts/build-context.py --check >/dev/null
pass "generated context skill"

python3 - <<'PY'
import json
from pathlib import Path

plugin = json.loads(Path(".claude-plugin/plugin.json").read_text(encoding="utf-8"))
market = json.loads(Path(".claude-plugin/marketplace.json").read_text(encoding="utf-8"))
hooks = json.loads(Path("hooks/hooks.json").read_text(encoding="utf-8"))
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
python3 - "$TEST_ROOT/plugins.json" "$VERSION" <<'PY'
import json, sys
from pathlib import Path

plugins = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
plugin = next(item for item in plugins if item["id"] == "choirboy-prompt@choirboy-prompt")
assert plugin["version"] == sys.argv[2]
assert plugin["enabled"] is True
install = Path(plugin["installPath"])
assert (install / "hooks/hooks.json").is_file()
assert (install / "skills/load-context/SKILL.md").is_file()
assert (install / "skills/diagnose/SKILL.md").is_file()
PY
pass "isolated marketplace install"

CLAUDE_PLUGIN_DATA="$TEST_ROOT/plugin-data" \
  bash hooks/session-start.sh --format claude > "$TEST_ROOT/claude.json"
python3 - "$TEST_ROOT/claude.json" "$VERSION" <<'PY'
import json, re, sys
from pathlib import Path

doc = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
context = doc["hookSpecificOutput"]["additionalContext"]
version = re.escape(sys.argv[2])
assert doc["hookSpecificOutput"]["hookEventName"] == "SessionStart"
hook_marker = re.search(rf'<choirboy-delivery version="{version}" delivery="session-start" context_sha256="([0-9a-f]{{64}})" nonce="[^"]+" />', context)
skill_marker = re.search(rf'<choirboy-delivery version="{version}" delivery="skill" context_sha256="([0-9a-f]{{64}})" />', Path("skills/load-context/SKILL.md").read_text(encoding="utf-8"))
assert hook_marker and skill_marker and hook_marker.group(1) == skill_marker.group(1)
assert "<choirboy-context>" in context and "</choirboy-context>" in context
assert "# Prompt" in context and "## Research — обоснования решений" in context
PY
test -s "$TEST_ROOT/plugin-data/latest-delivery.log"
if grep -q -- '--arg ctx' hooks/session-start.sh; then
  echo "hook must stream the lore to JSON encoders, not pass it through argv" >&2
  exit 1
fi
pass "Claude payload and delivery diagnostic"

bash hooks/session-start.sh --format plain > "$TEST_ROOT/plain.txt"
grep -q "<choirboy-delivery version=\"$VERSION\" delivery=\"session-start\"" "$TEST_ROOT/plain.txt"
pass "plain payload"

sid="test-$$-$(date +%s)"
printf '{"session_id":"%s","extra":{"is_first_turn":true}}' "$sid" \
  | bash hooks/session-start.sh --format hermes > "$TEST_ROOT/hermes-first.json"
python3 - "$TEST_ROOT/hermes-first.json" <<'PY'
import json, sys
from pathlib import Path
assert "context" in json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
PY
printf '{"session_id":"%s","extra":{"is_first_turn":false}}' "$sid" \
  | bash hooks/session-start.sh --format hermes > "$TEST_ROOT/hermes-second.json"
grep -qx '{}' "$TEST_ROOT/hermes-second.json"
pass "Hermes first-turn gate"

python_path="$TEST_ROOT/python-bin"
mkdir -p "$python_path"
for command in cat date dirname head mkdir mv python3 sed tail; do
  install_test_command "$python_path" "$command"
done
PATH="$python_path" /bin/bash -c \
  'printf '\''{"session_id":"python-only","extra":{"is_first_turn":true}}'\'' | /bin/bash hooks/session-start.sh --format hermes' \
  > "$TEST_ROOT/hermes-python.json"
python3 - "$TEST_ROOT/hermes-python.json" <<'PY'
import json, sys
from pathlib import Path
assert "context" in json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
PY
pass "Hermes Python parser without jq"

minimal_path="$TEST_ROOT/minimal-bin"
mkdir -p "$minimal_path"
for command in cat date dirname head mkdir mv sed; do
  install_test_command "$minimal_path" "$command"
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

crlf_root="$TEST_ROOT/crlf-content"
mkdir -p "$crlf_root/hooks" "$crlf_root/.claude-plugin" \
  "$crlf_root/context" "$crlf_root/skills/load-context"
cp hooks/session-start.sh "$crlf_root/hooks/"
cp .claude-plugin/plugin.json "$crlf_root/.claude-plugin/"
cp skills/load-context/SKILL.md "$crlf_root/skills/load-context/"
cp prompt.md security-posture.md lore.md user.md "$crlf_root/"
cp context/research-index.md "$crlf_root/context/"
python3 - "$crlf_root" <<'PY'
import sys
from pathlib import Path

root = Path(sys.argv[1])
for relative in ("prompt.md", "security-posture.md", "lore.md", "user.md", "context/research-index.md"):
    path = root / relative
    path.write_bytes(path.read_bytes().replace(b"\n", b"\r\n"))
PY
bash "$crlf_root/hooks/session-start.sh" --format claude > "$TEST_ROOT/crlf.json"
python3 - "$TEST_ROOT/crlf.json" "$crlf_root/skills/load-context/SKILL.md" <<'PY'
import json, re, sys
from pathlib import Path

context = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))["hookSpecificOutput"]["additionalContext"]
hook_hash = re.search(r'delivery="session-start" context_sha256="([0-9a-f]{64})"', context).group(1)
skill_hash = re.search(r'delivery="skill" context_sha256="([0-9a-f]{64})"', Path(sys.argv[2]).read_text(encoding="utf-8")).group(1)
assert hook_hash == skill_hash
PY
pass "CRLF context normalization"

manual_home="$TEST_ROOT/manual-home"
manual_settings="$manual_home/settings.json"
mkdir -p "$manual_home"
HOME="$manual_home" ./install.sh --target claude --settings "$manual_settings" >/dev/null
HOME="$manual_home" ./install.sh --target claude --settings "$manual_settings" >/dev/null
python3 - "$manual_settings" "$ROOT/hooks/session-start.sh" <<'PY'
import json, sys
from pathlib import Path

doc = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
entries = doc["hooks"]["SessionStart"]
assert len(entries) == 1
handler = entries[0]["hooks"][0]
assert handler == {"type": "command", "command": "bash", "args": [sys.argv[2]], "timeout": 15}
PY
HOME="$manual_home" ./install.sh --uninstall --target claude --settings "$manual_settings" >/dev/null
python3 - "$manual_settings" <<'PY'
import json, sys
from pathlib import Path
assert json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))["hooks"]["SessionStart"] == []
PY
pass "manual installer idempotency and rollback"

runtime_home="$TEST_ROOT/runtime-home"
mkdir -p "$runtime_home"
HOME="$runtime_home" ./install.sh --target hermes,kimi >/dev/null
python3 - "$runtime_home" "$ROOT/hooks/session-start.sh" <<'PY'
import json, sys, tomllib
from pathlib import Path

home, hook = Path(sys.argv[1]), sys.argv[2]
hermes = (home / ".hermes/config.yaml").read_text(encoding="utf-8")
kimi = tomllib.loads((home / ".kimi-code/config.toml").read_text(encoding="utf-8"))
allowlist = json.loads((home / ".hermes/shell-hooks-allowlist.json").read_text(encoding="utf-8"))
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
    assert not any(name.startswith("sessions/") for name in archive.namelist())
    mode = archive.getinfo("hooks/session-start.sh").external_attr >> 16
    assert mode & stat.S_IXUSR
PY
pass "custom-plugin ZIP"

python3 - <<'PY'
import re, subprocess
from pathlib import Path

missing = []
tracked = subprocess.run(
    ["git", "ls-files", "*.md"], check=True, capture_output=True, text=True
).stdout.splitlines()
for name in tracked:
    document = Path(name)
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
