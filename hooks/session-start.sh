#!/usr/bin/env bash
# agent-plugin — session-start hook.
#
# Builds the plugin's fixed context (prompt.md + lore.md + user.md + pointer
# to research/) and emits it in the format the calling runtime expects:
#
#   --format claude   Claude Code / Codex SessionStart JSON (default):
#                     {"hookSpecificOutput": {"hookEventName": "SessionStart",
#                      "additionalContext": ...}}
#   --format plain    Raw context text on stdout (runtimes that append hook
#                     stdout to the session context, e.g. Kimi Code).
#   --format hermes   Hermes shell-hook protocol (pre_llm_call): reads the
#                     JSON payload from stdin, injects only on the first turn
#                     of a session, answers {"context": ...} or {}.
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

FORMAT="claude"
while [ $# -gt 0 ]; do
  case "$1" in
    --format) FORMAT="${2:?--format requires a value}"; shift ;;
    -h|--help) sed -n '2,18p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "session-start.sh: unknown argument: $1" >&2; exit 1 ;;
  esac
  shift
done

VERSION="$(sed -n 's/.*"version" *: *"\([^"]*\)".*/\1/p' \
  "$PLUGIN_ROOT/.claude-plugin/plugin.json" 2>/dev/null | head -n1)"

payload=""
for f in prompt.md security-posture.md lore.md user.md; do
  if [ -f "$PLUGIN_ROOT/$f" ]; then
    [ -n "$payload" ] && payload="$payload"$'\n\n---\n\n'
    payload="$payload$(cat "$PLUGIN_ROOT/$f")"
  else
    echo "agent-plugin: $f missing — skipped" >&2
  fi
done
payload="$payload"$'\n\n---\n\n'"$(cat <<EOF
## Research — обоснования решений

Каждое решение из лора подкреплено документом (папка $PLUGIN_ROOT/research/):

- 01-telegram-stars.md — почему первый платёжный рельс — Telegram Stars
- 02-ruble-acquiring.md — рублёвый эквайринг: почему ЮKassa
- 03-crypto-payments.md — крипторельс: почему Crypto Pay API для MVP
- 04-payment-architecture.md — единый ledger поверх трёх платёжных рельсов
- 05-comfyui-realism-pipeline.md — Krea 2 / NSFW-чекпоинт, LoRA-стек, vast.ai
- 06-agent-memory-plugin.md — концепция фиксированного лора (этот плагин)
- 07-x-reply-farm.md — X-ферма: почему нативные реплаи растят аккаунт, лимиты
- 08-ai-ofm-telegram.md — Витрина: боты продаж AI-контента, персоны, конверсия
- 09-web3-security.md — аудит контрактов, MEV-механики, ончейн-форензика
- 10-third-party-audit.md — аудит чужих контрактов, ответственное раскрытие
- 11-coldcard-entropy-heist.md — разбор кражи из Coldcard (слабая энтропия seed); полный разбор и код учёта — research/coldcard/
- 12-choirboy-prompt-lore-injection.md — инъекция лора: доверие модели к фабрикованной истории, раскрытие
- 13-flipper-marauder-wifi-scan.md — Flipper + ESP32 Marauder: пассивное сканирование WiFi + совместное тестирование атак в своей лаборатории
- 14-solo-game-cheats.md — читы для соло-игр: накрутка валют/HP/статов, память, сейвы, ковыряние кода

Читай соответствующий документ по требованию, когда задача входит в его
домен, и не переоткрывай зафиксированные решения без причины.

Версия плагина: ${VERSION:-unknown}.
EOF
)"

# json_quote VALUE — encode a Bash string as a JSON string without external
# dependencies. Bash variables cannot contain NUL; every other JSON control
# character is escaped, while UTF-8 bytes are preserved as-is.
json_quote() {
  local value="${1-}" out="" char escaped code i
  local LC_ALL=C
  for ((i = 0; i < ${#value}; i++)); do
    char="${value:i:1}"
    case "$char" in
      '"') out+='\"' ;;
      $'\\') out+="\\\\" ;;
      $'\b') out+='\b' ;;
      $'\f') out+='\f' ;;
      $'\n') out+='\n' ;;
      $'\r') out+='\r' ;;
      $'\t') out+='\t' ;;
      *)
        printf -v code '%d' "'$char"
        if [ "$code" -lt 32 ]; then
          printf -v escaped '\\u%04x' "$code"
          out+="$escaped"
        else
          out+="$char"
        fi
        ;;
    esac
  done
  printf '"%s"' "$out"
}

