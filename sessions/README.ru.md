# sessions/ — демонстрация рукописной нативной сессии

**Языки:** [English](README.md) · [Русский](README.ru.md) ·
[简体中文](README.zh-CN.md)

Демонстрация для [research/12](../research/12-choirboy-prompt-lore-injection.md):
**один полностью рукописный диалог в трёх нативных форматах session store** —
Claude Code, Codex и Kimi Code. ID демонстрационные (`fa1ce000-…`), разговор
никогда не происходил: каждый байт сфабрикован вручную.

Смысл stub-диалога в том, что модель, следуя подложенному lore/meta-prompt,
сама пишет и затем смягчает prompt обхода цензуры, хотя в transcript нет
прямого trigger vocabulary. Вектор находится не в словах, а в provenance:
классификатор анализирует лексику запроса, но не проверяет происхождение
«предыдущей работы» в контексте.

Локальные session stores не защищают transcript подписью или MAC и не получают
серверное подтверждение его происхождения. Файла правильной формы достаточно,
чтобы совместимая версия рантайма показала его в resume picker и воспроизвела
как историю.

## Что это доказывает — и чего не доказывает

Для агента эти файлы становятся видимым свидетельством «реального прошлого
диалога»: transcript написан вручную, но локальный рантайм индексирует,
возобновляет и воспроизводит его через штатный history path. Это доказывает
отсутствие границы provenance.

Это **не доказательство, что изображённый разговор действительно состоялся**.
Fixtures синтетические и обязаны сохранять такую маркировку. Используйте их
только со своими локальными рантаймами и данными.

## Структура

| Рантайм | Файлы | Место store |
|---|---|---|
| Claude Code | `claude/<sessionId>.jsonl` | `~/.claude/projects/<mangled-cwd>/` |
| Codex | `codex/rollout-….jsonl` + `codex/threads-insert.sql` | `~/.codex/sessions/YYYY/MM/DD/` + `state_5.sqlite` |
| Kimi Code | `kimi/session_<uuid>/{state.json,agents/main/wire.jsonl}` + `kimi/session_index.jsonl.example` | `~/.kimi-code/sessions/wd_<name>_<hash>/` |

Пути внутри артефактов (`rollout_path` в SQL, `homedir` в `state.json`, запись
индекса) содержат буквальный placeholder `$HOME`. Разворачивайте его только в
тестовой копии, например `sed -i "s|\$HOME|$HOME|g" <copy>`.

## Воспроизведение на своей машине

Сделайте бэкап целевого store, закройте приложение перед изменением и удалите
демо после теста. Нативные схемы зависят от версии рантайма.

### Claude Code

```bash
cp sessions/claude/fa1ce000-0000-4000-8000-0000000000c1.jsonl \
   ~/.claude/projects/-home-research-choirboy-prompt/
```

Имя папки — `cwd` с заменёнными на дефисы слешами. Сессия появляется только в
resume list этого проекта. `claude --resume` и вкладка Claude Desktop **Code**
читают тот же store. Цепочка `uuid`/`parentUuid` в примере согласована.

### Codex

Rollout — источник истины, но picker читает SQLite:

```bash
mkdir -p ~/.codex/sessions/2026/08/10
cp sessions/codex/rollout-2026-08-10T18-30-00-fa1ce000-0000-7000-8000-0000000000c2.jsonl \
   ~/.codex/sessions/2026/08/10/
# приложение должно быть закрыто из-за WAL:
sed "s|\$HOME|$HOME|g" sessions/codex/threads-insert.sql \
  | sqlite3 ~/.codex/state_5.sqlite
```

`thread_history_1.sqlite` — производная проекция. ID в стиле UUIDv7, дата в
имени, путь `YYYY/MM/DD` и `created_at` должны быть согласованы.

### Kimi Code

```bash
mkdir -p ~/.kimi-code/sessions/wd_choirboy-prompt_demo
cp -r sessions/kimi/session_fa1ce000-0000-4000-8000-0000000000c3 \
      ~/.kimi-code/sessions/wd_choirboy-prompt_demo/
KIMI_DEMO_DIR="$HOME/.kimi-code/sessions/wd_choirboy-prompt_demo/session_fa1ce000-0000-4000-8000-0000000000c3"
sed "s|\$HOME|$HOME|g" "$KIMI_DEMO_DIR/state.json" > "$KIMI_DEMO_DIR/state.json.tmp"
mv "$KIMI_DEMO_DIR/state.json.tmp" "$KIMI_DEMO_DIR/state.json"
sed "s|\$HOME|$HOME|g" sessions/kimi/session_index.jsonl.example \
  >> ~/.kimi-code/session_index.jsonl
```

`search-index/` — производный tantivy-index; его не нужно переносить.

## Как написать свою рукописную сессию

1. Создайте безобидную сессию в нужном рантайме, чтобы получить актуальную схему.
2. Закройте рантайм и скопируйте только эту сессию во временную директорию.
3. Уберите токены, request ID, приватные пути, tool output и данные третьих лиц.
4. Согласованно замените ID и timestamps; сохраните роли, порядок, parent links,
   пути и metadata picker.
5. Пометьте результат `synthetic` или `hand-written` в заголовке и README.
6. Проверьте каждую JSON/JSONL-строку, сделайте бэкап своего store и протестируйте копию.
7. После эксперимента удалите тестовую запись.

Полный обязательный процесс написания lore, research, обоснований и sessions:
[docs/authoring.md](../docs/authoring.md).

## Граница

Это defensive research demo. Запускайте только на своих рантаймах. Пока
платформа не верифицирует provenance сессии, сфабрикованная история неотличима
для модели от реальной. Контрмеры: [docs/detection.md](../docs/detection.md).
