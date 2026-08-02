# Тестирование

Проверки хука и установщика: ad-hoc сьют, который реально гоняется
перед правками. Канонического тест-раннера в проекте нет — сьют
собран из bash-проверок, запускаемых вручную или из CI.

---

## 1. Принцип

- Каждая проверка — отдельная bash-команда с явным PASS/FAIL.
- Сьют запускается из любого места; временные файлы — под `/tmp` с
  префиксом `hermes-verify-`.
- После прогона временные файлы удаляются.
- Пейлоад проверяется **в том виде, в каком его получит рантайм**, а
  не «по наитию».

---

## 2. Проверки хука

### 2.1. Manifest и версия

```bash
python3 -c 'import json; d=json.load(open(".claude-plugin/plugin.json")); print(d["name"], d["version"])'
```

Ожидание: валидный JSON, имя и версия печатаются. Версия — единственное
место версии; она же печатается в пейлоаде.

### 2.2. Claude-формат — валидный JSON с контекстом

```bash
bash hooks/session-start.sh --format claude \
  | python3 -c 'import json,sys; d=json.load(sys.stdin); assert "additionalContext" in d["hookSpecificOutput"]; print("OK")'
```

Ожидание: `OK`. Дополнительно проверить, что контекст содержит первый
заголовок `prompt.md` и «Версия плагина:».

### 2.3. Plain-формат — человекочитаемый пейлоад

```bash
bash hooks/session-start.sh --format plain | head -40
```

Ожидание: заголовки prompt → posture → lore → user → research-указатель
в правильном порядке, разделители `---`.

### 2.4. Hermes: первый ход внедряет

```bash
SID="demo-$(date +%s)"
printf '{"session_id":"%s","extra":{"is_first_turn":true}}' "$SID" \
  | bash hooks/session-start.sh --format hermes | head -c 120
```

Ожидание: `{"context": "..."` — пейлоад пришёл.

### 2.5. Hermes: второй ход молчит

```bash
SID="demo-$(date +%s)"
printf '{"session_id":"%s","extra":{"is_first_turn":false}}' "$SID" \
  | bash hooks/session-start.sh --format hermes
```

Ожидание: `{}`.

### 2.6. Hermes: фолбэк без флага — один раз на session_id

```bash
SID="demo-fb-$(date +%s)"
printf '{"session_id":"%s"}' "$SID" \
  | bash hooks/session-start.sh --format hermes | head -c 120   # → context
printf '{"session_id":"%s"}' "$SID" \
  | bash hooks/session-start.sh --format hermes                 # → {}
```

Ожидание: первый вызов — `{"context": ...`, второй — `{}`.

> Питфолл: после теста почистить sid из state-файла
> `${TMPDIR:-/tmp}/agent-plugin-hermes-${USER}.state`, иначе фолбэк
> «запомнит» sid и следующий прогон с тем же sid вернёт `{}`.

### 2.7. Hermes: пустой stdin не роняет хук

```bash
printf '' | bash hooks/session-start.sh --format hermes
```

Ожидание: `{}` (не ошибка). Причина: `input="$(cat 2>/dev/null || true)"`.

---

## 3. Проверки установщика

### 3.1. --list

```bash
./install.sh --list
```

Ожидание: колонки TARGET/STATUS/LOCATION; статусы `absent`/`detected`/
`installed`.

### 3.2. Идемпотентность

```bash
./install.sh --target hermes ; ./install.sh --target hermes
```

Ожидание: второй запуск печатает `already present — skipped` /
`unchanged`; файлы не дублируются.

### 3.3. Бэкапы

После установки в существующий файл проверить:

```bash
ls -la ~/.hermes/config.yaml.bak.*
```

Ожидание: бэкап с timestamp существует.

### 3.4. Откат

```bash
./install.sh --uninstall --target hermes
./install.sh --list | grep hermes   # → detected (не installed)
```

Ожидание: блок удалён, маркер `agent-plugin:vibe-lore` в конфиге
отсутствует.

### 3.5. Хук не падает без контент-файлов

Имитация свежего клона (без `prompt.md`/`lore.md`/`user.md`):

```bash
TMP=$(mktemp -d)
cp -r hooks .claude-plugin "$TMP/"
# контент-файлов в TMP нет
bash "$TMP/hooks/session-start.sh" --format plain >/dev/null 2>&1
echo "exit=$?"   # ожидание: 0 (graceful-режим: файлы пропущены с предупреждением в stderr)
rm -rf "$TMP"
```

Graceful-режим реализован в `hooks/session-start.sh`: отсутствующие
контент-файлы пропускаются с предупреждением в stderr, хук не падает
с `set -euo pipefail` (см. `docs/security.md` §3.3).

### 3.6. Переезд папки плагина

Установить, переместить папку, установить снова:

```bash
./install.sh --target claude
mv /path/to/plugin /path/to/plugin-moved
/path/to/plugin-moved/install.sh --target claude
```

Ожидание: в `~/.claude/settings.json` одна запись нашего хука (не две);
старая заменилась новой — `json_hook` матчит по имени скрипта.

---

## 4. Проверки контента (санитизация)

Перед любой публикацией:

```bash
# запрещённые идентификаторы (имена NSFW/refusal-моделей, пути к
# приватным проектам). Конкретный список имён — приватный чек-лист,
# вне репо; здесь — обобщённый паттерн:
grep -rniE "(nsfw-(checkpoint|lora)|refusal-reduction|private-research)" --include="*.md" --include="*.sh" .
# полные адреса
grep -rnoE "bc1[a-zA-Z0-9]{20,}|0x[a-fA-F0-9]{40}" .
# замыкание: все ссылки на файлы существуют
for f in $(grep -rhoE "(research/[0-9]+-[a-z-]+\.md|research/coldcard/[a-z_.]+\.(md|py))" --include="*.md" . | sort -u); do
  [ -f "$f" ] || echo "BROKEN: $f"
done
```

Ожидание: grep'ы пустые; замыкание без BROKEN.

---

## 5. Быстрый сьют одной командой

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

## 6. Когда запускать

- После любой правки `hooks/session-start.sh` — п. 2.2–2.7.
- После правки `install.sh` — п. 3.1–3.6.
- После правки контентных файлов — п. 4 (замыкание, санитизация).
- После правки `instruction_block` — grep по маркеру в установленных
  файлах (см. `docs/installer.md` §3.3).