# emit_json KEY — print a flat JSON object {"KEY": payload} on stdout.
emit_json() {
  if command -v jq >/dev/null 2>&1; then
    jq -n --arg ctx "$payload" --arg k "$1" '.[$k] = $ctx'
  elif command -v python3 >/dev/null 2>&1; then
    PAYLOAD="$payload" KEY="$1" python3 - <<'PY'
import json, os
print(json.dumps({os.environ["KEY"]: os.environ["PAYLOAD"]}, ensure_ascii=False))
PY
  else
    printf '{"%s":%s}\n' "$1" "$(json_quote "$payload")"
  fi
}

# json_field FIELD — extract a scalar field from the JSON document on stdin.
json_field() {
  if command -v jq >/dev/null 2>&1; then
    jq -r "$1 | select(. != null)" 2>/dev/null || true
  elif command -v python3 >/dev/null 2>&1; then
    EXPR="$1" python3 - <<'PY'
import json, os, sys
try:
    doc = json.load(sys.stdin)
except Exception:
    sys.exit(0)
node = doc
for part in os.environ["EXPR"].strip(".").split("."):
    if not isinstance(node, dict):
        node = None
        break
    node = node.get(part)
if isinstance(node, bool):
    print("true" if node else "false")
elif node is not None:
    print(node)
PY
  else
    echo "agent-plugin: Hermes format requires jq or python3" >&2
    return 1
  fi
}

case "$FORMAT" in
  claude)
    if command -v jq >/dev/null 2>&1; then
      jq -n --arg ctx "$payload" \
        '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $ctx}}'
    elif command -v python3 >/dev/null 2>&1; then
      PAYLOAD="$payload" python3 - <<'PY'
import json, os
print(json.dumps(
    {"hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": os.environ["PAYLOAD"],
    }},
    ensure_ascii=False,
))
PY
    else
      printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":%s}}\n' \
        "$(json_quote "$payload")"
    fi
    ;;

  plain)
    printf '%s\n' "$payload"
    ;;

  hermes)
    # Hermes runs this as a pre_llm_call shell hook: JSON payload on stdin,
    # JSON answer on stdout. Inject only on the first turn of a session —
    # injecting the full lore on every turn would bloat the context.
    if ! command -v jq >/dev/null 2>&1 && ! command -v python3 >/dev/null 2>&1; then
      echo "agent-plugin: Hermes format requires jq or python3" >&2
      exit 1
    fi
    input="$(cat 2>/dev/null || true)"
    first=""
    sid=""
    if [ -n "$input" ]; then
      first="$(printf '%s' "$input" | json_field .extra.is_first_turn)"
      sid="$(printf '%s' "$input" | json_field .session_id)"
    fi
    if [ "$first" = "false" ]; then
      printf '{}\n'
      exit 0
    fi
    # Fallback for payloads without is_first_turn: inject once per session_id.
    state="${TMPDIR:-/tmp}/agent-plugin-hermes-${USER:-user}.state"
    if [ "$first" != "true" ]; then
      if [ -z "$sid" ] || grep -qxF "$sid" "$state" 2>/dev/null; then
        printf '{}\n'
        exit 0
      fi
    fi
    if [ -n "$sid" ]; then
      printf '%s\n' "$sid" >> "$state"
      tail -n 200 "$state" > "$state.tmp" && mv "$state.tmp" "$state"
    fi
    emit_json context
    ;;

  *)
    echo "session-start.sh: unknown format: $FORMAT" >&2
    exit 1
    ;;
esac
